#!/usr/bin/env bash
set -e

settings="${XILINX_VITIS}/settings64.sh"
if [[ ! -f "${settings}" ]]; then
    echo "Vitis environment not found: ${settings}" >&2
    exit 1
fi

# Source the Xilinx environment without exposing the container command's
# positional arguments to settings64.sh and its child scripts. settings64.sh
# may return non-zero for informational host checks, so disable errexit
# while sourcing and restore it afterwards.
load_vitis_environment() {
    set +e
    set +u
    source "${settings}"
    set -u
    set -e
}
load_vitis_environment
unset -f load_vitis_environment

exec "$@"
