#!/usr/bin/env bash
# setup: github — run via 'dots setup github'
#
# Logs gh into GitHub (browser/device-code flow) and uploads the ssh key,
# titled with the hostname. Needs the ssh key — runs 'dots setup ssh' first
# when it's missing. Every step is skipped when already done.
set -euo pipefail

KEY="$HOME/.ssh/id_ed25519"
DOTS="${DOTS:-dots}"

ssh_works() { # BatchMode: never prompt; unknown host key = not set up yet
    # ssh -T exits 1 even on success (no shell access) — judge by the greeting
    local out
    out="$(ssh -T -o BatchMode=yes -o ConnectTimeout=5 "$@" git@github.com 2>&1 || true)"
    grep -q "successfully authenticated" <<< "$out"
}

if [ "${1:-}" = "status" ]; then
    if gh auth status -h github.com >/dev/null 2>&1 && ssh_works; then
        echo "connected ($(gh api user --jq .login 2>/dev/null || echo "?"))"
        exit 0
    fi
    echo "not connected"
    exit 1
fi

[ -f "$KEY" ] || "$DOTS" setup ssh

if ! gh auth status -h github.com >/dev/null 2>&1; then
    # no browser on the TTY → gh prints a code for github.com/login/device
    gh auth login -h github.com --web --git-protocol ssh --skip-ssh-key -s admin:public_key
elif ! gh auth status -h github.com 2>&1 | grep -q "admin:public_key"; then
    gh auth refresh -h github.com -s admin:public_key
fi

pubkey="$(cut -d' ' -f1-2 "$KEY.pub")"
if gh api user/keys --jq '.[].key' | grep -qxF -- "$pubkey"; then
    echo "ssh key already on GitHub"
else
    gh ssh-key add "$KEY.pub" --title "$(uname -n)"
fi

# accept-new: first contact stores github.com's host key instead of prompting
if ssh_works -o StrictHostKeyChecking=accept-new; then
    echo "GitHub ssh works"
else
    echo "github: ssh -T git@github.com still fails" >&2
    exit 1
fi
