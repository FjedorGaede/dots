#!/bin/bash
APP_NAME="obsidian"
CLASS_NAME="obsidian"

if hyprctl clients | grep -q "class: $CLASS_NAME"; then
    hyprctl dispatch focuswindow "class:$CLASS_NAME"
else
    hyprctl dispatch exec $APP_NAME
fi
