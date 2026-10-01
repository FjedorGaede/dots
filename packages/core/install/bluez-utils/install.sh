#!/usr/bin/env bash
# install: bluez-utils (category: core)
# Runs on 'dots install core' after the category's packages are installed.
# MUST be idempotent — safe to run again on every install.
#
# Enables the bluetooth daemon (bluez, pulled in with bluez-utils from
# packages/core/packages.txt) — without it bluetoothctl, blueman and the
# quickshell bluetooth indicator find no adapter.
set -euo pipefail

UNIT="bluetooth.service"

if ! systemctl cat "$UNIT" >/dev/null 2>&1; then
    echo "$UNIT not found — is bluez-utils in packages/core/packages.txt?" >&2
    exit 1
fi

if systemctl is-enabled --quiet "$UNIT"; then
    echo "bluetooth already enabled"
    exit 0
fi

sudo systemctl enable --now "$UNIT"
echo "bluetooth enabled"
