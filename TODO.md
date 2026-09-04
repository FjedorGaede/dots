# TODO — Dotfiles Rebuild

> **Status: TEMPORARY.** Lives only for the rebuild + migration phase. Replaced
> with final AGENTS.md/TODO.md once migration is done. See `AGENTS.md` + `design-doc.md`.

## Setup / Meta

- [x] Design document received and stored (`design-doc.md`)
- [x] AGENTS.md + TODO.md updated to reflect the design

## Phase 1 — Build

### Skeleton
- [ ] Create directory structure: `packages/`, `stow/`, `dots-cli/{bin,lib}`, `bootstrap.sh`

### Skeleton (structure only — no files with content yet)
- [x] Create directory structure: `packages/`, `stow/`, `dots-cli/{bin,lib}`
- [ ] `bootstrap.sh`

### dots CLI (`dots-cli/`) — build BEFORE repo content, to dogfood it
- [x] `bin/dots` — entrypoint + dispatch to `lib/<cmd>.sh`
- [x] `lib/common.sh` — shared helpers (category discovery, gum wrappers)
- [x] `dots install [category...]` — all/menu when no category given
- [x] `dots add <pkg...> [--aur] [--category <name>]` — install first, track second; category prompt via gum (incl. "+ new category")
- [x] `dots remove <category> <pkg>` — untrack; `--uninstall` w/ confirm (open item: orphan check via `pacman -Qtdq`?)
- [x] `dots list [category]`
- [x] `dots stow [component...]` — menu, pre-selection via `stow -n` dry-run, backup-on-conflict (repo wins, NO `--adopt`)
- [x] `dots sync` — drift check, print-only
- [x] `dots-cli/AGENTS.md` — CLI internals reference (dispatch, arg-parsing convention, subcommand checklist)
- [ ] Interactive gum paths (install menu, add category prompt, stow menu, remove --uninstall confirm) still need a real-TTY test run
- [ ] Run shellcheck once available (`sudo pacman -S shellcheck`)

### Dogfood: use the CLI to build up the repository
- [ ] Package category files: create `core.txt`, `hyprland.txt`, `dev.txt`, `gaming.txt` **via `dots add`** — never hand-write lists (old lists live in `BACKUP_DO_NEVER_DELETE/ansible/roles/base/vars/main.yml` as reference)
- [ ] Stow components: port configs from old setup into `stow/` (hypr, waybar, shell, tmux, ghostty, yazi, wal, quickshell, …) and **link via `dots stow`** — exercises menu, pre-selection, conflict handling
- [ ] Verify with `dots list` / `dots sync` that tracked state matches reality
- [ ] `.commonshellrc` / PATH wiring for `dots-cli/bin`
- [ ] Decide fate of old-TODO questions not covered by design doc: zsh?, SSH keys for GitHub?, automatic hostnames?

### Bootstrap
- [ ] `bootstrap.sh` — ensure git/gum/stow (bare pacman), clone/pull `~/dotfiles`, `exec dots-cli/bin/dots install`
- [ ] Test bootstrap on a fresh machine or container

### Open items from design doc (defer, revisit later)
- [ ] `dots remove --uninstall` confirm-flow details
- [ ] Multi-machine variation (stow per-host overrides vs. templating)
- [ ] Font installation / `fc-cache` step

## Phase 2 — Migrate
- [ ] Back up current live dotfiles (`~/.dotfiles-backup/` flow)
- [ ] Run `dots install` + `dots stow` on the live machine
- [ ] Verify: Hyprland session, waybar, theming, shell, tmux, tools
- [ ] Retire old setup; replace AGENTS.md + TODO.md with permanent versions
