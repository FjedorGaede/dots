# cmd_setup — dots setup [name...]
# Interactive per-machine setup steps (accounts, logins, ...) from
# setup/<name>/setup.sh. Not part of 'dots install': these need a human.
# No names: menu over all steps, each labelled with its status (✔ done / ✘ open).
#
# Script contract: `setup.sh status` prints a one-line status and exits 0 when
# the step is done, non-zero when open; `setup.sh` (no argument) runs the step.
# Scripts get $DOTFILES_DIR and $DOTS (path to this CLI) in the environment.

SETUP_DIR="$DOTFILES_DIR/setup"

setup_names() { # setup step names, one per line (sorted)
    [ -d "$SETUP_DIR" ] || return 0
    find "$SETUP_DIR" -mindepth 2 -maxdepth 2 -name setup.sh -type f -printf '%h\n' | sed "s|^$SETUP_DIR/||" | sort
}

cmd_setup() {
    export DOTFILES_DIR
    export DOTS="$DOTFILES_DIR/dots-cli/bin/dots"

    local -a all=() chosen=()
    mapfile -t all < <(setup_names)
    [ ${#all[@]} -gt 0 ] || die "no setup steps found in $SETUP_DIR"

    local name
    if [ $# -gt 0 ]; then
        for name in "$@"; do
            [ -f "$SETUP_DIR/$name/setup.sh" ] || die "no such setup step: '$name' (existing: ${all[*]})"
        done
        chosen=("$@")
    else
        require_gum
        local -a labels=()
        local status mark
        for name in "${all[@]}"; do
            if status="$(bash "$SETUP_DIR/$name/setup.sh" status 2>&1 | head -n1; exit "${PIPESTATUS[0]}")"; then
                mark="✔"
            else
                mark="✘"
            fi
            labels+=("$(printf '%s %-12s %s' "$mark" "$name" "$status")")
        done
        mapfile -t chosen < <(gum_choose_many "Run which setup steps? (x to select, enter to confirm)" "${labels[@]}" || true)
        [ -n "${chosen[*]}" ] || { info "nothing selected"; return 0; }
        chosen=("${chosen[@]#* }")    # drop the ✔/✘ mark
        chosen=("${chosen[@]%% *}")   # label → name
    fi

    for name in "${chosen[@]}"; do
        info "setup: $name"
        bash "$SETUP_DIR/$name/setup.sh"
    done
}
