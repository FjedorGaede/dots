#!/usr/bin/env bash
# install: ly (category: hyprland)
# Runs on 'dots install hyprland' after the category's packages are installed.
# MUST be idempotent — safe to run again on every install.
#
# Enables the ly login screen (ly comes from packages/hyprland/packages.txt).
# Since ly 1.4 it is a per-TTY template unit, ly@<tty>.service — the old
# ly.service is gone. ly takes over tty2, so the getty there is disabled.
# Takes effect on the next boot.
set -euo pipefail

TTY="tty2"
UNIT="ly@$TTY.service"

if ! systemctl cat "$UNIT" >/dev/null 2>&1; then
    echo "$UNIT not found — is ly in packages/hyprland/packages.txt?" >&2
    exit 1
fi

if systemctl is-enabled --quiet "$UNIT"; then
    echo "ly already enabled ($UNIT)"
    exit 0
fi

sudo systemctl disable "getty@$TTY.service"
sudo systemctl enable "$UNIT"
echo "ly enabled on $TTY — active after the next reboot"
