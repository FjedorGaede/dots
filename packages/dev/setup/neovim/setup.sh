#!/usr/bin/env bash
# setup: neovim (category: dev)
# Runs on 'dots install dev' after the category's packages are installed.
# MUST be idempotent — safe to run again on every install.
#
# Manages neovim via bob (bob-nvim comes from packages/dev/packages.txt):
# installs latest stable + nightly and makes nightly the default.
set -euo pipefail

if ! command -v bob >/dev/null 2>&1; then
    echo "bob not found — is bob in packages/dev/packages.txt?" >&2
    exit 1
fi

# Idempotent: re-running installs/updates to the latest of each channel.
bob install stable
bob install nightly

# Make nightly the default (symlinks the selected version into bob's bin dir).
bob use nightly

# bob's shim dir must be on PATH for the `nvim` command; wire it once.
BOB_BIN="$HOME/.local/share/bob/nvim-bin"
if [ ! -e "$HOME/.local/bin/nvim" ] && [ -x "$BOB_BIN/nvim" ]; then
    mkdir -p "$HOME/.local/bin"
    ln -s "$BOB_BIN/nvim" "$HOME/.local/bin/nvim"
    echo "linked $HOME/.local/bin/nvim -> $BOB_BIN/nvim"
fi

nvim --version | head -n 1
