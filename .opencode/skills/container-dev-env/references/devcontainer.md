# Dev Container 配置

`devcontainer.json` 描述“如何把一个镜像变成开发环境”。优先复用 `run.sh` 使用的
同一个镜像，避免 IDE 与命令行的工具链、用户、挂载不一致。

## 最小示例

```jsonc
{
  "name": "project-dev",
  "build": {
    "dockerfile": "../Dockerfile.dev",
    "context": "..",
    "args": {
      "USER_ID": "${localEnv:USER_ID:1000}",
      "GROUP_ID": "${localEnv:GROUP_ID:1000}"
    }
  },
  "remoteUser": "dev",
  "updateRemoteUserUID": true,
  "workspaceFolder": "/workspace",
  "workspaceMount": "source=${localWorkspaceFolder},target=/workspace,type=bind",
  "mounts": [
    "source=${localEnv:HOME}/.cache/project,target=/home/dev/.cache,type=bind"
  ],
  "containerEnv": {
    "CACHE_ROOT": "/home/dev/.cache"
  },
  "postCreateCommand": "true",
  "customizations": {
    "vscode": { "extensions": [] }
  }
}
```

也可以直接引用已构建镜像：

```jsonc
{
  "name": "project-dev",
  "image": "registry.example.com/project-dev:2026.1",
  "remoteUser": "dev",
  "workspaceFolder": "/workspace"
}
```

## 常用字段

| 字段 | 作用 | 注意 |
| --- | --- | --- |
| `image` | 直接使用镜像 | 与 `build` 二选一 |
| `build.dockerfile` / `build.context` | 构建镜像 | 路径相对 `devcontainer.json` |
| `build.args` | 构建参数 | 可引用 `${localEnv:...}` |
| `build.target` | 多阶段目标 | CI 与开发可共用 Dockerfile |
| `remoteUser` | IDE/终端使用的用户 | 建议与 Dockerfile 的 `USER` 一致 |
| `containerUser` | 容器整体运行用户 | 一般不设，除非需要 root 启动 |
| `updateRemoteUserUID` | 将用户 UID/GID 改成宿主值 | 依赖运行时；Podman 下需实测 |
| `workspaceFolder` | IDE 打开的容器路径 | 必须与 `workspaceMount` 搭配 |
| `workspaceMount` | 源码挂载 | 字符串形式，同 `docker run --mount` |
| `mounts` | 额外挂载 | 缓存、GUI socket、GPU、许可证 |
| `containerEnv` | 容器级环境变量 | 静态，重建后生效 |
| `remoteEnv` | IDE/终端进程环境变量 | 可引用 `${containerEnv:...}` |
| `runArgs` | 传给 `docker run` 的参数 | Podman 专属参数需条件化 |
| `overrideCommand` | 覆盖镜像默认命令保持容器存活 | 默认 `true`；需要入口脚本时设 `false` |
| `shutdownAction` | 关闭窗口时的行为 | `stopContainer` / `stopCompose` / `none` |
| `features` | 安装 Dev Container Features | 与 Dockerfile 二选一或叠加 |
| `postCreateCommand` | 首次创建后的初始化 | 必须幂等，不要放长期服务 |
| `postStartCommand` | 每次启动执行 | 适合启动缓存预热等 |
| `hostRequirements` | CPU/内存/GPU 提示 | 仅提示，不负责分配 |

## 变量

| 变量 | 含义 |
| --- | --- |
| `${localEnv:VAR}` | 宿主环境变量，可给默认值 `${localEnv:VAR:default}` |
| `${containerEnv:VAR}` | 容器内已有环境变量（仅 `remoteEnv`） |
| `${localWorkspaceFolder}` | 宿主工作区路径 |
| `${containerWorkspaceFolder}` | 容器内工作区路径 |
| `${localWorkspaceFolderBasename}` | 工作区目录名 |
| `${devcontainerId}` | 稳定且唯一的开发容器 ID |

## 挂载模式

```jsonc
"mounts": [
  // 源码：通常由 workspaceMount 负责
  "source=${localWorkspaceFolder},target=/workspace,type=bind",

  // 依赖/编译缓存：宿主目录，便于检查和清理
  "source=${localEnv:HOME}/.cache/project,target=/home/dev/.cache/project,type=bind",

  // 包管理器缓存：命名卷，避免宿主权限问题
  "source=project-pnpm-store,target=/home/dev/.local/share/pnpm/store,type=volume",

  // GUI
  "source=/tmp/.X11-unix,target=/tmp/.X11-unix,type=bind,readonly",

  // GPU（按需，设备节点也可用 runArgs --device）
  "source=/dev/dri,target=/dev/dri,type=bind"
]
```

选择原则：

- **宿主目录**：需要跨容器共享、可备份、可 `du`/清理时用。
- **命名卷**：纯容器内部缓存、跨平台（Windows/macOS）时用。
- 挂载许可证、密钥时加 `readonly`；不要把宿主 home 整体挂进容器。

## Podman 注意事项

- `--userns=keep-id` 是 Podman 参数，放进 `runArgs` 后只能配合 Podman 使用：
  ```jsonc
  "runArgs": ["--userns=keep-id"]
  ```
- `updateRemoteUserUID` 依赖运行时对 `/etc/passwd` 和文件属主的处理；Podman 下
  可能不生效或不完整，建议在 Dockerfile 里直接用宿主 UID/GID 构建用户。
- SELinux 宿主上 bind mount 可能需要 `:z`。`mounts` 的字符串形式支持
  `... ,type=bind,z` 之类的选项；不生效时改用 `runArgs` 传
  `--security-opt label=disable`，并限制在开发容器内。
- 确认 devcontainer CLI 支持所选运行时；不同版本对 Podman 的支持程度不同。
- 在 Windows/macOS 上 UID/GID 映射行为不同，优先用命名卷，不要依赖宿主 UID。

## Features 还是 Dockerfile

- **Features**：通用工具（GitHub CLI、Node、Python、Docker-in-Docker），适合快速
  组合；可被多个项目复用。
- **Dockerfile**：需要固定系统包、交叉工具链、许可证、特殊入口脚本时使用。
- 两者可以叠加，但不要让 Feature 和 Dockerfile 安装同一工具的不同版本。

## Docker Compose

多服务时使用：

```jsonc
{
  "name": "project-dev",
  "dockerComposeFile": "../compose.yaml",
  "service": "dev",
  "workspaceFolder": "/workspace",
  "runServices": ["dev", "db"],
  "shutdownAction": "stopCompose"
}
```

Compose 模式下 `overrideCommand` 默认是 `false`，服务自身必须保持前台运行。

## 验证

```bash
# 构建并启动
devcontainer up --workspace-folder .

# 在容器内执行
devcontainer exec --workspace-folder . bash -lc 'id; command -v <tool>'

# 只构建镜像
devcontainer build --workspace-folder .
```

没有 devcontainer CLI 时，用同一镜像的 `run.sh` 做等价验证。

## 常见错误

- `workspaceMount` 设置了但 `workspaceFolder` 没设：配置无效。
- `remoteUser` 指向不存在的用户：容器启动后立即失败。
- `postCreateCommand` 里启动长期服务：命令不返回，创建流程挂起。
- 在 Docker 下使用 `--userns=keep-id`：直接报未知参数。
- 宿主机缓存路径不存在：部分工具会以 root 创建目录，造成后续权限问题；先
  `mkdir -p` 并确认属主。
