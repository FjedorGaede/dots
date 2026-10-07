#!/usr/bin/env bash
# install: slack (category: apps)
# Runs on 'dots install apps' after the category's packages are installed.
# MUST be idempotent — safe to run again on every install.
#
# Slack as a web app, the Omarchy way: a .desktop entry that opens
# app.slack.com in a chromeless vivaldi --app window (vivaldi comes from
# packages/apps/packages.txt). No Electron client — screen sharing in huddles
# goes through Chromium's PipeWire capture + xdg-desktop-portal-hyprland.
# The entry is rewritten on every run so changes here reach the machine.
set -euo pipefail

APPS_DIR="$HOME/.local/share/applications"
ICON_DIR="$APPS_DIR/icons"
ICON="$ICON_DIR/Slack.png"
ICON_URL="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/slack.png"
DESKTOP_FILE="$APPS_DIR/slack.desktop"

if ! command -v vivaldi >/dev/null 2>&1; then
    echo "vivaldi not found — is vivaldi in packages/apps/packages.txt?" >&2
    exit 1
fi

mkdir -p "$ICON_DIR"

if [ ! -s "$ICON" ]; then
    curl -fsSL -o "$ICON" "$ICON_URL"
fi

cat > "$DESKTOP_FILE" <<EOF
[Desktop Entry]
Version=1.0
Name=Slack
Comment=Slack web app
Exec=vivaldi --app=https://app.slack.com/client
Terminal=false
Type=Application
Icon=$ICON
Categories=Network;InstantMessaging;
StartupNotify=true
StartupWMClass=vivaldi-app.slack.com__client-Default
EOF

echo "slack web app installed: $DESKTOP_FILE"
