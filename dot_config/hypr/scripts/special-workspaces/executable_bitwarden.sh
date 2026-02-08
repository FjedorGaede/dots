if [[ $(pgrep -fc bitwarden) -gt 0 ]]; then
  hyprctl dispatch togglespecialworkspace bitwarden
else
  bitwarden &
fi
