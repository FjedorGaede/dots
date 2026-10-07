#!/bin/bash
# Slack is a vivaldi --app web app (packages/apps/install/slack) — no daemon,
# so it's either a window or not running.

# Check if a Slack window exists in Hyprland
if hyprctl clients -j | jq -e '.[] | select(.class == "vivaldi-app.slack.com__client-Default")' > /dev/null 2>&1; then
  # Window exists → toggle special workspace
  hyprctl dispatch 'hl.dsp.workspace.toggle_special("slack")'
else
  # Not running → fresh launch
  gtk-launch slack &
fi
