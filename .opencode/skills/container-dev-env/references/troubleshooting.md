# 排错

按“症状 → 检查 → 处理”的顺序排查。容器问题优先区分：运行时、权限、挂载、网络、
工具链。

## 运行时

### `unknown userns mode: keep-id`

使用的是标准 Docker。两种处理：

- 改用 Podman（本仓库脚本按 Podman 兼容层编写）；
- 或把 `--userns=keep-id` 换成 `--user "$(id -u):$(id -g)"`。

### 构建卷不支持

`docker build --volume ...` 只有 Podman/Buildah 支持。标准 Docker 需要：

- 把安装包放入构建上下文，用 `RUN --mount=type=bind`；
- 或复制进上下文后在同一层删除（注意中间层残留）；
- 或改用 `COPY` + 接受体积代价。

### 命令不存在

```bash
command -v <tool>
echo "$PATH"
```

确认进入的是目标镜像，而不是宿主或其他镜像；检查 `IMAGE_NAME` 是否覆盖了标签。

## 权限

### `permission denied` 写挂载目录

```bash
id                       # 容器内 UID/GID
ls -ld /workspace        # 宿主属主
```

处理：

- rootless Podman 加 `--userns=keep-id`；
- Docker 加 `--user "$(id -u):$(id -g)"`；
- 镜像内用户 UID/GID 与宿主一致；
- 预建缓存目录并 `chown`，避免 root 属主。

### 缓存目录属主变成 root

通常是把缓存挂在容器可写层外、又用 root 写入造成的。修正属主后，确保容器内以
非 root 用户运行。

### SELinux 拒绝

```bash
getenforce
```

- 需要共享标签：挂载加 `:z`；
- 独占目录：`:Z`；
- GUI/X11 或超大目录：`--security-opt label=disable`（仅本地开发）。

### 启动特别慢

`:z` 会递归重打标签。构建树/缓存很大时：

- 只对必要目录加 `:z`；
- 或对开发容器使用 `label=disable`；
- 检查是否重复挂载同一目录（同路径挂载 + 子路径挂载会各打一次标签）。

## 安装包与构建

### `installer not found`

- 路径是否指向真实文件（不是断链）；
- Vitis/PetaLinux 对安装包文件名有校验，必须使用预期名称；
- PetaLinux 2026.1 会临时复制到构建上下文，检查磁盘空间。

### 构建上下文找不到文件

- 软链接指向上下文外时 Docker 无法跟随；
- 用 `readlink -f` 确认真实路径；
- 大安装包优先用构建卷。

### 构建层过大

- 安装包是否 `COPY` 进层；
- 是否在同一 `RUN` 中清理 apt 缓存和临时文件；
- 多阶段是否把编译依赖带进运行时。

## Dev Container

### 容器启动后立刻退出

- `remoteUser` 用户不存在；
- `overrideCommand` 与入口脚本冲突；
- `postCreateCommand` 失败导致后续中断。

### UID 不匹配 / 文件属主异常

- `updateRemoteUserUID` 在 Podman 下可能不生效；
- 在 Dockerfile 中直接用宿主 UID/GID 构建用户；
- 检查 `runArgs` 是否与运行时兼容。

### 挂载没生效

- `mounts` 字符串是否符合 `docker run --mount` 语法；
- `${localEnv:HOME}` 在 Windows 上可能为空；
- 宿主机源路径不存在时，部分工具会创建 root 属主目录。

### IDE 与命令行环境不一致

- devcontainer 和 `run.sh` 是否使用同一镜像、同一用户、同一挂载；
- `containerEnv` 与 `run.sh` 的 `--env` 是否一致。

## GUI

### 窗口空白/白屏

- 是否缺少 X11 socket 或 `DISPLAY`；
- 旧 Qt/SWT/Java 应用是否需要强制 X11、GTK2、软件渲染；
- Vivado 2021.1 使用嵌套 Xephyr + Openbox；确认 `vitis:2021.1-gui` 镜像可用。

### 模态框脱离主窗口

不要设置 `_JAVA_AWT_WM_NONREPARENTING=1`；让嵌套窗口管理器管理父子关系。

### `cannot open display`

```bash
echo "$DISPLAY"
ls /tmp/.X11-unix
xauth list "$DISPLAY"
```

没有 cookie 时可临时 `xhost +si:localuser:$(id -un)`，用完撤销。

### GPU 未启用

```bash
ls -l /dev/dri
id
```

- 设备需对当前用户可读写；
- rootless Podman 需要 `--group-add keep-groups`；
- 不支持时设置 `VITIS_USE_GPU=0` 走软件渲染。

## 许可证

### `license not found`

```bash
echo "$XILINXD_LICENSE_FILE"
ls -l /run/licenses/
```

- 确认使用 `VIVADO_LICENSE_FILE` 或 `VIVADO_LICENSE_SERVER`；
- 许可证是否只读挂载成功；
- 文件内容/服务器地址是否正确；
- 不要把许可证提交到仓库或写入镜像。

## 缓存

### 构建没有命中缓存

1. `echo "$DL_DIR" "$SSTATE_DIR"`；
2. 检查项目配置是否显式覆盖了环境变量（强赋值优先）；
3. 检查版本层是否正确（`YOCTO_VERSION` / `PETALINUX_VERSION`）；
4. 检查目标架构层（`*_SSTATE_ARCH`）；
5. 在容器内 `readlink -f` 确认软链指向共享目录；
6. 确认缓存根已同路径挂载。

### 软链在容器内悬空

项目内软链通常是宿主绝对路径。运行时需要：

```bash
--volume "$HOME/.cache/project:$HOME/.cache/project:z"
```

### 清理后大量重建

- sstate 按 mtime 清理，迁移来的缓存保留旧时间；
- 不要刚迁移完就用较小的 `--sstate-days`；
- 清理前用 `info` 确认范围和占用。

### 磁盘满

```bash
df -h ~/.cache
du -sh ~/.cache/project/*
```

优先清理编译缓存；下载缓存按项目人工清理。把大缓存放到独立磁盘可避免占满根分区。

## 生成配置被覆盖

PetaLinux 的 `build/conf/local.conf` 是自动生成的。不要直接编辑：

- 用 `project-spec/meta-user/conf/petalinuxbsp.conf` 覆盖；
- 或在项目内使用软链接入共享缓存。

## 测试失败

先跑镜像契约测试：

```bash
cd vitis && make test
cd petalinux && make test
```

测试会验证：非 root 用户、工具命令存在、工作目录可写、缓存挂载回宿主、GUI 依赖、
许可证只读挂载。失败时先区分镜像问题还是挂载问题。
