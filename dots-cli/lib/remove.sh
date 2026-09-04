# cmd_remove — dots remove [<category> <pkg...>] [--uninstall]
# Default: untrack only (edit the category file).
# --uninstall: also remove from the system, after gum confirmation.
# With no arguments: searchable picker over all tracked packages.

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

    if [ ${#args[@]} -eq 0 ]; then
        remove_interactive "$uninstall"
        return 0
    fi

    [ ${#args[@]} -ge 2 ] || die "usage: dots remove [<category> <pkg...>] [--uninstall]"
    local category="${args[0]}"
    local -a pkgs=("${args[@]:1}")
    require_category "$category"

    untrack_packages "$category" "${pkgs[@]}"

    if [ "$uninstall" = true ]; then
        require_gum
        info "removing from system — sudo may ask for your password"
        gum_confirm "Also remove ${pkgs[*]} from the system?" || { info "skipped uninstall"; return 0; }
        uninstall_packages "${pkgs[@]}"
    fi
}

# untrack_packages <category> <pkg...>: rewrite the category file without the
# given packages. Reports what was found (and whether it was an aur: entry).
untrack_packages() {
    local category="$1"; shift
    local file
    file="$(category_file "$category")"

    local -A was_aur=()
    local -a remaining=() removed=()
    local line pkg keep
    while IFS= read -r line; do
        keep=true
        for pkg in "$@"; do
            if [ "$line" = "$pkg" ]; then
                keep=false
            elif [ "$line" = "aur:$pkg" ]; then
                keep=false
                was_aur[$pkg]=true
            fi
        done
        if $keep; then
            remaining+=("$line")
        else
            removed+=("$line")
        fi
    done < <(packages_in_category "$category")

    if [ ${#remaining[@]} -gt 0 ]; then
        printf '%s\n' "${remaining[@]}" > "$file"
    else
        : > "$file"
    fi
    info "untracked from '$category': ${removed[*]:-none}"

    # remember aur status for the caller via a file-scoped global
    UNTRACKED_WAS_AUR=("${!was_aur[@]}")
}

# uninstall_packages <pkg...>: remove from the system. AUR packages
# (foreign to pacman) go through yay.
uninstall_packages() {
    local pkg
    for pkg in "$@"; do
        if [ -z "$(pacman -Q "$pkg" 2>/dev/null)" ]; then
            warn "$pkg is not installed — nothing to uninstall"
            continue
        fi
        if [ -n "$(pacman -Qm "$pkg" 2>/dev/null)" ]; then
            yay -Rns --noconfirm "$pkg" || warn "failed to remove $pkg"
        else
            sudo pacman -Rns --noconfirm "$pkg" || warn "failed to remove $pkg"
        fi
    done
    info "uninstalled: $*"
}

# No-argument flow: pick tracked packages across all categories, then decide
# whether to also uninstall them from the system (default: untrack only).
remove_interactive() {
    local uninstall_flag="$1"
    require_gum

    local -a cats=()
    mapfile -t cats < <(categories)
    [ ${#cats[@]} -gt 0 ] || die "no categories tracked yet — nothing to remove"

    # entries as "category/pkg  (aur)" — searchable via gum's filter
    local -a entries=()
    local cat line
    for cat in "${cats[@]}"; do
        while IFS= read -r line; do
            if is_aur "$line"; then
                entries+=("$cat/$(pkg_name "$line")  (aur)")
            else
                entries+=("$cat/$line")
            fi
        done < <(packages_in_category "$cat")
    done
    [ ${#entries[@]} -gt 0 ] || die "no packages tracked yet"

    local -a picked=()
    mapfile -t picked < <(gum_choose_many "Remove which packages? (type to search)" "${entries[@]}")
    [ ${#picked[@]} -gt 0 ] || { info "nothing selected"; return 0; }

    # strip display decorations, group back into category -> packages
    local -A pkgs_by_cat=()
    local -a all_pkgs=()
    local entry cat_part pkg_part display_pkg
    for entry in "${picked[@]}"; do
        display_pkg="${entry#*/}"        # "cat/pkg  (aur)" -> "pkg  (aur)"
        display_pkg="${display_pkg%%  (*}" # strip "  (aur)"
        cat_part="${entry%%/*}"
        pkgs_by_cat[$cat_part]+=" $display_pkg"
        all_pkgs+=("$display_pkg")
    done

    for cat_part in "${!pkgs_by_cat[@]}"; do
        # shellcheck disable=SC2086
        untrack_packages "$cat_part" ${pkgs_by_cat[$cat_part]}
    done

    if $uninstall_flag; then
        info "removing from system — sudo may ask for your password"
        uninstall_packages "${all_pkgs[@]}"
    elif gum_confirm "Also uninstall ${all_pkgs[*]} from the system?"; then
        info "removing from system — sudo may ask for your password"
        uninstall_packages "${all_pkgs[@]}"
    else
        info "kept installed, only untracked"
    fi
}