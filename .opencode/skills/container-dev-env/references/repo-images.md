# 本仓库镜像矩阵

`docker` 命令在本机由 Podman 兼容层提供。所有镜像都以非 root 用户运行，源码挂载
到 `/workspace`，使用 `--userns=keep-id` 保持宿主 UID/GID。

| 目录 | 默认镜像 | 版本变量 | 构建 | 运行 |
| --- | --- | --- | --- | --- |
| `yocto/` | `yocto-builder:scarthgap` | `YOCTO_VERSION` | `./build.sh` | `./run.sh <poky>` |
| `petalinux/` | `petalinux:2026.1` | `PETALINUX_VERSION` | `make 2021.1` / `make 2026.1` | `common/run.sh <project>` |
| `vitis/` | `vitis:2021.1` | `VITIS_VERSION` | `make 2021.1` | `common/run.sh <project>` |
| `buildroot/` | `buildroot-builder:latest` | — | `./build.sh` | `./run.sh <buildroot>` |
| `marveltubes-zephyr/` | `localhost/marveltubes-zephyr:4.4.0-1.0.1` | — | `docker build` | 由 Zephyr/West 工程使用 |

## 通用变量

| 变量 | 作用 |
| --- | --- |
| `UBUNTU_APT_MIRROR` | 替换 Ubuntu 官方源，构建期生效 |
| `IMAGE_NAME` | 覆盖默认镜像标签 |
| `USER_ID` / `GROUP_ID` | 构建镜像内的用户 UID/GID，默认当前用户 |
| `USER_NAME` | 部分镜像支持自定义用户名 |

```bash
UBUNTU_APT_MIRROR=https://mirrors.tuna.tsinghua.edu.cn/ubuntu ./build.sh
```

## Yocto

```bash
cd yocto
./build.sh                          # 默认 scarthgap
YOCTO_VERSION=kirkstone ./build.sh  # 其他版本标签
./run.sh /path/to/poky
```

容器内：

```bash
source oe-init-build-env build
bitbake core-image-minimal
```

也可直接执行：

```bash
./run.sh /path/to/poky bash -lc \
  'source oe-init-build-env build && bitbake core-image-minimal'
```

### 变量

| 变量 | 默认 | 说明 |
| --- | --- | --- |
| `YOCTO_VERSION` | `scarthgap` | 选择镜像标签和 sstate 层 |
| `YOCTO_CACHE_DIR` | `~/.cache/yocto` | 共享缓存根 |
| `YOCTO_SSTATE_ARCH` | 空 | 按目标架构再加一层，如 `aarch64` |
| `YOCTO_CCACHE_MAXSIZE` | `5G` | 单个 ccache 目录上限 |
| `YOCTO_MIN_FREE_GB` | `20` | 剩余空间告警阈值 |

### 缓存

```text
~/.cache/yocto/
├── downloads/            # DL_DIR，全局共享
├── ccache/               # CCACHE_TOP_DIR
└── sstate/<version>/     # SSTATE_DIR，按版本隔离
    └── <arch>/           # 可选
```

```bash
./cache.sh info
./cache.sh gc --sstate-days 30 --ccache-size 5G
./cache.sh migrate --from /path/to/old/.yocto-cache
./cache.sh rm --yes
```

`make cache-info`、`make cache-gc`、`make cache-migrate` 是等价入口（参数用
`ARGS=` 传入）。

启用 ccache：在构建目录的 `conf/local.conf` 加 `INHERIT += "ccache"`。

项目内接入共享缓存：

```bash
ln -s ~/.cache/yocto/downloads /path/to/poky/build/downloads
ln -s ~/.cache/yocto/sstate/styhead /path/to/poky/build/sstate-cache
```

`run.sh` 会把缓存根按相同绝对路径挂载，软链在容器内可解析。

### 自定义镜像

```bash
IMAGE_NAME=rk-sdk-yocto:22.04 YOCTO_VERSION=styhead \
  ./run.sh /path/to/rockchip_linux_sdk/yocto
```

`YOCTO_VERSION` 同时决定镜像默认标签和 sstate 层；使用自定义镜像时用
`IMAGE_NAME` 覆盖标签。

## PetaLinux

| 版本 | 基础系统 | 安装来源 | 镜像 |
| --- | --- | --- | --- |
| 2021.1 | Ubuntu 18.04 | Xilinx Unified Installer | `petalinux:2021.1` |
| 2026.1 | Ubuntu 22.04 | PetaLinux `.run` 安装器 | `petalinux:2026.1` |

### 构建

