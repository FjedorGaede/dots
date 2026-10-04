#!/usr/bin/env bash
# bootstrap.sh — fresh-machine entrypoint for the dotfiles.
#
#   bash <(curl -fsSL https://raw.githubusercontent.com/FjedorGaede/dots/main/bootstrap.sh)
#
# fish (CachyOS's default login shell) has no <( ) — there:
#
#   bash (curl -fsSL https://raw.githubusercontent.com/FjedorGaede/dots/main/bootstrap.sh | psub)
#
# (NOT `curl ... | bash`: the script is interactive — sudo and gum need the
# terminal on stdin, which piping cuts off.)
# or, when the repo is already around:  ~/dots/bootstrap.sh
#
# Flow: sudo (kept alive) → base tools (pacman) → clone/pull repo →
# ALL questions up front (git identity, which optional categories, which items
# of them) → dots setup git + ssh → from here unattended: dots install
# (core first — its yay install script builds yay from the AUR, everything
# after needs it) → dots stow all → first-run setup (dracula theme, zsh login
# shell).
#
# Setup steps that need a browser or more (github, dots-remote, calendar) are
# left for later: 'dots setup'.
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
# always installed, no question — core provisions yay, so it goes first
MANDATORY=(core hyprland)

log() { if command -v gum >/dev/null 2>&1; then gum log --level info "$*"; else echo "==> $*"; fi; }
die() { if command -v gum >/dev/null 2>&1; then gum log --level error "$*" >&2; else echo "bootstrap: $*" >&2; fi; exit 1; }

# --- 0. sanity ----------------------------------------------------------------

[ -t 0 ] || die "interactive terminal required — run via: bash <(curl -fsSL $REPO_URL_RAW)  (fish: bash (curl -fsSL $REPO_URL_RAW | psub))"

grep -qE '^ID=(arch|cachyos)$' /etc/os-release 2>/dev/null \
    || die "not an Arch-based system (/etc/os-release says otherwise)"

[ "$(id -u)" -ne 0 ] || die "run as a regular user — the yay install script builds via makepkg, which refuses root"

# ask for the password once, up front — then keep the timestamp fresh so long
# AUR builds never stop at a sudo prompt. The loop dies with this script.
sudo -v
( while kill -0 "$$" 2>/dev/null; do sudo -n true; sleep 60; done ) 2>/dev/null &
SUDO_KEEPALIVE=$!
trap 'kill "$SUDO_KEEPALIVE" 2>/dev/null || true' EXIT

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

DOTS="$DOTFILES_DIR/dots-cli/bin/dots"

# --- 3. questions — everything that needs you, before anything long runs -----

log "a few questions — after these, bootstrap runs on its own"

git_name="$(gum input --prompt "git name: " --placeholder "Full Name" \
    --value "$(git config --global user.name || true)")"
git_email="$(gum input --prompt "git email: " --placeholder "you@example.com" \
    --value "$(git config --global user.email || true)")"
[ -n "$git_name" ] && [ -n "$git_email" ] || die "git name and email are required"

# optional categories = all minus MANDATORY
mapfile -t optional < <("$DOTS" list --categories | grep -vxF -f <(printf '%s\n' "${MANDATORY[@]}"))

chosen=()
if [ ${#optional[@]} -gt 0 ]; then
    mapfile -t chosen < <(gum choose --no-limit \
        --header "Choose from which categories? (${MANDATORY[*]} are always installed; x toggles)" \
        "${optional[@]}" || true)
fi

# per chosen category: which items — nothing pre-selected, ctrl+a = all
declare -A picks=()
for cat in "${chosen[@]}"; do
    [ -n "$cat" ] || continue
    mapfile -t items < <("$DOTS" list "$cat" --items)
    [ ${#items[@]} -gt 0 ] || continue
    mapfile -t picked < <(gum choose --no-limit \
        --header "Install what from '$cat'? (x toggles, ctrl+a all)" \
        "${items[@]}" || true)
    [ -n "${picked[*]}" ] || continue
    picks[$cat]="$(IFS=,; echo "${picked[*]}")"
done

# --- 4. git + ssh (mandatory, no further prompts) -----------------------------

GIT_NAME="$git_name" GIT_EMAIL="$git_email" "$DOTS" setup git
"$DOTS" setup ssh

log "that's all the input — the rest runs unattended"

# --- 5. install ---------------------------------------------------------------

log "installing: ${MANDATORY[*]}"
"$DOTS" install "${MANDATORY[@]}"

for cat in "${chosen[@]}"; do
    [ -n "${picks[$cat]:-}" ] || continue
    log "installing from $cat: ${picks[$cat]}"
    "$DOTS" install "$cat" --only "${picks[$cat]}"
done

# --- 6. stow all components -----------------------------------------------------

log "stowing all components"
"$DOTS" stow all

# --- 7. first-run setup ---------------------------------------------------------

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

# fresh Arch installs default to bash; zsh comes with core. sudo chsh: no
# password prompt (the keepalive holds the sudo timestamp)
zsh_bin="$(command -v zsh)"
if [ "$(getent passwd "$USER" | cut -d: -f7)" != "$zsh_bin" ]; then
    sudo chsh -s "$zsh_bin" "$USER"
    log "login shell set to zsh (active on next login)"
fi

log "bootstrap complete — reboot and start Hyprland; open steps (github, calendar, ...): dots setup"
