FROM ubuntu:22.04

ARG DEBIAN_FRONTEND=noninteractive
ARG USER_NAME=builder
ARG USER_ID=1000
ARG GROUP_ID=1000

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
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
