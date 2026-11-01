#!/usr/bin/env bash
# install: dictation (category: hyprland)
# Runs on 'dots install hyprland' after the category's packages are installed.
# MUST be idempotent — safe to run again on every install.
#
# Local push-to-talk dictation: whispy as the engine (Parakeet speech model,
# Vulkan/CPU), our own Quickshell pill + Hyprland keybinds on top.
# Self-contained: installs whispy + wtype + ydotool (not in packages.txt),
# downloads the model (~740 MB), seeds the config, and enables the whispy-daemon
# user service. Keybinds live in hypr/keybinds.lua, the pill in quickshell's
# modules/osd/DictationPill.qml.
#
# Re-run any time with:  dots install hyprland --only dictation
# Every step is idempotent, so re-running re-applies the config and restarts the
# daemon — that is the way to fix a broken setup.
#
# Injection (injection.mode = "paste"): the transcript goes onto the clipboard and
# a synthetic keystroke pastes it, so it appears as one block instead of being
# typed out. Needs ydotool with access to /dev/uinput (the `input` group, step 2)
# and the uinput kernel module. If either is missing, the mode stays "type"
# (character by character) until the script is run again after a reboot.
#
# The keystroke is Ctrl+Shift+V because Ctrl+V does not paste in terminals (in
# Ghostty it is quoted-insert, in nvim block-visual). Ctrl+Shift+V pastes in
# Ghostty and in Chromium/Electron apps (there as plain text); a few Qt apps
# (e.g. Telegram) only know Ctrl+V — change `paste_keys` in
# ~/.config/whispy/config.toml and restart the daemon if you hit one.
#
# Not used: 'whispy-daemon setup' in full copies whispy's own pill module into
# ~/.config/quickshell/Whispy (= into the stow repo); we have our own pill.
set -euo pipefail

PACKAGES=(whispy wtype ydotool)
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/whispy/config.toml"
UNIT_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
# ydotool tokens: Ctrl down, Shift down, V down, V up, Shift up, Ctrl up
PASTE_KEYS='29:1 42:1 47:1 47:0 42:0 29:0'

die() { echo "dictation: $*" >&2; exit 1; }
info() { echo "==> $*"; }

