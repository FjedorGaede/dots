#!/usr/bin/env bash
# install: insta360 (category: apps)
# Runs on 'dots install apps' (or --only <name>) after the category's packages.
# MUST be idempotent — safe to run again on every install.
#
# Control an Insta360 Link / Link 2 webcam from the home menu (gimbal, AI
# modes, image settings). The code is stowed with quickshell — overview in
# stow/quickshell/.config/quickshell/modules/insta360/README.md.
# A dots app (docs/APPS.md in the quickshell config): installs exactly the
# webcam controls' own packages.
#
# Re-run any time with:  dots install apps --only insta360
#
#   install.sh --check   exit 0 if everything is installed, 1 if not (no
#                        output) — Insta360Service.checkInstalled
set -euo pipefail

PACKAGES=(
    v4l-utils   # v4l2-ctl — pan/tilt/zoom, focus, image controls
    python      # link.py — the Insta360 extension unit (AI modes)
    qt6-multimedia         # live preview in the menu (Preview.qml) — also wakes the gimbal
    qt6-multimedia-ffmpeg  # its backend (V4L2 cameras)
)

if [ "${1:-}" = --check ]; then
    pacman -Q "${PACKAGES[@]}" >/dev/null 2>&1
    exit
fi

if pacman -Q "${PACKAGES[@]}" >/dev/null 2>&1; then
    echo "insta360 packages already installed"
else
    sudo pacman -S --needed --noconfirm "${PACKAGES[@]}"
fi

echo "insta360 ready — home menu → Webcam (shown while the camera is plugged in)"
