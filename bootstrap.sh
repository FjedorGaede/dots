#!/usr/bin/env bash
# bootstrap.sh — fresh-machine entrypoint for the dotfiles.
#
#   bash <(curl -fsSL https://raw.githubusercontent.com/FjedorGaede/dots/main/bootstrap.sh)
#
# (NOT `curl ... | bash`: the script is interactive — sudo and gum need the
# terminal on stdin, which piping cuts off.)
# or, when the repo is already around:  ~/dots/bootstrap.sh
#
# Flow: base tools (pacman) → clone/pull repo → pick categories (core+hyprland
# pre-selected) → dots install (its core/yay install script builds yay from the AUR if
# missing — that's why core must be installed) → dots stow all components →
# first-run setup (dracula theme, zsh login shell) → optional
# dots install agents --pick (claude, pi) → optional dots install apps --pick.
#
# The default theme is dracula; the custom accent comes from the stowed
# quickshell theme layering (theme/overrides.json), not from wal.

set -euo pipefail

REPO_URL="https://github.com/FjedorGaede/dots.git"
# branch to clone — override with DOTFILES_BRANCH until the work branch is
# merged into main
case "${DOTFILES_BRANCH:-}" in
    "") BRANCH="main" ;;
    *) BRANCH="$DOTFILES_BRANCH" ;;
esac
REPO_URL_RAW="https://raw.githubusercontent.com/FjedorGaede/dots/$BRANCH/bootstrap.sh"
DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dots}"
DEFAULT_THEME="dracula"

log() { if command -v gum >/dev/null 2>&1; then gum log --level info "$*"; else echo "==> $*"; fi; }
die() { if command -v gum >/dev/null 2>&1; then gum log --level error "$*" >&2; else echo "bootstrap: $*" >&2; fi; exit 1; }

# --- 0. sanity ----------------------------------------------------------------

[ -t 0 ] || die "interactive terminal required — run via: bash <(curl -fsSL $REPO_URL_RAW)"

grep -qE '^ID=(arch|cachyos)$' /etc/os-release 2>/dev/null \
    || die "not an Arch-based system (/etc/os-release says otherwise)"

[ "$(id -u)" -ne 0 ] || die "run as a regular user — the yay install script builds via makepkg, which refuses root"

sudo -v   # ask for the password once, up front

# --- 1. base tools + full system upgrade (from official repos; yay is not
#        available yet). The upgrade avoids partial upgrades: everything after
#        this installs against a current database.

log "full system upgrade (pacman -Syu)"
sudo pacman -Syu --noconfirm

log "installing base tools (git gum stow base-devel)"
sudo pacman -S --needed --noconfirm git gum stow base-devel

# --- 2. clone or update the repo ----------------------------------------------

if [ -d "$DOTFILES_DIR/.git" ]; then
    log "updating existing repo at $DOTFILES_DIR"
    git -C "$DOTFILES_DIR" pull --ff-only
else
    log "cloning dotfiles to $DOTFILES_DIR (branch: $BRANCH)"
    git clone -b "$BRANCH" "$REPO_URL" "$DOTFILES_DIR"
fi

# --- 3. pick categories (core + hyprland pre-selected) ------------------------

DOTS="$DOTFILES_DIR/dots-cli/bin/dots"

# agents and apps are left out here — steps 6 and 7 ask for them separately
mapfile -t all_cats < <(find "$DOTFILES_DIR/packages" -mindepth 1 -maxdepth 1 -type d ! -name '.*' ! -name agents ! -name apps -printf '%f\n' | sort)
[ ${#all_cats[@]} -gt 0 ] || die "no categories found in $DOTFILES_DIR/packages"

log "choose what to install (x toggles, core + hyprland pre-selected)"
chosen="$(gum choose --no-limit \
    --header "Install which categories?" \
    --selected "core,hyprland" \
    "${all_cats[@]}")"
[ -n "$chosen" ] || die "no categories selected"

# core provisions yay (via its install script) — without it no aur: package in
# any category can install. chosen is newline-separated (gum multi-select).
grep -qx "core" <<< "$chosen" \
    || die "category 'core' must be selected — it provisions yay"

# shellcheck disable=SC2086
log "installing: $chosen"
# core's yay install script builds yay from the AUR when missing — required
# before any other selected category can install its aur: entries.
# shellcheck disable=SC2086
"$DOTS" install $chosen

# --- 4. stow all components -----------------------------------------------------

log "stowing all components"
"$DOTS" stow all

# --- 5. first-run setup ---------------------------------------------------------

# initial colorscheme so Hyprland, quickshell and fzf have colors on first
# start. wal comes from the hyprland category — without it, skip.
if [ ! -f "$HOME/.cache/wal/colors.sh" ]; then
    if command -v wal >/dev/null 2>&1; then
        log "generating initial colorscheme ($DEFAULT_THEME — the accent comes from the quickshell theme overrides)"
        "$DOTS" theme "$DEFAULT_THEME"
    else
        log "skipping the colorscheme — wal not installed (comes with the hyprland category)"
    fi
fi

# fresh Arch installs default to bash; set zsh as the login shell
if [ "${SHELL:-}" != "$(command -v zsh)" ]; then
    if gum confirm "Set zsh as your login shell? (runs chsh)"; then
        chsh -s "$(command -v zsh)"
        log "login shell set to zsh (active on next login)"
    fi
fi

# --- 6. coding agents (optional) ----------------------------------------------

if gum confirm "Install coding agents?"; then
    "$DOTS" install agents --pick
fi

# --- 7. apps (optional, pick per app) ------------------------------------------

if gum confirm "Install apps?"; then
    "$DOTS" install apps --pick
fi

log "bootstrap complete — log out/in (or reboot) and start Hyprland"
