FROM ubuntu:18.04

ARG DEBIAN_FRONTEND=noninteractive
ARG UBUNTU_APT_MIRROR
ARG USER_NAME=petalinux
ARG USER_ID=1000
ARG GROUP_ID=1000

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

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
        python \
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
    && install -d -o "${USER_ID}" -g "${GROUP_ID}" /opt/Xilinx /workspace /downloads /sstate-cache /tmp/xilinx-installer

ENV LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    PETALINUX=/opt/Xilinx/PetaLinux/2021.1/tool

COPY --chown=${USER_ID}:${GROUP_ID} 2021.1/install_config.txt /tmp/install_config.txt
COPY --chown=${USER_ID}:${GROUP_ID} common/entrypoint.sh /usr/local/bin/petalinux-entrypoint

USER ${USER_NAME}
WORKDIR /home/${USER_NAME}

# build.sh mounts the 52 GB Unified Installer archive at /installer read-only.
RUN tar -xzf /installer/Xilinx_Unified_2021.1_0610_2318.tar.gz -C /tmp/xilinx-installer \
    && /tmp/xilinx-installer/Xilinx_Unified_2021.1_0610_2318/xsetup \
        --agree XilinxEULA,3rdPartyEULA,WebTalkTerms \
        --batch Install \
        --config /tmp/install_config.txt \
    && test -f "${PETALINUX}/settings.sh" \
    && rm -rf /tmp/xilinx-installer /tmp/install_config.txt

WORKDIR /workspace
ENTRYPOINT ["/usr/local/bin/petalinux-entrypoint"]
CMD ["bash"]
