#!/usr/bin/env bash
set -euo pipefail

version="${VITIS_VERSION:-2021.1}"
image="${IMAGE_NAME:-vitis:${version}}"
gui_image="${GUI_IMAGE_NAME:-${image}-gui}"
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
temporary_license=""

cleanup() {
    [[ -n "${temporary_license}" ]] && rm -f -- "${temporary_license}"
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

run_test "base image exists" image_exists "${image}"
run_test "Vitis environment and CLI tools" \
    docker run --rm --env "EXPECTED_VITIS_VERSION=${version}" "${image}" bash -lc '
        test "$(id -u)" -ne 0
        test "${VITIS_VERSION}" = "${EXPECTED_VITIS_VERSION}"
        test -f "${XILINX_VITIS}/settings64.sh"
        command -v xsct >/dev/null
        command -v vitis >/dev/null
        command -v vivado >/dev/null
        test "${PWD}" = /workspace
        touch /workspace/.vitis-ci-write-test
        rm /workspace/.vitis-ci-write-test
    '

run_test "GUI image exists" image_exists "${gui_image}"
run_test "nested GUI runtime dependencies" \
    docker run --rm "${gui_image}" bash -lc '
        test "$(id -u)" -ne 0
        command -v Xephyr >/dev/null
        command -v openbox >/dev/null
        command -v xdotool >/dev/null
        command -v xdpyinfo >/dev/null
        command -v xwininfo >/dev/null
        command -v vitis-nested-gui >/dev/null
    '

temporary_license="$(mktemp /tmp/vivado-license-test.XXXXXX.lic)"
printf '%s\n' '# CI mount test; not a real license' >"${temporary_license}"
run_test "local license is mounted read-only" \
    env IMAGE_NAME="${image}" VIVADO_LICENSE_FILE="${temporary_license}" \
    "${script_dir}/common/run.sh" "${script_dir}" bash -lc '
        test "${XILINXD_LICENSE_FILE}" = /run/licenses/vivado.lic
        test -r "${XILINXD_LICENSE_FILE}"
        test ! -w "${XILINXD_LICENSE_FILE}"
    '

run_test "floating license server is forwarded" \
    env IMAGE_NAME="${image}" VIVADO_LICENSE_SERVER=2100@license.example.invalid \
    "${script_dir}/common/run.sh" "${script_dir}" bash -lc '
        test "${XILINXD_LICENSE_FILE}" = 2100@license.example.invalid
    '

printf '[PASS] Vitis %s image tests completed\n' "${version}"
