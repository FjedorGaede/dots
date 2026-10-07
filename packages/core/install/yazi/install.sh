#!/usr/bin/env bash
# install: yazi (category: core)
# Runs on 'dots install core' after the category's packages are installed.
# MUST be idempotent — safe to run again on every install.
#
# Makes yazi the default file manager (inode/directory). The packaged
# yazi.desktop has Terminal=true, which most launchers can't resolve to
# ghostty, so we ship our own entry that opens yazi inside ghostty
# (without ghostty's close confirmation — yazi is always "running").
set -euo pipefail

APPS_DIR="$HOME/.local/share/applications"
DESKTOP_FILE="$APPS_DIR/yazi-ghostty.desktop"

mkdir -p "$APPS_DIR"

cat > "$DESKTOP_FILE" <<EOF
[Desktop Entry]
Name=Yazi
Comment=Terminal file manager (in Ghostty)
Icon=yazi
Type=Application
Exec=ghostty --confirm-close-surface=false -e yazi %u
Terminal=false
MimeType=inode/directory;
Categories=System;FileManager;
NoDisplay=true
EOF

xdg-mime default yazi-ghostty.desktop inode/directory
update-desktop-database "$APPS_DIR" 2>/dev/null || true

echo "yazi set as default file manager: $DESKTOP_FILE"
