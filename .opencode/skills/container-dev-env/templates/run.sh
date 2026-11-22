#!/usr/bin/env bash
# 通用容器运行包装模板。
# 用法: ./run.sh <源码目录> [容器内命令...]
set -euo pipefail

image="${IMAGE_NAME:-project-dev:latest}"
source_dir="${1:-$PWD}"
cache_root="${CACHE_ROOT:-${XDG_CACHE_HOME:-${HOME}/.cache}/project-dev}"
shift || true

mkdir -p "${cache_root}/downloads" "${cache_root}/cache"
if [[ "$#" -eq 0 ]]; then
    set -- bash
fi

docker_args=(
    --rm
    # Podman: 保持宿主 UID/GID。标准 Docker 改为 --user "$(id -u):$(id -g)"
    --userns=keep-id
    --hostname project
    --volume "${source_dir}:/workspace:z"
    # 同路径挂载：让项目内指向缓存根的绝对软链在容器内可解析
    --volume "${cache_root}:${cache_root}:z"
    --volume "${cache_root}/downloads:/downloads:z"
    --workdir /workspace
    --env "CACHE_ROOT=${cache_root}"
    --env "DL_DIR=/downloads"
)

if [[ -t 0 && -t 1 ]]; then
    docker_args+=(-it)
fi

exec docker run "${docker_args[@]}" "${image}" "$@"
