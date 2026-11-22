#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=cache-env.sh
source "${script_dir}/cache-env.sh"

runtime="${CONTAINER_RUNTIME:-docker}"

die() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

usage() {
    cat <<'EOF'
usage: cache.sh <command> [options]

commands:
  info                          show cache locations and sizes
  gc [--sstate-days N] [--ccache-size SIZE]
                                prune sstate entries older than N days (default 30)
                                and cap each derived ccache directory (default 5G)
  migrate --from DIR            merge a legacy per-project cache into the shared root
                                (no-clobber, skips tmpk_*, refuses while a build runs)
  rm [--yes]                    remove sstate for the selected version/arch

environment:
  YOCTO_CACHE_DIR       shared cache root (default: ${XDG_CACHE_HOME:-$HOME/.cache}/yocto)
  YOCTO_VERSION         Yocto release selecting the sstate layer (default: scarthgap)
  YOCTO_SSTATE_ARCH     optional target architecture layer (e.g. aarch64)
  YOCTO_CCACHE_MAXSIZE  ccache size limit used by gc (default: 5G)
  YOCTO_SSTATE_KEEP_DAYS sstate age threshold used by gc (default: 30)
  IMAGE_NAME            builder image used for ccache cleanup (default: yocto-builder:<version>)
  CONTAINER_RUNTIME     container runtime (default: docker)
EOF
}

size_of() {
    local path="$1"
    if [[ -e "${path}" ]]; then
        du -sh -- "${path}" 2>/dev/null | cut -f1
    else
        printf 'missing'
    fi
}

have_image() {
    "${runtime}" image inspect "${yocto_image}" >/dev/null 2>&1
}

acquire_lock() {
    mkdir -p "${yocto_cache_root}"
    exec 9>>"${yocto_lock_file}"
    if ! flock -n 9; then
        die "a build is currently using ${yocto_cache_root}; retry after it finishes"
    fi
}

cmd_info() {
    printf 'cache root:    %s\n' "${yocto_cache_root}"
    if [[ -d "${yocto_sstate_dir}" ]]; then
        printf 'active sstate: %s\n' "${yocto_sstate_dir}"
    else
        printf 'active sstate: %s (not created yet)\n' "${yocto_sstate_dir}"
    fi
    printf '%-32s %s\n' "downloads" "$(size_of "${yocto_cache_root}/downloads")"
    printf '%-32s %s\n' "ccache" "$(size_of "${yocto_cache_root}/ccache")"
    printf '%-32s %s\n' "sstate" "$(size_of "${yocto_cache_root}/sstate")"
    if [[ -d "${yocto_cache_root}/sstate" ]]; then
        while IFS= read -r -d '' dir; do
            printf '%-32s %s\n' "  ${dir#"${yocto_cache_root}/sstate/"}" "$(size_of "${dir}")"
        done < <(find "${yocto_cache_root}/sstate" -mindepth 1 -maxdepth 1 -type d -print0 | sort -z)
    fi
    if [[ -d "${yocto_cache_root}" ]]; then
        df -h -- "${yocto_cache_root}" | awk 'NR==1 || NR==2'
    fi
}

prune_ccache() {
    local max_size="$1"

    if [[ ! -d "${yocto_cache_root}/ccache" ]]; then
        return 0
    fi

    local host_ccache_major=""
    if command -v ccache >/dev/null 2>&1; then
        host_ccache_major="$(ccache --version 2>/dev/null \
            | sed -n '1s/.*version \([0-9][0-9]*\).*/\1/p')"
    fi

    if [[ -n "${host_ccache_major}" ]] && ((host_ccache_major >= 4)); then
        while IFS= read -r -d '' dir; do
            ccache --dir "${dir}" --max-size "${max_size}" >/dev/null 2>&1 || true
            ccache --dir "${dir}" --cleanup >/dev/null 2>&1 || true
        done < <(find "${yocto_cache_root}/ccache" -type f -name CACHEDIR.TAG -printf '%h\0' 2>/dev/null | sort -zu)
    elif have_image; then
        "${runtime}" run --rm --userns=keep-id \
            --volume "${yocto_cache_root}/ccache:/ccache:z" \
            --env "CCACHE_MAXSIZE=${max_size}" \
            "${yocto_image}" bash -lc '
                set -euo pipefail
                find /ccache -type f -name CACHEDIR.TAG -printf "%h\0" |
                    sort -zu |
                    while IFS= read -r -d "" dir; do
                        ccache --dir "$dir" --max-size "${CCACHE_MAXSIZE}" >/dev/null
                        ccache --dir "$dir" --cleanup >/dev/null
                    done
            '
    else
        echo "warning: ccache >= 4 not found and image ${yocto_image} is unavailable; skipping ccache cleanup" >&2
    fi
}

