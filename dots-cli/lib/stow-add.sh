# cmd_stow_add — dots stow-add [--all] <name|path> [path]
# Imports a live config directory (default ~/.config/<name>) into the repo as a
# new stow component: stow/<name>/<path-relative-to-$HOME>.
#
# Whitelist selection: the source's top-level entries are listed (dirs
# collapsed) and you pick what to track. Junk-guessing has no future rules to
# maintain — what you don't pick stays a real file in the live dir and the
# repo never sees it. Entries that look like runtime state (sockets, logs,
# pid/tmp, cache dirs) are shown but not pre-selected. --all selects
# everything except sockets, for non-interactive use.
#
# Nested .git dirs inside picked trees are stripped (vendored) — an embedded
# repo would otherwise be committed as an empty gitlink.
#
# Then: backup-on-conflict stow + surgical auto-commit — the import-side twin
# of `dots stow`, same auto-commit pattern as `dots add`.
set -euo pipefail

cmd_stow_add() {
    local all=false
    local -a pos=()
    while [ $# -gt 0 ]; do
        case "$1" in
            --all) all=true ;;
            -*) die "unknown flag: $1" ;;
            *) pos+=("$1") ;;
        esac
        shift
    done
    [ ${#pos[@]} -ge 1 ] && [ ${#pos[@]} -le 2 ] \
        || die "usage: dots stow-add [--all] <name|path> [path]"
    local name="${pos[0]}"
    local src="${pos[1]:-}"

    # Single path argument → component name = basename of the path.
    if [ ${#pos[@]} -eq 1 ]; then
        case "$name" in
            */*|~*)
                src="$name"
                name="$(basename "${src%/}")"
                info "no name given — using component name '$name' (from $src)"
                ;;
        esac
    fi
    [ ${#pos[@]} -eq 2 ] && src="${pos[1]}"
    [ -n "$src" ] || src="$HOME/.config/$name"

    # Validate the component name (no slashes/spaces; 'all' is reserved).
    case "$name" in
        ""|*/*|*[!a-zA-Z0-9._-]*) die "invalid component name: '$name' (letters, digits, . _ - only)" ;;
        all) die "'all' is reserved by 'dots stow'" ;;
    esac
    local comp
    while IFS= read -r comp; do
        [ "$comp" = "$name" ] && die "component already exists: stow/$name"
    done < <(stow_components)

    # Resolve the source: must be an existing directory under $HOME, not in the repo.
    src="${src/#\~/$HOME}"
    src="$(readlink -m "$src")"
    [ -d "$src" ] || die "not a directory: $src"
    case "$src" in
        "$HOME") die "refusing to import \$HOME itself" ;;
        "$HOME"/*) ;;
        *) die "source must live inside \$HOME: $src" ;;
    esac
    case "$src" in
        "$DOTFILES_DIR"|"$DOTFILES_DIR"/*) die "refusing to import from inside the repo" ;;
    esac

    local rel="${src#"$HOME"/}"
    local dest="$STOW_DIR/$name/$rel"

    # Candidate list: top-level entries only (dirs are picked as a whole).
    local -a entries=()
    local e
    while IFS= read -r e; do
        [ -n "$e" ] || continue
        entries+=("$e")
    done < <(cd "$src" && find . -mindepth 1 -maxdepth 1 -printf '%P\n' | sort)
    [ ${#entries[@]} -gt 0 ] || die "source directory is empty: $src"

    # --- selection --------------------------------------------------------
    local -a picked=()
    if $all; then
        for e in "${entries[@]}"; do
            [ -S "$src/$e" ] || picked+=("$e")   # --all skips only sockets
        done
    else
        require_gum
        mapfile -t picked < <(pick_entries || true)
    fi
    [ ${#picked[@]} -gt 0 ] || die "nothing selected — nothing imported"

    # --- copy the picked entries ------------------------------------------
    mkdir -p "$dest"
    for e in "${picked[@]}"; do
        cp -a "$src/$e" "$dest/"
    done
    info "imported: ${picked[*]}"

    # Vendor: strip nested .git dirs (an embedded repo would otherwise be
    # committed as an empty gitlink; plugins are pinned assets).
    local -a nested=()
    while IFS= read -r e; do
        [ -n "$e" ] || continue
        nested+=("$e")
    done < <(find "$dest" \( -type d -name .git -prune \) -printf '%P\n')
    if [ ${#nested[@]} -gt 0 ]; then
        for e in "${nested[@]}"; do rm -rf "$dest/$e"; done
        info "vendored (stripped nested .git): ${nested[*]}"
    fi

    # --- stow: back up whatever is at the live path, then link -------------
    info "stowing $name (live files at ~/$rel are backed up, then linked from the repo)"
    backup_conflicts "$name"
    stow -d "$STOW_DIR" -t "$HOME" "$name"
    success "imported + stowed: $name (stow/$name/$rel)"

    # Auto-commit (surgical: only the new component).
    repo_commit_paths "stow: add $name (imported from ~/$rel)" "$STOW_DIR/$name"
}

# Interactive whitelist picker. Looks like state (sockets, logs, pid/tmp,
# cache) is listed but NOT pre-selected; everything else is.
pick_entries() {
    local -a options=() defaults=()
    local e
    for e in "${entries[@]}"; do
        if is_state "$src/$e"; then
            options+=("$e  [state?]")
        else
            options+=("$e")
            defaults+=("$e")
        fi
    done

    local header="Track which entries from ~/$rel? (x to select, enter to apply)"
    if gum choose --help 2>&1 | grep -q -- '--selected='; then
        local joined
        joined="$(IFS=,; echo "${defaults[*]:-}")"
        if [ -n "$joined" ]; then
            gum choose --no-limit --header "$header" --selected "$joined" "${options[@]}"
        else
            gum choose --no-limit --header "$header" "${options[@]}"
        fi
    else
        # older gum: no pre-selection — label state-ish entries instead
        gum choose --no-limit --header "$header  ([state?] = probably not config)" \
            "${options[@]}"
    fi | sed 's/  \[state?\]$//'
}

# is_state <path>: likely runtime state, not config — sockets, fifos, logs,
# pid/tmp files, cache dirs.
is_state() {
    local p="$1"
    case "$(basename "$p")" in
        *.log|*.sock|*.pid|*.tmp|cache|.cache) return 0 ;;
    esac
    [ -S "$p" ] && return 0
    [ -p "$p" ] && return 0
    return 1
}
