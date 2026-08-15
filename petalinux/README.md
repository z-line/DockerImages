# PetaLinux 构建环境

每个 PetaLinux 版本使用独立的基础系统和安装流程，避免宿主依赖与工具链互相污染。

| 版本 | 基础系统 | 安装来源 | 镜像标签 |
| --- | --- | --- | --- |
| 2021.1 | Ubuntu 18.04 | Xilinx Unified Installer | `petalinux:2021.1` |
| 2026.1 | Ubuntu 22.04 | PetaLinux 独立 `.run` 安装器 | `petalinux:2026.1` |

## 构建 2021.1

仓库中的 `installer/Xilinx_Unified_2021.1_0610_2318.tar.gz` 链接会被自动使用：

```bash
make 2021.1
```

也可显式指定安装包：

```bash
./2021.1/build.sh /path/to/Xilinx_Unified_2021.1_0610_2318.tar.gz
```

安装包在构建过程中以只读卷挂载，不会复制进构建上下文或最终镜像层。此方式使用
Podman/Buildah 提供的构建卷功能（当前系统的 `docker` 命令由 Podman 兼容层提供）。

## 构建 2026.1

PetaLinux 2026.1 官方流程使用独立安装器：

```bash
./2026.1/build.sh /path/to/petalinux-v2026.1-final-installer.run
```

可用 `PETALINUX_PLATFORM` 选择 `arm`、`aarch64`、`microblaze`，留空安装全部平台。

## 自动化测试

构建完成后可运行 PetaLinux 2026.1 的非交互式镜像契约测试：

```bash
make test
```

测试验证入口环境、主要 PetaLinux 命令、非 root 用户和可写工作目录。CI/CD 可用
`IMAGE_NAME` 指向刚构建或从镜像仓库拉取的标签：

```bash
IMAGE_NAME=registry.example.com/petalinux:2026.1 make test
```

## 运行

统一运行脚本通过版本变量选择镜像：

```bash
PETALINUX_VERSION=2021.1 ./common/run.sh /path/to/project
PETALINUX_VERSION=2026.1 ./common/run.sh /path/to/project
```

直接执行构建：

```bash
PETALINUX_VERSION=2021.1 ./common/run.sh /path/to/project petalinux-build
```

入口脚本会自动加载对应版本的 `settings.sh`。PetaLinux 以与宿主 UID/GID 相同的非
root 用户运行，减少挂载工程目录时的权限问题。

2021.1 Unified Installer 的实际工具路径为 `/opt/Xilinx/PetaLinux/2021.1/tool`；
2026.1 独立安装器的工具路径为 `/opt/petalinux/2026.1`。

执行安装表示接受相应 AMD/Xilinx EULA、第三方软件条款及 2021.1 安装器要求的
WebTalk 条款；请在构建前阅读安装包中的许可文件。
