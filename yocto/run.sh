#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=cache-env.sh
source "${script_dir}/cache-env.sh"

source_dir="${1:-$PWD}"
min_free_gb="${YOCTO_MIN_FREE_GB:-20}"
shift || true

# downloads and ccache are shared across projects, versions and architectures;
# sstate is isolated per version (and per target architecture when
# YOCTO_SSTATE_ARCH is set), matching AMD/upstream sstate distribution layout.
mkdir -p "${yocto_cache_root}/downloads" "${yocto_cache_root}/ccache" "${yocto_sstate_dir}"

# The shared cache is global now; surface a hint when an old per-project cache
# is left behind, but never switch to it implicitly.
legacy_cache="${source_dir}/.yocto-cache"
if [[ -z "${YOCTO_CACHE_DIR:-}" && -d "${legacy_cache}" ]] \
    && [[ -n "$(find "${legacy_cache}" -type f -print -quit 2>/dev/null)" ]]; then
    echo "warning: legacy cache ${legacy_cache} is no longer used" >&2
    echo "         migrate it with: ${script_dir}/cache.sh migrate --from ${legacy_cache}" >&2
fi

if [[ "${min_free_gb}" =~ ^[0-9]+$ ]]; then
    avail_kb="$(df -Pk "${yocto_cache_root}" | awk 'NR==2 {print $4}')"
    if [[ -n "${avail_kb}" ]] && ((avail_kb / 1024 / 1024 < min_free_gb)); then
        echo "warning: only $((avail_kb / 1024 / 1024)) GiB free on cache filesystem (${yocto_cache_root})" >&2
    fi
fi

if [[ "$#" -eq 0 ]]; then
    set -- bash
fi

# Hold a shared lock for the container's lifetime so cache.sh gc can tell when
# a build is running. The descriptor stays open across exec.
exec 9>>"${yocto_lock_file}"
if ! flock -s 9; then
    echo "warning: cannot lock ${yocto_lock_file}; cache GC may race with this build" >&2
fi

docker_args=(
    --rm
    --userns=keep-id
    --volume "${source_dir}:/workspace:z"
    # Mount the cache at its host path too, so project symlinks such as
    # build/downloads -> ~/.cache/yocto/downloads resolve inside the container.
    # The :z on this mount labels the whole tree; the subpath mounts below must
    # not relabel it again (that is expensive for large caches).
    --volume "${yocto_cache_root}:${yocto_cache_root}:z"
    --volume "${yocto_cache_root}/downloads:/downloads"
    --volume "${yocto_sstate_dir}:/sstate-cache"
    --volume "${yocto_cache_root}/ccache:/ccache"
    --workdir /workspace
    --env DL_DIR=/downloads
    --env SSTATE_DIR=/sstate-cache
    --env CCACHE_TOP_DIR=/ccache
    --env "CCACHE_MAXSIZE=${YOCTO_CCACHE_MAXSIZE:-5G}"
    --env "BB_ENV_PASSTHROUGH_ADDITIONS=${BB_ENV_PASSTHROUGH_ADDITIONS:+${BB_ENV_PASSTHROUGH_ADDITIONS} }DL_DIR SSTATE_DIR CCACHE_TOP_DIR CCACHE_MAXSIZE"
)

if [[ -t 0 && -t 1 ]]; then
    docker_args+=(-it)
fi

exec docker run "${docker_args[@]}" "${yocto_image}" "$@"
