#!/usr/bin/env bash
# setup: yay (category: core)
# Runs on 'dots install core' after the category's packages are installed.
# MUST be idempotent — safe to run again on every install.
#
# Ensures yay exists: builds it from the AUR via makepkg when it is not
# installed (yay itself cannot come from the AUR without yay). aur: entries in
# packages.txt need yay at install time, so this setup runs before any other
# category needs it — bootstrap.sh installs core first by design.
set -euo pipefail

if command -v yay >/dev/null 2>&1; then
    echo "yay already installed: $(yay --version | head -n1)"
    exit 0
fi

# makepkg build dependencies (only installed if missing)
if ! pacman -Q --quiet base-devel git >/dev/null 2>&1; then
    echo "installing build dependencies (base-devel git)"
    sudo pacman -S --needed --noconfirm base-devel git
fi

BUILD_DIR="$(mktemp -d)"
trap 'rm -rf "$BUILD_DIR"' EXIT

git clone --depth=1 https://aur.archlinux.org/yay.git "$BUILD_DIR/yay"
( cd "$BUILD_DIR/yay" && makepkg -si --noconfirm )

command -v yay >/dev/null 2>&1 || { echo "yay build finished but yay is not on PATH" >&2; exit 1; }
echo "yay installed: $(yay --version | head -n1)"
