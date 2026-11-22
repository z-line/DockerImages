#!/usr/bin/env bash
set -euo pipefail

version="${PETALINUX_VERSION:-2026.1}"
image="${IMAGE_NAME:-petalinux:${version}}"
project_dir="${1:-$PWD}"
cache_root="${PETALINUX_CACHE_DIR:-${XDG_CACHE_HOME:-${HOME}/.cache}/yocto}"
sstate_arch="${PETALINUX_SSTATE_ARCH:-}"
shift || true

# downloads is shared across versions and architectures; sstate is isolated
# per version (and per target architecture when PETALINUX_SSTATE_ARCH is set),
# matching AMD's arm/aarch64/microblaze sstate distribution layout.
sstate_dir="${cache_root}/sstate/${version}"
if [[ -n "${sstate_arch}" ]]; then
    sstate_dir="${sstate_dir}/${sstate_arch}"
fi

mkdir -p "${cache_root}/downloads" "${sstate_dir}"

# The default cache root is shared with the Yocto image. Warn when an old
# per-project cache is still present so it is migrated instead of silently
# rebuilding everything.
legacy_cache="${project_dir}/.petalinux-cache"
if [[ -z "${PETALINUX_CACHE_DIR:-}" && -d "${legacy_cache}" ]] \
    && [[ -n "$(find "${legacy_cache}" -type f -print -quit 2>/dev/null)" ]]; then
    echo "warning: legacy cache ${legacy_cache} is no longer used" >&2
    echo "         keep using it with PETALINUX_CACHE_DIR=${legacy_cache}" >&2
    echo "         or move its downloads/sstate into ${cache_root}" >&2
fi

if [[ "$#" -eq 0 ]]; then
    set -- bash
fi

docker_args=(
    --rm
    --userns=keep-id
    --hostname petalinux
    --volume "${project_dir}:/workspace:z"
    # Mount the cache at its host path too, so project symlinks such as
    # build/downloads -> ~/.cache/yocto/downloads resolve inside the container.
    # The :z labels the whole tree; the subpath mounts must not relabel it again.
    --volume "${cache_root}:${cache_root}:z"
    --volume "${cache_root}/downloads:/downloads"
    --volume "${sstate_dir}:/sstate-cache"
    --workdir /workspace
    --env DL_DIR=/downloads
    --env SSTATE_DIR=/sstate-cache
)

# PetaLinux 2021.1 embeds a pre-Kirkstone BitBake, where the environment
# allow-list is still named BB_ENV_EXTRAWHITE. Newer releases use the renamed
# BB_ENV_PASSTHROUGH_ADDITIONS variable.
if [[ "${version}" == "2021.1" ]]; then
    docker_args+=(
        --env "BB_ENV_EXTRAWHITE=${BB_ENV_EXTRAWHITE:+${BB_ENV_EXTRAWHITE} }DL_DIR SSTATE_DIR"
    )
else
    docker_args+=(
        --env "BB_ENV_PASSTHROUGH_ADDITIONS=${BB_ENV_PASSTHROUGH_ADDITIONS:+${BB_ENV_PASSTHROUGH_ADDITIONS} }DL_DIR SSTATE_DIR"
    )
fi

if [[ -t 0 && -t 1 ]]; then
    docker_args+=(-it)
fi

exec docker run "${docker_args[@]}" "${image}" "$@"
