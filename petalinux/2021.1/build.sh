#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
root_dir="$(cd -- "${script_dir}/.." && pwd)"
installer="${1:-${root_dir}/installer/Xilinx_Unified_2021.1_0610_2318.tar.gz}"
image="${IMAGE_NAME:-petalinux:2021.1}"

if [[ ! -f "${installer}" ]]; then
    echo "Unified Installer not found: ${installer}" >&2
    echo "Usage: $0 /path/to/Xilinx_Unified_2021.1_0610_2318.tar.gz" >&2
    exit 1
fi

installer_real="$(readlink -f -- "${installer}")"
installer_dir="$(dirname -- "${installer_real}")"
installer_name="$(basename -- "${installer_real}")"
if [[ "${installer_name}" != "Xilinx_Unified_2021.1_0610_2318.tar.gz" ]]; then
    echo "Unexpected installer filename: ${installer_name}" >&2
    echo "Expected: Xilinx_Unified_2021.1_0610_2318.tar.gz" >&2
    exit 1
fi

docker build \
    --security-opt label=disable \
    --volume "${installer_dir}:/installer:ro" \
    --build-arg "USER_ID=${USER_ID:-$(id -u)}" \
    --build-arg "GROUP_ID=${GROUP_ID:-$(id -g)}" \
    --tag "${image}" \
    --file "${script_dir}/Dockerfile" \
    "${root_dir}"
