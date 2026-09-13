#!/usr/bin/env bash
set -euo pipefail

version="${YOCTO_VERSION:-scarthgap}"
image="${IMAGE_NAME:-yocto-builder:${version}}"
source_dir="${1:-$PWD}"
cache_root="${YOCTO_CACHE_DIR:-${source_dir}/.yocto-cache}"
sstate_arch="${YOCTO_SSTATE_ARCH:-}"
shift || true

# downloads and ccache are shared across versions and architectures; sstate is
# isolated per version (and per target architecture when YOCTO_SSTATE_ARCH is
# set), matching AMD/upstream sstate distribution layout.
sstate_dir="${cache_root}/sstate/${version}"
if [[ -n "${sstate_arch}" ]]; then
    sstate_dir="${sstate_dir}/${sstate_arch}"
fi

mkdir -p "${cache_root}/downloads" "${cache_root}/ccache" "${sstate_dir}"
if [[ "$#" -eq 0 ]]; then
    set -- bash
fi

docker_args=(
    --rm
    --userns=keep-id
    --volume "${source_dir}:/workspace:z"
    --volume "${cache_root}/downloads:/downloads:z"
    --volume "${sstate_dir}:/sstate-cache:z"
    --volume "${cache_root}/ccache:/ccache:z"
    --workdir /workspace
    --env DL_DIR=/downloads
    --env SSTATE_DIR=/sstate-cache
    --env CCACHE_TOP_DIR=/ccache
    --env "BB_ENV_PASSTHROUGH_ADDITIONS=${BB_ENV_PASSTHROUGH_ADDITIONS:+${BB_ENV_PASSTHROUGH_ADDITIONS} }DL_DIR SSTATE_DIR CCACHE_TOP_DIR"
)

if [[ -t 0 && -t 1 ]]; then
    docker_args+=(-it)
fi

exec docker run "${docker_args[@]}" "${image}" "$@"
