# Yocto Project 编译环境

面向 Yocto Project 5.0 Scarthgap，使用官方支持的 Ubuntu 22.04，并安装官方列出的
headless 构建依赖。

```bash
./build.sh
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

下载和 sstate 缓存默认保存在源码旁的 `.yocto-cache`。可通过 `YOCTO_CACHE_DIR`
指定共享缓存根目录。运行脚本分别设置 `DL_DIR=/downloads` 和
`SSTATE_DIR=/sstate-cache`，并通过 `BB_ENV_PASSTHROUGH_ADDITIONS` 将它们传递给
BitBake。
