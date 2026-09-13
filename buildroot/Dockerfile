FROM ubuntu:22.04

ARG DEBIAN_FRONTEND=noninteractive
ARG UBUNTU_APT_MIRROR
ARG USER_NAME=builder
ARG USER_ID=1000
ARG GROUP_ID=1000

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
    && apt-get -o Acquire::Retries=5 -o Acquire::http::Timeout=30 update \
    && apt-get -o Acquire::Retries=5 -o Acquire::http::Timeout=30 install -y --no-install-recommends \
        bc \
        binutils \
        bison \
        build-essential \
        bzip2 \
        ca-certificates \
        ccache \
        cpio \
        curl \
        cvs \
        debianutils \
        diffutils \
        file \
        findutils \
        flex \
        gawk \
        git \
        graphviz \
        gzip \
        less \
        libncurses-dev \
        locales \
        mercurial \
        openssh-client \
        patch \
        perl \
        python3 \
        python3-aiohttp \
        python3-matplotlib \
        rsync \
        subversion \
        sudo \
        tar \
        unzip \
        wget \
    && locale-gen en_US.UTF-8 \
    && rm -rf /var/lib/apt/lists/*

RUN groupadd --gid "${GROUP_ID}" "${USER_NAME}" \
    && useradd --uid "${USER_ID}" --gid "${GROUP_ID}" --create-home --shell /bin/bash "${USER_NAME}" \
    && echo "${USER_NAME} ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/${USER_NAME}" \
    && chmod 0440 "/etc/sudoers.d/${USER_NAME}" \
    && install -d -o "${USER_ID}" -g "${GROUP_ID}" /workspace /downloads

ENV LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    BR2_DL_DIR=/downloads

USER ${USER_NAME}
WORKDIR /workspace
CMD ["bash"]
