#!/usr/bin/env bash
set -euo pipefail

image="${IMAGE_NAME:-yocto-builder:scarthgap}"
source_dir="${1:-$PWD}"
cache_root="${YOCTO_CACHE_DIR:-${source_dir}/.yocto-cache}"
shift || true

mkdir -p "${cache_root}/downloads" "${cache_root}/sstate-cache"
if [[ "$#" -eq 0 ]]; then
    set -- bash
fi

exec docker run --rm -it \
    --userns=keep-id \
    --volume "${source_dir}:/workspace:z" \
    --volume "${cache_root}/downloads:/downloads:z" \
    --volume "${cache_root}/sstate-cache:/sstate-cache:z" \
    --workdir /workspace \
    --env DL_DIR=/downloads \
    --env SSTATE_DIR=/sstate-cache \
    --env BB_ENV_PASSTHROUGH_ADDITIONS="DL_DIR SSTATE_DIR" \
    "${image}" "$@"
