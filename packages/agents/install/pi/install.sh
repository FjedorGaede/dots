#!/usr/bin/env bash
# install: pi (category: agents)
# Runs on 'dots install agents' after the category's packages are installed.
# MUST be idempotent — safe to run again on every install.
#
# Installs the pi coding agent via its official installer — no system
# nodejs/npm needed. pi runs on Node >= 22.19: an existing node is used if new
# enough; if there is none, the installer fetches a private Node into
# ~/.local/share/pi-node. The pi command lands in ~/.local/bin.
#
# Its config lives in the stowed pi component (~/.config/pi, via
# PI_CODING_AGENT_DIR in .zshrc). The install itself is pinned to the default
# ~/.pi/agent so it never ends up inside the stowed (possibly repo-symlinked)
# ~/.config/pi.
set -euo pipefail

for p in "$(command -v pi || true)" "$HOME/.local/bin/pi" "$HOME/.pi/agent/bin/pi"; do
    if [ -n "$p" ] && [ -x "$p" ]; then
        echo "pi already installed: $p"
        exit 0
    fi
done

# The installer puts pi into the first known bin dir on PATH, else into
# ~/.pi/agent/bin plus a "add it to your PATH?" question (written to $SHELL's
# rc — fish on a fresh CachyOS). During bootstrap ~/.local/bin isn't on PATH
# yet (the shell rc isn't stowed) → put it there: pi lands in ~/.local/bin.
mkdir -p "$HOME/.local/bin"
export PATH="$HOME/.local/bin:$PATH"

# The installer has no "yes to all" and asks on /dev/tty — "install Node.js?"
# (no node yet) and its action menu "install Pi?". script(1) gives it a
# pseudo-terminal fed with the answers (both "y", the defaults). stdout
# through cat: no tty on stdout skips the closing "Start pi now?".
# SHELL=bash: script runs the command with $SHELL (fish on fresh CachyOS).
printf 'y\ny\n' | SHELL=/bin/bash script -qec \
    'curl -fsSL https://pi.dev/install.sh | PI_CODING_AGENT_DIR="$HOME/.pi/agent" sh | cat' /dev/null
