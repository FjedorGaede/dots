#!/usr/bin/env bash
# setup: nvim-config (category: dev)
# Runs on 'dots install dev' after the category's packages are installed.
# MUST be idempotent — safe to run again on every install.
#
# The neovim config is developed in its OWN git repo (not stowed — that would
# merge its history into the dotfiles repo and break pushing to it). This
# setup only makes sure the clone exists and is up to date: clone via HTTPS
# (public repo, works without SSH keys on a fresh machine), pull when present.
set -euo pipefail

REPO_HTTPS="https://github.com/FjedorGaede/neovim-config.git"
REPO_SSH="git@github.com:FjedorGaede/neovim-config.git"
DEST="$HOME/.config/nvim"

if [ -d "$DEST/.git" ]; then
    echo "nvim config repo exists at $DEST — pulling"
    if ! git -C "$DEST" pull --ff-only; then
        echo "warning: pull failed (local commits or offline) — keeping current state" >&2
    fi
else
    git clone "$REPO_HTTPS" "$DEST"
    echo "hint: once SSH keys are set up, switch the remote for push access:"
    echo "  git -C $DEST remote set-url origin $REPO_SSH"
fi

git -C "$DEST" log --oneline -1
