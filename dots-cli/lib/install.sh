# cmd_install — dots install [category...] [--packages-only] [--pick]
#                dots install <category> --only <item,item,...>
# Installs packages from the given categories, then runs the categories'
# install/ scripts (skipped with --packages-only). --pick shows one menu per
# category with its packages and install scripts to choose from. --only is
# the non-interactive twin of --pick: installs just the named items (names as
# printed by 'dots list <cat> --items'). With no category arguments,
# shows a multi-select menu of all categories.

cmd_install() {
    local packages_only=false pick=false only=""
    local -a wanted=()

    while [ $# -gt 0 ]; do
        case "$1" in
            --packages-only) packages_only=true ;;
            --pick) pick=true ;;
            --only)
                shift
                [ $# -gt 0 ] || die "usage: dots install <category> --only <item,...>"
                only="$1"
                ;;
            -*) die "unknown flag: $1" ;;
            *) wanted+=("$1") ;;
        esac
        shift
    done
    ! $pick || require_gum
    if [ -n "$only" ]; then
        ! $pick || die "use either --pick or --only, not both"
        [ ${#wanted[@]} -eq 1 ] || die "exactly one category with --only — usage: dots install <category> --only <item,...>"
    fi

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

        local -a pkgs=() scripts=()
        mapfile -t pkgs < <(packages_in_category "$cat")
        $packages_only || mapfile -t scripts < <(install_scripts "$cat")
        $pick && pick_items "$cat" pkgs scripts
        [ -z "$only" ] || only_items "$cat" "$only" pkgs scripts

        install_packages "$cat" "${pkgs[@]}"
        if $packages_only; then
            info "skipping install scripts (--packages-only)"
        else
            run_install_scripts "$cat" "${scripts[@]}"
        fi
        if $pick || [ -n "$only" ]; then
            report_picked "$cat" pkgs scripts
        else
            success "category '$cat' installed"
        fi
    done
}

# pick_items <cat> <pkgs-array-name> <scripts-array-name>
# One menu over a category's packages (labelled pacman/aur) and install
# scripts. A package and a script with the same name are one entry
# ("pacman + install").
# Narrows both arrays in place to what was picked (none picked = nothing).
pick_items() {
    local cat="$1"
    local -n _pkgs="$2" _scripts="$3"
    local -a labels=() picked=()
    local line name kind s

    for line in "${_pkgs[@]}"; do
        name="$(pkg_name "$line")"
        if is_aur "$line"; then kind="aur"; else kind="pacman"; fi
        for s in "${_scripts[@]}"; do
            [ "$s" = "$name" ] && kind="$kind + install"
        done
        labels+=("$(printf '%-28s %s' "$name" "$kind")")
    done
    for s in "${_scripts[@]}"; do
        is_listed "$s" "${_pkgs[@]}" || labels+=("$(printf '%-28s %s' "$s" "install")")
    done
    [ ${#labels[@]} -gt 0 ] || return 0

    mapfile -t picked < <(gum_choose_many "Install what from '$cat'? (x to select, ctrl+a all, enter to confirm)" "${labels[@]}" || true)
    picked=("${picked[@]%% *}")   # label → name

    local -a keep_pkgs=() keep_scripts=()
    for line in "${_pkgs[@]}"; do
        is_picked "$(pkg_name "$line")" "${picked[@]}" && keep_pkgs+=("$line")
    done
    for s in "${_scripts[@]}"; do
        is_picked "$s" "${picked[@]}" && keep_scripts+=("$s")
    done
    _pkgs=("${keep_pkgs[@]}")
    _scripts=("${keep_scripts[@]}")
}

# only_items <cat> <item,item,...> <pkgs-array-name> <scripts-array-name>
# Narrows both arrays in place to the named items, like pick_items without
# the menu. An item naming a package and a script selects both. Unknown
# names die — a typo must not silently install nothing.
only_items() {
    local cat="$1" list="$2"
    local -n _opkgs="$3" _oscripts="$4"
    local -a names=() keep_pkgs=() keep_scripts=()
    local name line s found

    IFS=',' read -ra names <<< "$list"
    for name in "${names[@]}"; do
        found=false
        is_listed "$name" "${_opkgs[@]}" && found=true
        for s in "${_oscripts[@]}"; do
            [ "$s" = "$name" ] && found=true
        done
        $found || die "'$cat' has no item '$name' (see: dots list $cat --items)"
    done

    for line in "${_opkgs[@]}"; do
        is_picked "$(pkg_name "$line")" "${names[@]}" && keep_pkgs+=("$line")
    done
    for s in "${_oscripts[@]}"; do
        is_picked "$s" "${names[@]}" && keep_scripts+=("$s")
    done
    _opkgs=("${keep_pkgs[@]}")
    _oscripts=("${keep_scripts[@]}")
}

# report_picked <cat> <pkgs-array-name> <scripts-array-name> — what --pick did
report_picked() {
    local cat="$1"
    local -n _p="$2" _s="$3"
    if [ ${#_p[@]} -eq 0 ] && [ ${#_s[@]} -eq 0 ]; then
        info "'$cat': nothing installed"
        return 0
    fi
    local -a names=() line
    for line in "${_p[@]}"; do names+=("$(pkg_name "$line")"); done
    [ ${#names[@]} -eq 0 ] || success "'$cat': installed ${names[*]}"
    [ ${#_s[@]} -eq 0 ] || success "'$cat': ran install script ${_s[*]}"
}

is_picked() { # is_picked <name> <name...> -> exit 0 if name is among the rest
    local want="$1" n; shift
    for n in "$@"; do [ "$n" = "$want" ] && return 0; done
    return 1
}

is_listed() { # is_listed <name> <package line...> -> exit 0 if a line is that package
    local want="$1" line; shift
    for line in "$@"; do [ "$(pkg_name "$line")" = "$want" ] && return 0; done
    return 1
}

# install_packages <cat> <package line...> — pacman for native, yay for aur:.
install_packages() {
    local cat="$1"; shift
    [ $# -gt 0 ] || return 0
    local -a native=() aur=() line
    for line in "$@"; do
        [ -n "$line" ] || continue
        if is_aur "$line"; then
            aur+=("$(pkg_name "$line")")
        else
            native+=("$(pkg_name "$line")")
        fi
    done

    if [ ${#native[@]} -gt 0 ]; then
        sudo pacman -S --needed --noconfirm "${native[@]}"
    fi
    if [ ${#aur[@]} -gt 0 ]; then
        command -v yay >/dev/null 2>&1 || die "yay not found, needed for AUR packages in '$cat': ${aur[*]}"
        yay -S --needed --noconfirm "${aur[@]}"
    fi
    info "packages for '$cat' done"
}

# run_install_scripts <cat> <name...> — runs each install/<name>/install.sh in order.
run_install_scripts() {
    local cat="$1"; shift
    [ $# -gt 0 ] || return 0

    local name
    for name in "$@"; do
        info "install script: $cat/$name"
        bash "$(category_dir "$cat")/install/$name/install.sh"
    done
    info "install scripts for '$cat' done"
}
