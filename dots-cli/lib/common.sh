# common.sh — shared helpers for the dots CLI.
# Sourced by bin/dots (which defines DOTFILES_DIR and LIB_DIR before sourcing)
# and by every lib/<cmd>.sh. No commands here, only helpers.

set -euo pipefail

PACKAGES_DIR="$DOTFILES_DIR/packages"
STOW_DIR="$DOTFILES_DIR/stow"
PREFS_DIR="$DOTFILES_DIR/prefs"
BACKUP_DIR="$HOME/.dotfiles-backup"

usage() {
    cat <<'EOF'
dots — dotfiles CLI

Machine setup (rare — new machine / migration):
  dots install [category...] [--packages-only] [--pick]
                              Install packages from categories (menu if none
                              given) + run their install/ scripts (skipped
                              with --packages-only); --pick = choose packages
                              + install scripts from a menu
  dots install <category> --only <item,...>
                              Install only the named items of one category
                              (names from 'dots list <category> --items')
  dots setup [name...]        Interactive per-machine setup steps (git, ssh,
                              github, dots-remote, calendar) from setup/;
                              no name = menu with done/open status
  dots setup --status | --ignore <name> | --unignore <name>
                              Status lines for the bar indicator / hide a
                              step from it
  dots stow [component...|all] Stow components (menu, pre-selecting linked ones;
                              'all' links every component without the menu)
  dots stow-add [--all] [--dry-run] <name|path> [path]
                              Import a live config (default ~/.config/<name>)
                              as a new stow component: pick dirs/files in a
                              tree, nested .git is vendored, then stow + commit
                              (existing component: extend it; --dry-run: only
                              print what would happen)
  dots stow-remove [--yes] <component...>
                              Detach a component: unstow, copy repo content back
                              over the live symlinks, remove from repo + commit
  dots list [category]        Show tracked packages (all or one category)
  dots list --categories      Category names, one per line
  dots list <category> --items
                              Installable items (packages + install scripts)
  dots sync                   Drift check: installed vs. tracked (print-only)

Packages (tracking changes auto-commit + auto-push):
  dots add <pkg...> [--aur] [--category <name>]
                              Install package(s), then track them in a category
  dots add --script <name> [--category <name>]
                              Scaffold a new install script for a category
  dots remove [<category> <pkg...>] [--uninstall]
                              Untrack package(s); --uninstall also removes from
                              system; no arguments = searchable picker

Daily:
  dots update [--dry-run]     Pull the repo (fast-forward only), restow every
                              linked component, report packages to install,
                              reload Hyprland; --dry-run = preview only
  dots prefs [diff|capture|apply] [app...] [--yes]
                              App settings that can't be stowed (Vivaldi
                              shortcuts, ...): capture = machine → repo,
                              apply = repo → machine (closes + reopens a
                              running app), diff = compare; no app = all in
                              prefs/ (see prefs/README.md)
  dots edit [component]       Open $EDITOR in the stow tree (whole tree or one
                              component); edits land in the repo — commit them
  dots theme [-l] [name]      Apply a pywal16 colorscheme (+ per-app adapters in
                              dots-cli/theming/); no name = picker, -l = light
  dots calendar [client|login|logout|list]
                              Google account login for the quickshell
                              calendar (OAuth); no command = menu

Git (pushing + everything else — lazygit: pull = p, push = Shift+P):
  dots git                    Open lazygit in the repo

Category layout (packages/ is scanned — a directory = one category):
  packages/<category>/packages.txt       one package per line, aur: prefix → yay
  packages/<category>/install/<name>/install.sh   optional install script (idempotent bash)
  setup/<name>/setup.sh       interactive setup step for 'dots setup'

Environment:
  DOTFILES_DIR    Repo root (auto-detected from the script location)
EOF
}

die() {
    if command -v gum >/dev/null 2>&1; then
        gum log --level error "$*" >&2
    else
        echo "dots: $*" >&2
    fi
    exit 1
}

# Leveled logging through gum when available, plain echo otherwise.
info() {
    if command -v gum >/dev/null 2>&1; then
        gum log --level info "$*"
    else
        echo "==> $*"
    fi
}

warn() {
    if command -v gum >/dev/null 2>&1; then
        gum log --level warn "$*" >&2
    else
        echo "dots: warning: $*" >&2
    fi
}

# gum log has no success level — a green ✔ line via gum style instead.
success() {
    if command -v gum >/dev/null 2>&1; then
        gum style --foreground 76 "✔ $*"
    else
        echo "✔ $*"
    fi
}

