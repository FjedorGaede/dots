# cmd_add — dots add <pkg...> [--aur] [--category <name>]
# Installs first, tracks second — a failed install never gets recorded.
# Without --category, prompts via gum (existing categories + "+ new category").

cmd_add() {
    local -a pkgs=()
    local force_aur=false category=""

    while [ $# -gt 0 ]; do
        case "$1" in
            --aur) force_aur=true ;;
            --category)
                shift
                [ $# -gt 0 ] || die "--category needs a value"
                category="$1"
                ;;
            -*) die "unknown flag: $1" ;;
            *) pkgs+=("$1") ;;
        esac
        shift
    done

    [ ${#pkgs[@]} -gt 0 ] || die "usage: dots add <pkg...> [--aur] [--category <name>]"

    # 1. Install
    if [ "$force_aur" = true ]; then
        command -v yay >/dev/null 2>&1 || die "yay not found (required for --aur)"
        yay -S --needed "${pkgs[@]}"
    else
        sudo pacman -S --needed "${pkgs[@]}"
    fi

    # 2. Pick / create the category
    if [ -z "$category" ]; then
        require_gum
        local -a options=()
        mapfile -t options < <(categories)
        options+=("+ new category")
        local picked
        picked="$(gum_choose_one "Track ${pkgs[*]} under which category?" "${options[@]}")" \
            || die "cancelled"
        [ -n "$picked" ] || die "no category selected"
        if [ "$picked" = "+ new category" ]; then
            category="$(gum_input "New category name:" "e.g. hyprland")" || die "cancelled"
            [ -n "$category" ] || die "empty category name"
        else
            category="$picked"
        fi
    fi

    # 3. Track
    local file
    file="$(category_file "$category")"
    mkdir -p "$PACKAGES_DIR"
    touch "$file"
    local line
    for line in "${pkgs[@]}"; do
        [ "$force_aur" = true ] && line="aur:$line"
        if grep -qx "$line" "$file"; then
            info "already tracked in '$category': $line"
        else
            echo "$line" >> "$file"
            info "tracked in '$category': $line"
        fi
    done
}