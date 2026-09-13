# syntax=docker/dockerfile:1.7

FROM ubuntu:22.04

ARG DEBIAN_FRONTEND=noninteractive
ARG PETALINUX_VERSION=2026.1
ARG PETALINUX_PLATFORM=
ARG UBUNTU_APT_MIRROR
ARG USER_NAME=petalinux
ARG USER_ID=1000
ARG GROUP_ID=1000

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Host packages required by PetaLinux/Yocto on Ubuntu 22.04.
# UBUNTU_APT_MIRROR is optional; when set, sources.list is rewritten after
# installing ca-certificates so https mirrors work.
RUN if [ -n "${UBUNTU_APT_MIRROR}" ]; then \
        apt-get -o Acquire::Retries=5 -o Acquire::http::Timeout=30 update \
        && apt-get -o Acquire::Retries=5 -o Acquire::http::Timeout=30 install -y --no-install-recommends ca-certificates \
        && mirror="${UBUNTU_APT_MIRROR%/}" \
        && sed -i \
            -e "s|http://archive.ubuntu.com/ubuntu|${mirror}|g" \
            -e "s|http://security.ubuntu.com/ubuntu|${mirror}|g" \
            /etc/apt/sources.list; \
    fi \
    && dpkg --add-architecture i386 \
    && apt-get -o Acquire::Retries=5 -o Acquire::http::Timeout=30 update \
    && apt-get -o Acquire::Retries=5 -o Acquire::http::Timeout=30 install -y --no-install-recommends \
        autoconf \
        automake \
        bc \
        bison \
        build-essential \
        ca-certificates \
        chrpath \
        cpio \
        curl \
        debianutils \
        diffstat \
        file \
        flex \
        gawk \
        gcc-multilib \
        git \
        gnupg \
        gzip \
        iproute2 \
        iputils-ping \
        less \
        libegl1-mesa \
        libglib2.0-dev \
        libncurses5-dev \
        libncursesw5-dev \
        libselinux1 \
        libsdl1.2-dev \
        libssl-dev \
        libtool \
        locales \
        lsb-release \
        net-tools \
        openssh-client \
        pax \
        python3 \
        python3-git \
        python3-jinja2 \
        python3-pexpect \
        python3-pip \
        python3-subunit \
        rsync \
        screen \
        socat \
        sudo \
        tar \
        texinfo \
        tmux \
        unzip \
        wget \
        x11-utils \
        xterm \
        xz-utils \
        zlib1g-dev \
        zlib1g:i386 \
    && locale-gen en_US.UTF-8 \
    && ln -sf /bin/bash /bin/sh \
    && rm -rf /var/lib/apt/lists/*

RUN groupadd --gid "${GROUP_ID}" "${USER_NAME}" \
    && useradd --uid "${USER_ID}" --gid "${GROUP_ID}" --create-home --shell /bin/bash "${USER_NAME}" \
    && echo "${USER_NAME} ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/${USER_NAME}" \
    && chmod 0440 "/etc/sudoers.d/${USER_NAME}" \
    && install -d -o "${USER_ID}" -g "${GROUP_ID}" \
        "/opt/petalinux/${PETALINUX_VERSION}" \
        /workspace \
        /downloads \
        /sstate-cache

ENV LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    PETALINUX=/opt/petalinux/${PETALINUX_VERSION}

USER ${USER_NAME}
WORKDIR /home/${USER_NAME}

# The installer is visible only during this step and is not stored in an image layer.
# PETALINUX_PLATFORM may be: arm, aarch64, microblaze, a quoted list, or empty for all.
RUN --mount=type=bind,source=petalinux-installer.run,target=/tmp/petalinux-installer.run,ro \
    platform_args=() \
    && if [[ -n "${PETALINUX_PLATFORM}" ]]; then platform_args=(--platform "${PETALINUX_PLATFORM}"); fi \
    && bash /tmp/petalinux-installer.run \
        --dir "${PETALINUX}" \
        --log /tmp/petalinux-install.log \
        -y \
        "${platform_args[@]}" \
    && test -f "${PETALINUX}/settings.sh"

COPY --chown=${USER_ID}:${GROUP_ID} common/entrypoint.sh /usr/local/bin/petalinux-entrypoint

WORKDIR /workspace
ENTRYPOINT ["/usr/local/bin/petalinux-entrypoint"]
CMD ["bash"]
