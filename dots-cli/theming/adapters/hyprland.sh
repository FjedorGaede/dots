#!/usr/bin/env bash
# Theme adapter: hyprland.
#
# Hyprland only parses ~/.cache/wal/colors-hyprland.conf once at config load
# (via shared.lua) — it does NOT watch the file. So after wal regenerates the
# cache we must explicitly reload the hyprland config.

set -euo pipefail

command -v hyprctl >/dev/null 2>&1 || exit 0     # not on hyprland — nothing to do
hyprctl instances 2>/dev/null | grep -q . || exit 0  # no running instance

hyprctl reload >/dev/null
