#!/bin/bash
APP_NAME="obsidian"
CLASS_NAME="obsidian"

if hyprctl clients | grep -q "class: $CLASS_NAME"; then
    hyprctl dispatch 'hl.dsp.focus({window="class:'"$CLASS_NAME"'"})'
else
    hyprctl dispatch 'hl.dsp.exec_cmd("'"$APP_NAME"'")'
fi
