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

### Git integration (requested)
- [ ] Easy git commit flow in the CLI: whenever the user adds/removes packages (`dots add`/`dots remove`) or changes configs (stow components, setup scripts), there should be a simple way to commit those changes on the machine — e.g. a `dots commit` command (stage + commit with a sensible generated message) and/or an optional auto-commit prompt at the end of mutating commands
- [x] gum 2.0 quirks handled: `--header` not `--prompt`, `x` toggles multi-select (documented in menu hints), `--selected` takes comma-separated value

### Dogfood: package transfer (DONE)
- [x] `core` — session-agnostic tools + ghostty + brightnessctl + yay (19 pkgs)
- [x] `hyprland` — full session stack + extras (13 pkgs)
- [x] `dev` — lazygit + bob
- [x] `tuxedo-extras` — tuxedo-control-center-bin (new category via CLI)
- [x] `packages/dev/setup/neovim/setup.sh` — bob: install stable+nightly, default nightly
- [x] Deliberately dropped: waybar (obsolete vs quickshell bar), astal, swayosd (custom OSD.qml), wlogout (PowerMenu.qml), mako, rofi, nm-connection-editor, vim, entr, just, ffmpeg/imagemagick/poppler/resvg/yazi/zoxide tracking
- [ ] Run the neovim setup once to verify (`dots install dev` or the script directly)
- [x] Old custom scripts: decided + ported (see Stow components section — fkill/my-repos/pi-quick-toggle ported, rest dropped, set-colors → theming)

### Theming / post-install scripts (needed for migration)
- [x] DECIDED: stay on pywal16 (actively maintained fork; matugen/wallust considered and rejected for now — revisit only if generated palettes annoy; template conversion is easiest during this port)
- [x] DECIDED: wal/colorschemes/{dark,light} are EMPTY — only pywal16 built-in themes are used; nothing to migrate there
- [x] `dots theme [-l] [name]` CLI command — pywal16 picker + adapter architecture.
      Ownership: dots-cli/theming/apply-theme.sh is THE engine (wal + adapters +
      notify); lib/theme.sh is the thin CLI (flags + picker); other callers (e.g.
      future theming setup script) call apply-theme.sh directly. Adapters:
      dots-cli/theming/adapters/*.sh (executable = enabled, $1 = theme name);
      hyprland.sh + quickshell.sh ship — hyprctl reload; qs kill + qs -d (qs CLI
      has no reload subcommand, restart is the catch-all). Docs: dots-cli/theming/README.md + "Theming" section in
      dots-cli/AGENTS.md. WAL_BIN=echo = safe dry-run. transfer-packages.sh removed.
- [x] Pruned dead wal templates (waybar/mako/swaync/swayosd) — only
      colors-hyprland.conf remains in stow/wal
- [ ] Port the old theming flow into setup scripts + configs (USER IS RETHINKING
      THEMING — coordinate before building):
  - [ ] `wal` flow: pywal16 colorscheme generation from wallpaper (old `set-colors` script — reviewed: works but /bin/sh+bashism accident, swayosd block dead, no cancel guard; superseded by `dots theme`)
  - [ ] Apply wal templates → hyprland (quickshell needs no template, reads cache live)
  - [ ] Wire theming into a category setup (e.g. `hyprland/setup/theme/setup.sh`) so `dots install` re-applies the theme
  - [ ] Decide trigger: re-run on wallpaper change (old behavior) or install-time only?

### Stow components (NEXT)
- [x] Step 0 drift check (read-only): live system is NEWER than the repo backup
      (zshrc/bashrc bun+angular lines, hypr autostart/keybinds swaync, lazygit
      pagers fix, most of quickshell rewritten live). Port content from the live
      machine / `~/.local/share/chezmoi`, NOT from the stale backup. `chezmoi
      apply` would delete 4 live quickshell QMLs + revert drift — do not run it;
      retire chezmoi at end of migration. swaync is actively used (in, unlike
      mako/swayosd). All relevant files are chezmoi-managed.
- [x] Component grouping (final: hypr, quickshell, ghostty, tmux, tools
      (lsd/lazygit/walker), wal, shell (bash/zsh/commonshellrc/ideavimrc),
      scripts (fkill, my-repos, pi-quick-toggle), pi (agent config: AGENTS.md,
      settings.json, keybindings.json, skills/, prompts/, themes/, extensions/;
      NOT custom-harness (dropped), NOT auth/trust/sessions/state — secrets and
      machine-local. skills/brave-search/node_modules gitignored (npm ci on
      fresh clones); stow leaves live node_modules in place, verified in sandbox))
- [x] DECIDED: yazi and swaync dropped (not needed anymore); old scripts dropped:
      arch_install, yay_install, divider, wifi-menu, log, tmux-sessionizer;
      set-colors folds into the theming/wal setup script; fkill, my-repos,
      pi-quick-toggle ported into the `scripts` component
- [x] Port config content per component — DONE (ported from the LIVE machine,
      which is newer than backup per step 0; all files already rendered, no
      template stripping needed). Notes: tmux ships only tmux.conf (plugins/ =
      tpm runtime), wal = templates+colorschemes only (no cache), wallpapers
      (4.6M, 1 img) included in hypr, quickshell kept 1:1 incl.
      .claude/settings.local.json + .qmlls.ini, walker config added to tools.
      Scripts stowed as .local/bin/custom-commands/ so the Ctrl+P shell palette
      keeps finding them; the drifted chezmoi copy of `dots` there is NOT ported
      (CLI lives in repo, reached via PATH).
- [x] Port `.commonshellrc` with `DOTFILES_DIR` PATH export for `dots-cli/bin`
      (also removed from repo copy: yazi shell function, tmux-sessionizer/
      tmux-reattach/`~/.local/scripts` PATH lines — all dropped tools)
- [x] Sandbox stow test: all 8 components link clean into /tmp/fakehome, zero
      conflicts (fake home discarded)
- [ ] Re-sync stow components before ANY live linking — user actively edits live
      configs. 2026-09-05 second sync: quickshell gained MediaPlayer.qml (new
      media widget) + Theme.qml FIX (StandardPaths.homeLocation is undefined in
      QML → wal FileView never worked; now Quickshell.env("HOME"), .text is a
      function, theme layering: catppuccin → pywal colors.json →
      theme/overrides.json, accent exported to ~/.cache/quickshell-theme/
      hyprlock.conf), toast sizes bumped, hyprlock.conf sources the exported
      accent. NOTE: repo copy of Theme.qml was the BROKEN version — stowing
      before re-sync would have broken the theme.
- [x] Full fake-home rehearsal PASSED (HOME=/tmp/fakehome + copies of live
      files → `dots stow` all 8 components, exit 0): per-file symlinks into
      existing real dirs, conflicts backed up, live-only files (tmux plugins/)
      untouched. Caught + fixed: quickshell/.qmlls.ini was an absolute symlink
      to /run (qmlls runtime artifact) — removed from repo, stow refuses those.
- [ ] Link components via `dots stow` on the live machine (Phase 2,
      component-by-component, chezmoi NOT touched meanwhile)
- [ ] nvim config: external git repo (`github.com/FjedorGaede/neovim-config`) — clone as setup script or stow component
- [x] Decide: zsh stays as default shell — USER ACTION: `dots add zsh --category core` (zsh was never tracked)
- [ ] SSH keys for GitHub setup, automatic hostnames

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
