#!/usr/bin/env bash
set -e

# settings.sh can return a non-zero status for informational host checks, so
# disable errexit while sourcing and restore it afterwards.
load_petalinux_environment() {
    set +e
    set +u
    source "${PETALINUX}/settings.sh"
    set -u
    set -e
}
load_petalinux_environment
unset -f load_petalinux_environment

exec "$@"
