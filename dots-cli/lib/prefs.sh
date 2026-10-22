# cmd_prefs — dots prefs [diff|capture|apply] [app...] [--yes]
# Settings of apps that rewrite their own config file on exit (Vivaldi's
# Preferences), so stow can't link it. prefs/<app>/app.sh names the live file,
# the process and the JSON keys the repo owns; prefs/<app>/prefs.json holds
# their values.
#   diff     show live vs. repo (default when no subcommand is given)
#   capture  live → repo: rewrite prefs.json; commit via dots git
#   apply    repo → live: shows the diff and asks (--yes: no questions), then
#            backs up and replaces the keys; a running app is closed first and
#            reopened afterwards
#   merge-driver %O %A %B   git merge driver for prefs/*/prefs.json (see
#            .gitattributes): per-setting three-way merge; real conflicts fall
#            back to git's text merge with markers, resolved in dots git
# Helpers (prefs_load, prefs_extract, prefs_apply_live, ...) live in common.sh —
# dots update uses them too.

set -euo pipefail

cmd_prefs() {
    local sub=diff yes=false
    local -a apps=()
    case "${1:-}" in
        diff|capture|apply) sub="$1"; shift ;;
        merge-driver) shift; prefs_merge_driver "$@"; return ;;
    esac
    while [ $# -gt 0 ]; do
        case "$1" in
            -y|--yes) yes=true ;;
            -h|--help)
                echo "usage: dots prefs [diff|capture|apply] [app...] [--yes]"
                return 0
                ;;
            -*) die "unknown flag: $1 (usage: dots prefs [diff|capture|apply] [app...] [--yes])" ;;
            *) apps+=("$1") ;;
        esac
        shift
    done
    command -v jq >/dev/null 2>&1 || die "jq is required"
    prefs_merge_driver_register

    [ ${#apps[@]} -gt 0 ] || mapfile -t apps < <(prefs_apps)
    [ -n "${apps[*]:-}" ] || die "no apps in $PREFS_DIR"

    local app
    for app in "${apps[@]}"; do
        require_prefs_app "$app"
        prefs_load "$app"
        "prefs_$sub" "$app"
    done
}

prefs_diff() {
    local app="$1" repo_file
    repo_file="$(prefs_file "$app")"
    [ -f "$target" ] || { warn "$app: $target missing"; return 0; }
    [ -f "$repo_file" ] || { warn "$app: nothing captured yet — 'dots prefs capture $app'"; return 0; }
    if prefs_in_sync "$app"; then
        success "$app: live settings match the repo"
        return 0
    fi
    info "$app: repo (-) vs. live (+)"
    diff -u --color=auto --label "repo: prefs/$app/prefs.json" --label "live: $target" \
        <(jq -S . "$repo_file") <(prefs_extract "$target") || true
    echo "  keep live → dots prefs capture $app    take repo → dots prefs apply $app"
}

prefs_capture() {
    local app="$1" repo_file
    repo_file="$(prefs_file "$app")"
    [ -f "$target" ] || die "$app: $target missing"
    if prefs_in_sync "$app" && [ -f "$repo_file" ]; then
        success "$app: nothing to capture, repo already matches"
        return 0
    fi
    prefs_running && warn "$app is running — it saves changes with a few seconds' delay; capture again if something is missing"
    prefs_extract "$target" > "$repo_file"
    git -C "$DOTFILES_DIR" --no-pager diff --stat -- "$repo_file" 2>/dev/null || true
    prefs_privacy_check "$repo_file"
    success "captured $app → prefs/$app/prefs.json — review + commit via dots git"
}

# The repo is public: list every string that could be personal — URLs (minus
# browser-internal ones), email addresses, home paths — so it gets a look
# before pushing.
prefs_privacy_check() {
    local -a hits=()
    mapfile -t hits < <(jq -r '.. | strings
        | select(test("^[a-z][a-z0-9+.-]*://|[^ @]+@[^ @]+\\.[a-z]+|/home/|^~/"; "i"))
        | select(test("^(chrome|chrome-extension|vivaldi|about|devtools)://") | not)' "$1" | sort -u)
    [ -n "${hits[*]:-}" ] || return 0
    warn "the repo is public — these end up on GitHub, check them before pushing:"
    printf '    %s\n' "${hits[@]}" >&2
}

prefs_apply() {
    local app="$1" question
    if prefs_in_sync "$app" && [ -f "$(prefs_file "$app")" ]; then
        success "$app: live settings already match the repo"
        return 0
    fi
    if ! $yes; then
        require_gum
        prefs_diff "$app"
        question="Replace the live $app settings above with the repo's?"
        prefs_running && question="$question ($app gets closed and reopened)"
        gum_confirm "$question" || { info "$app: skipped"; return 0; }
    fi
    # already asked (or --yes) — close without a second question
    prefs_closed "$app" false prefs_apply_live "$app"
}

# prefs_merge_driver <base> <ours> <theirs>: git writes the result to <ours>
prefs_merge_driver() {
    [ $# -eq 3 ] || die "usage: dots prefs merge-driver <base> <ours> <theirs>"
    local merged
    merged="$(mktemp)"
    if prefs_merge3 "$1" "$2" "$3" > "$merged"; then
        mv "$merged" "$2"
        return 0
    fi
    rm -f "$merged"
    warn "prefs: same setting changed on both sides — resolve the markers in dots git"
    git merge-file -L ours -L base -L theirs "$2" "$1" "$3" || true
    return 1
}