cmd_gc() {
    local sstate_days="${YOCTO_SSTATE_KEEP_DAYS:-30}"
    local ccache_size="${YOCTO_CCACHE_MAXSIZE:-5G}"

    while (($#)); do
        case "$1" in
            --sstate-days)
                [[ $# -ge 2 ]] || die "--sstate-days needs a value"
                sstate_days="$2"
                shift 2
                ;;
            --ccache-size)
                [[ $# -ge 2 ]] || die "--ccache-size needs a value"
                ccache_size="$2"
                shift 2
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                die "unknown gc option: $1"
                ;;
        esac
    done

    [[ "${sstate_days}" =~ ^[0-9]+$ ]] || die "--sstate-days must be a non-negative integer"

    acquire_lock

    local before after
    before="$(du -sk "${yocto_cache_root}" 2>/dev/null | cut -f1)"

    if [[ -d "${yocto_sstate_dir}" ]]; then
        printf 'pruning sstate entries older than %s days in %s\n' \
            "${sstate_days}" "${yocto_sstate_dir}"
        find "${yocto_sstate_dir}" -type f -mtime "+${sstate_days}" \
            \( -name '*.siginfo' -o -name '*.tar.*' \) -delete
    fi

    prune_ccache "${ccache_size}"

    after="$(du -sk "${yocto_cache_root}" 2>/dev/null | cut -f1)"
    if [[ -n "${before}" && -n "${after}" ]]; then
        printf 'cache size: %s -> %s\n' \
            "$(numfmt --to=iec --from-unit=1024 "${before}" 2>/dev/null || printf '%s KiB' "${before}")" \
            "$(numfmt --to=iec --from-unit=1024 "${after}" 2>/dev/null || printf '%s KiB' "${after}")"
    fi
}

merge_tree() {
    local src="$1" dst="$2" exclude="${3:-}"
    local entry name

    [[ -d "${src}" ]] || return 0
    [[ -n "$(find "${src}" -mindepth 1 -print -quit 2>/dev/null)" ]] || return 0
    if [[ "$(realpath -m "${src}")" == "$(realpath -m "${dst}")" ]]; then
        return 0
    fi

    mkdir -p "${dst}"
    while IFS= read -r -d '' entry; do
        name="${entry##*/}"
        # shellcheck disable=SC2053 # exclude is an intentional glob
        if [[ -n "${exclude}" && "${name}" == ${exclude} ]]; then
            printf 'skipped %s\n' "${entry}"
            continue
        fi
        if [[ -f "${entry}" && -f "${dst}/${name}" ]] \
            && ! cmp -s -- "${entry}" "${dst}/${name}"; then
            printf 'kept existing (content differs): %s\n' "${dst}/${name}"
            continue
        fi
        cp -a --reflink=auto --no-clobber -- "${entry}" "${dst}/"
    done < <(find "${src}" -mindepth 1 -maxdepth 1 -print0)
    printf 'merged %s -> %s\n' "${src}" "${dst}"
}

warn_absolute_symlinks() {
    local src="$1" link

    [[ -d "${src}" ]] || return 0
    link="$(find "${src}" -type l -lname '/*' -print -quit 2>/dev/null || true)"
    if [[ -n "${link}" ]]; then
        printf 'warning: absolute symlink preserved: %s\n' "${link}" >&2
        printf '         it may dangle outside its original container; replace it with a real file if needed\n' >&2
    fi
}

cmd_migrate() {
    local from=""
    local layered_src=""

    while (($#)); do
        case "$1" in
            --from)
                [[ $# -ge 2 ]] || die "--from needs a directory"
                from="$2"
                shift 2
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                die "unknown migrate option: $1"
                ;;
        esac
    done

    [[ -n "${from}" ]] || die "migrate requires --from DIR"
    [[ -d "${from}" ]] || die "source directory not found: ${from}"

    mkdir -p "${yocto_cache_root}/downloads" "${yocto_cache_root}/ccache" "${yocto_sstate_dir}"
    acquire_lock

    warn_absolute_symlinks "${from}/downloads"
    warn_absolute_symlinks "${from}/ccache"
    warn_absolute_symlinks "${from}/sstate-cache"
    warn_absolute_symlinks "${from}/sstate/${yocto_version}"

    # tmpk_* are interrupted git clones, never valid downloads.
    merge_tree "${from}/downloads" "${yocto_cache_root}/downloads" 'tmpk_*'
    merge_tree "${from}/ccache" "${yocto_cache_root}/ccache"
    # Legacy flat layout: <root>/sstate-cache/<hash prefix>/...
    merge_tree "${from}/sstate-cache" "${yocto_sstate_dir}"

    # Already layered layout: <root>/sstate/<version>[/<arch>]/...
    # When an arch layer is selected, merge that layer instead of nesting
    # <arch>/<arch> inside the destination.
    layered_src="${from}/sstate/${yocto_version}"
    if [[ -n "${yocto_sstate_arch}" && -d "${layered_src}/${yocto_sstate_arch}" ]]; then
        layered_src="${layered_src}/${yocto_sstate_arch}"
    fi
    merge_tree "${layered_src}" "${yocto_sstate_dir}"

    printf 'migrated into %s; verify cache hits before removing %s\n' \
        "${yocto_cache_root}" "${from}"
}

cmd_rm() {
    local assume_yes=0

    while (($#)); do
        case "$1" in
            --yes|-y)
                assume_yes=1
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                die "unknown rm option: $1"
                ;;
        esac
    done

    if [[ ! -d "${yocto_sstate_dir}" ]]; then
        printf 'nothing to remove: %s\n' "${yocto_sstate_dir}"
        return 0
    fi

    if ((!assume_yes)); then
        [[ -t 0 ]] || die "refusing to remove ${yocto_sstate_dir} without --yes"
        read -r -p "remove ${yocto_sstate_dir}? [y/N] " reply
        [[ "${reply}" == [yY] ]] || {
            echo "aborted"
            return 0
        }
    fi

    acquire_lock
    rm -rf -- "${yocto_sstate_dir}"
    printf 'removed %s\n' "${yocto_sstate_dir}"
}

command="${1:-}"
if (($#)); then
    shift
fi

case "${command}" in
    info)
        cmd_info "$@"
        ;;
    gc)
        cmd_gc "$@"
        ;;
    migrate)
        cmd_migrate "$@"
        ;;
    rm)
        cmd_rm "$@"
        ;;
    ""|-h|--help|help)
        usage
        ;;
    *)
        usage >&2
        die "unknown command: ${command}"
        ;;
esac
