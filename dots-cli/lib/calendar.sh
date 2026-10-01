# calendar.sh — `dots calendar`: Google account login for the quickshell
# calendar. Thin CLI surface: all logic (OAuth, sync) lives in the
# quickshell component, stow/quickshell/.config/quickshell/scripts/gcal-sync.py.
# Secrets (OAuth client, tokens) stay in ~/.local/share/quickshell/
# — never in this repo.

set -euo pipefail

GCAL_SYNC="$STOW_DIR/quickshell/.config/quickshell/scripts/gcal-sync.py"

calendar_usage() {
    cat <<'EOF'
usage: dots calendar [command]        no command = menu
  client [file]      install the OAuth client JSON (Desktop app; no file → newest in ~/Downloads)
  login [email]      add a Google account (opens the browser)
  logout [email]     revoke + forget an account (no email = picker)
  list               accounts and which of their calendars are synced (✓)
EOF
}

gcal() { python3 "$GCAL_SYNC" "$@"; }

calendar_logout() {
    local email="${1:-}"
    if [ -z "$email" ]; then
        local -a emails=()
        mapfile -t emails < <(gcal emails)
        [ ${#emails[@]} -gt 0 ] && [ -n "${emails[0]}" ] || die "no Google accounts logged in"
        require_gum
        email="$(gum_choose_one "Log out which account?" "${emails[@]}")" || true
        [ -n "$email" ] || die "no account selected"
    fi
    gcal logout "$email"
}

cmd_calendar() {
    [ -f "$GCAL_SYNC" ] || die "gcal-sync.py not found at $GCAL_SYNC"
    local cmd="${1:-}"
    [ $# -gt 0 ] && shift

    if [ -z "$cmd" ]; then
        require_gum
        local choice
        choice="$(gum_choose_one "Calendar" \
            "Log in a Google account" "Log out an account" "List accounts + calendars" \
            "Set up the OAuth client")" || true
        case "$choice" in
            "Log in a Google account")    cmd=login ;;
            "Log out an account")         cmd=logout ;;
            "List accounts + calendars")  cmd=list ;;
            "Set up the OAuth client")    cmd=client ;;
            *) die "nothing selected" ;;
        esac
    fi

    case "$cmd" in
        client)
            [ $# -le 1 ] || die "usage: dots calendar client [file]"
            gcal client "$@"
            ;;
        login)
            [ $# -le 1 ] || die "usage: dots calendar login [email]"
            info "opening the browser — pick the account and tick the calendar checkbox"
            gcal login "$@"
            success "logged in — the quickshell calendar picks it up right away"
            ;;
        logout) calendar_logout "$@" ;;
        list)   gcal accounts ;;
        -h|--help|help) calendar_usage ;;
        *) calendar_usage >&2; die "unknown calendar command: '$cmd'" ;;
    esac
}
