# cmd_stow_add — dots stow-add [--all] [--dry-run] <name|path> [path]
# Imports a live config directory (default ~/.config/<name>) into the repo as a
# new stow component: stow/<name>/<path-relative-to-$HOME>. If stow/<name>
# already exists, it is extended: tracked files are pre-selected and locked,
# only files not yet in the repo are copied.
#
# Whitelist selection: a tree picker (fzf, vim keys) — a dir is tracked whole
# by toggling it, or opened with l to pick single files / subdirs inside it,
# at any depth; h goes back up. Junk-guessing has no future rules to
# maintain — what you don't pick stays a real file in the live dir and the
# repo never sees it. Entries that look like runtime state (sockets, logs,
# pid/tmp, cache dirs) are shown but not pre-selected. --all selects every
# top-level entry except sockets, for non-interactive use.
#
# Nested .git dirs inside picked trees are stripped (vendored) — an embedded
# repo would otherwise be committed as an empty gitlink.
#
# Then: backup-on-conflict stow + surgical auto-commit — the import-side twin
# of `dots stow`, same auto-commit pattern as `dots add`. --dry-run runs the
# picker, prints what would be tracked/backed up, and touches nothing.
set -euo pipefail

cmd_stow_add() {
    local all=false dry=false
    local -a pos=()
    while [ $# -gt 0 ]; do
        case "$1" in
            --all) all=true ;;
            --dry-run|-n) dry=true ;;
            -*) die "unknown flag: $1" ;;
            *) pos+=("$1") ;;
        esac
        shift
    done
    [ ${#pos[@]} -ge 1 ] && [ ${#pos[@]} -le 2 ] \
        || die "usage: dots stow-add [--all] [--dry-run] <name|path> [path]"
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
    # Existing component → extend it: what's tracked is pre-selected (and
    # can't be unticked — that's stow-remove's job), only new picks are added.
    local comp extend=false
    while IFS= read -r comp; do
        [ "$comp" = "$name" ] && extend=true
    done < <(stow_components)

    # Resolve the source: must be an existing directory under $HOME, not in
    # the repo. Symlinks are NOT resolved for the path (a folded stow link
    # like ~/.config/x -> stow/x/.config/x must keep its ~ path).
    src="${src/#\~/$HOME}"
    src="$(realpath -s -m "$src")"
    [ -d "$src" ] || die "not a directory: $src"
    case "$(readlink -f "$src")" in
        "$STOW_DIR/$name"/*)
            die "~/${src#"$HOME"/} is a folded link into stow/$name — files you create there are already in the repo; commit them with 'dots git'" ;;
    esac
    case "$src" in
        "$HOME") die "refusing to import \$HOME itself" ;;
        "$HOME"/*) ;;
        *) die "source must live inside \$HOME: $src" ;;
    esac
    case "$(readlink -f "$src")" in
        "$DOTFILES_DIR"|"$DOTFILES_DIR"/*) die "refusing to import from inside the repo" ;;
    esac

    local rel="${src#"$HOME"/}"
    local dest="$STOW_DIR/$name/$rel"
    $extend && info "stow/$name exists — extending it (tracked entries are pre-selected)"

    # Top-level entries: the --all set and the picker's default selection.
    local -a entries=()
    local e
    while IFS= read -r e; do
        [ -n "$e" ] || continue
        entries+=("$e")
    done < <(cd "$src" && find . -mindepth 1 -maxdepth 1 -printf '%P\n' | sort)
    [ ${#entries[@]} -gt 0 ] || die "source directory is empty: $src"

    # --- selection --------------------------------------------------------
    # SEL: picked paths relative to $src (files or whole dirs). Invariant: no
    # picked path lies inside another picked dir.
    declare -gA SEL=()
    if $all; then
        for e in "${entries[@]}"; do
            [ -S "$src/$e" ] || SEL["$e"]=1   # --all skips only sockets
        done
    else
        command -v fzf >/dev/null 2>&1 || die "fzf is required for the picker (dots install core), or pass --all"
        pick_fzf
    fi
    local -a picked=()
    mapfile -t picked < <(printf '%s\n' "${!SEL[@]}" | grep -v '^$' | sort)
    [ ${#picked[@]} -gt 0 ] || die "nothing selected — nothing imported"

    # Files to copy: everything under the picks not yet in the repo. Nested
    # .git dirs are skipped (vendored) — an embedded repo would otherwise be
    # committed as an empty gitlink; plugins are pinned assets.
    local -a new=() nested=()
    local f
    while IFS= read -r f; do
        [ -e "$dest/$f" ] || [ -L "$dest/$f" ] || new+=("$f")
    done < <(cd "$src" && for e in "${picked[@]}"; do
                 find "$e" -name .git -prune -o ! -type d -print
             done)
    mapfile -t nested < <(cd "$src" && for e in "${picked[@]}"; do
                              find "$e" -name .git -prune -print
                          done)
    [ ${#new[@]} -gt 0 ] || die "nothing new selected — stow/$name unchanged"

    if $dry; then
        dry_run_report
        return 0
    fi

    # --- copy (parents created as real dirs) -------------------------------
    for f in "${new[@]}"; do
        mkdir -p "$dest/$(dirname "$f")"
        cp -a "$src/$f" "$dest/$f"
    done
    info "copied ${#new[@]} file(s) into stow/$name/$rel"
    [ ${#nested[@]} -gt 0 ] && info "vendored (skipped nested .git): ${nested[*]}"

    # --- stow: back up whatever is at the live path, then link -------------
    info "stowing $name (live files at ~/$rel are backed up, then linked from the repo)"
    backup_conflicts "$name"
    stow -d "$STOW_DIR" -t "$HOME" "$name"

    # Auto-commit (surgical: only this component).
    if $extend; then
        success "extended + stowed: $name (+${#new[@]} file(s))"
        repo_commit_paths "stow: extend $name (+${#new[@]} file(s) from ~/$rel)" "$STOW_DIR/$name"
    else
        success "imported + stowed: $name (stow/$name/$rel)"
        repo_commit_paths "stow: add $name (imported from ~/$rel)" "$STOW_DIR/$name"
    fi
}

# pick_fzf: the tree picker, on fzf (gum has no custom key bindings). Edits
# SEL. fzf's bindings run `pt` as child processes, so the picker's state lives
# in a temp dir for the session (sel = picked paths, cwd = shown dir) and is
# deleted when fzf exits.
pick_fzf() {
    local tmp e rc=0
    tmp="$(mktemp -d)"
    : > "$tmp/cwd"
    : > "$tmp/locked"
    if $extend; then
        # tracked = every file already in the repo under this source
        [ -d "$dest" ] && (cd "$dest" && find . ! -type d -printf '%P\n') > "$tmp/locked"
        cp "$tmp/locked" "$tmp/sel"
    else
        for e in "${entries[@]}"; do
            is_state "$src/$e" || printf '%s\n' "$e"
        done > "$tmp/sel"
    fi
    export PT_SRC="$src" PT_REL="$rel" PT_TMP="$tmp"
    export -f pt pt_normalize is_state
    pt normalize

    pt list | fzf --ansi --no-input --no-sort --layout=reverse --info=hidden \
        --delimiter=$'\t' --with-nth=2 --gutter=' ' --with-shell='bash -c' \
        --border=rounded --border-label=" ~/$rel " --border-label-pos=3 \
        --header='l/→ open · h/← back · space/x toggle · enter import · esc cancel' \
        --bind='j:down,k:up,q:abort' \
        --bind='l:transform(pt open {1}),right:transform(pt open {1})' \
        --bind='h:transform(pt up),left:transform(pt up)' \
        --bind='space:execute-silent(pt toggle {1})+reload-sync(pt list)' \
        --bind='x:execute-silent(pt toggle {1})+reload-sync(pt list)' \
        >/dev/null || rc=$?

    # 0 = accepted; 1 = enter on an empty dir (no item) — also accepted
    if [ "$rc" -le 1 ]; then
        while IFS= read -r e; do
            [ -n "$e" ] && SEL["$e"]=1
        done < "$tmp/sel"
    fi
    rm -rf "$tmp"
    [ "$rc" -le 1 ] || die "aborted — nothing imported"
}

# pt <list|toggle|open|up|normalize> [path]: picker actions run by fzf's
# bindings (see pick_fzf). A shown entry is [x] if it or a parent dir is
# picked, [~] if something inside it is picked. Toggling inside a dir that is
# picked whole splits it: the dir is replaced by all its other entries.
# Locked paths (already tracked, when extending) always stay picked.
pt() {
    local cmd="$1" p="${2:-}" cwd l k a c n q rest comp
    p="${p%$'\t'}"
    cwd="$(cat "$PT_TMP/cwd")"
    local -A S=() L=()
    while IFS= read -r l; do [ -n "$l" ] && S["$l"]=1; done < "$PT_TMP/sel"
    while IFS= read -r l; do [ -n "$l" ] && L["$l"]=1; done < "$PT_TMP/locked"

    case "$cmd" in
        list)
            while IFS= read -r n; do
                [ -n "$n" ] || continue
                q="${cwd:+$cwd/}$n"
                local mark="[ ]" label="$n" extra="" inside=0
                [ -d "$PT_SRC/$q" ] && [ ! -L "$PT_SRC/$q" ] && label="$n/"
                a="$q"
                while :; do
                    [ -n "${S[$a]:-}" ] && { mark=$'\033[32m[x]\033[0m'; break; }
                    [[ "$a" == */* ]] || break
                    a="${a%/*}"
                done
                if [ "$mark" = "[ ]" ]; then
                    for k in "${!S[@]}"; do
                        case "$k" in "$q"/*) inside=$((inside + 1)) ;; esac
                    done
                    [ "$inside" -gt 0 ] && { mark=$'\033[33m[~]\033[0m'; extra=$'  \033[33m'"$inside picked inside"$'\033[0m'; }
                fi
                [ -n "${L[$q]:-}" ] && extra="$extra"$'  \033[2mtracked\033[0m'
                is_state "$PT_SRC/$q" && extra="$extra"$'  \033[2m[state?]\033[0m'
                printf '%s\t%s %s%s\n' "$q" "$mark" "$label" "$extra"
            done < <(cd "$PT_SRC/$cwd" && {
                         find . -mindepth 1 -maxdepth 1 -type d -printf '%P\n' | sort
                         find . -mindepth 1 -maxdepth 1 ! -type d -printf '%P\n' | sort
                     })
            ;;
        toggle)
            [ -n "$p" ] || return 0
            if [ -n "${S[$p]:-}" ]; then
                unset 'S[$p]'
            else
                a="$p"
                while [[ "$a" == */* ]]; do
                    a="${a%/*}"
                    [ -n "${S[$a]:-}" ] && break
                done
                if [ "$a" != "$p" ] && [ -n "${S[$a]:-}" ]; then
                    # split the picked ancestor $a down to $p, leaving $p out
                    unset 'S[$a]'
                    rest="${p#"$a"/}"
                    while :; do
                        comp="${rest%%/*}"
                        while IFS= read -r c; do
                            [ -n "$c" ] && [ "$c" != "$comp" ] && S["$a/$c"]=1
                        done < <(cd "$PT_SRC/$a" && find . -mindepth 1 -maxdepth 1 -printf '%P\n')
                        [ "$rest" = "$comp" ] && break
                        a="$a/$comp"
                        rest="${rest#*/}"
                    done
                else
                    # pick whole (drops anything picked inside it)
                    for k in "${!S[@]}"; do
                        case "$k" in "$p"/*) unset 'S[$k]' ;; esac
                    done
                    S["$p"]=1
                fi
            fi
            pt_normalize
            ;;
        normalize)
            pt_normalize
            ;;
        open)
            [ -n "$p" ] && [ -d "$PT_SRC/$p" ] && [ ! -L "$PT_SRC/$p" ] || return 0
            printf '%s\n' "$p" > "$PT_TMP/cwd"
            echo "reload-sync(pt list)+pos(1)+change-border-label: ~/$PT_REL/$p "
            ;;
        up)
            [ -n "$cwd" ] || return 0
            l="${cwd%/*}"
            [ "$l" = "$cwd" ] && l=""
            printf '%s\n' "$l" > "$PT_TMP/cwd"
            # land on the dir we came from (pos = its 1-based row)
            n="$(pt list | cut -f1 | grep -nxF -- "$cwd" | cut -d: -f1)"
            echo "reload-sync(pt list)+pos(${n:-1})+change-border-label: ~/$PT_REL${l:+/$l} "
            ;;
    esac
}

# pt_normalize: (on pt's S/L) re-add locked paths not covered by a pick, then
# collapse dirs whose entries are all picked into the dir itself (deepest
# first; nested .git ignored), and write S back.
pt_normalize() {
    local k a d c all n
    for k in "${!L[@]}"; do
        a="$k"
        while [ -z "${S[$a]:-}" ] && [[ "$a" == */* ]]; do a="${a%/*}"; done
        [ -n "${S[$a]:-}" ] || S["$k"]=1
    done
    local -A D=()
    for k in "${!S[@]}"; do
        a="$k"
        while [[ "$a" == */* ]]; do a="${a%/*}"; D["$a"]=1; done
    done
    while IFS= read -r d; do
        [ -n "$d" ] && [ -z "${S[$d]:-}" ] || continue
        all=1 n=0
        while IFS= read -r c; do
            [ -n "$c" ] || continue
            n=$((n + 1))
            [ -n "${S[$d/$c]:-}" ] || { all=0; break; }
        done < <(cd "$PT_SRC/$d" 2>/dev/null && find . -mindepth 1 -maxdepth 1 ! -name .git -printf '%P\n')
        [ "$all" = 1 ] && [ "$n" -gt 0 ] || continue
        for k in "${!S[@]}"; do
            case "$k" in "$d"/*) unset 'S[$k]' ;; esac
        done
        S["$d"]=1
    done < <(for d in "${!D[@]}"; do printf '%s\n' "$d"; done | awk -F/ '{ print NF "\t" $0 }' | sort -rn | cut -f2-)
    printf '%s\n' "${!S[@]}" > "$PT_TMP/sel"
}

# dry_run_report: what the real run would do — nothing is written.
dry_run_report() {
    local f shown=0
    info "dry run — nothing copied, stowed or committed"
    echo "would add ${#new[@]} file(s) to stow/$name/$rel:"
    for f in "${new[@]}"; do
        shown=$((shown + 1))
        [ "$shown" -le 30 ] || { echo "  … and $(( ${#new[@]} - 30 )) more"; break; }
        echo "  $f"
    done
    [ ${#nested[@]} -gt 0 ] && echo "would skip nested .git (vendoring): ${nested[*]}"
    echo "would back up those live files to $BACKUP_DIR/$name.<timestamp>/ and link them from the repo"
    if $extend; then
        echo "would commit: stow: extend $name (+${#new[@]} file(s) from ~/$rel)"
    else
        echo "would commit: stow: add $name (imported from ~/$rel)"
    fi
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
