# Buildroot 编译环境

基于 Ubuntu 22.04，包含 Buildroot 官方要求的宿主工具，以及 menuconfig、源码获取、
ccache、依赖图和包统计所需的常用可选工具。

```bash
./build.sh
./run.sh /path/to/buildroot
```

直接编译：

```bash
./run.sh /path/to/buildroot make
```

宿主源码目录挂载到 `/workspace`，下载缓存默认保存在源码旁的 `.buildroot-dl` 并挂载
到 `/downloads`。可通过 `BUILDROOT_DL_DIR` 指定共享缓存位置。
