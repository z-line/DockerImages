FROM ubuntu:22.04

ARG DEBIAN_FRONTEND=noninteractive
ARG USER_NAME=builder
ARG USER_ID=1000
ARG GROUP_ID=1000

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bash \
        build-essential \
        bzip2 \
        ca-certificates \
        ccache \
        chrpath \
        cpio \
        debianutils \
        diffstat \
        file \
        gawk \
        gcc \
        git \
        iputils-ping \
        libacl1 \
        libegl1-mesa \
        liblz4-tool \
        libsdl1.2-dev \
        locales \
        mesa-common-dev \
        openssh-client \
        python3 \
        python3-git \
        python3-jinja2 \
        python3-pexpect \
        python3-pip \
        python3-subunit \
        rsync \
        socat \
        sudo \
        texinfo \
        tmux \
        unzip \
        wget \
        xz-utils \
        zstd \
    && locale-gen en_US.UTF-8 \
    && rm -rf /var/lib/apt/lists/*

RUN groupadd --gid "${GROUP_ID}" "${USER_NAME}" \
    && useradd --uid "${USER_ID}" --gid "${GROUP_ID}" --create-home --shell /bin/bash "${USER_NAME}" \
    && echo "${USER_NAME} ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/${USER_NAME}" \
    && chmod 0440 "/etc/sudoers.d/${USER_NAME}" \
    && install -d -o "${USER_ID}" -g "${GROUP_ID}" /workspace /downloads /sstate-cache

ENV LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    SHELL=/bin/bash

USER ${USER_NAME}
WORKDIR /workspace
CMD ["bash"]
