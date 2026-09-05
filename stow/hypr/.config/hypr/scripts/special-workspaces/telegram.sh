#!/bin/bash

# Check if a Telegram window exists in Hyprland
if hyprctl clients -j | jq -e '.[] | select(.class == "org.telegram.desktop")' > /dev/null 2>&1; then
  # Window exists → toggle special workspace
  hyprctl dispatch 'hl.dsp.workspace.toggle_special("telegram")'
elif pgrep -fc Telegram > /dev/null; then
  # Daemon running but no window → bring it back
  Telegram -desktop --
else
  # Not running → fresh launch
  Telegram &
fi
