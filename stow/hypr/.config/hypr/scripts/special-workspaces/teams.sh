#!/bin/bash
# Microsoft Teams (teams-for-linux); window rules put it on workspace "teams".
#   teams.sh   Super+X   — go to teams (launch if not running)
# Pressing the key again while on that workspace goes back where you came from.
WS="teams"

active=$(hyprctl activeworkspace -j | jq -r '.name')

if [ "$active" = "$WS" ]; then
    hyprctl dispatch 'hl.dsp.focus({workspace="previous"})'
elif ! hyprctl clients -j | jq -e 'any(.[]; .class == "teams-for-linux")' > /dev/null; then
    hyprctl dispatch 'hl.dsp.exec_cmd("teams-for-linux")'
elif hyprctl workspaces -j | jq -e --arg w "$WS" 'any(.[]; .name == $w)' > /dev/null; then
    hyprctl dispatch 'hl.dsp.focus({workspace="name:'"$WS"'"})'
fi
