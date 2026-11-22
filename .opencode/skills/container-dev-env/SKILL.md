---
name: 容器化开发环境
description: 通用容器化开发与构建环境、Dev Container 工作流：为项目选择或创建 Dockerfile、devcontainer.json、run.sh，处理非 root UID/GID、挂载与 SELinux、共享缓存、GUI/GPU 直通、许可证和可复现构建。也覆盖本仓库的 Yocto/PetaLinux/Vitis/Buildroot/Zephyr 镜像。Use when containerizing a development or build environment, writing .devcontainer, debugging container mounts/permissions/caches, or building this repository's images.
---

# 容器化开发环境

## 核心原则

1. **开发和构建一律进容器**。宿主机只负责：源码编辑、容器运行时（Podman/Docker）、
   GUI 服务器、许可证文件、缓存目录。
2. 宿主机缺工具时，优先创建或更新镜像、devcontainer，不要在宿主机安装工具链。
3. 镜像内使用非 root 用户，UID/GID 与宿主一致；工作目录固定（本仓库统一
   `/workspace`）。
4. 安装包、许可证、密钥不进镜像层：构建期用只读构建卷，运行期用只读 bind mount。
5. 版本可复现：基础镜像固定 tag 或 digest，工具链版本通过 build arg 传入。

## 先判断场景

| 场景 | 做法 |
| --- | --- |
| 已有镜像可用 | 写 `run.sh` 包装 `docker run`，复用镜像和缓存 |
| 需要 IDE/终端一体化 | 增加 `.devcontainer/devcontainer.json`，共用同一镜像 |
| 工具链不满足 | 改 Dockerfile，加 build arg 或多阶段构建 |
| 多服务（数据库、调试器） | Docker Compose + devcontainer `dockerComposeFile` |
| 一次性命令 | `docker run --rm`，但仍挂载源码与缓存 |

优先复用现有镜像和脚本，不要为每个任务新建环境。

## 通用工作流

1. **盘点依赖**：语言/工具链、系统库、GUI、设备、许可证、缓存位置。
2. **选基础镜像**：官方或组织内镜像；CI/生产固定 digest，开发可用 tag。
3. **写 Dockerfile**：
   - `ARG UBUNTU_APT_MIRROR`（或对应发行版的镜像参数）
   - `ARG USER_ID` / `GROUP_ID`，创建非 root 用户并配置 sudo
   - 安装依赖、locale，设置 `WORKDIR /workspace`
   - 预建缓存目录，避免容器内 root 属主
   - 入口脚本处理信号并用 `exec` 启动实际命令
4. **写 devcontainer.json**：
   - `build.dockerfile` + `build.context`，或直接 `image`
   - `remoteUser`、`updateRemoteUserUID`
   - `mounts` 挂缓存与源码，`containerEnv` 传路径
   - `postCreateCommand` 只做幂等初始化
   - `--userns=keep-id` 等运行时参数放 `runArgs`
5. **写 run.sh**：
   - `--rm`、`--userns=keep-id`、`--hostname`
   - 源码挂到 `/workspace`
   - 缓存目录挂载；项目内有软链时再加同路径挂载
   - 条件 `-it`；`exec docker run ...`
6. **缓存**：宿主目录优先（可检查、可备份）；统一 `~/.cache/<project>`；
   下载缓存与编译缓存分层。
7. **验证**：`id`、工具版本、最小构建、缓存写入能回宿主、GUI/许可证冒烟。

## 缓存与挂载

- 缓存根默认放宿主 `~/.cache/...`，不要放在镜像层或容器可写层。
- 多个容器共享同一缓存时，容器内路径必须稳定；项目内软链接需要容器以
  **相同绝对路径**挂载缓存根才能解析。
- 下载缓存可以全局共享；编译/sstate 缓存按工具链版本和目标架构分层。
- 清理脚本要加锁，避免与构建并发；迁移后的缓存保留旧 mtime，不要立刻按小阈值
  GC。详细布局见 `references/caches.md`。

## GUI、GPU、许可证

- X11：挂载 `/tmp/.X11-unix`，传 `DISPLAY`/`XAUTHORITY`；Wayland 通过 XWayland。
- GPU：只挂载当前用户可读写的 `/dev/dri/*`；rootless Podman 用
  `--group-add keep-groups` 保留 render/video 组权限。
- 许可证：运行期只读挂载，优先浮动许可证服务器；不要把 `.lic` 提交或写入镜像。
- 旧图形栈（如 Vivado 2021.1）可能需要嵌套 Xephyr + 软件渲染，详见
  `references/runtime.md`。

## 安全边界

- 不把密钥、token、许可证、安装包写入镜像层或构建上下文。
- 大安装包用构建卷（Podman/Buildah）或构建后删除，不要 `COPY` 进层。
- 许可证只读挂载；尽量缩小 `--privileged`、`label=disable` 的使用范围。
- 容器内只保留必要的提权能力，避免给普通用户无密码 sudo 之外的额外路径。

## 本仓库

本仓库是上述模式的完整实现：Yocto、PetaLinux、Vitis/Vivado、Buildroot、Zephyr。
镜像矩阵、变量和命令见 `references/repo-images.md`。

```bash
cd yocto && ./run.sh /path/to/poky
cd petalinux && PETALINUX_VERSION=2021.1 ./common/run.sh /path/to/project
cd vitis && ./common/run.sh /path/to/project xsct
cd buildroot && ./run.sh /path/to/buildroot make
```

## 参考

- `references/devcontainer.md`：devcontainer.json 字段、变量、Podman 注意事项
- `references/dockerfile-patterns.md`：Dockerfile 与非 root 用户模式
- `references/runtime.md`：run.sh、挂载、SELinux、GUI/GPU、许可证
- `references/caches.md`：共享缓存、软链、GC
- `references/repo-images.md`：本仓库镜像矩阵
- `references/troubleshooting.md`：常见故障排查

模板在 `templates/`，复制后按项目修改。
