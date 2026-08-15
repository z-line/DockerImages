# Vitis 开发环境

当前提供 AMD/Xilinx Vitis Unified Software Platform 2021.1 镜像。镜像使用
Ubuntu 18.04，并从 Unified Installer 完整安装 Vitis、Vivado 和对应器件支持。

## 构建

默认使用仓库中 `installer/` 目录下的安装包（可软链接到本机安装包，与 PetaLinux
2021.1 相同）：

```bash
make 2021.1
```

也可以显式指定安装包：

```bash
./2021.1/build.sh /path/to/Xilinx_Unified_2021.1_0610_2318.tar.gz
```

构建会生成 `vitis:2021.1` 和 `vitis:2021.1-gui`。安装包通过只读构建卷提供，不会
复制到最终镜像层。构建依赖 Podman/Buildah 的构建卷功能（当前系统的 `docker`
命令由 Podman 兼容层提供），在标准 Docker daemon 上无法使用 `--volume` 构建卷。
完整安装需要较长时间和较大的磁盘空间。

## 自动化测试

构建完成后可运行非交互式镜像契约测试：

```bash
make test
```

测试验证 Vitis/Vivado 命令、非 root 用户、可写工作目录，以及 GUI 派生镜像中的
Xephyr、Openbox 和窗口控制工具。CI/CD 可通过 `IMAGE_NAME` 和
`GUI_IMAGE_NAME` 测试自定义镜像标签：

```bash
IMAGE_NAME=registry.example.com/vitis:2021.1 \
GUI_IMAGE_NAME=registry.example.com/vitis:2021.1-gui make test
```

## 运行

打开容器终端：

```bash
./common/run.sh /path/to/project
```

执行 XSCT：

```bash
./common/run.sh /path/to/project xsct
```

## Vivado/Vitis 许可证

许可证在运行时提供，不会写入镜像。使用浮动许可证服务器（推荐用于 CI/CD）：

```bash
VIVADO_LICENSE_SERVER=2100@license-server \
./common/run.sh /path/to/project vivado
```

使用本地 `.lic` 文件：

```bash
VIVADO_LICENSE_FILE=/secure/path/Xilinx.lic \
./common/run.sh /path/to/project vivado
```

许可证文件会以只读方式挂载到容器内。脚本也会原样传递标准的
`XILINXD_LICENSE_FILE` 和 `LM_LICENSE_FILE` 环境变量，便于兼容现有 FlexNet
配置。不要把许可证文件放入镜像或提交到版本库。

运行 Vitis GUI：

```bash
./common/run.sh /path/to/project vitis
```

运行 Vivado GUI：

```bash
./common/run.sh /path/to/project vivado
```

运行脚本会保留宿主 UID/GID，并为 Podman bind mount 设置共享 SELinux 标签。检测到
`DISPLAY` 和 `/tmp/.X11-unix` 时，会自动转发 X11 socket、Xauthority 凭据和
显示环境。Vitis 2021.1 的 Eclipse/SWT 与现代 Wayland、GTK3 和 Mesa 存在兼容
问题，因此强制使用 X11 和 GTK2。Vitis 的 GPU 渲染已在当前宿主验证通过并默认
启用。Vivado 2021.1 的旧图形栈在现代 XWayland/Mesa 下可能在交互重绘时随机
卡死，因此 Vivado 在 `vitis:2021.1-gui` 派生镜像中使用 Xephyr + Openbox
独立显示环境和软件渲染。宿主只管理一个 Xephyr 窗口，Vivado 的模态弹窗由
Openbox 管理。Vivado GUI 使用宿主 IPC 以启用 Xephyr 的 MIT-SHM 加速。可用
`VITIS_GUI_RESOLUTION=2560x1440` 调整初始分辨率。Openbox 会自动最大化
Vivado，使其铺满整个 Xephyr 窗口。后台尺寸监视器每 250 ms 检测一次 Xephyr
根窗口变化，并主动调整 Vivado 2021.1 主窗口，因此拖动改变外层窗口尺寸时界面
会同步重排。

脚本还会覆盖 XTerm 的旧位图字体设置，避免 Vivado 在现代 XWayland 下因缺少
`C-120` 字体而出现白色空窗口。

不要为 Vivado 设置 `_JAVA_AWT_WM_NONREPARENTING=1`。嵌套桌面中的 Openbox
会正确管理 Java 模态弹窗的父子关系。
运行脚本还会等待 Vitis 启动器放到后台的 Eclipse 进程；关闭 IDE 后容器会自动
退出。

为允许 Fedora/RHEL 系列宿主上的 SELinux 访问 X11 socket，GUI 模式会禁用该
容器的 SELinux label 隔离。容器默认分配 2 GiB 共享内存；可以通过
`VITIS_SHM_SIZE=4g` 调整。

在 Wayland 桌面下，Vitis 2021.1 通过 XWayland 显示，因此宿主仍需提供
`DISPLAY` 和 `/tmp/.X11-unix`。如果宿主没有 Xauthority 文件，可临时授权当前
本地用户：

```bash
xhost +si:localuser:"$(id -un)"
./common/run.sh /path/to/project vitis
xhost -si:localuser:"$(id -un)"
```

执行安装表示接受 AMD/Xilinx EULA、第三方软件条款及 WebTalk 条款；构建前请阅读
安装包中的许可文件。
