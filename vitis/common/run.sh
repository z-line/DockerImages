#!/usr/bin/env bash
set -euo pipefail

version="${VITIS_VERSION:-2021.1}"
project_dir="${1:-$PWD}"
temporary_xauthority=""
temporary_xresources=""
shift || true

cleanup() {
    if [[ -n "${temporary_xauthority}" ]]; then
        rm -f -- "${temporary_xauthority}"
    fi
    if [[ -n "${temporary_xresources}" ]]; then
        rm -f -- "${temporary_xresources}"
    fi
}
trap cleanup EXIT

if [[ "$#" -eq 0 ]]; then
    set -- bash
fi

requested_command="${1:-bash}"
image="${IMAGE_NAME:-vitis:${version}}"
default_use_gpu=1
if [[ "${requested_command}" == "vivado" ]]; then
    image="${IMAGE_NAME:-vitis:${version}-gui}"
    default_use_gpu=0
    set -- vitis-nested-gui "$@"
fi

# The 2021.1 launcher backgrounds Eclipse and exits immediately. Keep PID 1
# alive until the detached IDE process closes, otherwise the GUI only flashes
# a white window before the container is stopped.
if [[ "${1:-}" == "vitis" ]]; then
    shift
    set -- bash -lc \
        'vitis "$@"; while pgrep -u "$(id -u)" -f "${XILINX_VITIS}/eclipse/lnx64.o/eclipse" >/dev/null; do sleep 1; done' \
        vitis "$@"
fi

docker_args=(
    --rm
    --userns=keep-id
    --hostname vitis
    --volume "${project_dir}:/workspace:z"
    --workdir /workspace
)

# Prefer an explicitly mounted license file, then a floating license server,
# while still supporting the standard FlexNet environment variables.
if [[ -n "${VIVADO_LICENSE_FILE:-}" ]]; then
    if [[ ! -f "${VIVADO_LICENSE_FILE}" ]]; then
        echo "Vivado license file not found: ${VIVADO_LICENSE_FILE}" >&2
        exit 1
    fi
    license_file="$(readlink -f -- "${VIVADO_LICENSE_FILE}")"
    docker_args+=(
        --volume "${license_file}:/run/licenses/vivado.lic:ro,z"
        --env XILINXD_LICENSE_FILE=/run/licenses/vivado.lic
    )
elif [[ -n "${VIVADO_LICENSE_SERVER:-}" ]]; then
    docker_args+=(--env "XILINXD_LICENSE_FILE=${VIVADO_LICENSE_SERVER}")
elif [[ -n "${XILINXD_LICENSE_FILE:-}" ]]; then
    docker_args+=(--env "XILINXD_LICENSE_FILE=${XILINXD_LICENSE_FILE}")
fi

if [[ -n "${LM_LICENSE_FILE:-}" ]]; then
    docker_args+=(--env "LM_LICENSE_FILE=${LM_LICENSE_FILE}")
fi

if [[ "${requested_command}" == "vivado" ]]; then
    docker_args+=(--ipc=host)
    docker_args+=(--env "VITIS_GUI_RESOLUTION=${VITIS_GUI_RESOLUTION:-1920x1080}")
    if [[ -n "${VITIS_GUI_TEST_RESIZE:-}" ]]; then
        docker_args+=(--env "VITIS_GUI_TEST_RESIZE=${VITIS_GUI_TEST_RESIZE}")
    fi
else
    docker_args+=(--shm-size "${VITIS_SHM_SIZE:-2g}")
fi

if [[ -t 0 && -t 1 ]]; then
    docker_args+=(-it)
fi

if [[ -n "${DISPLAY:-}" && -d /tmp/.X11-unix ]]; then
    docker_args+=(
        --security-opt label=disable
        --env "DISPLAY=${DISPLAY}"
        --volume /tmp/.X11-unix:/tmp/.X11-unix:ro
        --env GDK_BACKEND=x11
        --env SWT_GTK3=0
        --env "QT_X11_NO_MITSHM=1"
        --env LIBOVERLAY_SCROLLBAR=0
        --env NO_AT_BRIDGE=1
    )

    temporary_xresources="$(mktemp /tmp/vitis-xresources.XXXXXX)"
    printf '%s\n' \
        'XTerm*font: fixed' \
        'XTerm*boldMode: false' \
        'XTerm*faceName: DejaVu Sans Mono' \
        > "${temporary_xresources}"
    docker_args+=(
        --env XENVIRONMENT=/tmp/.vitis.Xresources
        --volume "${temporary_xresources}:/tmp/.vitis.Xresources:ro,z"
    )

    xauthority="${XAUTHORITY:-${HOME}/.Xauthority}"
    if [[ -f "${xauthority}" ]]; then
        temporary_xauthority="$(mktemp /tmp/vitis-xauth.XXXXXX)"
        # Rewrite the cookie family (first 4 hex chars -> ffff) so the copy is
        # bound to this display only and cannot be replayed elsewhere. Never
        # fall back to copying the raw host .Xauthority, which would expose
        # cookies for every display. If the rewrite fails or yields no entries
        # for this display, skip X authority and rely on the host xhost
        # fallback (see README) instead.
        if xauth -f "${xauthority}" nlist "${DISPLAY}" \
            | sed -e 's/^..../ffff/' \
            | xauth -f "${temporary_xauthority}" nmerge - \
            && [[ -s "${temporary_xauthority}" ]]; then
            chmod 0600 "${temporary_xauthority}"
            docker_args+=(
                --env XAUTHORITY=/tmp/.vitis.Xauthority
                --volume "${temporary_xauthority}:/tmp/.vitis.Xauthority:ro,z"
            )
        else
            rm -f -- "${temporary_xauthority}"
            temporary_xauthority=""
            echo "Warning: no usable X11 cookie for DISPLAY=${DISPLAY}; X clients will rely on host xhost access (see vitis/README.md)" >&2
        fi
    fi

    if [[ "${VITIS_USE_GPU:-${default_use_gpu}}" == "1" && -d /dev/dri ]]; then
        for device in /dev/dri/*; do
            [[ -c "${device}" ]] && docker_args+=(--device "${device}")
        done
    else
        docker_args+=(
            --env LIBGL_ALWAYS_SOFTWARE=1
            --env _JAVA_OPTIONS=-Dsun.java2d.xrender=false
        )
    fi
elif [[ -n "${DISPLAY:-}" ]]; then
    echo "Warning: DISPLAY=${DISPLAY} set but /tmp/.X11-unix missing; running headless" >&2
fi

docker run "${docker_args[@]}" "${image}" "$@"
