# theme.sh — `dots theme`: the CLI surface of theming. All theming logic
# (wal invocation, adapter iteration, notify) lives in ../theming/apply-theme.sh —
# this file only resolves the theme name (argument or picker) and calls it.

theme_in_section() { # theme_in_section <wal --theme output> <section> <name>
    awk -v sec="$2:" -v name=" - $3" '
        /^[^ ]/ { in_sec = ($0 == sec) }
        in_sec && ($0 == name || $0 == name " (last used)") { found = 1 }
        END { exit !found }
    ' <<<"$1"
}

cmd_theme() {
    local light="" name=""

    while [ $# -gt 0 ]; do
        case "$1" in
            -l|--light) light="-l" ;;
            -h|--help)
                echo "usage: dots theme [-l] [name]   # -l = light themes, no name = interactive picker"
                return 0
                ;;
            *) name="$1" ;;
        esac
        shift
    done

    # interactive picker over pywal16's built-in themes
    if [ -z "$name" ]; then
        require_gum
        command -v wal >/dev/null 2>&1 || die "wal not found (aur:python-pywal16)"
        local themes
        themes="$(wal --theme 2>/dev/null | sed -n 's/^ - //p' | sort -u)"
        [ -n "$themes" ] || die "pywal16 reported no themes$([ -n "$light" ] && echo ' for light mode')"
        name="$(gum filter --header "Select a color theme" $themes)" || true
        [ -z "$name" ] && die "no theme selected"
    fi

    # light-only themes (e.g. catppuccin-latte) fail without -l; themes that
    # exist in both lists (e.g. solarized) stay dark unless -l is given
    if [ -z "$light" ] && command -v wal >/dev/null 2>&1; then
        local listing
        listing="$(wal --theme 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g')"
        if theme_in_section "$listing" "Light Themes" "$name" \
            && ! theme_in_section "$listing" "Dark Themes" "$name"; then
            light="-l"
        fi
    fi

    "$DOTFILES_DIR/dots-cli/theming/apply-theme.sh" $light "$name"
}
