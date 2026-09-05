#!/usr/bin/env bash
# apply-theme.sh — the theming engine. Owns ALL theming logic; the CLI
# (lib/theme.sh) and any setup scripts are thin callers of this script.
#
# Usage: apply-theme.sh [-l] <theme-name>
#   -l         light colorscheme
#
# What it does:
#   1. wal regenerates ~/.cache/wal and renders ~/.config/wal/templates/
#   2. runs every executable adapter in adapters/ with the theme name as $1
#   3. notify-send summary
#
# Adapter contract: see README.md. WAL_BIN env override stubs wal (testing).

set -euo pipefail

SOURCE="${BASH_SOURCE[0]}"
while [ -L "$SOURCE" ]; do
    DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
    SOURCE="$(readlink "$SOURCE")"
    [[ $SOURCE == /* ]] || SOURCE="$DIR/$SOURCE"
done
DOTFILES_DIR="$(cd "$(dirname "$SOURCE")/../.." && pwd)"
LIB_DIR="$DOTFILES_DIR/dots-cli/lib"

# shellcheck source=../lib/common.sh
source "$LIB_DIR/common.sh"

THEME_ADAPTERS_DIR="$(cd "$(dirname "$SOURCE")/adapters" && pwd)"
WAL_BIN="${WAL_BIN:-wal}"

run_adapters() { # run_adapters <theme-name> -> 0 if all adapters succeeded
    local theme="$1" adapter failed=0 total=0

    # sorted glob; nullglob so an empty dir is simply "no adapters"
    shopt -s nullglob
    for adapter in "$THEME_ADAPTERS_DIR"/*.sh; do
        [ -x "$adapter" ] || continue   # non-executable = disabled
        total=$((total + 1))
        if "$adapter" "$theme" >>"$THEME_LOG" 2>&1; then
            success "adapter: $(basename "$adapter")"
        else
            warn "adapter failed: $(basename "$adapter") (see $THEME_LOG)"
            failed=$((failed + 1))
        fi
    done
    shopt -u nullglob

    [ "$total" -eq 0 ] && info "no theme adapters found in $THEME_ADAPTERS_DIR"
    [ "$failed" -eq 0 ]
}

main() {
    local light="" name=""

    while [ $# -gt 0 ]; do
        case "$1" in
            -l|--light) light="-l" ;;
            *) name="$1" ;;
        esac
        shift
    done
    [ -n "$name" ] || die "usage: apply-theme.sh [-l] <theme-name>"

    command -v "$WAL_BIN" >/dev/null 2>&1 || die "wal not found (aur:python-pywal16)"

    info "setting colorscheme: $name$([ -n "$light" ] && echo ' (light)')"

    # regenerate ~/.cache/wal, render templates, reload wal-integrated apps
    THEME_LOG="$(mktemp)"
    if ! "$WAL_BIN" $light --theme "$name"; then
        rm -f "$THEME_LOG"
        die "wal failed to apply theme '$name'"
    fi
    success "wal: colors generated and templates rendered"

    if ! run_adapters "$name"; then
        rm -f "$THEME_LOG"
        die "one or more theme adapters failed"
    fi
    rm -f "$THEME_LOG"

    command -v notify-send >/dev/null 2>&1 && \
        notify-send -t 5000 "Theme Updated" "Color theme was updated to $name"
    success "theme applied: $name"
}

main "$@"
