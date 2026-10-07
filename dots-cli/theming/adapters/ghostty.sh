#!/usr/bin/env bash
# Theme adapter: ghostty.
#
# Ghostty pulls in ~/.cache/wal/colors-ghostty via config-file, but only reads
# its config at startup. SIGUSR2 makes running instances reload it, so open
# windows pick up the new colors too.

set -euo pipefail

pkill -USR2 -x ghostty 2>/dev/null || true   # no running ghostty — nothing to do
