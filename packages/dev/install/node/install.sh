#!/usr/bin/env bash
# install: node (category: dev)
# Runs on 'dots install dev' after the category's packages are installed.
# MUST be idempotent — safe to run again on every install.
#
# Manages node/npm via nvm (nvm comes from packages/dev/packages.txt):
# installs the latest LTS and makes it the default. Node versions live in
# ~/.nvm; .commonshellrc loads nvm in interactive shells.
set -euo pipefail

NVM_INIT="/usr/share/nvm/init-nvm.sh"

if [ ! -s "$NVM_INIT" ]; then
    echo "nvm not found — is nvm in packages/dev/packages.txt?" >&2
    exit 1
fi

export NVM_DIR="$HOME/.nvm"
export NVM_SYMLINK_CURRENT=true
mkdir -p "$NVM_DIR"

# nvm.sh is not safe under `set -eu` (unbound vars, non-zero internal checks)
set +eu
# shellcheck source=/dev/null
source "$NVM_INIT"

# Idempotent: re-running installs the newest LTS if a new one is out.
nvm install --lts || exit 1
nvm alias default 'lts/*' || exit 1
nvm use default >/dev/null || exit 1
set -eu

echo "node $(node --version), npm $(npm --version)"
