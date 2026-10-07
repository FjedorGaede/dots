# cmd_update — dots update [--dry-run]
# Brings this machine in line with the remote repo:
#   1. refuse on uncommitted changes to tracked files (commit/stash via dots git)
#   2. fetch, show incoming commits, pull --ff-only (diverged → die, use dots git)
#   3. restow every linked component (stow -R: links new files, prunes links
#      of deleted ones) — runs even without new commits, so it repairs drift
#   4. report what needs sudo or a decision: unstowed components that changed,
#      changed categories with missing packages / changed install scripts
#   5. reload Hyprland if it runs and its config changed, print configerrors
# --dry-run: fetch + show incoming commits + preview the restow; mutates nothing.
# The only pull path in the CLI — pushing stays with lazygit (dots git).

set -euo pipefail

cmd_update() {
    local dry_run=false
    while [ $# -gt 0 ]; do
        case "$1" in
            -n|--dry-run) dry_run=true ;;
            *) die "usage: dots update [--dry-run]" ;;
        esac
        shift
    done

    local repo="$DOTFILES_DIR"
    if ! { git -C "$repo" diff --quiet && git -C "$repo" diff --cached --quiet; }; then
        $dry_run || die "uncommitted changes in $repo — commit or stash them first (dots git)"
        warn "uncommitted changes in $repo — a real update would refuse to run"
    fi
    git -C "$repo" rev-parse --abbrev-ref '@{u}' >/dev/null 2>&1 \
        || die "branch '$(git -C "$repo" branch --show-current)' has no upstream — nothing to update from"

    info "fetching"
    git -C "$repo" fetch --quiet || die "git fetch failed (offline?)"

    local ahead behind
    read -r ahead behind < <(git -C "$repo" rev-list --left-right --count 'HEAD...@{u}')
    if [ "$ahead" -gt 0 ] && [ "$behind" -gt 0 ]; then
        die "local and remote have diverged ($ahead local, $behind remote commits) — resolve in dots git"
    fi
    [ "$ahead" -eq 0 ] || warn "$ahead local commit(s) not pushed yet — push via dots git"

    local old_head
    old_head="$(git -C "$repo" rev-parse HEAD)"
    if [ "$behind" -gt 0 ]; then
        info "$behind new commit(s):"
        git -C "$repo" log --oneline --no-decorate 'HEAD..@{u}' | sed 's/^/    /'
        if $dry_run; then
            info "dry run — not pulling; the restow preview below is for the current checkout"
        else
            git -C "$repo" pull --quiet --ff-only || die "git pull --ff-only failed"
            success "pulled"
        fi
    else
        info "already up to date with $(git -C "$repo" rev-parse --abbrev-ref '@{u}')"
    fi

    local -a changed=()
    mapfile -t changed < <(git -C "$repo" diff --name-only "$old_head" HEAD)

    local hypr_touched=false
    restow_linked || hypr_touched=true
    path_changed "stow/hypr/" && hypr_touched=true

    report_unstowed
    report_packages
    $dry_run || ! $hypr_touched || reload_hyprland
}

# path_changed <prefix>: true if a file under <prefix> changed in the pull.
path_changed() {
    local f
    for f in "${changed[@]:-}"; do
        [ -n "$f" ] && [ "${f#"$1"}" != "$f" ] && return 0
    done
    return 1
}

# any_linked <component>: true if ANY tracked file of the component resolves
# to the repo. Stricter than is_linked's first-file probe, which misses a
# stowed component whose first file happens to be the newly added one.
any_linked() {
    local comp="$1" rel
    while IFS= read -r rel; do
        [ "$(readlink -f "$HOME/$rel" 2>/dev/null)" = "$(readlink -f "$STOW_DIR/$comp/$rel")" ] && return 0
    done < <(find "$STOW_DIR/$comp" -type f -printf '%P\n')
    return 1
}

# restow_linked: stow -R every linked component and list the links that
# actually changed. Returns 1 if hypr's links changed (caller reloads), else 0.
restow_linked() {
    local comp out hypr_changed=false any=false
    local -a added=() removed=()
    for comp in $(stow_components); do
        any_linked "$comp" || continue
        any=true
        if $dry_run; then
            out="$(stow -n -v -R -d "$STOW_DIR" -t "$HOME" "$comp" 2>&1)" \
                || { warn "restow of $comp would fail:"; echo "$out" >&2; continue; }
        else
            backup_conflicts "$comp"
            out="$(stow -v -R -d "$STOW_DIR" -t "$HOME" "$comp" 2>&1)" \
                || { warn "restow of $comp failed:"; echo "$out" >&2; continue; }
        fi
        mapfile -t added < <(net_links + <<<"$out")
        mapfile -t removed < <(net_links - <<<"$out")
        if [ -n "${added[*]:-}${removed[*]:-}" ]; then
            [ "$comp" = hypr ] && hypr_changed=true
            local p
            for p in "${added[@]:-}"; do [ -z "$p" ] || echo "    + ~/$p"; done
            for p in "${removed[@]:-}"; do [ -z "$p" ] || echo "    - ~/$p"; done
            $dry_run && info "$comp: would change links above" || success "restowed $comp (links changed above)"
        fi
    done
    $any || warn "no linked components — run 'dots stow' first"
    $any && ! $dry_run && success "all linked components restowed"
    ! $hypr_changed
}

# net_links <+|->: read stow -v output on stdin, print the paths whose link was
# net added (+) or removed (-). A restow UNLINKs and re-LINKs everything, and
# with folded dirs stow even links then reverts — so net it out per path.
net_links() {
    sed 's/ (reverts previous action)$//' | awk -v want="$1" '
        /^LINK: /   { p = $2; s[p]++ }
        /^UNLINK: / { p = $2; s[p]-- }
        END { for (p in s) if ((want == "+" && s[p] > 0) || (want == "-" && s[p] < 0)) print p }
    ' | sort
}

# Components that changed upstream but aren't stowed on this machine — could
# be brand new or deliberately skipped here, so only report.
report_unstowed() {
    local comp
    for comp in $(stow_components); do
        any_linked "$comp" && continue
        path_changed "stow/$comp/" && warn "component '$comp' changed but isn't stowed here — 'dots stow $comp' to link it"
    done
    return 0
}

# Categories whose packages.txt or install scripts changed: list packages that
# aren't installed, point at dots install (needs sudo — never run from here).
report_packages() {
    command -v pacman >/dev/null 2>&1 || return 0
    local cat installed
    installed="$(pacman -Qq)"
    for cat in $(categories); do
        path_changed "packages/$cat/" || continue
        local -a missing=()
        mapfile -t missing < <(packages_in_category "$cat" | sed 's/^aur://' \
            | grep -vxF -f <(printf '%s\n' "$installed") || true)
        if [ -n "${missing[*]:-}" ]; then
            warn "$cat: ${#missing[@]} tracked package(s) not installed: ${missing[*]} — run 'dots install $cat'"
        elif path_changed "packages/$cat/install/"; then
            warn "$cat: install scripts changed — run 'dots install $cat' to apply them"
        fi
    done
    return 0
}

reload_hyprland() {
    command -v hyprctl >/dev/null 2>&1 && [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] || return 0
    hyprctl reload >/dev/null || { warn "hyprctl reload failed"; return 0; }
    sleep 1
    local errs
    errs="$(hyprctl configerrors 2>&1 | sed '/^[[:space:]]*$/d')"
    if [ -n "$errs" ]; then
        warn "Hyprland reloaded with config errors:"
        echo "$errs" | sed 's/^/    /' >&2
    else
        success "Hyprland reloaded, no config errors"
    fi
}
