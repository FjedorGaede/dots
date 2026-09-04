# cmd_list — dots list [category]
# Prints tracked packages. One category scoped, or all with headers.

cmd_list() {
    [ $# -le 1 ] || die "usage: dots list [category]"

    if [ $# -eq 1 ]; then
        require_category "$1"
        packages_in_category "$1"
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