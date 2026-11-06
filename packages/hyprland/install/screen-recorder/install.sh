#!/usr/bin/env bash
# install: screen-recorder (category: hyprland)
# Runs on 'dots install hyprland' after the category's packages are installed.
# MUST be idempotent — safe to run again on every install.
#
# Loom-style screen recorder in quickshell (Super+R): gpu-screen-recorder for
# the capture, a draggable webcam bubble that ends up in the video.
# Self-contained like dictation: installs exactly the recorder's own packages
# (not in packages.txt). The code is stowed with quickshell — overview in
# stow/quickshell/.config/quickshell/modules/recorder/README.md.
#
# Shared tools it also uses come from packages.txt (slurp, wl-clipboard,
# libnotify; jq from core) — they are not the recorder's alone.
#
# Re-run any time with:  dots install hyprland --only screen-recorder
#
#   install.sh --check   exit 0 if everything is installed, 1 if not (no
#                        output) — the recorder menu asks this before it offers
#                        the one-click install (RecorderService.checkInstalled)
set -euo pipefail

PACKAGES=(
    gpu-screen-recorder    # KMS capture → also records the webcam bubble
    qt6-multimedia         # QtMultimedia for the webcam picture (WebcamFeed.qml)
    qt6-multimedia-ffmpeg  # its backend (V4L2 cameras)
)

if [ "${1:-}" = --check ]; then
    pacman -Q "${PACKAGES[@]}" >/dev/null 2>&1
    exit
fi

if pacman -Q "${PACKAGES[@]}" >/dev/null 2>&1; then
    echo "screen-recorder packages already installed"
else
    sudo pacman -S --needed --noconfirm "${PACKAGES[@]}"
fi

# Started from the recorder menu, the shell reloads itself afterwards (picks
# up QtMultimedia); from a plain `dots install`, the next login does
echo "screen-recorder ready — Super+R"
