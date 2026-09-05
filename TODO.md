# TODO — Dotfiles Rebuild

> **Status: TEMPORARY.** Lives only for the rebuild + migration phase. Replaced
> with final AGENTS.md/TODO.md once migration is done. See `AGENTS.md` + `design-doc.md`.

## Phase 1 — Build

### Done (details in git history + dots-cli/AGENTS.md)
- [x] dots CLI: install/add/remove/list/stow/sync/theme/edit/git — all built,
      dogfooded, documented in dots-cli/AGENTS.md (9 flat verbs, grouped usage)
- [x] Git integration: add/remove auto-commit + auto-push (surgical — only the
      touched category file); `dots git` = lazygit as the only manual git door
- [x] Theming engine: dots-cli/theming/apply-theme.sh + adapters
      (hyprland.sh, quickshell.sh); WAL_BIN=echo dry-run; dead templates pruned
- [x] Stow port: all 9 components (hypr, quickshell, ghostty, tmux, tools, wal,
      shell, scripts, pi) ported from live machine, sandbox-tested, fake-home
      rehearsal passed
- [x] Packages tracked: core (incl. zsh), hyprland, dev, tuxedo-extras;
      neovim setup script (bob); yay setup script (core/setup/yay)
- [x] LIVE MIGRATION DONE 2026-09-05: all 9 components stowed, every replaced
      file in ~/.dotfiles-backup/, chezmoi PURGED. System runs from the repo.
- [x] bootstrap.sh written + pushed: sanity → pacman base tools → clone → gum
      category picker (core+hyprland pre-selected) → dots install (yay setup
      builds from AUR when missing) → stow all → first-run (dracula + chsh zsh)

### Open — Phase 1
- [ ] Test bootstrap in an Arch container (`~/test-bootstrap.sh`) — BLOCKED:
      user must reboot first (running kernel 7.1.3 is outdated, its modules
      were deleted; docker can't start until then)
- [ ] Run `dots install dev` once to verify the neovim/bob setup script
      (needs sudo password → user runs it)
- [x] Post-bootstrap manual checklist documented in README.md (SSH keys, remote
      switch, gh auth, brave-search npm ci, hostname) — including a loud
      "the one exception" section for the neovim config (user chose Option 2:
      nvim stays its own repo; known and accepted cost = one special case to
      remember, documented instead of hidden)
- [x] Theming install-time wiring — DECIDED: none for now. Fresh machines get
      dracula via bootstrap; afterwards `dots theme` is run manually when
      wanted. Wallpaper-following colors: user will build it themselves if the
      need arises (design stays: fixed scheme + accent from overrides.json).
- [x] nvim config — DECIDED: stays its own repo (NOT stowed — stowing would
      merge its history into dots and break pushing to neovim-config).
      Distributed via packages/dev/setup/nvim-config/setup.sh: HTTPS clone on
      fresh machines (public repo), ff-only pull when present, SSH-remote hint.
      Live ~/.config/nvim is already the clone, in sync with origin.
- [ ] Fonts: does the setup need a font install/fc-cache script? (ASK)

### Deferred (design doc open items)
- [ ] `dots sync --foreign` filter (1589 untracked is noisy)
- [ ] `dots remove --uninstall` orphan-dependency check (`pacman -Qtdq`)
- [ ] Multi-machine variation (stow per-host overrides vs templating)

## Phase 2 — Migrate (mostly done)
- [x] Live dotfiles backed up via `dots stow` conflict flow (~/.dotfiles-backup/)
- [x] `dots install` + `dots stow` on the live machine — done, all 9 components
- [ ] Verify after reboot: Hyprland session, quickshell bar, theming, shell,
      tmux, tools, Ctrl+P palette, `dots theme`
- [ ] Retire leftovers: `dots-old` copy in ~/.local/bin/custom-commands/,
      ~/.config/__BACKUP__hypr, ~/.config/__OLD__nvim, ~/.local/scripts
- [ ] GitHub housekeeping: make `refactor/rework-system` the `main` branch
- [ ] Replace AGENTS.md + TODO.md with permanent versions; delete the backup
      older-than-needed ~/.dotfiles-backup entries
