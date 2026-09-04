# cmd_install — dots install [category...] [--no-setup]
# Installs packages from the given categories, then runs the categories'
# setup/ scripts (skipped with --no-setup). With no arguments, shows a
# multi-select menu of all categories.

cmd_install() {
    local no_setup=false
    local -a wanted=()

    while [ $# -gt 0 ]; do
        case "$1" in
            --no-setup) no_setup=true ;;
            -*) die "unknown flag: $1" ;;
            *) wanted+=("$1") ;;
        esac
        shift
    done

    local -a chosen
    if [ ${#wanted[@]} -eq 0 ]; then
        mapfile -t wanted < <(categories)
        [ ${#wanted[@]} -gt 0 ] || die "no categories found in $PACKAGES_DIR — track some first with 'dots add'"
        require_gum
        mapfile -t chosen < <(gum_choose_many "Install which categories? (x to select, enter to confirm)" "${wanted[@]}")
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
        info "installing category '$cat'"
        install_category "$cat"
        if $no_setup; then
            info "skipping setups (--no-setup)"
        else
            run_setups "$cat"
        fi
        success "category '$cat' installed"
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

    if [ ${#native[@]} -gt 0 ]; then
        sudo pacman -S --needed --noconfirm "${native[@]}"
    fi
    if [ ${#aur[@]} -gt 0 ]; then
        command -v yay >/dev/null 2>&1 || die "yay not found, needed for AUR packages in '$cat': ${aur[*]}"
        yay -S --needed --noconfirm "${aur[@]}"
    fi
    info "packages for '$cat' done"
}

# Run every setup/*/setup.sh of a category, in sorted order.
run_setups() {
    local cat="$1"
    local -a setups=()
    mapfile -t setups < <(setup_scripts "$cat")
    [ ${#setups[@]} -gt 0 ] || return 0

    local name
    for name in "${setups[@]}"; do
        local script
        script="$(category_dir "$cat")/setup/$name/setup.sh"
        info "setup: $cat/$name"
        bash "$script"
    done
    info "setups for '$cat' done"
}