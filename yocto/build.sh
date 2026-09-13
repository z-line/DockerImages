#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
version="${YOCTO_VERSION:-scarthgap}"
image="${IMAGE_NAME:-yocto-builder:${version}}"

docker build \
    --build-arg "YOCTO_VERSION=${version}" \
    --build-arg "UBUNTU_APT_MIRROR=${UBUNTU_APT_MIRROR:-}" \
    --build-arg "USER_ID=${USER_ID:-$(id -u)}" \
    --build-arg "GROUP_ID=${GROUP_ID:-$(id -g)}" \
    --tag "${image}" \
    "${script_dir}"
