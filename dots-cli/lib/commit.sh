# commit.sh — `dots commit [message] [--push]`: the manual commit flow for
# repo changes. Changes are grouped (configs / packages / cli / other) and
# each group becomes its own commit — CLI code and dotfile configs don't end
# up mixed in one commit. add/remove auto-commit separately via
# repo_commit_paths in common.sh.

cmd_commit() {
    git -C "$DOTFILES_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1 \
        || die "not a git repo: $DOTFILES_DIR"

    local msg="" push=""
    while [ $# -gt 0 ]; do
        case "$1" in
            --push) push=1 ;;
            -h|--help) echo "usage: dots commit [message] [--push]"; return 0 ;;
            *) msg="$1" ;;
        esac
        shift
    done

    git -C "$DOTFILES_DIR" status --porcelain > "$(mktemp)" 2>/dev/null || true
    local status_file
    status_file="$(mktemp)"
    git -C "$DOTFILES_DIR" status --porcelain > "$status_file"
    [ -s "$status_file" ] || { rm -f "$status_file"; die "nothing to commit — working tree clean"; }

    # classify changed paths into groups: label|prefix
    # shellcheck disable=SC2016
    local -A groups=( \
        ["configs (stow/)"]='' \
        ["packages"]='packages: ' \
        ["dots-cli"]='dots-cli: ' \
        ["other"]='' )
    local -a order=("configs (stow/)" "packages" "dots-cli" "other")
    local -A files=()
    local path group
    while IFS= read -r path; do
        [ -n "$path" ] || continue
        case "$path" in
            stow/*)      group="configs (stow/)" ;;
            packages/*)  group="packages" ;;
            dots-cli/*)  group="dots-cli" ;;
            *)           group="other" ;;
        esac
        files[$group]+="$path"$'\n'
    done < <(cut -c4- "$status_file")
    rm -f "$status_file"

    # which groups to commit (only the non-empty ones)
    local -a present=() options=() selected=()
    local g
    for g in "${order[@]}"; do
        [ -n "${files[$g]:-}" ] || continue
        present+=("$g")
        options+=("$g")
    done

    if [ ${#present[@]} -eq 1 ]; then
        selected=("${present[0]}")
    else
        require_gum
        info "pending changes in ${#present[@]} groups:"
        for g in "${present[@]}"; do
            info "  $g: $(printf '%s' "${files[$g]}" | grep -c .) file(s)"
        done
        # gum 2.0: --selected takes a comma-separated value, x toggles
        local joined
        joined="$(IFS=,; echo "${present[*]}")"
        mapfile -t selected < <(gum choose --no-limit \
            --header "Commit which groups? (each becomes its own commit; x toggles)" \
            --selected "$joined" "${options[@]}" || true)
        if [ ${#selected[@]} -eq 0 ]; then
            if [ -n "$msg" ]; then
                info "no TTY for the group picker — committing all groups"
                selected=("${present[@]}")
            else
                info "nothing selected"
                return 0
            fi
        fi
    fi

    for g in "${selected[@]}"; do
        local group_msg="$msg"
        # stage exactly this group's paths
        local -a paths=()
        mapfile -t paths < <(printf '%s' "${files[$g]}" | sed '/^$/d')
        git -C "$DOTFILES_DIR" add -- "${paths[@]}"
        if [ -z "$group_msg" ]; then
            require_gum
            group_msg="$(gum input --prompt "Commit message [$g]:" --value "${groups[$g]:-}")" || true
            [ -z "$group_msg" ] && { warn "skipped '$g' (no message)"; continue; }
        elif [ -n "${groups[$g]}" ]; then
            group_msg="${groups[$g]}$msg"   # apply group prefix in non-interactive mode
        fi
        git -C "$DOTFILES_DIR" commit --quiet -m "$group_msg"
        success "committed: $group_msg"
    done

    if [ -n "$push" ]; then
        repo_push
    elif command -v gum >/dev/null 2>&1 && gum_confirm "Push to origin now?"; then
        repo_push
    fi
}
