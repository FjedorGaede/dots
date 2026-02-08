if [[ $(pgrep -fc Spotify) -gt 0 ]]; then
  hyprctl dispatch togglespecialworkspace spotify
else
  spotify &
fi
