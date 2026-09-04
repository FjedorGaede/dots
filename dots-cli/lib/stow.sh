# cmd_stow — dots stow [component...]
# Stows components into $HOME. With no arguments: gum multi-select menu over
# stow/*, with already-linked components pre-selected.
# Conflicts: existing files are backed up to $BACKUP_DIR first — repo wins.
# `stow --adopt` is deliberately never used.

cmd_stow() {
    local -a all=() args=("$@")
    mapfile -t all < <(stow_components)
    [ ${#all[@]} -gt 0 ] || die "no components found in $STOW_DIR"

    local -a chosen=()
    if [ ${#args[@]} -gt 0 ]; then
        local c
        for c in "${args[@]}"; do
            [ -d "$STOW_DIR/$c" ] || die "no such component: '$c' (existing: ${all[*]})"
            chosen+=("$c")
        done
    else
        require_gum
        chosen=($(select_components))
        [ ${#chosen[@]} -gt 0 ] || { info "nothing selected"; return 0; }
    fi

    local comp
    for comp in "${chosen[@]}"; do
        info "stowing $comp"
        backup_conflicts "$comp"
        stow -d "$STOW_DIR" -t "$HOME" "$comp"
        info "stowed: $comp"
    done
}

# Multi-select menu; pre-selects linked components when gum supports --selected.
select_components() {
    local -a linked=() options=()
    local comp
    for comp in "${all[@]}"; do
        if is_linked "$comp"; then
            linked+=("$comp")
            options+=("$comp  [linked]")
        else
            options+=("$comp")
        fi
    done

    if gum choose --help 2>&1 | grep -q -- '--selected'; then
        # gum >= 0.14: genuinely pre-select the linked ones
        if [ ${#linked[@]} -gt 0 ]; then
            gum choose --no-limit --prompt "Stow which components? (space to toggle, enter to apply)" \
                --selected "${linked[@]}" "${options[@]}" | sed 's/  \[linked\]$//' || true
        else
            gum choose --no-limit --prompt "Stow which components? (space to toggle, enter to apply)" \
                "${options[@]}" | sed 's/  \[linked\]$//' || true
        fi
    else
        # older gum: fall back to labelling linked components in the menu
        gum choose --no-limit --prompt "Stow which components? [linked] = already stowed" \
            "${options[@]}" | sed 's/  \[linked\]$//' || true
    fi
}