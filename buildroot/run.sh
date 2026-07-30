#!/usr/bin/env bash
set -euo pipefail

image="${IMAGE_NAME:-buildroot-builder:latest}"
source_dir="${1:-$PWD}"
downloads="${BUILDROOT_DL_DIR:-${source_dir}/.buildroot-dl}"
shift || true

mkdir -p "${downloads}"
if [[ "$#" -eq 0 ]]; then
    set -- bash
fi

exec docker run --rm -it \
    --userns=keep-id \
    --volume "${source_dir}:/workspace:z" \
    --volume "${downloads}:/downloads:z" \
    --workdir /workspace \
    "${image}" "$@"