# --- gum wrappers -----------------------------------------------------------
# gum is the interaction layer. Interactive commands refuse to run without it.

require_gum() {
    command -v gum >/dev/null 2>&1 || die "gum is required for interactive use (sudo pacman -S gum), or pass arguments explicitly"
}

gum_confirm() { # gum_confirm <prompt> -> exit 0 on yes
    gum confirm "$1"
}

gum_input() { # gum_input <prompt> <placeholder> -> value on stdout
    gum input --placeholder "$2" --prompt "$1"
}

gum_choose_one() { # gum_choose_one <question> <option>... -> selected option
    local header="$1"; shift
    gum choose --header "$header" "$@"
}

gum_choose_many() { # gum_choose_many <question> <option>... -> selected options, one per line
    local header="$1"; shift
    gum choose --no-limit --header "$header" "$@"
}

# --- categories -------------------------------------------------------------
# A category is a directory under packages/ containing packages.txt and an
# optional install/ directory. Discovered by scanning — no registry.

categories() { # all category names, one per line
    [ -d "$PACKAGES_DIR" ] || return 0
    find "$PACKAGES_DIR" -mindepth 1 -maxdepth 1 -type d ! -name '.*' -printf '%f\n' | sort
}

category_dir() { echo "$PACKAGES_DIR/$1"; }
category_file() { echo "$PACKAGES_DIR/$1/packages.txt"; }

category_exists() { [ -f "$(category_file "$1")" ]; }

require_category() {
    category_exists "$1" || die "no such category: '$1' (existing: $(categories | tr '\n' ' '))"
}

packages_in_category() { # lines minus blanks/comments; aur: prefix preserved
    local file
    file="$(category_file "$1")"
    [ -f "$file" ] || return 0
    sed -e 's/#.*$//' -e 's/[[:space:]]*$//' "$file" | grep -v '^$' || true
}

install_scripts() { # install script names for a category, one per line (sorted)
    local dir
    dir="$(category_dir "$1")/install"
    [ -d "$dir" ] || return 0
    find "$dir" -mindepth 2 -maxdepth 2 -name install.sh -type f -printf '%h\n' | sed "s|^$dir/||" | sort
}

is_aur() { [ "${1#aur:}" != "$1" ]; }
pkg_name() { echo "${1#aur:}"; }

# --- stow -------------------------------------------------------------------

stow_components() { # all component names under stow/
    [ -d "$STOW_DIR" ] || return 0
    find "$STOW_DIR" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort
}

