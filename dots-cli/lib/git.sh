# git.sh — `dots git`: open lazygit in the dotfiles repo.
# Manual commits belong in a real TUI (staging, messages, push — lazygit does
# it all: pull = p, push = Shift+P). The *automatic* part lives in add/remove
# via repo_commit_paths (common.sh): tracking changes commit themselves
# surgically and push.

cmd_git() {
    command -v lazygit >/dev/null 2>&1 || die "lazygit not found (sudo pacman -S lazygit)"
    info "opening lazygit in $DOTFILES_DIR"
    lazygit -p "$DOTFILES_DIR"
}
