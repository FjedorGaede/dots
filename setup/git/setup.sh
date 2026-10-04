#!/usr/bin/env bash
# setup: git — run via 'dots setup git'
#
# Sets the global git identity (user.name, user.email). Only these two keys
# are written — everything else in ~/.gitconfig stays untouched. bootstrap.sh
# asks up front and passes GIT_NAME/GIT_EMAIL, then nothing is prompted.
set -euo pipefail

name="$(git config --global user.name || true)"
email="$(git config --global user.email || true)"

if [ "${1:-}" = "status" ]; then
    if [ -n "$name" ] && [ -n "$email" ]; then
        echo "$name <$email>"
        exit 0
    fi
    echo "not set"
    exit 1
fi

name="${GIT_NAME:-$(gum input --prompt "git name: " --placeholder "Full Name" --value "$name")}"
email="${GIT_EMAIL:-$(gum input --prompt "git email: " --placeholder "you@example.com" --value "$email")}"
[ -n "$name" ] && [ -n "$email" ] || { echo "git: name and email are required" >&2; exit 1; }

git config --global user.name "$name"
git config --global user.email "$email"
echo "git identity: $name <$email>"
