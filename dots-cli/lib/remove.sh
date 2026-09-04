# cmd_remove — dots remove <category> <pkg...> [--uninstall]
# Default: untrack only (edit the category file).
# --uninstall: also remove from the system, after gum confirmation.

cmd_remove() {
    local uninstall=false
    local -a args=()

    while [ $# -gt 0 ]; do
        case "$1" in
            --uninstall) uninstall=true ;;
            -*) die "unknown flag: $1" ;;
            *) args+=("$1") ;;
        esac
        shift
    done

    [ ${#args[@]} -ge 2 ] || die "usage: dots remove <category> <pkg...> [--uninstall]"
    local category="${args[0]}"
    local -a pkgs=("${args[@]:1}")
    require_category "$category"

    local file
    file="$(category_file "$category")"

    local -A was_aur=()
    local -a remaining=() aur_pkgs=()
    local line pkg keep
    while IFS= read -r line; do
        keep=true
        for pkg in "${pkgs[@]}"; do
            if [ "$line" = "$pkg" ]; then
                keep=false
            elif [ "$line" = "aur:$pkg" ]; then
                keep=false
                was_aur[$pkg]=true
                aur_pkgs+=("$pkg")
            fi
        done
        if $keep; then
            remaining+=("$line")
        fi
    done < <(packages_in_category "$category")

    if [ ${#remaining[@]} -gt 0 ]; then
        printf '%s\n' "${remaining[@]}" > "$file"
    else
        : > "$file"
    fi
    info "untracked from '$category': ${pkgs[*]}"

    if [ "$uninstall" = true ]; then
        require_gum
        info "removing from system — sudo may ask for your password"
        gum_confirm "Also remove ${pkgs[*]} from the system?" || { info "skipped uninstall"; return 0; }
        for pkg in "${pkgs[@]}"; do
            if [ -n "${was_aur[$pkg]:-}" ]; then
                yay -Rns --noconfirm "$pkg" || warn "failed to remove $pkg (was it installed?)"
            else
                sudo pacman -Rns --noconfirm "$pkg" || warn "failed to remove $pkg (was it installed?)"
            fi
        done
        info "uninstalled: ${pkgs[*]}"
    fi
}