# config_set <section> <key> <value> — replace one key inside a section, keep the
# rest of the file (comments, edits) untouched, and fail loudly if it did not take.
config_set() {
    local section="$1" key="$2" value="$3"
    case "$value" in
        # quoted value: replace only the quotes, so trailing comments survive
        \"*\") sed -i "/^\[$section\]/,/^\[/ s|^\($key *= *\)\"[^\"]*\"|\1$value|" "$CONFIG" ;;
        *) sed -i "/^\[$section\]/,/^\[/ s|^\($key *= *\)[^ #]*|\1$value|" "$CONFIG" ;;
    esac
    local got
    got="$(awk -v s="[$section]" -v k="$key" '
        /^\[/ { insec = ($0 == s) }
        insec && $0 ~ "^"k" *=" {
            sub(/^[^=]*= */, "")   # drop "key = "
            sub(/ *#.*$/, "")      # drop a trailing comment
            sub(/ *$/, "")
            print; exit
        }' "$CONFIG")"
    [ "$got" = "$value" ] || die "could not set $section.$key in $CONFIG (got: ${got:-nothing})"
}

# ── 1. packages (whispy is AUR, so yay) ───────────────────────────────────────
if pacman -Q "${PACKAGES[@]}" >/dev/null 2>&1; then
    echo "whispy + wtype + ydotool already installed"
else
    command -v yay >/dev/null 2>&1 || die "yay not found (whispy is an AUR package)"
    yay -S --needed --noconfirm "${PACKAGES[@]}"   # whispy builds from source: a few minutes
fi
for c in whispy-daemon whispy-client wtype ydotool; do
    command -v "$c" >/dev/null 2>&1 || die "$c not on PATH after installing"
done

# ── 2. uinput access for ydotool (sudo) ──────────────────────────────────────
# The distro rule (/usr/lib/udev/rules.d/80-uinput.rules) hands /dev/uinput to the
# `input` group; a group change only reaches the session at the next login.
if ! id -nG "$USER" | tr ' ' '\n' | grep -qx input; then
    info "adding $USER to the 'input' group (sudo) — takes effect after a re-login"
    sudo groupadd -f input
    sudo usermod -aG input "$USER"
fi
# Load the module at boot: after a kernel update the old /lib/modules tree is gone,
# so uinput only becomes available again with the new kernel (i.e. after a reboot).
printf 'uinput\n' | sudo tee /etc/modules-load.d/uinput.conf >/dev/null
if [ ! -e /sys/class/misc/uinput ]; then
    info "uinput is not loaded — trying modprobe (sudo)"
    sudo modprobe uinput 2>/dev/null || true
fi
# Left over from an earlier version of this script (a uaccess rule that the seat
# rules never picked up — the group route above is the one that works).
if [ -e /etc/udev/rules.d/81-uinput.rules ]; then
    sudo rm -f /etc/udev/rules.d/81-uinput.rules
fi

uinput_ok=0
if [ -e /sys/class/misc/uinput ] && [ -w /dev/uinput ]; then
    uinput_ok=1
    echo "uinput: loaded and writable by $USER"
fi

# ── 3. ydotoold user service (whispy's verify checks ydotoold.service) ───────
if [ "$uinput_ok" = 1 ]; then
    if ! systemctl --user cat ydotoold.service >/dev/null 2>&1; then
        info "installing ydotoold.service"
        mkdir -p "$UNIT_DIR"
        cat > "$UNIT_DIR/ydotoold.service" <<'EOF'
[Unit]
Description=ydotoold (uinput daemon for dictation paste injection)
PartOf=graphical-session.target

[Service]
Type=simple
ExecStart=ydotoold
Restart=on-failure
RestartSec=2

[Install]
WantedBy=graphical-session.target
EOF
        systemctl --user daemon-reload
    fi
    systemctl --user enable --now ydotoold.service
fi

# ── 4. keep the microphone awake (user config, no sudo) ─────────────────────
# WirePlumber suspends an idle input device after 5 s (measured: the node goes to
# `suspended`). Dictation opens the stream on the key press and the mic then
# needs ~1 s to wake up: the first words come back ~17 dB too quiet (-41 instead
# of -24 dB), so the level display showed nothing at the start of a sentence.
# The setting is per node and cannot be generic — it names the microphone present
# now, and is rewritten if the default source changes.
MIC_NODE="$(wpctl inspect @DEFAULT_AUDIO_SOURCE@ 2>/dev/null | sed -n 's/.*node.name = "\(.*\)"/\1/p' | head -1)"
WP_CONF="${XDG_CONFIG_HOME:-$HOME/.config}/wireplumber/wireplumber.conf.d/51-mic-no-suspend.conf"
if [ -n "$MIC_NODE" ]; then
    wanted="$(cat <<EOF
# Keep the microphone from being suspended when idle (see dots: dictation).
# It takes about a second to wake up, and dictation starts capturing on the key
# press — that first second would come back far too quiet, so the level display
# missed the first words. Matched by node name only: other devices still suspend.
monitor.alsa.rules = [
  {
    matches = [
      { node.name = "$MIC_NODE" }
    ]
    actions = {
      update-props = {
        session.suspend-timeout-seconds = 0
      }
    }
  }
]
EOF
)"
    if [ ! -e "$WP_CONF" ] || ! cmp -s <(printf '%s\n' "$wanted") "$WP_CONF"; then
        info "keeping the microphone awake: $MIC_NODE"
        mkdir -p "$(dirname "$WP_CONF")"
        printf '%s\n' "$wanted" > "$WP_CONF"
        systemctl --user restart wireplumber   # brief audio interruption
    else
        echo "microphone stays awake already ($MIC_NODE)"
    fi
else
    echo "note: no default microphone found — skipping the suspend fix"
fi

# ── 5. speech engine, model, config, whispy-daemon (each step idempotent) ─────
whispy-daemon setup stt      # Parakeet engine (the AUR package ships it → no-op)
whispy-daemon setup model    # checksum-verified download, skipped when present
whispy-daemon setup systemd  # seeds config.toml (never overwrites), enables whispy-daemon

# ── 6. injection mode: paste in one block, or type until uinput is there ─────
if [ "$uinput_ok" = 1 ]; then
    config_set injection mode '"paste"'
    config_set injection paste_keys "\"$PASTE_KEYS\""
    # whispy drops a clip at 60 s with an error (the pill shows an X) — raise it
    config_set audio max_clip_secs "300.0"
    echo "injection: paste (one block, Ctrl+Shift+V), clip limit 5 min"
else
    config_set injection mode '"type"'
    echo "injection: type (character by character) — see the note at the end"
fi

# ── 7. (re)start and check ───────────────────────────────────────────────────
systemctl --user restart whispy-daemon
whispy-daemon setup verify

cat <<'EOF'

Keybinds: hold F9 to talk (release inserts it), Super+Ctrl+X toggles,
          Super+Ctrl+Shift+X discards — hypr/keybinds.lua.
Pill:     quickshell modules/osd/DictationPill.qml, state from DictationService.
EOF

if [ "$uinput_ok" = 0 ]; then
    cat >&2 <<'EOF'

dictation: block paste is not active yet.
  /dev/uinput is not there: this kernel has no uinput module (a kernel update is
  waiting, the running kernel's /lib/modules tree is gone) and/or the 'input'
  group is not active in this session yet.
  Reboot, then run this again — it will switch to paste automatically:

      dots install hyprland --only dictation
EOF
    exit 1
fi
