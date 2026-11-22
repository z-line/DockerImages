# shellcheck shell=bash
# Shared cache path resolution for run.sh and cache.sh.
# Source this file; do not execute it directly.

yocto_version="${YOCTO_VERSION:-scarthgap}"
yocto_image="${IMAGE_NAME:-yocto-builder:${yocto_version}}"
yocto_cache_root="${YOCTO_CACHE_DIR:-${XDG_CACHE_HOME:-${HOME}/.cache}/yocto}"
yocto_sstate_arch="${YOCTO_SSTATE_ARCH:-}"
yocto_sstate_dir="${yocto_cache_root}/sstate/${yocto_version}"
if [[ -n "${yocto_sstate_arch}" ]]; then
    yocto_sstate_dir="${yocto_sstate_dir}/${yocto_sstate_arch}"
fi
yocto_lock_file="${yocto_cache_root}/.cache.lock"
