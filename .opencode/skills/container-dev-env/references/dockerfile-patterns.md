# Dockerfile 模式

目标是可复现、非 root、缓存友好、安装包不进镜像层。

## 基础骨架

```dockerfile
# syntax=docker/dockerfile:1
FROM ubuntu:22.04

ARG DEBIAN_FRONTEND=noninteractive
ARG UBUNTU_APT_MIRROR
ARG USER_NAME=dev
ARG USER_ID=1000
ARG GROUP_ID=1000

# 1. 可选：替换 Ubuntu 官方源
RUN if [ -n "${UBUNTU_APT_MIRROR}" ]; then \
        apt-get update && apt-get install -y --no-install-recommends ca-certificates \
        && mirror="${UBUNTU_APT_MIRROR%/}" \
        && sed -i \
            -e "s|http://archive.ubuntu.com/ubuntu|${mirror}|g" \
            -e "s|http://security.ubuntu.com/ubuntu|${mirror}|g" \
            /etc/apt/sources.list; \
    fi

# 2. 系统依赖一次装完，减少层数
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bash build-essential ca-certificates curl git locales sudo \
    && locale-gen en_US.UTF-8 \
    && rm -rf /var/lib/apt/lists/*

# 3. 非 root 用户，UID/GID 与宿主一致
RUN groupadd --gid "${GROUP_ID}" "${USER_NAME}" \
    && useradd --uid "${USER_ID}" --gid "${GROUP_ID}" --create-home \
        --shell /bin/bash "${USER_NAME}" \
    && echo "${USER_NAME} ALL=(ALL) NOPASSWD:ALL" \
        > "/etc/sudoers.d/${USER_NAME}" \
    && chmod 0440 "/etc/sudoers.d/${USER_NAME}" \
    && install -d -o "${USER_ID}" -g "${GROUP_ID}" \
        /workspace "/home/${USER_NAME}/.cache"

ENV LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    SHELL=/bin/bash

USER ${USER_NAME}
WORKDIR /workspace
CMD ["bash"]
```

## 关键约定

### 非 root 用户

- 构建参数默认取 `1000`，由 `build.sh` 传入 `$(id -u)`、`$(id -g)`。
- 预建 `/workspace` 和缓存目录并 `chown`，否则首次写挂载点会失败或产生 root 属主。
- 需要 sudo 时只给该用户 NOPASSWD，并限制在镜像内。

### apt 镜像

- 用 `ARG UBUNTU_APT_MIRROR`，空值时保持官方源。
- 替换后必须再 `apt-get update`，并删除 `/var/lib/apt/lists/*`。
- Debian 使用 `/etc/apt/sources.list.d/debian.sources` 时，替换逻辑要相应调整。

### 层序

1. 基础镜像与 `ARG`
2. 系统包（变化少）
3. 语言/工具链（变化中）
4. 用户与目录
5. 入口脚本与默认命令（变化多）

把经常变化的 `COPY` 放最后，最大化缓存命中。

### 多阶段

工具链很大、运行时不需编译依赖时使用：

```dockerfile
FROM ubuntu:22.04 AS toolchain
# 安装编译器、SDK、头文件

FROM ubuntu:22.04 AS runtime
COPY --from=toolchain /opt/toolchain /opt/toolchain
ENV PATH=/opt/toolchain/bin:${PATH}
```

注意：跨阶段复制后仍要检查运行时库依赖（`ldd`）。

## 安装包：不要进镜像层

### 方案 A：Podman/Buildah 构建卷（适合仓库外的大安装包）

```bash
docker build \
    --security-opt label=disable \
    --volume /path/to/installer-dir:/installer:ro \
    --build-arg INSTALLER=/installer/installer.run \
    --tag project-dev:1 \
    .
```

Dockerfile：

```dockerfile
RUN /installer/installer.run --mode unattended --prefix /opt/tool \
    && rm -rf /tmp/*
```

安装包不会进入构建上下文，也不会留在最终层。标准 Docker daemon 不支持构建卷，
需要 Podman/Buildah。

### 方案 B：构建上下文内临时复制并删除

```dockerfile
COPY installer.run /tmp/installer.run
RUN /tmp/installer.run --mode unattended --prefix /opt/tool \
    && rm -f /tmp/installer.run
```

即使同一层删除，安装包仍可能存在于中间层；只适合可公开、体积可控的文件。

### 方案 C：BuildKit bind mount（文件在构建上下文内）

```dockerfile
RUN --mount=type=bind,source=installer.run,target=/tmp/installer.run,readonly \
    /tmp/installer.run --mode unattended --prefix /opt/tool
```

不会写入镜像层；要求文件位于构建上下文中。

## 入口脚本

```dockerfile
COPY --chmod=0755 entrypoint.sh /usr/local/bin/entrypoint
ENTRYPOINT ["/usr/local/bin/entrypoint"]
CMD ["bash"]
```

入口脚本至少做到：

```bash
#!/usr/bin/env bash
set -euo pipefail
# 只做初始化（source 工具链、修正权限），然后 exec 实际命令
exec "$@"
```

不要用入口脚本吞掉信号或启动后台服务；容器需要前台进程。

## 构建参数清单

| 参数 | 用途 |
| --- | --- |
| `UBUNTU_APT_MIRROR` | 加速 apt，空值为官方源 |
| `USER_NAME` | 容器内用户名，默认 `dev` |
| `USER_ID` / `GROUP_ID` | 与宿主对齐，避免挂载权限问题 |
| 工具链版本 | 如 `GO_VERSION`、`NODE_VERSION`、`PETALINUX_VERSION` |
| 目标架构 | 交叉编译时传入 `TARGET_ARCH` |

## 安全

- 不在 `ARG` 或 `ENV` 中写密钥；构建参数会出现在镜像历史里。
- 不把 `.git`、许可证、安装包复制进上下文；用 `.dockerignore` 排除。
- 安装完删除包管理器缓存和临时文件。
- 不在镜像中配置无密码的远程登录。

## 验证

```bash
docker build -t project-dev:test .
docker run --rm project-dev:test bash -lc 'id; command -v <tool>; <tool> --version'
docker run --rm --userns=keep-id -v "$PWD:/workspace:z" project-dev:test \
    bash -lc 'touch /workspace/.write-test && rm /workspace/.write-test'
```
