if [[ $(pgrep -fc Spotify) -gt 0 ]]; then
  hyprctl dispatch 'hl.dsp.workspace.toggle_special("spotify")'
else
  spotify &
fi
