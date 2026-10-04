#!/usr/bin/env bash
# setup: ssh — run via 'dots setup ssh'
#
# Creates ~/.ssh/id_ed25519 (no passphrase), labelled with the git email.
# Never overwrites an existing key. Uploading it to GitHub is 'dots setup github'.
set -euo pipefail

KEY="$HOME/.ssh/id_ed25519"
DOTS="${DOTS:-dots}"

if [ "${1:-}" = "status" ]; then
    if [ -f "$KEY" ]; then
        echo "key present ($(cut -d' ' -f3- "$KEY.pub" 2>/dev/null))"
        exit 0
    fi
    echo "no key"
    exit 1
fi

if [ -f "$KEY" ]; then
    echo "ssh key already exists: $KEY"
    exit 0
fi

# the email labels the key — git identity first
[ -n "$(git config --global user.email || true)" ] || "$DOTS" setup git

mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"
ssh-keygen -t ed25519 -N "" -C "$(git config --global user.email)" -f "$KEY"
