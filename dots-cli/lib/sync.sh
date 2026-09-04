# cmd_sync — dots sync
# Drift check between tracked categories and what's actually installed.
# Print-only: never modifies anything.

cmd_sync() {
    [ $# -eq 0 ] || die "usage: dots sync (takes no arguments)"

    command -v pacman >/dev/null 2>&1 || die "pacman not found — this command is Arch/CachyOS only"

    # tracked = every package listed in any category, aur: prefix stripped
    local -a cats=()
    mapfile -t cats < <(categories)

    local tracked_sorted="/dev/null"
    if [ ${#cats[@]} -gt 0 ]; then
        local cat
        for cat in "${cats[@]}"; do
            packages_in_category "$cat" | sed 's/^aur://'
        done | sort -u > /tmp/dots-tracked.$$
        tracked_sorted="/tmp/dots-tracked.$$"
    fi

    local installed_sorted="/tmp/dots-installed.$$"
    pacman -Qq | sort -u > "$installed_sorted"

    local rc=0

    if [ ${#cats[@]} -gt 0 ]; then
        local -a untracked=()
        mapfile -t untracked < <(comm -13 "$tracked_sorted" "$installed_sorted")
        if [ ${#untracked[@]} -gt 0 ]; then
            echo "Installed but NOT tracked (${#untracked[@]}):"
            printf '  %s\n' "${untracked[@]}"
        else
            echo "Nothing installed that isn't tracked."
        fi

        local -a missing=()
        mapfile -t missing < <(comm -23 "$tracked_sorted" "$installed_sorted")
        if [ ${#missing[@]} -gt 0 ]; then
            echo
            echo "Tracked but NOT installed (${#missing[@]}):"
            printf '  %s\n' "${missing[@]}"
            rc=1
        else
            echo "All tracked packages are installed."
        fi
    else
        echo "No categories tracked yet — nothing to compare."
    fi

    rm -f "$installed_sorted"
    [ -f "$tracked_sorted" ] && [ "$tracked_sorted" != "/dev/null" ] && rm -f "$tracked_sorted"
    exit $rc
}