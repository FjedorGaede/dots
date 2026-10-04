#!/usr/bin/env bash
# setup: dots-remote — run via 'dots setup dots-remote'
#
# Switches ~/dots origin from https (how bootstrap clones — no key yet) to
# ssh. Needs GitHub ssh access — runs 'dots setup github' first when missing.
# Switches back to the old url if the ssh remote doesn't answer.
set -euo pipefail

SSH_URL="git@github.com:FjedorGaede/dots.git"
DOTS="${DOTS:-dots}"
REPO="${DOTFILES_DIR:-$HOME/dots}"

current="$(git -C "$REPO" remote get-url origin)"

if [ "${1:-}" = "status" ]; then
    if [ "$current" = "$SSH_URL" ]; then
        echo "ssh ($SSH_URL)"
        exit 0
    fi
    echo "https — not switched"
    exit 1
fi

if [ "$current" = "$SSH_URL" ]; then
    echo "origin already uses ssh"
    exit 0
fi

bash "$REPO/setup/github/setup.sh" status >/dev/null || "$DOTS" setup github

git -C "$REPO" remote set-url origin "$SSH_URL"
if git -C "$REPO" ls-remote origin >/dev/null 2>&1; then
    echo "origin: $SSH_URL"
else
    git -C "$REPO" remote set-url origin "$current"
    echo "dots-remote: $SSH_URL not reachable — origin left at $current" >&2
    exit 1
fi
