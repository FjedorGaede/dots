#!/usr/bin/env bash
# setup: online-coach — run via 'dots setup online-coach'
# dots-setup: optional
#
# Installs the Online Coach App (YSConsulting GmbH, Play id
# com.cyquer.onlinecoach) into Waydroid. There is no Linux build; the
# Android app runs in Waydroid (optional step 'waydroid', run first if missing).
#
# Installed from the Play Store, not from an APK mirror: Google-signed
# build, and Play keeps it updated. That needs a per-machine Google login
# inside Android, so it can't run unattended in 'dots install'. Optional
# step: listed in the setup menu, but the bar never nags about it. Flow: start Waydroid → (once) whitelist the device via
# 'waydroid-register' → open the app's Play page → you tap "Installieren"
# → Waydroid creates the launcher entry itself.
#
#   setup.sh status   exit 0 when the launcher entry exists
set -euo pipefail

PKG=com.cyquer.onlinecoach
DESKTOP="$HOME/.local/share/applications/waydroid.$PKG.desktop"

if [ "${1:-}" = status ]; then
    if [ -f "$DESKTOP" ]; then
        echo "installed"
        exit 0
    fi
    echo "coaching app (Android, via Waydroid) — not installed"
    exit 1
fi

if [ -f "$DESKTOP" ]; then
    echo "Online Coach already installed — it's in the launcher"
    exit 0
fi

if ! bash "$DOTFILES_DIR/setup/waydroid/setup.sh" status >/dev/null 2>&1; then
    echo "waydroid missing — setting it up first"
    bash "$DOTFILES_DIR/setup/waydroid/setup.sh"
fi

# Kernel updated since boot → its modules are gone and waydroid-net.sh can't
# load the bridge/netfilter modules: the session dies right away
if [ ! -d "/usr/lib/modules/$(uname -r)" ]; then
    echo "kernel was updated since boot — reboot first, then re-run 'dots setup online-coach'"
    exit 1
fi

# Full UI also starts the session; keep it in the background
echo "starting waydroid…"
waydroid show-full-ui >/dev/null 2>&1 &
running=false
for _ in $(seq 90); do
    if waydroid status 2>/dev/null | grep -q 'Session:.*RUNNING'; then
        running=true
        break
    fi
    sleep 1
done
if ! $running; then
    echo "waydroid session didn't start — see: journalctl -u waydroid-container -n 30"
    exit 1
fi

# Manual steps are printed as a framed "YOUR TURN" block, so the log always
# says what to do next (the Android UI itself is out of our reach).
todo() {
    local title="$1"; shift
    if command -v gum >/dev/null 2>&1; then
        gum style --border rounded --border-foreground 212 --padding "0 1" \
            "YOUR TURN — $title" "" "$@"
    else
        printf '\n=== YOUR TURN — %s ===\n' "$title"; printf '  %s\n' "$@"; echo
    fi
}

# Session RUNNING ≠ Android booted: an intent sent earlier is silently lost
echo "waiting for Android to finish booting…"
for _ in $(seq 120); do
    [ "$(waydroid prop get sys.boot_completed 2>/dev/null | tail -1)" = 1 ] && break
    sleep 1
done

# The Google app (Assistant / "Hey Google") listens on the mic and pops up
# its own window when you talk. Not needed for Play Store or the app itself →
# disable it inside Android. Idempotent; re-enable with
#   sudo waydroid shell -- pm enable com.google.android.googlequicksearchbox
sudo waydroid shell -- pm disable-user --user 0 com.google.android.googlequicksearchbox >/dev/null 2>&1 \
    && echo "Google app / Assistant disabled in Android" || true

if ! gum confirm "Has this Waydroid been registered with Google before (waydroid-register)?"; then
    waydroid-register || true
    todo "register the device with Google (once per Waydroid install)" \
        "1. The browser opened google.com/android/uncertified — sign in." \
        "2. Paste the android_id (already in your clipboard) and click 'Register'." \
        "3. Wait 5–10 minutes (Google needs a moment)." \
        "4. Run:  waydroid session stop" \
        "5. Run again:  dots setup online-coach   (answer 'Yes' this time)"
    exit 1
fi

echo "opening the Play Store page…"
waydroid app intent android.intent.action.VIEW "market://details?id=$PKG" >/dev/null 2>&1 || true

todo "install the app in the Android window" \
    "1. Play Store opens on 'Online Coach' (YSConsulting GmbH)." \
    "   Not there? Tap 'Play Store' on the Android home screen and search 'Online Coach'." \
    "2. Sign in with your Google account if asked." \
    "   'Device not certified'? → Ctrl+C, run waydroid-register, see its steps." \
    "3. Tap 'Installieren' and wait for the download." \
    "This script notices the install by itself — keep this terminal open."

# Waydroid writes the .desktop file as soon as the app is installed
echo "waiting for the install (max 10 min)…"
for _ in $(seq 300); do
    if [ -f "$DESKTOP" ]; then
        echo "✔ Online Coach installed — it's in the launcher"
        exit 0
    fi
    sleep 2
done

todo "no install detected after 10 min" \
    "1. Finish the install in the Play Store (Android window)." \
    "2. Run again:  dots setup online-coach"
exit 1
