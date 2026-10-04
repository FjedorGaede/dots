#!/usr/bin/env bash
# install: herdr (category: dev)
# Runs on 'dots install dev' after the category's packages are installed.
# MUST be idempotent — safe to run again on every install.
#
# Installs herdr via its official installer (checksum-verified binary into
# ~/.local/bin). It updates itself with `herdr update`, so this only installs
# when missing — no AUR package. Config lives in the stowed herdr component.
set -euo pipefail

HERDR_BIN="$HOME/.local/bin/herdr"

if [ -x "$HERDR_BIN" ]; then
    echo "herdr already installed: $("$HERDR_BIN" --version)"
    exit 0
fi

curl -fsSL https://herdr.dev/install.sh | HERDR_INSTALL_DIR="$HOME/.local/bin" sh

# print version by explicit path — a fresh-install session may not have
# ~/.local/bin on PATH yet
"$HERDR_BIN" --version
