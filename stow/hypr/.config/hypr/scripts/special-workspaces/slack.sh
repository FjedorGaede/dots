#!/bin/bash
# Slack desktop app (aur:slack-desktop); window rules put the main window on
# workspace "slack" and huddle windows on workspace "huddle".
#   slack.sh          Super+Z        — go to slack (launch if not running)
#   slack.sh huddle   Super+Shift+Z  — go to the huddle
# Pressing the key again while on that workspace goes back where you came from.
WS="${1:-slack}"

active=$(hyprctl activeworkspace -j | jq -r '.name')

if [ "$active" = "$WS" ]; then
    hyprctl dispatch 'hl.dsp.focus({workspace="previous"})'
elif [ "$WS" = "slack" ] && ! hyprctl clients -j | jq -e 'any(.[]; .class == "slack")' > /dev/null; then
    hyprctl dispatch 'hl.dsp.exec_cmd("slack")'
elif hyprctl workspaces -j | jq -e --arg w "$WS" 'any(.[]; .name == $w)' > /dev/null; then
    hyprctl dispatch 'hl.dsp.focus({workspace="name:'"$WS"'"})'
fi
