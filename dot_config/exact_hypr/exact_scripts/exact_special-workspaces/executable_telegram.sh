if [[ $(pgrep -fc Telegram) -gt 0 ]]; then
  hyprctl dispatch togglespecialworkspace telegram
else
  Telegram &
fi
