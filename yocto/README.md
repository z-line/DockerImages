# Yocto Project 编译环境

面向 Yocto Project 5.0 Scarthgap，使用官方支持的 Ubuntu 22.04，并安装官方列出的
headless 构建依赖。

## 构建

构建默认生成 `yocto-builder:scarthgap`；通过 `YOCTO_VERSION` 支持多个 Yocto
版本镜像：

```bash
YOCTO_VERSION=scarthgap ./build.sh        # 默认
YOCTO_VERSION=kirkstone ./build.sh
```

默认使用 Ubuntu 官方软件源。需要使用镜像站加速时，可通过
`UBUNTU_APT_MIRROR` 显式指定：

```bash
UBUNTU_APT_MIRROR=https://mirrors.tuna.tsinghua.edu.cn/ubuntu ./build.sh
```

## 运行

```bash
./run.sh /path/to/poky
```

进入容器后：

```bash
source oe-init-build-env
bitbake core-image-minimal
```

也可直接执行：

```bash
./run.sh /path/to/poky bash -lc \
  'source oe-init-build-env build && bitbake core-image-minimal'
```

`run.sh` 通过 `YOCTO_VERSION` 选择对应镜像（默认 `scarthgap`，与构建一致）。

## 缓存组织

缓存默认保存在源码旁的 `.yocto-cache`，可通过 `YOCTO_CACHE_DIR` 指定共享缓存根
目录。不同缓存按共享性分层组织：

```
YOCTO_CACHE_DIR
├── downloads/                 # 全局共享：跨版本、跨架构（源码包与版本无关）
├── ccache/                    # 全局共享：Yocto 按目标与配方自动分层
└── sstate/
    └── <版本>/                # 按版本隔离（跨版本 sstate 不兼容）
        └── <架构>/            # 可选：设置 YOCTO_SSTATE_ARCH 时按目标架构再分
```

- `downloads`（DL_DIR）和 `ccache`（CCACHE_TOP_DIR）跨版本、跨架构共享，避免重复
  下载与重复编译缓存。Yocto 的 `ccache` 类会在共享根目录下按目标与配方派生实际
  的 `CCACHE_DIR`。
- `sstate`（SSTATE_DIR）**必须按版本隔离**：不同 Yocto 版本的 sstate 不兼容。
  多架构处理器构建时设置 `YOCTO_SSTATE_ARCH`（如 `aarch64`、`arm`、`x86_64`）
  再按目标架构分一层，与 AMD/上游 sstate 分发布局一致：

```bash
YOCTO_VERSION=scarthgap YOCTO_SSTATE_ARCH=aarch64 ./run.sh /path/to/poky
```

从旧版扁平 `sstate-cache/` 目录升级时，把已有缓存合并到按版本隔离的布局即可
避免全量重建。使用复制合并可兼容新版脚本已经创建目标目录的情况；确认新构建
能命中缓存后，再删除旧目录：

```bash
mkdir -p /path/to/.yocto-cache/sstate/scarthgap
cp -a /path/to/.yocto-cache/sstate-cache/. \
  /path/to/.yocto-cache/sstate/scarthgap/
```

容器内分别以 `DL_DIR=/downloads`、`SSTATE_DIR=/sstate-cache` 和
`CCACHE_TOP_DIR=/ccache` 提供，并通过 `BB_ENV_PASSTHROUGH_ADDITIONS` 传递给
BitBake。实际 `CCACHE_DIR` 由 Yocto 的 `ccache` 类生成，避免清理单个配方时删除
整个共享缓存。

要在构建中启用 ccache，在 `conf/local.conf` 中添加：

```conf
INHERIT += "ccache"
```
