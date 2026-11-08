#!/usr/bin/env bash
# install: usb-flasher (category: hyprland)
# Runs on 'dots install hyprland' after the category's packages are installed.
# MUST be idempotent — safe to run again on every install.
#
# Write an ISO / image to a USB stick from the home menu. The code is stowed
# with quickshell — overview in
# stow/quickshell/.config/quickshell/modules/flasher/README.md.
# A dots app (docs/APPS.md in the quickshell config): installs exactly the
# flasher's own packages. A polkit agent (hyprpolkitagent) comes with the
# hyprland category.
#
# Re-run any time with:  dots install hyprland --only usb-flasher
#
#   install.sh --check   exit 0 if everything is installed, 1 if not (no
#                        output) — FlasherService.checkInstalled
set -euo pipefail

PACKAGES=(
    util-linux   # lsblk, umount
    coreutils    # dd, sync
    polkit       # pkexec — dd needs root
)

if [ "${1:-}" = --check ]; then
    pacman -Q "${PACKAGES[@]}" >/dev/null 2>&1
    exit
fi

if pacman -Q "${PACKAGES[@]}" >/dev/null 2>&1; then
    echo "usb-flasher packages already installed"
else
    sudo pacman -S --needed --noconfirm "${PACKAGES[@]}"
fi

echo "usb-flasher ready — home menu → Flash USB stick"