# is_linked <component>: true if the first tracked file of the component is a
# symlink pointing into the repo (i.e. the component is stowed). Approximation
# is fine — it only drives menu pre-selection.
is_linked() {
    local comp="$1" probe target link
    probe="$(find "$STOW_DIR/$comp" -type f -printf '%P\n' | head -n 1)"
    [ -n "$probe" ] || return 1
    target="$HOME/$probe"
    [ -L "$target" ] || return 1
    link="$(readlink "$target")"
    case "$link" in
        "$STOW_DIR"/"$comp"/*|*/stow/"$comp"/*) return 0 ;;
        *) return 1 ;;
    esac
}

# backup_conflicts <component>: move existing real files (or symlinks pointing
# elsewhere) to $BACKUP_DIR so the repo's version wins. "Repo wins on conflict."
backup_conflicts() {
    local comp="$1" ts dir rel target
    ts="$(date +%Y%m%d-%H%M%S)"
    dir="$BACKUP_DIR/$comp.$ts"
    find "$STOW_DIR/$comp" -type f -printf '%P\n' | while IFS= read -r rel; do
        target="$HOME/$rel"
        [ -e "$target" ] || [ -L "$target" ] || continue
        # already ours: linked directly, or reached through a folded dir link
        # (e.g. ~/.config/x -> stow/x/.config/x) — then target IS the repo file
        [ "$(readlink -f "$target")" = "$(readlink -f "$STOW_DIR/$comp/$rel")" ] && continue
        mkdir -p "$dir/$(dirname "$rel")"
        mv "$target" "$dir/$rel"
        warn "backed up $target -> $dir/$rel"
    done
}

# --- prefs ------------------------------------------------------------------
# Settings of apps that rewrite their own JSON config (can't be stowed): the
# repo keeps only the chosen keys in prefs/<app>/prefs.json and merges them
# into the live file. prefs/<app>/app.sh sets target, process, launch, keys.

prefs_apps() { # app names under prefs/ (dirs with an app.sh)
    [ -d "$PREFS_DIR" ] || return 0
    find "$PREFS_DIR" -mindepth 2 -maxdepth 2 -name app.sh -type f -printf '%h\n' \
        | sed "s|^$PREFS_DIR/||" | sort
}

require_prefs_app() {
    [ -f "$PREFS_DIR/$1/app.sh" ] || die "no such prefs app: '$1' (existing: $(prefs_apps | tr '\n' ' '))"
}

# prefs_load <app>: sets target, process, launch + keys (arrays) from
# prefs/<app>/app.sh. launch is optional (no launch = no reopen after apply).
prefs_load() {
    target="" process="" launch=() keys=()
    # shellcheck source=/dev/null
    source "$PREFS_DIR/$1/app.sh"
    [ -n "$target" ] && [ -n "$process" ] && [ ${#keys[@]} -gt 0 ] \
        || die "prefs/$1/app.sh must set target, process and keys"
}

prefs_file() { echo "$PREFS_DIR/$1/prefs.json"; }

prefs_running() { pgrep -x "$process" >/dev/null 2>&1; }

# prefs_stop: graceful quit — SIGTERM to the main process (the oldest; its
# helper processes exit with it). Chromium handles it like a normal quit:
# session and Preferences are saved, nothing counts as a crash.
prefs_stop() {
    local pid i
    pid="$(pgrep -o -x "$process")" || return 0
    kill -TERM "$pid"
    for i in $(seq 30); do
        prefs_running || return 0
        sleep 0.5
    done
    die "$process still running 15s after asking it to quit — nothing changed"
}

prefs_start() {
    if [ ${#launch[@]} -eq 0 ]; then
        warn "no launch command in app.sh — start it yourself"
        return 0
    fi
    setsid -f "${launch[@]}" >/dev/null 2>&1 </dev/null
    success "reopened ${launch[0]}"
}

# prefs_closed <app> <ask> <command...>: run command while the app is closed.
# If it runs: ask first (ask=true; no terminal or gum → report, return 1),
# quit it, run the command in a subshell (so a die still reaches the reopen),
# reopen it. Returns the command's status.
prefs_closed() {
    local app="$1" ask="$2" rc=0
    shift 2
    if ! prefs_running; then
        "$@"
        return
    fi
    if $ask; then
        if ! [ -t 0 ] || ! command -v gum >/dev/null 2>&1; then
            warn "$app is running — close it, then 'dots prefs apply $app'"
            return 1
        fi
        gum_confirm "$app is running — close it, apply, and reopen it?" \
            || { warn "$app: skipped — later: close it, then 'dots prefs apply $app'"; return 1; }
    fi
    prefs_stop
    ( "$@" ) || rc=$?
    prefs_start
    return "$rc"
}

# prefs_extract <json file>: the listed keys only (dotted paths), sorted,
# pretty-printed — the format prefs.json is stored in. Missing keys are left out.
prefs_extract() {
    jq -S --args '. as $src | reduce ($ARGS.positional[] | split(".")) as $p ({};
        ($src | getpath($p)) as $v | if $v == null then . else setpath($p; $v) end)' \
        "${keys[@]}" < "$1"
}

# prefs_in_sync <app>: true if the live values equal the repo's (needs prefs_load).
# A missing prefs.json or live file counts as in sync — nothing to compare.
prefs_in_sync() {
    local repo_file
    repo_file="$(prefs_file "$1")"
    [ -f "$repo_file" ] && [ -f "$target" ] || return 0
    [ "$(prefs_extract "$target")" = "$(jq -S . "$repo_file")" ]
}

# prefs_merge3 <base> <ours> <theirs>: three-way merge of prefs fragments, per
# leaf (scalars and arrays of scalars, e.g. one command's shortcut list): a
# leaf changed on one side takes that side. Prints the merged JSON; leaves
# both sides changed differently are listed on stderr → exit 1. A missing
# base file counts as {}.
prefs_merge3() {
    local base="$1" result
    [ -s "$base" ] || base=<(echo '{}')
    result="$(jq -n --slurpfile b "$base" --slurpfile o "$2" --slurpfile t "$3" '
        def leaves: def r(p):
            if type == "object" and length > 0 then to_entries[] as $e | ($e.value | r(p + [$e.key]))
            elif type == "array" and any(.[]; type == "object" or type == "array")
                then to_entries[] as $e | ($e.value | r(p + [$e.key]))
            else p end; r([]);
        $b[0] as $b | $o[0] as $o | $t[0] as $t
        | [$b, $o, $t] | map([leaves]) | add | unique
        | reduce .[] as $p ({merged: {}, conflicts: []};
            ($b | getpath($p)) as $bv | ($o | getpath($p)) as $ov | ($t | getpath($p)) as $tv
            | if $ov == $tv or $tv == $bv then {v: $ov}
              elif $ov == $bv then {v: $tv}
              else {c: true} end as $r
            | if $r.c then .conflicts += [$p | map(tostring) | join(".")]
              elif $r.v == null then .
              else .merged |= setpath($p; $r.v) end)
    ')" || return 2
    jq -S .merged <<<"$result"
    jq -e '.conflicts == []' <<<"$result" >/dev/null && return 0
    jq -r '.conflicts[] | "  conflict: \(.)"' <<<"$result" >&2
    return 1
}

# prefs_merge_driver_register: git merge driver for prefs/*/prefs.json (the
# .gitattributes line is in the repo, the driver lives in .git/config).
# Idempotent; called by dots prefs and dots update.
prefs_merge_driver_register() {
    git -C "$DOTFILES_DIR" config merge.dots-prefs.name "dots prefs three-way JSON merge"
    git -C "$DOTFILES_DIR" config merge.dots-prefs.driver \
        "\"$DOTFILES_DIR/dots-cli/bin/dots\" prefs merge-driver %O %A %B"
}

# prefs_apply_live <app>: back up the live file, then replace each listed key with
# the repo's value (whole subtree — the repo owns that key). Keys missing from
# prefs.json stay untouched. Caller checks that the app isn't running.
prefs_apply_live() {
    local app="$1" repo_file dir tmp
    repo_file="$(prefs_file "$app")"
    [ -f "$repo_file" ] || die "prefs/$app/prefs.json missing — run 'dots prefs capture $app' on a configured machine"
    [ -f "$target" ] || die "$target missing — start $app once so it creates it"
    dir="$BACKUP_DIR/prefs-$app.$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$dir"
    cp -p "$target" "$dir/"
    tmp="$(mktemp "$target.dots.XXXXXX")"
    if ! jq -c --slurpfile repo "$repo_file" --args '. as $t
            | reduce ($ARGS.positional[] | split(".")) as $p ($t;
                ($repo[0] | getpath($p)) as $v | if $v == null then . else setpath($p; $v) end)' \
            "${keys[@]}" < "$target" > "$tmp"; then
        rm -f "$tmp"
        die "merging prefs/$app/prefs.json into $target failed — file untouched"
    fi
    mv "$tmp" "$target"
    success "applied prefs/$app → $target (backup: $dir)"
}

# --- git integration ---------------------------------------------------------
# Auto-commit for tracking changes (add/remove) + manual `dots commit` for
# configs. Commits from add/remove stage ONLY the touched category files, so
# unrelated in-progress config edits never get swept into them.

repo_push() { # best-effort push; never fails the calling command
    if ! git -C "$DOTFILES_DIR" push --quiet 2>/dev/null; then
        warn "not pushed (offline or no upstream?) — run 'git push' later"
    fi
}

repo_commit_paths() { # repo_commit_paths <message> <path>... — stage exactly the
                      # given paths, commit, push best-effort; silent no-op if
                      # nothing changed after staging
    local msg="$1"
    shift
    git -C "$DOTFILES_DIR" add -- "$@" || return 1
    git -C "$DOTFILES_DIR" diff --cached --quiet -- "$@" && return 0
    # commit only these paths — anything else already staged stays staged
    git -C "$DOTFILES_DIR" commit --quiet -m "$msg" -- "$@"
    success "committed: $msg"
    repo_push
}

# --- dispatch ----------------------------------------------------------------

main() {
    local cmd="${1:-help}"
    [ $# -gt 0 ] && shift

    case "$cmd" in
        install|setup|add|remove|list|stow|sync|update|prefs|theme|calendar|edit|git)
            # shellcheck source=/dev/null
            source "$LIB_DIR/$cmd.sh"
            "cmd_$cmd" "$@"
            ;;
        stow-add)
            # explicit mapping — unquoted cmd_stow-add would parse as
            # "cmd_stow minus add"
            source "$LIB_DIR/stow-add.sh"
            cmd_stow_add "$@"
            ;;
        stow-remove)
            source "$LIB_DIR/stow-remove.sh"
            cmd_stow_remove "$@"
            ;;
        help|-h|--help)
            usage
            ;;
        --subcommands)
            # for shell completion (e.g. zsh compdef) — one subcommand per line
            printf '%s\n' install setup add remove list stow stow-add stow-remove sync update prefs theme calendar edit git
            ;;
        *)
            usage >&2
            die "unknown command: '$cmd'"
            ;;
    esac
}