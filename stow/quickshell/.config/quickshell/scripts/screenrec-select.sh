#!/usr/bin/env bash
# Picks the capture target for the screen recorder (services/RecorderService.qml).
#
#   screenrec-select.sh screen   → "screen <monitor> <x> <y> <w> <h>"  (focused monitor)
#   screenrec-select.sh region   → "region <x> <y> <w> <h>"            (slurp drag)
#   screenrec-select.sh window   → "region <x> <y> <w> <h>"            (slurp, click a window)
#
# All coordinates are global *logical* pixels — what gpu-screen-recorder's
# `-region WxH+X+Y` expects (it scales them itself; verified at scale 1.33).
# Exit code 1 = cancelled (Escape in slurp) → the service goes back to idle.
set -euo pipefail

case "${1:-}" in
screen)
    hyprctl -j monitors | jq -er '
        .[] | select(.focused)
        # logical size; rotated outputs (transform 1/3/5/7) swap w/h
        | (if (.transform % 2) == 1 then [.height, .width] else [.width, .height] end) as $s
        | "screen \(.name) \(.x) \(.y) \($s[0] / .scale | round) \($s[1] / .scale | round)"'
    ;;
region)
    # </dev/null: with a non-tty stdin slurp waits to read predefined boxes
    # from it — quickshell's Process stdin is an open pipe → it hung, invisible
    sel=$(slurp -d -f "%x %y %w %h" </dev/null) || exit 1
    echo "region $sel"
    ;;
window)
    # Outlines of the windows on every visible (special) workspace; slurp -r
    # restricts the selection to one of them (click = pick)
    ws=$(hyprctl -j monitors | jq -c '[.[] | .activeWorkspace.id, .specialWorkspace.id]')
    sel=$(hyprctl -j clients | jq -r --argjson ws "$ws" '
            .[] | select(.mapped and (.hidden | not) and (.workspace.id as $w | $ws | index($w)))
            | "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"' \
          | slurp -r -f "%x %y %w %h") || exit 1
    echo "region $sel"
    ;;
*)
    echo "usage: $0 screen|region|window" >&2
    exit 2
    ;;
esac
