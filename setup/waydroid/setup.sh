#!/usr/bin/env bash
# setup: waydroid — run via 'dots setup waydroid'
# dots-setup: optional
#
# Android apps on Linux (e.g. Online Coach App, which only ships for
# Android/iOS). Waydroid runs a full Android in an LXC container on the
# host kernel — CachyOS kernels ship binder/binderfs built in, Hyprland
# provides the Wayland session.
#
#   - waydroid from extra, waydroid-container.service enabled
#   - python-pyclip: shared clipboard host ↔ Android (Ctrl+C / Ctrl+V both
#     ways); without it waydroid silently skips its clipboard service
#   - Android image WITH Google Play (GAPPS) — apps get installed from the
#     Play Store and keep Play Services (push, login). Google first has to
#     whitelist the device once: run 'waydroid-register' after this script.
#   - ufw (active by default on CachyOS) blocks DNS/DHCP/forwarding on the
#     waydroid0 bridge → Android would have no internet without these rules.
#
# Installed Android apps appear as normal desktop entries
# (~/.local/share/applications/waydroid.*.desktop) in the launcher.
#
# Opt-in (not every machine needs Android): a setup step, not an install
# script, so 'dots install apps' / bootstrap never pull in ~1 GB of Android.
# Idempotent — safe to re-run.
#
#   setup.sh status   exit 0 if installed + initialised, 1 if not
set -euo pipefail

if [ "${1:-}" = status ]; then
    if pacman -Q waydroid python-pyclip >/dev/null 2>&1 && [ -f /var/lib/waydroid/waydroid.cfg ]; then
        echo "installed"
        exit 0
    fi
    echo "Android apps on Linux — not installed"
    exit 1
fi

PACKAGES=(waydroid python-pyclip)
if pacman -Q "${PACKAGES[@]}" >/dev/null 2>&1; then
    echo "waydroid + python-pyclip already installed"
else
    sudo pacman -S --needed --noconfirm "${PACKAGES[@]}"
fi

if systemctl is-enabled --quiet waydroid-container.service 2>/dev/null; then
    echo "waydroid-container.service already enabled"
else
    sudo systemctl enable --now waydroid-container.service
fi

# Android image: downloads ~1 GB once. Skipped when already initialised
# (re-init would wipe nothing, but re-downloads; use 'sudo waydroid init -f').
if [ -f /var/lib/waydroid/waydroid.cfg ]; then
    echo "waydroid already initialised ($(grep -m1 '^system_ota' /var/lib/waydroid/waydroid.cfg | grep -oiE 'gapps|vanilla' || echo unknown) image)"
else
    sudo waydroid init -s GAPPS
    # the container service needs a restart to pick up the fresh image
    sudo systemctl restart waydroid-container.service
fi

# Firewall: only when ufw is actually running. 'ufw allow' is idempotent
# (prints "Skipping adding existing rule").
if command -v ufw >/dev/null 2>&1 && systemctl is-active --quiet ufw; then
    sudo ufw allow in on waydroid0 to any port 53 proto udp comment waydroid-dns >/dev/null
    sudo ufw allow in on waydroid0 to any port 67 proto udp comment waydroid-dhcp >/dev/null
    sudo ufw route allow in on waydroid0 comment waydroid-forward >/dev/null
    sudo ufw route allow out on waydroid0 comment waydroid-forward >/dev/null
    echo "ufw rules for waydroid0 in place"
fi

echo "waydroid ready: $(pacman -Q waydroid | awk '{print $2}')"
echo "next: run 'waydroid-register' once (Google Play device whitelisting)"
