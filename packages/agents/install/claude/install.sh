#!/usr/bin/env bash
# install: claude (category: agents)
# Runs on 'dots install agents' after the category's packages are installed.
# MUST be idempotent — safe to run again on every install.
#
# Installs Claude Code via Anthropic's native installer (into ~/.local/bin,
# versions under ~/.local/share/claude). It auto-updates itself, so this only
# installs when missing — no AUR package (that one lags far behind).
set -euo pipefail

CLAUDE_BIN="$HOME/.local/bin/claude"

if [ -x "$CLAUDE_BIN" ]; then
    echo "claude already installed: $("$CLAUDE_BIN" --version)"
    exit 0
fi

curl -fsSL https://claude.ai/install.sh | bash

# print version by explicit path — a fresh-install session may not have
# ~/.local/bin on PATH yet
"$CLAUDE_BIN" --version
