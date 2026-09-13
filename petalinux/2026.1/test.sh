#!/usr/bin/env bash
set -euo pipefail

version="${PETALINUX_VERSION:-2026.1}"
image="${IMAGE_NAME:-petalinux:${version}}"
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
root_dir="$(cd -- "${script_dir}/.." && pwd)"
temporary_cache=""

cleanup() {
    [[ -n "${temporary_cache}" ]] && rm -rf -- "${temporary_cache}"
}
trap cleanup EXIT

run_test() {
    local name="$1"
    shift
    printf '[TEST] %s\n' "${name}"
    "$@"
}

image_exists() {
    docker image inspect "$1" >/dev/null
}

run_test "image exists" image_exists "${image}"
run_test "PetaLinux environment and CLI tools" \
    docker run --rm --env "EXPECTED_PETALINUX_VERSION=${version}" "${image}" bash -lc '
        test "$(id -u)" -ne 0
        test "${PETALINUX}" = "/opt/petalinux/${EXPECTED_PETALINUX_VERSION}"
        test -f "${PETALINUX}/settings.sh"
        command -v petalinux-create >/dev/null
        command -v petalinux-build >/dev/null
        command -v petalinux-config >/dev/null
        command -v petalinux-package >/dev/null
        test "${PWD}" = /workspace
        touch /workspace/.petalinux-ci-write-test
        rm /workspace/.petalinux-ci-write-test
    '

temporary_cache="$(mktemp -d /tmp/petalinux-cache-test.XXXXXX)"
run_test "downloads and sstate caches are mounted" \
    env IMAGE_NAME="${image}" PETALINUX_CACHE_DIR="${temporary_cache}" \
    "${root_dir}/common/run.sh" "${script_dir}" bash -lc '
        test "${DL_DIR}" = /downloads
        test "${SSTATE_DIR}" = /sstate-cache
        case "${BB_ENV_PASSTHROUGH_ADDITIONS}" in
            *"DL_DIR SSTATE_DIR"*) ;;
            *) echo "BB_ENV_PASSTHROUGH_ADDITIONS missing DL_DIR SSTATE_DIR: [${BB_ENV_PASSTHROUGH_ADDITIONS}]" >&2; exit 1;;
        esac
        test -d /downloads
        test -d /sstate-cache
        printf downloads > /downloads/.petalinux-ci-cache-test
        printf sstate > /sstate-cache/.petalinux-ci-cache-test
    '
# The sentinels must be visible on the host through the bind mounts; this
# fails when either mount is broken and the writes stayed in the container.
downloads_sentinel="${temporary_cache}/downloads/.petalinux-ci-cache-test"
sstate_sentinel_dir="${temporary_cache}/sstate/${version}"
if [[ -n "${PETALINUX_SSTATE_ARCH:-}" ]]; then
    sstate_sentinel_dir="${sstate_sentinel_dir}/${PETALINUX_SSTATE_ARCH}"
fi
sstate_sentinel="${sstate_sentinel_dir}/.petalinux-ci-cache-test"
if [[ -f "${downloads_sentinel}" && -f "${sstate_sentinel}" ]]; then
    echo "[OK] cache writes are visible on the host"
    rm -f -- "${downloads_sentinel}" "${sstate_sentinel}"
else
    echo "cache writes are NOT visible on the host; a bind mount is broken" >&2
    exit 1
fi

printf '[PASS] PetaLinux %s image tests completed\n' "${version}"
