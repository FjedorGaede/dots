# cmd_install — dots install [category...]
# Installs packages from the given categories. With no arguments, shows a
# multi-select menu of all categories (defaults to all selected).

cmd_install() {
    local -a wanted=("$@") chosen

    if [ ${#wanted[@]} -eq 0 ]; then
        mapfile -t wanted < <(categories)
        [ ${#wanted[@]} -gt 0 ] || die "no categories found in $PACKAGES_DIR — track some first with 'dots add'"
        require_gum
        mapfile -t chosen < <(gum_choose_many "Install which categories?" "${wanted[@]}")
        # gum choose exits 0 with no selection when cancelled; treat empty as all
        if [ ${#chosen[@]} -eq 0 ] || [ -z "${chosen[*]}" ]; then
            chosen=("${wanted[@]}")
        fi
    else
        chosen=("${wanted[@]}")
    fi

    local cat
    for cat in "${chosen[@]}"; do
        require_category "$cat"
        install_category "$cat"
    done
}

install_category() {
    local cat="$1"
    local -a native=() aur=() line
    while IFS= read -r line; do
        [ -n "$line" ] || continue
        if is_aur "$line"; then
            aur+=("$(pkg_name "$line")")
        else
            native+=("$(pkg_name "$line")")
        fi
    done < <(packages_in_category "$cat")

    info "installing category: $cat"
    if [ ${#native[@]} -gt 0 ]; then
        sudo pacman -S --needed "${native[@]}"
    fi
    if [ ${#aur[@]} -gt 0 ]; then
        command -v yay >/dev/null 2>&1 || die "yay not found, needed for AUR packages in '$cat': ${aur[*]}"
        yay -S --needed "${aur[@]}"
    fi
    info "category '$cat' done"
}