```bash
cd petalinux

# 2021.1：安装包放到 installer/ 或显式传参
mkdir -p installer
ln -s /path/to/Xilinx_Unified_2021.1_0610_2318.tar.gz \
  installer/Xilinx_Unified_2021.1_0610_2318.tar.gz
make 2021.1
# 或
./2021.1/build.sh /path/to/Xilinx_Unified_2021.1_0610_2318.tar.gz

# 2026.1
./2026.1/build.sh /path/to/petalinux-v2026.1-final-installer.run
```

`PETALINUX_PLATFORM` 可选 `arm`、`aarch64`、`microblaze`，留空安装全部平台。

### 运行

```bash
PETALINUX_VERSION=2021.1 ./common/run.sh /path/to/project
PETALINUX_VERSION=2021.1 ./common/run.sh /path/to/project petalinux-build
```

入口脚本自动加载对应版本的 `settings.sh`。

### 缓存

默认 `~/.cache/yocto`，与 Yocto 镜像共用 downloads：

| 变量 | 说明 |
| --- | --- |
| `PETALINUX_CACHE_DIR` | 覆盖缓存根 |
| `PETALINUX_SSTATE_ARCH` | 按架构分层 |

```bash
PETALINUX_SSTATE_ARCH=aarch64 ./common/run.sh /path/to/project petalinux-build
```

工程内可用软链接入：

```bash
ln -s ~/.cache/yocto/downloads /path/to/project/build/downloads
ln -s ~/.cache/yocto/sstate/2021.1 /path/to/project/build/sstate-cache
```

`build/conf/local.conf` 是自动生成的，不建议直接编辑；需要覆盖时改
`project-spec/meta-user/conf/petalinuxbsp.conf`：

```conf
DL_DIR = "/downloads"
SSTATE_DIR = "/sstate-cache"
```

2021.1 使用 `BB_ENV_EXTRAWHITE`，2026.1 使用 `BB_ENV_PASSTHROUGH_ADDITIONS`。

### 测试

```bash
make test          # 2026.1 镜像契约测试
```

## Vitis / Vivado

```bash
cd vitis
mkdir -p installer
ln -s /path/to/Xilinx_Unified_2021.1_0610_2318.tar.gz \
  installer/Xilinx_Unified_2021.1_0610_2318.tar.gz
make 2021.1        # 生成 vitis:2021.1 与 vitis:2021.1-gui
```

构建使用 Podman/Buildah 构建卷提供安装包，标准 Docker daemon 不支持。

### 运行

```bash
./common/run.sh /path/to/project          # bash
./common/run.sh /path/to/project xsct
./common/run.sh /path/to/project vitis
./common/run.sh /path/to/project vivado   # 自动使用 -gui 镜像和嵌套 GUI
```

### 许可证

```bash
VIVADO_LICENSE_SERVER=2100@license-server \
  ./common/run.sh /path/to/project vivado

VIVADO_LICENSE_FILE=/secure/path/Xilinx.lic \
  ./common/run.sh /path/to/project vivado
```

也接受 `XILINXD_LICENSE_FILE`、`LM_LICENSE_FILE`。许可证只读挂载，不写入镜像。

### GUI / GPU 变量

| 变量 | 默认 | 说明 |
| --- | --- | --- |
| `VITIS_GUI_RESOLUTION` | `1920x1080` | 嵌套桌面分辨率 |
| `VITIS_SHM_SIZE` | `2g` | 共享内存 |
| `VITIS_USE_GPU` | `1`（vivado 为 `0`） | `0` 强制软件渲染 |

GUI 需要宿主 `DISPLAY` 和 `/tmp/.X11-unix`；Wayland 下通过 XWayland。Vivado 使用
Xephyr + Openbox 独立桌面，避免旧图形栈在现代 Mesa 下卡死。

### 测试

```bash
make test
IMAGE_NAME=registry.example.com/vitis:2021.1 \
GUI_IMAGE_NAME=registry.example.com/vitis:2021.1-gui make test
```

## Buildroot

```bash
cd buildroot
./build.sh
./run.sh /path/to/buildroot
./run.sh /path/to/buildroot make
```

- 默认镜像：`buildroot-builder:latest`。
- 下载缓存默认 `<源码>/.buildroot-dl`，挂载到 `/downloads`；
  `BUILDROOT_DL_DIR` 可指定共享目录。
- 当前 `run.sh` 没有缓存根同路径挂载；如果项目内使用绝对路径软链，需要补挂载。

## Zephyr

```bash
cd marveltubes-zephyr
docker build -t localhost/marveltubes-zephyr:4.4.0-1.0.1 .
```

基于官方 Zephyr build 镜像的固定 digest，额外安装 `cbor2` 和 `littlefs-python`，
供 `zephyr/scripts/build_littlefs_images.py` 使用。由 MarvelTubes 工程的 West 流程
调用，不提供独立 `run.sh`。

## 根目录

各镜像的详细说明以各自目录的 `README.md` 为准；本文件只提供速查矩阵。
