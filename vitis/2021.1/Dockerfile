FROM ubuntu:18.04

ARG DEBIAN_FRONTEND=noninteractive
ARG VITIS_VERSION=2021.1
ARG UBUNTU_APT_MIRROR
ARG USER_NAME=vitis
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
        curl \
        desktop-file-utils \
        file \
        flex \
        gawk \
        gcc-multilib \
        git \
        graphviz \
        gzip \
        iproute2 \
        iputils-ping \
        less \
        libasound2 \
        libcanberra-gtk-module \
        libcanberra-gtk3-module \
        libfontconfig1 \
        libglib2.0-0 \
        libgtk2.0-0 \
        libgtk-3-0 \
        libncurses5 \
        libncurses5-dev \
        libnss3 \
        libsm6 \
        libssl1.0.0 \
        libstdc++6:i386 \
        libtinfo5 \
        libx11-6 \
        libxext6 \
        libxft2 \
        libxi6 \
        libxrender1 \
        libxt6 \
        locales \
        make \
        net-tools \
        openjdk-11-jre \
        patch \
        python \
        python3 \
        rsync \
        sudo \
        tar \
        tcl \
        unzip \
        wget \
        xauth \
        xterm \
        xvfb \
        xz-utils \
        zip \
        && locale-gen en_US.UTF-8 \
        && rm -rf /var/lib/apt/lists/*

RUN groupadd --gid "${GROUP_ID}" "${USER_NAME}" \
    && useradd --uid "${USER_ID}" --gid "${GROUP_ID}" --create-home --shell /bin/bash "${USER_NAME}" \
    && echo "${USER_NAME} ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/${USER_NAME}" \
    && chmod 0440 "/etc/sudoers.d/${USER_NAME}" \
    && install -d -o "${USER_ID}" -g "${GROUP_ID}" /opt/Xilinx /workspace /tmp/xilinx-installer

ENV LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    VITIS_VERSION=${VITIS_VERSION} \
    XILINX_VITIS=/opt/Xilinx/Vitis/${VITIS_VERSION}

USER ${USER_NAME}
WORKDIR /home/${USER_NAME}

# build.sh mounts the Unified Installer archive at /installer read-only.
RUN tar -xzf /installer/Xilinx_Unified_2021.1_0610_2318.tar.gz -C /tmp/xilinx-installer \
    && /tmp/xilinx-installer/Xilinx_Unified_2021.1_0610_2318/xsetup \
        --agree XilinxEULA,3rdPartyEULA,WebTalkTerms \
        --batch Install \
        --product Vitis \
        --edition "Vitis Unified Software Platform" \
        --location /opt/Xilinx \
    && test -f "${XILINX_VITIS}/settings64.sh" \
    && test -x "${XILINX_VITIS}/bin/xsct" \
    && rm -rf /tmp/xilinx-installer

USER root
RUN apt-get -o Acquire::Retries=5 -o Acquire::http::Timeout=30 update \
    && apt-get -o Acquire::Retries=5 -o Acquire::http::Timeout=30 install -y --no-install-recommends \
        dbus-x11 \
        x11-utils \
    && rm -rf /var/lib/apt/lists/* \
    && "${XILINX_VITIS}/scripts/installLibs.sh"

COPY --chown=${USER_ID}:${GROUP_ID} common/entrypoint.sh /usr/local/bin/vitis-entrypoint

USER ${USER_NAME}
WORKDIR /workspace
ENTRYPOINT ["/usr/local/bin/vitis-entrypoint"]
CMD ["bash"]
