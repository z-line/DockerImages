#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
image="${IMAGE_NAME:-buildroot-builder:latest}"

docker build \
    --build-arg "USER_ID=${USER_ID:-$(id -u)}" \
    --build-arg "GROUP_ID=${GROUP_ID:-$(id -g)}" \
    --tag "${image}" \
    "${script_dir}"
