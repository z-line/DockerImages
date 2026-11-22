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

缓存默认保存在用户级全局目录，本机所有 Yocto 项目共用，避免重复下载与重复编译。
可通过 `YOCTO_CACHE_DIR` 指定其他位置：

```
${YOCTO_CACHE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/yocto}
├── downloads/                 # DL_DIR，全局共享：跨项目、跨版本、跨架构
├── ccache/                    # CCACHE_TOP_DIR，全局共享
├── sstate/
│   └── <版本>/                # SSTATE_DIR，按版本隔离（跨版本 sstate 不兼容）
│       └── <架构>/            # 可选：设置 YOCTO_SSTATE_ARCH 时按目标架构再分
└── .cache.lock                # 构建共享锁，供清理脚本判断占用
```

- `downloads`（DL_DIR）和 `ccache`（CCACHE_TOP_DIR）跨项目、版本和架构共享。
  Yocto 的 `ccache` 类会在共享根目录下按目标与配方派生实际 `CCACHE_DIR`，
  清理单个配方不会删除整个共享缓存。
- `sstate`（SSTATE_DIR）**必须按版本隔离**：不同 Yocto 版本的 sstate 不兼容。
  多架构构建时设置 `YOCTO_SSTATE_ARCH`（如 `aarch64`、`arm`、`x86_64`）再分一层，
  与 AMD/上游 sstate 分发布局一致：

```bash
YOCTO_VERSION=scarthgap YOCTO_SSTATE_ARCH=aarch64 ./run.sh /path/to/poky
```

- 同一份 sstate 可以跨项目复用：签名包含 MACHINE、DISTRO 与 tune 信息，配置
  不同的构建只会降低命中率，不会错误复用。
- 多个容器可以同时构建并共享缓存：`run.sh` 持有共享锁，`cache.sh gc` 在检测到
  构建进行时会拒绝执行。
- ccache 单目录上限由 `YOCTO_CCACHE_MAXSIZE`（默认 `5G`）控制。要在构建中启用
  ccache，在 `conf/local.conf` 中添加：

```conf
INHERIT += "ccache"
```

容器内分别以 `DL_DIR=/downloads`、`SSTATE_DIR=/sstate-cache`、
`CCACHE_TOP_DIR=/ccache` 和 `CCACHE_MAXSIZE` 提供，并通过
`BB_ENV_PASSTHROUGH_ADDITIONS` 传递给 BitBake。

### 查看与清理

```bash
./cache.sh info
./cache.sh gc --sstate-days 30 --ccache-size 5G
YOCTO_VERSION=kirkstone ./cache.sh gc
```

`sstate` 按修改时间成对删除 `.siginfo` 与对应的 `*.tar.*`，只会导致后续重建，
不会破坏缓存一致性；`downloads` 不做自动删除。通过 `run.sh` 启动的构建会持有
共享锁，`gc` 检测到后拒绝执行；手工 `docker run` 的构建不受此保护。也可通过
`make cache-info`、`make cache-gc` 调用。

迁移进来的 sstate 保留原始修改时间，刚迁移完不要用较小的 `--sstate-days` 清理，
否则会删除仍然有效的旧条目。

### 从旧目录迁移

旧版本把缓存放在源码旁的 `.yocto-cache`。迁移到全局目录：

```bash
./cache.sh migrate --from /path/to/project/.yocto-cache
```

命令会合并 `downloads`、`ccache` 和旧的扁平 `sstate-cache`（归入当前
`YOCTO_VERSION` 层；设置了 `YOCTO_SSTATE_ARCH` 时归入对应架构层）。迁移使用
no-clobber：目标已有同名文件会保留，`tmpk_*` 临时目录会跳过，绝对路径软链会
给出警告；迁移期间持有构建锁，检测到构建进行时会拒绝执行。确认新构建能命中
缓存后再删除旧目录。

### 接入已有工程

已有工程可以保留原来的 `build/downloads`、`build/sstate-cache` 路径，把它们换成
指向全局缓存的软链即可：

```bash
ln -s ~/.cache/yocto/downloads /path/to/project/build/downloads
ln -s ~/.cache/yocto/sstate/scarthgap /path/to/project/build/sstate-cache
```

`run.sh` 会把缓存根以相同的绝对路径挂载进容器，因此软链在容器内也能解析。使用
其他 Yocto 版本时把 `scarthgap` 换成对应版本目录（如 RockChip styhead SDK 用
`YOCTO_VERSION=styhead`，对应 `~/.cache/yocto/sstate/styhead`）。

### 跨主机共享

sstate 只有在 Yocto 版本和构建镜像（工具链）一致时才可跨主机复用。可以把
`YOCTO_CACHE_DIR` 指到 NFS/Samba 挂载点，或另行配置 `SSTATE_MIRRORS`；本仓库
不内置远程镜像配置。

跨主机共享要求文件系统支持 `flock`。不支持时 `run.sh` 会告警并继续，`cache.sh`
的清理命令可能因拿不到锁而拒绝执行。
