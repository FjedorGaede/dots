# cmd_setup — dots setup [name...] | --status | --ignore <name> | --unignore <name>
# Interactive per-machine setup steps (accounts, logins, ...) from
# setup/<name>/setup.sh. Not part of 'dots install': these need a human.
# No names: menu over all steps, each labelled with its status (✔ done / ✘ open
# / – ignored).
# --status: one line per step, tab-separated: <name> <done|open|ignored> <text>
# (machine-readable — quickshell's SetupService reads it).
# --ignore/--unignore: hide a step from the bar indicator. The only state file
# of the CLI (dots-cli/AGENTS.md): "ignored" is a decision, nothing to query.
#
# Script contract: `setup.sh status` prints a one-line status and exits 0 when
# the step is done, non-zero when open; `setup.sh` (no argument) runs the step.
# Scripts get $DOTFILES_DIR and $DOTS (path to this CLI) in the environment.

SETUP_DIR="$DOTFILES_DIR/setup"
SETUP_IGNORED="${XDG_STATE_HOME:-$HOME/.local/state}/dots/setup-ignored"

setup_names() { # setup step names, one per line (sorted)
    [ -d "$SETUP_DIR" ] || return 0
    find "$SETUP_DIR" -mindepth 2 -maxdepth 2 -name setup.sh -type f -printf '%h\n' | sed "s|^$SETUP_DIR/||" | sort
}

is_ignored() { grep -qxF -- "$1" "$SETUP_IGNORED" 2>/dev/null; }

# setup_state <name> — prints "<done|open|ignored>\t<status text>"
setup_state() {
    local text state=open
    if text="$(bash "$SETUP_DIR/$1/setup.sh" status 2>&1 | head -n1; exit "${PIPESTATUS[0]}")"; then
        state=done
    elif is_ignored "$1"; then
        state=ignored
    fi
    printf '%s\t%s\n' "$state" "$text"
}

require_setup() {
    [ -f "$SETUP_DIR/$1/setup.sh" ] || die "no such setup step: '$1' (existing: $(setup_names | tr '\n' ' '))"
}

cmd_setup() {
    export DOTFILES_DIR
    export DOTS="$DOTFILES_DIR/dots-cli/bin/dots"

    local -a all=() chosen=()
    mapfile -t all < <(setup_names)
    [ ${#all[@]} -gt 0 ] || die "no setup steps found in $SETUP_DIR"

    local name
    case "${1:-}" in
        --status)
            for name in "${all[@]}"; do
                printf '%s\t%s\n' "$name" "$(setup_state "$name")"
            done
            return 0
            ;;
        --ignore)
            [ $# -eq 2 ] || die "usage: dots setup --ignore <name>"
            require_setup "$2"
            is_ignored "$2" && return 0
            mkdir -p "$(dirname "$SETUP_IGNORED")"
            echo "$2" >> "$SETUP_IGNORED"
            info "ignored: $2"
            return 0
            ;;
        --unignore)
            [ $# -eq 2 ] || die "usage: dots setup --unignore <name>"
            require_setup "$2"
            if is_ignored "$2"; then
                local rest
                rest="$(grep -vxF -- "$2" "$SETUP_IGNORED" || true)"
                printf '%s\n' "$rest" | grep -v '^$' > "$SETUP_IGNORED" || true
            fi
            info "unignored: $2"
            return 0
            ;;
        -*) die "unknown flag: $1" ;;
    esac

    if [ $# -gt 0 ]; then
        for name in "$@"; do require_setup "$name"; done
        chosen=("$@")
    else
        require_gum
        local -a labels=()
        local state text mark
        for name in "${all[@]}"; do
            IFS=$'\t' read -r state text < <(setup_state "$name")
            case "$state" in
                done) mark="✔" ;;
                ignored) mark="–"; text="$text (ignored)" ;;
                *) mark="✘" ;;
            esac
            labels+=("$(printf '%s %-12s %s' "$mark" "$name" "$text")")
        done
        mapfile -t chosen < <(gum_choose_many "Run which setup steps? (x to select, enter to confirm)" "${labels[@]}" || true)
        [ -n "${chosen[*]}" ] || { info "nothing selected"; return 0; }
        chosen=("${chosen[@]#* }")    # drop the ✔/✘/– mark
        chosen=("${chosen[@]%% *}")   # label → name
    fi

    for name in "${chosen[@]}"; do
        info "setup: $name"
        bash "$SETUP_DIR/$name/setup.sh"
    done
}
