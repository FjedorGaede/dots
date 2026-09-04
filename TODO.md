# TODO — Dotfiles Rebuild

> **Status: TEMPORARY.** Lives only for the rebuild + migration phase. Replaced
> with final AGENTS.md/TODO.md once migration is done. See `AGENTS.md` + `design-doc.md`.

## Setup / Meta

- [x] Design document received and stored (`design-doc.md`)
- [x] AGENTS.md + TODO.md updated to reflect the design

## Phase 1 — Build

### Skeleton
- [x] Directory structure: `packages/<category>/`, `stow/`, `dots-cli/{bin,lib}`
- [ ] `bootstrap.sh` (deferred — needs the yay chicken-egg handling designed)

### dots CLI (`dots-cli/`) — built and dogfooded
- [x] `bin/dots` — entrypoint + dispatch; symlink-safe DOTFILES_DIR resolution
- [x] `lib/common.sh` — helpers: category/setup discovery, gum wrappers, leveled logging (`info`/`warn`/`success`/`die`)
- [x] `dots install [cat...] [--no-setup]` — packages then `setup/*/setup.sh`; `--noconfirm` flow-through
- [x] `dots add <pkg...> [--aur] [--category]` — install first, track second; searchable category menu + "+ new category"
- [x] `dots add --setup <name>` — scaffolds `packages/<cat>/setup/<name>/setup.sh`
- [x] `dots remove [cat pkg...] [--uninstall]` — explicit form + interactive picker across categories; AUR detection via `pacman -Qm`
- [x] `dots list [category]`
- [x] `dots stow [component...]` — menu, pre-selects linked, backs up conflicts, repo wins
- [x] `dots sync` — drift check both directions, print-only
- [x] `dots --subcommands` — shell completion support
- [x] `dots-cli/AGENTS.md` — CLI internals reference
- [x] gum 2.0 quirks handled: `--header` not `--prompt`, `x` toggles multi-select (documented in menu hints), `--selected` takes comma-separated value

### Dogfood: package transfer (DONE)
- [x] `core` — session-agnostic tools + ghostty + brightnessctl + yay (19 pkgs)
- [x] `hyprland` — full session stack + extras (13 pkgs)
- [x] `dev` — lazygit + bob
- [x] `tuxedo-extras` — tuxedo-control-center-bin (new category via CLI)
- [x] `packages/dev/setup/neovim/setup.sh` — bob: install stable+nightly, default nightly
- [x] Deliberately dropped: waybar (obsolete vs quickshell bar), astal, swayosd (custom OSD.qml), wlogout (PowerMenu.qml), mako, rofi, nm-connection-editor, vim, entr, just, ffmpeg/imagemagick/poppler/resvg/yazi/zoxide tracking
- [ ] Run the neovim setup once to verify (`dots install dev` or the script directly)
- [ ] Old custom scripts ported or dropped: tmux-sessionizer, wifi-menu, set-colors (wal), log, arch/yay install helpers

### Theming / post-install scripts (needed for migration)
- [x] DECIDED: stay on pywal16 (actively maintained fork; matugen/wallust considered and rejected for now — revisit only if generated palettes annoy; template conversion is easiest during this port)
- [ ] Port the old theming flow into setup scripts + configs:
  - [ ] `wal` flow: pywal16 colorscheme generation from wallpaper (old `set-colors` script)
  - [ ] Apply wal templates → hyprland, quickshell/waybar, swaync (drop swayosd + mako templates — those packages are dropped)
  - [ ] Colorschemes: keep old `wal/colorschemes/{dark,light}` or regenerate fresh
  - [ ] Wire theming into a category setup (e.g. `hyprland/setup/theme/setup.sh`) so `dots install` re-applies the theme
  - [ ] Decide trigger: re-run on wallpaper change (old behavior) or install-time only?

### Stow components (NEXT)
- [ ] Inventory old configs in `BACKUP_DO_NEVER_DELETE/` and define component grouping (proposal: hypr, quickshell, ghostty, yazi, tmux, shell, wal, misc)
- [ ] Port config content per component (chezmoi templates → plain files; wal templates updated for dropped swayosd)
- [ ] Port `.commonshellrc` with `DOTFILES_DIR` PATH export for `dots-cli/bin`
- [ ] Link components via `dots stow` on the live machine (real conflict/backup test)
- [ ] nvim config: external git repo (`github.com/FjedorGaede/neovim-config`) — clone as setup script or stow component
- [ ] Decide: zsh stays?, SSH keys for GitHub setup, automatic hostnames

### Bootstrap
- [ ] `bootstrap.sh` — ensure git/gum/stow (bare pacman), clone/pull `~/dots`, handle missing yay (makepkg build), `exec dots-cli/bin/dots install core hyprland`
- [ ] Test bootstrap on a fresh machine or container

### Open items from design doc (deferred)
- [ ] `dots sync --foreign` filter (1589 untracked is noisy)
- [ ] `dots remove --uninstall` orphan-dependency check (`pacman -Qtdq`)
- [ ] Multi-machine variation (stow per-host overrides vs templating)
- [ ] Font installation / `fc-cache` setup script

## Phase 2 — Migrate
- [ ] Back up current live dotfiles (`~/.dotfiles-backup/` flow via `dots stow`)
- [ ] Run `dots install` + `dots stow` on the live machine
- [ ] Verify: Hyprland session, quickshell bar, theming, shell, tmux, tools
- [ ] Retire old setup (remove `dots-old`, chezmoi leftovers); replace AGENTS.md + TODO.md with permanent versions
