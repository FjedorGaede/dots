#!/usr/bin/env bash
# bootstrap.sh — fresh-machine entrypoint for the dotfiles.
#
#   curl -fsSL https://raw.githubusercontent.com/FjedorGaede/dots/main/bootstrap.sh | bash
#
# or, when the repo is already around:  ~/dots/bootstrap.sh
#
# Flow: base tools (pacman) → clone/pull repo → build yay from AUR if missing
# (makepkg, therefore: never run as root) → pick categories (core+hyprland
# pre-selected) → dots install → dots stow all components → first-run setup
# (dracula theme, zsh login shell).
#
# The default theme is dracula; the custom accent comes from the stowed
# quickshell theme layering (theme/overrides.json), not from wal.

set -euo pipefail

REPO_URL="https://github.com/FjedorGaede/dots.git"
DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dots}"
DEFAULT_THEME="dracula"

log() { if command -v gum >/dev/null 2>&1; then gum log --level info "$*"; else echo "==> $*"; fi; }
die() { if command -v gum >/dev/null 2>&1; then gum log --level error "$*" >&2; else echo "bootstrap: $*" >&2; fi; exit 1; }

# --- 0. sanity ----------------------------------------------------------------

grep -qE '^ID=(arch|cachyos)$' /etc/os-release 2>/dev/null \
    || die "not an Arch-based system (/etc/os-release says otherwise)"

[ "$(id -u)" -ne 0 ] || die "run as a regular user — makepkg (yay build) refuses root"

sudo -v   # ask for the password once, up front

# --- 1. base tools (from official repos; yay is not available yet) -------------

log "installing base tools (git gum stow base-devel)"
sudo pacman -S --needed --noconfirm git gum stow base-devel

# --- 2. clone or update the repo ----------------------------------------------

if [ -d "$DOTFILES_DIR/.git" ]; then
    log "updating existing repo at $DOTFILES_DIR"
    git -C "$DOTFILES_DIR" pull --ff-only
else
    log "cloning dotfiles to $DOTFILES_DIR"
    git clone "$REPO_URL" "$DOTFILES_DIR"
fi

# --- 3. build yay from the AUR if it is not installed --------------------------

if ! command -v yay >/dev/null 2>&1; then
    log "yay not found — building from AUR (this can take a few minutes)"
    rm -rf /tmp/yay-bootstrap
    git clone --depth=1 https://aur.archlinux.org/yay.git /tmp/yay-bootstrap
    ( cd /tmp/yay-bootstrap && makepkg -si --noconfirm )
    command -v yay >/dev/null 2>&1 || die "yay build finished but yay is still not on PATH"
    rm -rf /tmp/yay-bootstrap
else
    log "yay already present"
fi

DOTS="$DOTFILES_DIR/dots-cli/bin/dots"

# --- 4. pick categories (core + hyprland pre-selected) ------------------------

mapfile -t all_cats < <(find "$DOTFILES_DIR/packages" -mindepth 1 -maxdepth 1 -type d ! -name '.*' -printf '%f\n' | sort)
[ ${#all_cats[@]} -gt 0 ] || die "no categories found in $DOTFILES_DIR/packages"

log "choose what to install (x toggles, core + hyprland pre-selected)"
chosen="$(gum choose --no-limit \
    --header "Install which categories?" \
    --selected "core,hyprland" \
    "${all_cats[@]}")"
[ -n "$chosen" ] || die "no categories selected"

# shellcheck disable=SC2086
log "installing: $chosen"
# shellcheck disable=SC2086
"$DOTS" install $chosen

# --- 5. stow all components -----------------------------------------------------

mapfile -t components < <(find "$DOTFILES_DIR/stow" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort)
[ ${#components[@]} -gt 0 ] || die "no stow components found"
# shellcheck disable=SC2086
log "stowing all components: ${components[*]}"
# shellcheck disable=SC2086
"$DOTS" stow ${components[@]}

# --- 6. first-run setup ---------------------------------------------------------

# the stowed commonshellrc sources ~/.cache/wal/colors.sh — generate the
# initial colorscheme so new shells don't error before the first theme run.
if [ ! -f "$HOME/.cache/wal/colors.sh" ]; then
    log "generating initial colorscheme ($DEFAULT_THEME — the accent comes from the quickshell theme overrides)"
    "$DOTS" theme "$DEFAULT_THEME"
fi

# fresh Arch installs default to bash; set zsh as the login shell
if [ "${SHELL:-}" != "$(command -v zsh)" ]; then
    if gum confirm "Set zsh as your login shell? (runs chsh)"; then
        chsh -s "$(command -v zsh)"
        log "login shell set to zsh (active on next login)"
    fi
fi

log "bootstrap complete — log out/in (or reboot) and start Hyprland"
