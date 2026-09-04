# common.sh — shared helpers for the dots CLI.
# Sourced by bin/dots (which defines DOTFILES_DIR and LIB_DIR before sourcing)
# and by every lib/<cmd>.sh. No commands here, only helpers.

set -euo pipefail

PACKAGES_DIR="$DOTFILES_DIR/packages"
STOW_DIR="$DOTFILES_DIR/stow"
BACKUP_DIR="$HOME/.dotfiles-backup"

usage() {
    cat <<'EOF'
dots — dotfiles CLI

Usage:
  dots install [category...]    Install packages from categories (menu if none given)
  dots add <pkg...> [--aur] [--category <name>]
                                Install package(s), then track them in a category
  dots remove <category> <pkg...> [--uninstall]
                                Untrack package(s) from a category; --uninstall also removes from system
  dots list [category]          Show tracked packages (all or one category)
  dots stow [component...]      Stow components (menu, pre-selecting linked ones)
  dots sync                     Drift check: installed vs. tracked packages (print-only)

Environment:
  DOTFILES_DIR    Repo root (auto-detected from the script location)
EOF
}

die() {
    if command -v gum >/dev/null 2>&1; then
        gum log --level error "$*" >&2
    else
        echo "dots: $*" >&2
    fi
    exit 1
}

# Leveled logging through gum when available, plain echo otherwise.
info() {
    if command -v gum >/dev/null 2>&1; then
        gum log --level info "$*"
    else
        echo "==> $*"
    fi
}

warn() {
    if command -v gum >/dev/null 2>&1; then
        gum log --level warn "$*" >&2
    else
        echo "dots: warning: $*" >&2
    fi
}

# --- gum wrappers -----------------------------------------------------------
# gum is the interaction layer. Interactive commands refuse to run without it.

require_gum() {
    command -v gum >/dev/null 2>&1 || die "gum is required for interactive use (sudo pacman -S gum), or pass arguments explicitly"
}

gum_confirm() { # gum_confirm <prompt> -> exit 0 on yes
    gum confirm "$1"
}

gum_input() { # gum_input <prompt> <placeholder> -> value on stdout
    gum input --placeholder "$2" --prompt "$1"
}

gum_choose_one() { # gum_choose_one <question> <option>... -> selected option
    local header="$1"; shift
    gum choose --header "$header" "$@"
}

gum_choose_many() { # gum_choose_many <question> <option>... -> selected options, one per line
    local header="$1"; shift
    gum choose --no-limit --header "$header" "$@"
}

# --- categories -------------------------------------------------------------

categories() { # all category names, one per line (empty output if none yet)
    [ -d "$PACKAGES_DIR" ] || return 0
    find "$PACKAGES_DIR" -maxdepth 1 -name '*.txt' -printf '%f\n' | sed 's/\.txt$//' | sort
}

category_file() { echo "$PACKAGES_DIR/$1.txt"; }

category_exists() { [ -f "$(category_file "$1")" ]; }

require_category() {
    category_exists "$1" || die "no such category: '$1' (existing: $(categories | tr '\n' ' '))"
}

packages_in_category() { # lines minus blanks/comments; aur: prefix preserved
    local file
    file="$(category_file "$1")"
    [ -f "$file" ] || return 0
    sed -e 's/#.*$//' -e 's/[[:space:]]*$//' "$file" | grep -v '^$' || true
}

is_aur() { [ "${1#aur:}" != "$1" ]; }
pkg_name() { echo "${1#aur:}"; }

# --- stow -------------------------------------------------------------------

stow_components() { # all component names under stow/
    [ -d "$STOW_DIR" ] || return 0
    find "$STOW_DIR" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort
}

# is_linked <component>: true if the first tracked file of the component is a
# symlink pointing into the repo (i.e. the component is stowed). Approximation
# is fine — it only drives menu pre-selection.
is_linked() {
    local comp="$1" probe target link
    probe="$(find "$STOW_DIR/$comp" -type f -printf '%P\n' | head -n 1)"
    [ -n "$probe" ] || return 1
    target="$HOME/$probe"
    [ -L "$target" ] || return 1
    link="$(readlink "$target")"
    case "$link" in
        "$STOW_DIR"/"$comp"/*|*/stow/"$comp"/*) return 0 ;;
        *) return 1 ;;
    esac
}

# backup_conflicts <component>: move existing real files (or symlinks pointing
# elsewhere) to $BACKUP_DIR so the repo's version wins. "Repo wins on conflict."
backup_conflicts() {
    local comp="$1" ts dir rel target link
    ts="$(date +%Y%m%d-%H%M%S)"
    dir="$BACKUP_DIR/$comp.$ts"
    find "$STOW_DIR/$comp" -type f -printf '%P\n' | while IFS= read -r rel; do
        target="$HOME/$rel"
        [ -e "$target" ] || [ -L "$target" ] || continue
        if [ -L "$target" ]; then
            link="$(readlink "$target")"
            case "$link" in
                "$STOW_DIR"/"$comp"/*|*/stow/"$comp"/*) continue ;;  # already ours
            esac
        fi
        mkdir -p "$dir/$(dirname "$rel")"
        mv "$target" "$dir/$rel"
        warn "backed up $target -> $dir/$rel"
    done
}

# --- dispatch ----------------------------------------------------------------

main() {
    local cmd="${1:-help}"
    [ $# -gt 0 ] && shift

    case "$cmd" in
        install|add|remove|list|stow|sync)
            # shellcheck source=/dev/null
            source "$LIB_DIR/$cmd.sh"
            "cmd_$cmd" "$@"
            ;;
        help|-h|--help)
            usage
            ;;
        *)
            usage >&2
            die "unknown command: '$cmd'"
            ;;
    esac
}