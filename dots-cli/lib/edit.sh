# edit.sh — `dots edit [component]`: open $EDITOR in the stow tree so configs
# can be browsed and edited directly (files are the repo's — commit afterwards).
# No argument: stow/ root. Argument: that component — descending through
# single-entry directory chains (stow/hypr/.config/hypr) so you land in the
# folder that actually holds the files, not the stow wrapper dirs.

cmd_edit() {
    local editor="${VISUAL:-${EDITOR:-}}"
    [ -n "$editor" ] || die "no editor set (export EDITOR=... in ~/.commonshellrc)"

    local dir="$STOW_DIR"
    if [ $# -gt 0 ]; then
        [ -d "$STOW_DIR/$1" ] || die "no such component: '$1' (existing: $(stow_components | tr '\n' ' '))"
        dir="$STOW_DIR/$1"
        # follow single-entry directory chains to the real content folder
        while [ "$(find "$dir" -mindepth 1 -maxdepth 1 | wc -l)" -eq 1 ] \
                && [ -z "$(find "$dir" -mindepth 1 -maxdepth 1 ! -type d -print -quit)" ]; do
            dir="$(find "$dir" -mindepth 1 -maxdepth 1 -type d -print -quit)"
        done
    fi

    info "opening $dir"
    local -a editor_cmd=()
    read -r -a editor_cmd <<< "$editor"
    (cd "$dir" && "${editor_cmd[@]}" .)

    # edits land in the repo — nudge towards committing
    if [ -n "$(git -C "$DOTFILES_DIR" status --porcelain)" ]; then
        info "repo has uncommitted changes — run 'dots commit'"
    fi
}
