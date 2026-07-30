#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
root_dir="$(cd -- "${script_dir}/.." && pwd)"
version="${PETALINUX_VERSION:-2026.1}"
image="${IMAGE_NAME:-petalinux:${version}}"
platform="${PETALINUX_PLATFORM:-}"
installer="${1:-${root_dir}/petalinux-installer.run}"

if [[ ! -f "${installer}" ]]; then
    echo "PetaLinux installer not found: ${installer}" >&2
    echo "Usage: $0 /path/to/petalinux-v${version}-final-installer.run" >&2
    exit 1
fi

if [[ ! -x "${installer}" ]]; then
    chmod u+x "${installer}"
fi

temporary_installer=false
if [[ "${installer}" != "${root_dir}/petalinux-installer.run" ]]; then
    # Docker build contexts cannot follow a symlink that points outside the context.
    # Reflink is instant and space-efficient on filesystems that support it.
    cp --reflink=auto "${installer}" "${root_dir}/petalinux-installer.run"
    temporary_installer=true
fi

cleanup() {
    if [[ "${temporary_installer}" == true ]]; then
        rm -f "${root_dir}/petalinux-installer.run"
    fi
}
trap cleanup EXIT

DOCKER_BUILDKIT=1 docker build \
    --build-arg "PETALINUX_VERSION=${version}" \
    --build-arg "PETALINUX_PLATFORM=${platform}" \
    --build-arg "USER_ID=${USER_ID:-$(id -u)}" \
    --build-arg "GROUP_ID=${GROUP_ID:-$(id -g)}" \
    --tag "${image}" \
    --file "${script_dir}/Dockerfile" \
    "${root_dir}"
