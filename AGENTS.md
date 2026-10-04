# AGENTS.md — Dotfiles

> **Permanent.** This repo replaced the old chezmoi/Ansible setup in September
> 2026. The old system is preserved read-only in `BACKUP_DO_NEVER_DELETE/`
> (reference only — never modify or delete anything in it). The full design
> rationale lives in `design-doc.md`; CLI internals in `dots-cli/AGENTS.md`.

## What this repository is

Personal dotfiles for CachyOS + Hyprland, managed with **bash + GNU stow + gum**.
One repo, one CLI (`dots`), one-command bootstrap on a fresh machine.

**Core principles (from `design-doc.md`, do not violate):**
- **No DSL, no templating, no state files.** Bash, stow, gum only. The
  filesystem + pacman/stow queries are the source of truth. (Sole exception:
  the local `dots setup --ignore` list, see `dots-cli/AGENTS.md`.)
- **Repo always wins on conflict.** Existing machine files get backed up to
  `~/.dotfiles-backup/` and replaced by repo versions — never the reverse.
  `stow --adopt` is banned.
- **One command surface.** Everything goes through `dots`, not loose scripts.

## Structure

```
├── AGENTS.md            # this file
├── design-doc.md        # authoritative design + rejected approaches
├── bootstrap.sh         # curl-pipe-bash entrypoint for fresh machines
├── packages/<category>/ # one dir = one category
│   │   └── packages.txt # one package per line; aur: prefix → yay
│   └── install/<name>/install.sh   # optional idempotent install scripts
├── setup/<name>/setup.sh  # interactive per-machine steps (dots setup)
├── stow/<component>/    # one folder per stow package (the actual dotfiles)
├── dots-cli/            # the CLI tool (see dots-cli/AGENTS.md for internals)
└── BACKUP_DO_NEVER_DELETE/   # frozen remains of the old chezmoi setup
```

Stow components: **hypr, quickshell, ghostty, tmux, tools, wal, shell,
scripts, pi, nvim, herdr**. New components are created with `dots stow-add` — never
direct `stow --adopt`. Deliberately dropped (do not reintroduce): waybar, astal,
swayosd, wlogout, mako, rofi, nm-connection-editor, vim — the custom
quickshell shell replaces several of them.

## The `dots` CLI

On `$PATH` via shell rc. Flat verbs:

| Command | Purpose |
|---|---|
| `dots install [category...] [--packages-only] [--pick]` | Install categories (menu if none given) + run install scripts (`--pick`: choose packages + install scripts from one menu) |
| `dots install <category> --only <item,...>` | Non-interactive `--pick`: install only the named items (packages and/or install scripts) |
| `dots setup [name...]` | Interactive per-machine steps from `setup/` (git, ssh, github, dots-remote, calendar); no name = menu with ✔/✘/– status. `--status`: tab-separated for quickshell; `--ignore`/`--unignore <name>`: hide a step from the bar's setup indicator (wrench, shown while a step is open; click = popup, row = run in terminal) |
| `dots add <pkg...> [--aur] [--category <c>]` | Install + track (the day-to-day habit; replaces raw `pacman -S`) |
| `dots remove [<cat> <pkg>] [--uninstall]` | Untrack (and optionally uninstall) |
| `dots list [category]` | Print tracked packages (`--categories`: only category names; `<category> --items`: packages + install scripts, the names `--only` takes) |
| `dots stow [component...]` | Menu over stow components; conflicts backed up to `~/.dotfiles-backup/` |
| `dots stow-add [--all] [--dry-run] <name\|path> [path]` | Import a live config (default `~/.config/<name>`) as a new stow component: pick what to track in an fzf tree picker — whole dirs or single files at any depth (`x`/space toggle, `l` open dir, `h` back; state-ish entries unselected), nested .git vendored, then stow + auto-commit. On an existing component it **extends** it: tracked files are pre-selected (locked), only new picks are added. `--dry-run` (`-n`) only prints what would happen |
| `dots stow-remove [--yes] <component...>` | Detach: unstow, copy the repo's files back over the live paths, remove from repo + auto-commit. Never touches `~/.dotfiles-backup/` |
| `dots sync` | Drift check: installed-but-untracked packages (print-only) |
| `dots theme` | Apply theming scheme (default: dracula; `WAL_BIN=echo` for dry-run) |
| `dots calendar [client\|login\|logout\|list]` | Log Google accounts into the quickshell calendar (OAuth; client + tokens stay in `~/.local/share/quickshell/`, never in the repo). Thin wrapper around `stow/quickshell/.config/quickshell/scripts/gcal-sync.py` |
| `dots edit` | Open repo files in editor |
| `dots git` | lazygit in the repo — the only manual git door |

`add`/`remove` auto-commit + auto-push (surgically — only the touched
category file). Never hand-edit `packages/*/packages.txt` to bypass the CLI.

## Working rules

1. **Install scripts must be idempotent** — they re-run on every `dots install`.
2. **Packages only via `dots add`** — direct pacman/yay installs cause drift
   that only `dots sync` would catch.
3. **nvim is stowed like everything else** (`stow/nvim`). The old
   `neovim-config` repo is archived on GitHub (history only).
4. **Big changes** (new tools, new subcommands, structural changes beyond
   `design-doc.md`) must be proposed and approved before implementation.
5. **Commit only when the user confirms** changes were tested and work.
6. This agent has no TTY — `sudo`-requiring steps (`dots add`/`install`) are
   run by the user interactively.
7. gum 2.0 quirks: `choose` uses `--header` (not `--prompt`); `x` toggles in
   multi-select (space does not); `--selected` takes a comma-separated value.

## Bootstrap

`bash <(curl -fsSL .../bootstrap.sh)` (fish, CachyOS's default shell:
`bash (curl -fsSL .../bootstrap.sh | psub)`) — sanity check + sudo keepalive →
pacman base tools (git/gum/stow) → clone → **all questions up front** (git
name/email, which optional categories, which items of each — core + hyprland
are always installed) → `dots setup git` + `dots setup ssh` → unattended:
`dots install core hyprland`, `dots install <cat> --only <items>` per pick →
stow all → dracula theme → `sudo chsh` to zsh. Bootstrap only *uses* the CLI
(`list --categories`, `list --items`, `install --only`) — no CLI behavior
exists just for it. github, dots-remote and calendar stay for later
(`dots setup`). Fresh machines get dracula automatically; afterwards
`dots theme` is run manually.

## Roadmap / open ideas

- `dots sync --foreign` filter (system-wide untracked list is noisy)
- `dots remove --uninstall` orphan-dependency check (`pacman -Qtdq`)
- Multi-machine variation (per-host stow overrides vs templating —
  prefer stow mechanisms before ever reaching for templating)