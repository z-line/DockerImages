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

docker_args=(
    --rm
    --userns=keep-id
    --volume "${source_dir}:/workspace:z"
    --volume "${downloads}:/downloads:z"
    --workdir /workspace
)

if [[ -t 0 && -t 1 ]]; then
    docker_args+=(-it)
fi

exec docker run "${docker_args[@]}" "${image}" "$@"
