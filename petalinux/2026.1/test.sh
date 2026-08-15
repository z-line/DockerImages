#!/usr/bin/env bash
set -euo pipefail

version="${PETALINUX_VERSION:-2026.1}"
image="${IMAGE_NAME:-petalinux:${version}}"

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

printf '[PASS] PetaLinux %s image tests completed\n' "${version}"
