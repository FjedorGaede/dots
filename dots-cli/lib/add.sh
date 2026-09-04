# cmd_add — dots add <pkg...> [--aur] [--category <name>]
#            dots add --setup <name> [--category <name>]
# Installs first, tracks second — a failed install never gets recorded.
# Without --category, prompts via gum (existing categories + "+ new category").

cmd_add() {
    local force_aur=false category="" setup_name=""
    local -a pkgs=()

    while [ $# -gt 0 ]; do
        case "$1" in
            --aur) force_aur=true ;;
            --category)
                shift
                [ $# -gt 0 ] || die "--category needs a value"
                category="$1"
                ;;
            --setup)
                shift
                [ $# -gt 0 ] || die "--setup needs a name"
                setup_name="$1"
                ;;
            -*) die "unknown flag: $1" ;;
            *) pkgs+=("$1") ;;
        esac
        shift
    done

    # Setup scaffolding: creates packages/<cat>/setup/<name>/setup.sh
    if [ -n "$setup_name" ]; then
        [ ${#pkgs[@]} -eq 0 ] || die "--setup takes no packages — usage: dots add --setup <name> [--category <cat>]"
        pick_category
        scaffold_setup "$category" "$setup_name"
        return 0
    fi

    [ ${#pkgs[@]} -gt 0 ] || die "usage: dots add <pkg...> [--aur] [--category <name>]"

    # 1. Install
    info "installing ${pkgs[*]}"
    if [ "$force_aur" = true ]; then
        command -v yay >/dev/null 2>&1 || die "yay not found (required for --aur)"
        yay -S --needed --noconfirm "${pkgs[@]}"
    else
        sudo pacman -S --needed --noconfirm "${pkgs[@]}"
    fi

    # 2. Pick / create the category
    pick_category

    # 3. Track
    info "tracking under '$category': ${pkgs[*]}"
    local file
    file="$(category_file "$category")"
    mkdir -p "$(dirname "$file")"
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
    success "${pkgs[*]} installed and tracked in '$category'"
}

# Resolve the target category: explicit --category, or gum menu with existing
# categories plus "+ new category" as the last, searchable entry.
pick_category() {
    if [ -n "$category" ]; then
        return 0
    fi
    require_gum
    local -a options=()
    mapfile -t options < <(categories)
    options+=("+ new category")
    local picked
    picked="$(gum_choose_one "Which category?" "${options[@]}")" || die "cancelled"
    [ -n "$picked" ] || die "no category selected"
    if [ "$picked" = "+ new category" ]; then
        category="$(gum_input "New category name: " "e.g. hyprland")" || die "cancelled"
        [ -n "$category" ] || die "empty category name"
    else
        category="$picked"
    fi
}

# Create packages/<cat>/setup/<name>/setup.sh with an idempotent skeleton.
scaffold_setup() {
    local cat="$1" name="$2"
    local dir
    dir="$(category_dir "$cat")/setup/$name"
    [ -e "$dir" ] && die "setup already exists: packages/$cat/setup/$name"

    mkdir -p "$dir"
    touch "$(category_file "$cat")"   # make sure the category itself is valid

    cat > "$dir/setup.sh" <<EOF
#!/usr/bin/env bash
# setup: $name (category: $cat)
# Runs on 'dots install $cat' after the category's packages are installed.
# MUST be idempotent — safe to run again on every install.
set -euo pipefail

echo "TODO: implement the $name setup"
EOF
    chmod +x "$dir/setup.sh"
    info "scaffolded packages/$cat/setup/$name/setup.sh — edit it; it runs on 'dots install $cat'"
}