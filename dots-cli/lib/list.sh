# cmd_list — dots list [category] [--items] | dots list --categories
# Prints tracked packages. One category scoped, or all with headers.
# --categories: only the category names, one per line.
# --items: everything installable in one category (package names + install
# scripts, a package and a script with the same name once), one per line —
# the names 'dots install <cat> --only' takes.

cmd_list() {
    local only_categories=false items=false
    local -a args=()

    while [ $# -gt 0 ]; do
        case "$1" in
            --categories) only_categories=true ;;
            --items) items=true ;;
            -*) die "unknown flag: $1" ;;
            *) args+=("$1") ;;
        esac
        shift
    done

    if $only_categories; then
        [ ${#args[@]} -eq 0 ] && ! $items || die "usage: dots list --categories"
        categories
        return 0
    fi

    [ ${#args[@]} -le 1 ] || die "usage: dots list [category] [--items]"

    if $items; then
        [ ${#args[@]} -eq 1 ] || die "usage: dots list <category> --items"
        require_category "${args[0]}"
        category_items "${args[0]}"
        return 0
    fi

    if [ ${#args[@]} -eq 1 ]; then
        require_category "${args[0]}"
        packages_in_category "${args[0]}"
        return 0
    fi

    local -a cats=()
    mapfile -t cats < <(categories)
    [ ${#cats[@]} -gt 0 ] || { info "no categories tracked yet — use 'dots add'"; return 0; }

    local cat
    for cat in "${cats[@]}"; do
        echo "# $cat"
        packages_in_category "$cat" | awk '{ if ($0 ~ /^aur:/) print "  (aur) " substr($0, 5); else print "  " $0 }'
        echo
    done
}

category_items() { # category_items <cat> — package names, then install scripts that aren't a package
    local line s
    local -a names=()
    while IFS= read -r line; do
        names+=("$(pkg_name "$line")")
    done < <(packages_in_category "$1")
    printf '%s\n' "${names[@]}" | grep -v '^$' || true
    while IFS= read -r s; do
        [ -n "$s" ] || continue
        printf '%s\n' "${names[@]}" | grep -qx -- "$s" || echo "$s"
    done < <(install_scripts "$1")
}
