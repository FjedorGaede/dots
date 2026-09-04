#!/usr/bin/env bash
# TEMPORARY one-off: select which packages from the old (backup) setup to
# transfer into the new repo. Selected entries are added via `dots add`
# (install-first, track-second) — dogfooding the CLI as intended.
set -euo pipefail

DOTS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/dots-cli/bin/dots"

# entries: category/package — "aur:" prefix routes through yay
# core          = session-agnostic (any DE): shell/system tools + ghostty
# hyprland      = the full Hyprland session stack + optional desktop extras
# dev           = development tools
entries=(
  # core — shell/system tools, usable in any session
  "core/btop" "core/curl" "core/fd" "core/ffmpeg" "core/fzf" "core/git"
  "core/gum" "core/htop" "core/imagemagick" "core/jq" "core/lsd"
  "core/openssh" "core/poppler" "core/resvg" "core/ripgrep" "core/starship"
  "core/stow" "core/tmux" "core/unzip" "core/yazi" "core/zip" "core/zoxide"
  "core/brightnessctl" "core/aur:yay" "core/ghostty"
  # hyprland — the session stack (compositor + shell + launcher + lock)
  "hyprland/hyprland" "hyprland/quickshell" "hyprland/hyprlock"
  "hyprland/hypridle" "hyprland/hyprpaper" "hyprland/hyprshot"
  "hyprland/hyprpolkitagent" "hyprland/waybar"
  "hyprland/aur:walker" "hyprland/aur:elephant" "hyprland/aur:astal"
  "hyprland/aur:wlogout" "hyprland/aur:swayosd"
  # hyprland — optional desktop extras / machine-specific
  "hyprland/pamixer" "hyprland/pavucontrol" "hyprland/nm-connection-editor"
  "hyprland/blueman" "hyprland/aur:tuxedo-control-center"
  "hyprland/aur:python-pywal16"
  # dev
  "dev/entr" "dev/just" "dev/lazygit" "dev/bob"
)

# Fix tracking from earlier experiments: hyprland/quickshell were added to
# core under the old rule — untrack (NOT uninstall), re-added below.
"$DOTS" remove core hyprland quickshell || true

mapfile -t selected < <(gum choose --no-limit --header \
  "Transfer which packages to the new repo? (x to select, type to search, enter to confirm)" \
  "${entries[@]}")

count=0
for e in "${selected[@]}"; do
  [ -n "$e" ] || continue
  cat="${e%%/*}"; pkg="${e#*/}"
  if [[ "$pkg" == aur:* ]]; then
    "$DOTS" add "${pkg#aur:}" --aur --category "$cat"
  else
    "$DOTS" add "$pkg" --category "$cat"
  fi
  count=$((count + 1))
done
echo "Transferred $count package(s). Review with: dots list"
