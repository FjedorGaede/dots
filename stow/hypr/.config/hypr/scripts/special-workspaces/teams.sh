#!/bin/bash
# Microsoft Teams (teams-for-linux); window rules put it on workspace "teams".
#   teams.sh   Super+X   — go to teams (launch if not running)
# Pressing the key again while on that workspace goes back where you came from.
WS="teams"

# Main monitor = the one workspaces.lua's (enabled) rule assigns this workspace to.
# A window rule creates the workspace on whatever monitor had focus at launch,
# ignoring that rule, so the scripts put it back on the main monitor themselves.
main=$(hyprctl workspacerules -j | jq -r --arg w "name:$WS" \
    '[.[] | select(.enabled and .workspaceString == $w)] | last | .monitor // empty')

active=$(hyprctl activeworkspace -j | jq -r '.name')

if [ "$active" = "$WS" ]; then
    hyprctl dispatch 'hl.dsp.focus({workspace="previous"})'
elif ! hyprctl clients -j | jq -e 'any(.[]; .class == "teams-for-linux")' > /dev/null; then
    [ -n "$main" ] && hyprctl dispatch 'hl.dsp.focus({monitor="'"$main"'"})'
    hyprctl dispatch 'hl.dsp.exec_cmd("teams-for-linux")'
elif hyprctl workspaces -j | jq -e --arg w "$WS" 'any(.[]; .name == $w)' > /dev/null; then
    if [ -n "$main" ]; then
        hyprctl dispatch 'hl.dsp.workspace.move({workspace="name:'"$WS"'", monitor="'"$main"'"})'
    fi
    hyprctl dispatch 'hl.dsp.focus({workspace="name:'"$WS"'"})'
fi
