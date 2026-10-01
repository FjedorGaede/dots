#!/usr/bin/env bash
# install: pi (category: agents)
# Runs on 'dots install agents' after the category's packages are installed.
# MUST be idempotent — safe to run again on every install.
#
# Installs the pi coding agent via its official installer — no system
# nodejs/npm needed. pi runs on Node >= 22.19: an existing node is used if new
# enough; if there is none, the installer asks to fetch a private Node into
# ~/.local/share/pi-node. The pi command lands in ~/.local/bin.
#
# Its config lives in the stowed pi component (~/.config/pi, via
# PI_CODING_AGENT_DIR in .zshrc). The install itself is pinned to the default
# ~/.pi/agent so it never ends up inside the stowed (possibly repo-symlinked)
# ~/.config/pi.
set -euo pipefail

if command -v pi >/dev/null 2>&1 || [ -x "$HOME/.local/bin/pi" ]; then
    echo "pi already installed: $(command -v pi || echo "$HOME/.local/bin/pi")"
    exit 0
fi

# stdout through cat: no tty on stdout skips the installer's closing
# "Start pi now?" prompt; its Node question still reaches /dev/tty.
curl -fsSL https://pi.dev/install.sh \
    | PI_CODING_AGENT_DIR="$HOME/.pi/agent" sh | cat
