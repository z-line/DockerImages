# 运行容器

`run.sh` 的目标：把宿主源码、缓存、GUI 和许可证以最小权限、正确的 UID 映射交给
容器，并把剩余参数原样传给容器内命令。

## 基本骨架

```bash
#!/usr/bin/env bash
set -euo pipefail

image="${IMAGE_NAME:-project-dev:latest}"
source_dir="${1:-$PWD}"
cache_root="${CACHE_ROOT:-${XDG_CACHE_HOME:-${HOME}/.cache}/project}"
shift || true

mkdir -p "${cache_root}"
if [[ "$#" -eq 0 ]]; then
    set -- bash
fi

docker_args=(
    --rm
    --userns=keep-id
    --hostname project
    --volume "${source_dir}:/workspace:z"
    --volume "${cache_root}:${cache_root}:z"
    --workdir /workspace
    --env "CACHE_ROOT=${cache_root}"
)

if [[ -t 0 && -t 1 ]]; then
    docker_args+=(-it)
fi

exec docker run "${docker_args[@]}" "${image}" "$@"
```

## 用户与权限

### rootless Podman（推荐）

```bash
--userns=keep-id
```

容器内用户与调用者 UID 一致，挂载目录不会变成 root 属主。容器内还应使用非 root
用户（镜像 `USER`），否则 root 会映射到 subuid。

### Docker

标准 Docker 不支持 `--userns=keep-id`，用：

```bash
--user "$(id -u):$(id -g)"
```

或在镜像内创建与宿主 UID/GID 相同的用户。不要让容器以 root 写 bind mount。

### 检查

```bash
docker run --rm --userns=keep-id -v "$PWD:/workspace:z" image \
    bash -lc 'id; touch /workspace/.t && rm /workspace/.t'
```

## SELinux

| 方式 | 行为 | 适用 |
| --- | --- | --- |
| `:z` | 共享标签，允许容器访问 | 多个容器共享同一目录 |
| `:Z` | 私有标签，仅当前容器 | 单容器独占目录 |
| `--security-opt label=disable` | 关闭该容器标签隔离 | GUI/X11、大目录避免重复 relabel |

- `:z` 会在每次启动时递归打标签，目录很大时启动明显变慢；缓存和构建树可达数十 GB。
- 只在必要时使用 `label=disable`，且限制在本地开发容器。
- 许可证文件用 `:ro,z`；X11 socket 用只读挂载。

## 挂载

```bash
--volume "${source_dir}:/workspace:z"          # 源码
--volume "${cache_root}/downloads:/downloads:z" # 下载缓存
--volume "${cache_root}/sstate:/sstate:z"       # 编译缓存
--volume "${cache_root}:${cache_root}:z"        # 同路径，供项目内软链解析
--volume /tmp/.X11-unix:/tmp/.X11-unix:ro       # X11
--device /dev/dri/renderD128                    # GPU（按需）
--volume "${license}:/run/licenses/tool.lic:ro,z"
```

### 为什么需要“同路径挂载”

项目里常见：

```text
build/downloads -> /home/user/.cache/project/downloads
```

这是宿主机绝对路径。容器只挂 `/workspace` 时软链悬空；把缓存根按**相同绝对路径**
再挂一次，软链在容器内即可解析。它不会复制数据，只是多一个挂载点。

## 环境变量

- 构建工具变量（`DL_DIR`、`SSTATE_DIR`、`CCACHE_DIR`）要与挂载路径一致。
- 需要覆盖项目配置时，注意优先级：很多工具的环境变量只覆盖默认值，项目配置文件
  里的显式赋值会赢。必要时通过项目配置或命令行参数处理。
- 用 `--env-file` 管理多个变量；不要把密钥写进脚本或镜像。

## GUI

### X11

```bash
--env "DISPLAY=${DISPLAY}"
--volume /tmp/.X11-unix:/tmp/.X11-unix:ro
--env XAUTHORITY=/tmp/.Xauthority
--volume "${XAUTHORITY}:/tmp/.Xauthority:ro,z"
```

- 只复制当前 `DISPLAY` 的 cookie，不要挂整个 `~/.Xauthority`。
- 没有可读 cookie 时，可临时 `xhost +si:localuser:$(id -un)`，用完撤销。
- Wayland 桌面通过 XWayland 提供 X11 socket。

### 嵌套桌面

旧版 Qt/Java/SWT 应用在现代 Mesa/Wayland 下可能白屏或卡死。做法：

- 容器内启动 Xephyr + 窗口管理器（如 Openbox），宿主只显示一个窗口。
- 强制软件渲染（`LIBGL_ALWAYS_SOFTWARE=1`）。
- 不要给旧版 Java 应用设置 `_JAVA_AWT_WM_NONREPARENTING=1`，否则模态框可能脱离管理。

## GPU

```bash
--device /dev/dri/renderD128
--group-add keep-groups      # rootless Podman，保留宿主附加组
```

- 先检查设备对当前用户可读写；不可用时回退软件渲染。
- `keep-groups` 需要较新的 Podman；不支持时给警告，不要直接失败。
- 不要在无 GPU 的环境里强制硬件渲染。

## 共享内存

GUI、浏览器、数据库等可能需要更大的 `/dev/shm`：

```bash
--shm-size 2g
```

按应用调整，不要默认给过大值。

## 主机名、IPC、init

- `--hostname` 固定主机名，避免构建脚本依赖随机名。
- 需要 Xephyr MIT-SHM 或进程间共享时用 `--ipc=host`，仅限可信本地开发。
- 需要正确处理僵尸进程时加 `--init` 或在镜像中使用 tini。

## Docker 与 Podman 差异

| 能力 | Docker | Podman |
| --- | --- | --- |
| `--userns=keep-id` | 不支持 | 支持 |
| 构建卷 `docker build --volume` | 不支持 | 支持（Buildah） |
| rootless 默认 | 需配置 | 默认 |
| `--group-add keep-groups` | 不适用 | 较新版本支持 |
| SELinux `:z` | 支持 | 支持 |

本仓库的脚本按 Podman 兼容层编写；在标准 Docker 上运行前先确认参数兼容性。

## 验证清单

```bash
id                                  # 非 root，UID 与宿主一致
pwd                                 # /workspace
touch /workspace/.write-test        # 挂载可写
ls /downloads /sstate-cache         # 缓存可见
command -v <tool>                   # 工具链存在
<tool> --version
```

GUI/许可证任务再补：窗口能打开、许可证可读、GPU 或软件渲染路径符合预期。
