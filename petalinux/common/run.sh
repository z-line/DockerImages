#!/usr/bin/env bash
set -euo pipefail

version="${PETALINUX_VERSION:-2026.1}"
image="${IMAGE_NAME:-petalinux:${version}}"
project_dir="${1:-$PWD}"
shift || true

if [[ "$#" -eq 0 ]]; then
    set -- bash
fi

exec docker run --rm -it \
    --userns=keep-id \
    --hostname petalinux \
    --volume "${project_dir}:/workspace:z" \
    --workdir /workspace \
    "${image}" \
    "$@"
