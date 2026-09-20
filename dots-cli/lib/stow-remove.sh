# cmd_stow_remove — dots stow-remove [--yes] <component>
# Detaches a stow component: unstow, copy the repo's files back over the live
# paths (replacing the symlinks — no backup is read or written), delete
# stow/<component>, commit + push. The opposite of `dots stow-add`.
set -euo pipefail

cmd_stow_remove() {
    local yes=false
    local -a comps=()
    while [ $# -gt 0 ]; do
        case "$1" in
            --yes) yes=true ;;
            -*) die "unknown flag: $1" ;;
            *) comps+=("$1") ;;
        esac
        shift
    done
    [ ${#comps[@]} -ge 1 ] || die "usage: dots stow-remove [--yes] <component...>"

    local -a all=()
    mapfile -t all < <(stow_components)
    local c ok
    for c in "${comps[@]}"; do
        ok=false
        local e
        for e in "${all[@]:-}"; do
            [ -n "$e" ] || continue
            [ "$e" = "$c" ] && ok=true
        done
        $ok || die "no such component: '$c' (existing: ${all[*]})"
    done

    if ! $yes; then
        require_gum
        gum_confirm "Detach ${comps[*]}? Unstows, restores live files from the repo copy, and removes the component(s) from the repo." \
            || { info "cancelled"; return 0; }
    fi

    local comp f rel target
    for comp in "${comps[@]}"; do
        info "unstowing $comp"
        stow -D -d "$STOW_DIR" -t "$HOME" "$comp"

        # Restore: copy every tracked file back to its live path (stow -D
        # removed the symlinks; this leaves the machine as before the import).
        while IFS= read -r f; do
            [ -n "$f" ] || continue
            target="$HOME/$f"
            if [ -e "$target" ] || [ -L "$target" ]; then
                warn "not overwritten: $target (unexpected file — check manually)"
                continue
            fi
            mkdir -p "$(dirname "$target")"
            cp "$STOW_DIR/$comp/$f" "$target"
        done < <(find "$STOW_DIR/$comp" -type f -printf '%P\n')

        rm -rf "$STOW_DIR/$comp"
        success "removed: $comp (repo content copied back over the live paths)"
        repo_commit_paths "stow: remove $comp" "$STOW_DIR/$comp"
    done
}
