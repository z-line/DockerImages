#!/usr/bin/env bash
set -euo pipefail

nested_display_number="${VITIS_NESTED_DISPLAY_NUMBER:-99}"
nested_server_display=":${nested_display_number}"
nested_client_display="127.0.0.1:${nested_display_number}.0"
resolution="${VITIS_GUI_RESOLUTION:-1920x1080}"
openbox_config="/tmp/vitis-openbox.xml"
outer_display="${DISPLAY:?outer DISPLAY is not set}"
outer_xauthority="${XAUTHORITY:-}"

cleanup() {
    [[ -n "${application_pid:-}" ]] && kill "${application_pid}" 2>/dev/null || true
    [[ -n "${window_manager_pid:-}" ]] && kill "${window_manager_pid}" 2>/dev/null || true
    [[ -n "${xephyr_pid:-}" ]] && kill "${xephyr_pid}" 2>/dev/null || true
}
terminate() {
    trap - EXIT INT TERM
    cleanup
    exit 143
}
trap cleanup EXIT
trap terminate INT TERM

Xephyr "${nested_server_display}" \
    -screen "${resolution}" \
    -resizeable \
    -br \
    -ac \
    -nolisten unix \
    -listen tcp &
xephyr_pid=$!

for _ in $(seq 1 100); do
    if DISPLAY="${nested_client_display}" xdpyinfo >/dev/null 2>&1; then
        break
    fi
    sleep 0.1
done
DISPLAY="${nested_client_display}" xdpyinfo >/dev/null

cat >"${openbox_config}" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<openbox_config xmlns="http://openbox.org/3.4/rc">
  <applications>
    <application class="*" name="*">
      <decor>yes</decor>
      <maximized>yes</maximized>
      <focus>yes</focus>
    </application>
  </applications>
</openbox_config>
EOF

DISPLAY="${nested_client_display}" openbox \
    --config-file "${openbox_config}" >/tmp/openbox.log 2>&1 &
window_manager_pid=$!

for _ in $(seq 1 50); do
    if DISPLAY="${nested_client_display}" xprop \
        -root _NET_SUPPORTING_WM_CHECK 2>/dev/null | grep -q 'window id'; then
        break
    fi
    sleep 0.1
done

export DISPLAY="${nested_client_display}"
unset XAUTHORITY

"$@" &
application_pid=$!

if [[ -n "${VITIS_GUI_TEST_RESIZE:-}" ]]; then
    (
        sleep 2
        DISPLAY="${outer_display}" XAUTHORITY="${outer_xauthority}" \
            xdotool search --class Xephyr \
            windowsize "${VITIS_GUI_TEST_RESIZE%x*}" "${VITIS_GUI_TEST_RESIZE#*x}"
    ) &
fi

last_geometry=""
while kill -0 "${application_pid}" 2>/dev/null; do
    geometry="$(xwininfo -root 2>/dev/null | awk '
        /Width:/ { width=$2 }
        /Height:/ { height=$2 }
        END { if (width && height) print width "x" height }
    ')"
    if [[ -n "${geometry}" && "${geometry}" != "${last_geometry}" ]]; then
        width="${geometry%x*}"
        height="${geometry#*x}"
        while read -r window_id; do
            [[ -n "${window_id}" ]] || continue
            xdotool windowmove "${window_id}" 0 0 || true
            xdotool windowsize "${window_id}" "${width}" "${height}" || true
        done < <(xdotool search --onlyvisible --name 'Vivado' 2>/dev/null || true)
        last_geometry="${geometry}"
    fi
    sleep 0.25
done

wait "${application_pid}"
