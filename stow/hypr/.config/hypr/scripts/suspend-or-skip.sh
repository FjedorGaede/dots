#!/bin/sh
# hypridle suspend-listener wrapper.
# Skips suspend while the quickshell "stay awake" toggle is on
# (file written by ~/.config/quickshell/StayAwakeService.qml).
# Everything else (dim/lock/screen-off) is handled by the other listeners.

FLAG="$HOME/.cache/quickshell/stay-awake.json"

if [ -f "$FLAG" ] && grep -q '"enabled"[[:space:]]*:[[:space:]]*true' "$FLAG"; then
    notify-send -a quickshell -u normal "Stay awake" "Suspend skipped — stay-awake is on"
    exit 0
fi

exec systemctl suspend
