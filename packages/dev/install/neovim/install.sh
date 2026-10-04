#!/usr/bin/env bash
# install: neovim (category: dev)
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

# Without this key, `bob use` asks "Add bob-managed Neovim binary to your
# $PATH automatically?" — not needed: the nvim link below + .commonshellrc
# cover PATH. jq merge keeps any other keys in the config.
BOB_CONFIG_FILE="$HOME/.config/bob/config.json"
mkdir -p "$(dirname "$BOB_CONFIG_FILE")"
[ -s "$BOB_CONFIG_FILE" ] || echo '{}' > "$BOB_CONFIG_FILE"
jq '.add_neovim_binary_to_path = false' "$BOB_CONFIG_FILE" > "$BOB_CONFIG_FILE.tmp"
mv "$BOB_CONFIG_FILE.tmp" "$BOB_CONFIG_FILE"

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

# print version by explicit path — a fresh-install session may not have
# ~/.local/bin on PATH yet
"$BOB_BIN/nvim" --version | head -n 1
