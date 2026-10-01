#!/usr/bin/env bash
# Theme adapter: quickshell.
#
# Quickshell's CLI has no reload subcommand (only log/list/kill/ipc, and the
# shell's IpcHandlers don't cover theming). Theme.qml watches
# ~/.cache/wal/colors.json for live color updates, but a restart is the
# catch-all that also re-runs any QML that reads colors at instantiation time.

set -euo pipefail

command -v qs >/dev/null 2>&1 || exit 0          # not installed — nothing to do
qs list 2>/dev/null | grep -q '^Instance' || exit 0  # not running — nothing to do

qs kill

# wait for the old instance(s) to fully exit before relaunching
for _ in 1 2 3 4 5 6 7 8 9 10; do
    qs list 2>/dev/null | grep -q '^Instance' || break
    sleep 0.2
done

# daemonize again, exactly like the hyprland autostart does
qs -d
