#!/usr/bin/env bash
# updates-check.sh — system update state for the bar (UpdatesService).
# No root, changes nothing: checkupdates (pacman-contrib) syncs into a temp
# copy of the databases. Prints tab-separated key/value lines:
#
#   updates  <n>             pending package updates (0 when the check failed)
#   days     <n>|-1          days since the last COMPLETED 'pacman -Syu'
#                            (-1: none in the log)
#   mirror   ok|error|offline  checkupdates failed with internet up → error
#   reboot   0|1             running kernel's modules are gone (kernel updated)
set -uo pipefail

LOG=/var/log/pacman.log

# --- pending updates / mirror health ---
list="$(checkupdates 2>/dev/null)"
rc=$?
updates=0
mirror=ok
case $rc in
    0) updates="$(printf '%s\n' "$list" | grep -c .)" ;;
    2) ;;                                   # nothing to update
    *)
        if [ "$(nmcli networking connectivity 2>/dev/null)" = full ]; then
            mirror=error
        else
            mirror=offline
        fi
        ;;
esac

# --- last completed full upgrade ---
# "starting full system upgrade" alone isn't enough: an aborted -Syu (n at the
# prompt, download 404) logs it too. Count it only when a "transaction
# completed" follows before the next pacman command.
last="$(awk '
    /\[PACMAN\] Running /                  { pending = "" }
    /starting full system upgrade/          { pending = substr($1, 2, 19) }
    /\[ALPM\] transaction completed/        { if (pending != "") { last = pending; pending = "" } }
    END { print last }
' "$LOG" 2>/dev/null)"
days=-1
if [ -n "$last" ]; then
    then_s="$(date -d "${last/T/ }" +%s 2>/dev/null || echo 0)"
    [ "$then_s" -gt 0 ] && days=$(( ($(date +%s) - then_s) / 86400 ))
fi

# --- reboot pending ---
reboot=0
[ -d "/usr/lib/modules/$(uname -r)" ] || reboot=1

printf 'updates\t%s\ndays\t%s\nmirror\t%s\nreboot\t%s\n' "$updates" "$days" "$mirror" "$reboot"
