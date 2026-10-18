#!/usr/bin/env bash
# install: bluez-tools (category: core)
# Runs on 'dots install core' after the category's packages are installed.
# MUST be idempotent — safe to run again on every install.
#
# Runs bt-agent (from bluez-tools) as a systemd user service — the BlueZ
# pairing agent. Without one, devices that need a pairing confirmation
# (keyboards, phones) fail silently from the quickshell bluetooth panel,
# which can pair but has no agent API. Same approach as omarchy.
#
# The unit is installed system-wide (/etc/systemd/user) rather than stowed:
# 'dots install core' runs before stow on a fresh machine.
set -euo pipefail

SRC="$(dirname "$0")/bt-agent.service"
DEST="/etc/systemd/user/bt-agent.service"
UNIT="bt-agent.service"

if ! command -v bt-agent >/dev/null 2>&1; then
    echo "bt-agent not found — is bluez-tools in packages/core/packages.txt?" >&2
    exit 1
fi

if ! cmp -s "$SRC" "$DEST"; then
    sudo install -Dm644 "$SRC" "$DEST"
    systemctl --user daemon-reload
    echo "installed $DEST"
fi

if systemctl --user is-enabled --quiet "$UNIT" && systemctl --user is-active --quiet "$UNIT"; then
    echo "bt-agent already enabled and running"
    exit 0
fi

# restart, not just start: picks up a changed unit file
systemctl --user enable "$UNIT"
systemctl --user restart "$UNIT"
echo "bt-agent enabled and running"
