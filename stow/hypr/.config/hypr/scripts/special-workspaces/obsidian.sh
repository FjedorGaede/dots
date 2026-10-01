#!/bin/bash
APP_NAME="obsidian"
# Obsidian >= 1.13 reports class "md.obsidian.Obsidian" (was "obsidian")
CLASS_NAME="md.obsidian.Obsidian"

if hyprctl clients -j | jq -e --arg c "$CLASS_NAME" 'any(.[]; .class == $c)' > /dev/null; then
    hyprctl dispatch 'hl.dsp.focus({window="class:md\\.obsidian\\.Obsidian"})'
else
    hyprctl dispatch 'hl.dsp.exec_cmd("'"$APP_NAME"'")'
fi
