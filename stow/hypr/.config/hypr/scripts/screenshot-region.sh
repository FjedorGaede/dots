#!/usr/bin/env bash
# Region screenshot to clipboard. Unlike `hyprshot -m region`, does nothing
# (no clipboard write, no notification) when the selection is cancelled with Esc.
geometry=$(slurp -d) || exit 0
[ -n "$geometry" ] || exit 0
grim -g "$geometry" - | wl-copy --type image/png || exit 1
notify-send "Screenshot saved" "Image copied to the clipboard" -a Hyprshot
