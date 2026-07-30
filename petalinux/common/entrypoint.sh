#!/usr/bin/env bash
set -e

# settings.sh can return a non-zero status for informational host checks.
set +u
load_petalinux_environment() {
    source "${PETALINUX}/settings.sh"
}
load_petalinux_environment
unset -f load_petalinux_environment
set -u

exec "$@"
