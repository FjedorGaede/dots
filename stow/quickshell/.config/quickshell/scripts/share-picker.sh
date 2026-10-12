#!/bin/bash
# xdg-desktop-portal-hyprland custom_picker_binary (hypr/xdph.conf) → the
# Quickshell share picker (modules/overlays/SharePicker.qml).
#
# xdph runs this once per ScreenCast session, passes the window list in
# $XDPH_WINDOW_SHARING_LIST and reads "[SELECTION]<flags>/<screen:NAME|
# window:HANDLE|region:OUT@X,Y,W,H>" from stdout; no [SELECTION] = cancelled.
#
# Chromium/Electron (Vivaldi, Slack) open a preview session and then the real
# capture session → replay the first pick for repeats within TTL seconds, so
# the picker shows once per share. Falls back to the stock picker when
# Quickshell isn't running.
set -u

RUN="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
CACHE="$RUN/share-picker.cache"
TTL=15

exec 9>"$CACHE.lock"
flock 9   # concurrent sessions wait here, then read the fresh cache

if [ -f "$CACHE" ]; then
    ts=$(sed -n 1p "$CACHE")
    sel=$(sed -n 2p "$CACHE")
    if [ -n "$sel" ] && [ $(($(date +%s) - ts)) -le "$TTL" ]; then
        printf '%s\n' "$sel"
        exit 0
    fi
fi

FIFO=$(mktemp -u "$RUN/share-picker.XXXXXX")
mkfifo -m 600 "$FIFO" || exec hyprland-share-picker "$@"
trap 'rm -f "$FIFO"' EXIT

if ! qs ipc call sharepicker open "$FIFO" "${XDPH_WINDOW_SHARING_LIST:-}" >/dev/null 2>&1; then
    rm -f "$FIFO"
    exec hyprland-share-picker "$@"
fi

# Quickshell writes one line: "screen:…" / "window:…" / "region:…", or "" on cancel
if ! sel=$(timeout 300 head -n1 "$FIFO"); then
    qs ipc call sharepicker cancel >/dev/null 2>&1
    sel=""
fi

if [ -n "$sel" ]; then
    sel="[SELECTION]/$sel"
    # Stamp after the pick — the user may take longer than TTL to choose
    printf '%s\n%s\n' "$(date +%s)" "$sel" > "$CACHE"
    printf '%s\n' "$sel"
else
    rm -f "$CACHE"   # a cancel must not be replayed
fi
