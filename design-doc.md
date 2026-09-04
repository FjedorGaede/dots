# CachyOS + Hyprland Dotfiles — Design Document

## Goal

A single repo, bootstrappable with one command on a fresh machine, that
reproducibly sets up packages and configs. Package installation is
organized into categories (not just "core" and "aur"), managed through a
small CLI tool (`dots`) rather than loose scripts.

## Design principles

- **No new DSL.** Bash, stow, and gum. No templating language, no YAML/JSON
  config format to relearn after time away.
- **Filesystem is the source of truth.** No state file tracking "what was
  previously selected/installed" — the tool queries pacman and stow
  directly every time. Nothing to drift out of sync.
- **One command to bootstrap.** `bash <(curl ... bootstrap.sh)` on a fresh
  machine takes it from nothing to fully set up.
- **Categories, not one flat list.** Packages are grouped by purpose
  (`core`, `hyprland`, `dev`, `gaming`, ...) so you can install subsets —
  a work laptop doesn't need the gaming category, for instance.
- **Repo wins on conflict.** Existing real files on a machine get backed
  up and replaced by the repo's version, never the other way around.
- **A real CLI, not scattered scripts.** `dots` is the single entrypoint
  for installing, adding, removing, and syncing packages, and for
  applying configs — so there's one command surface to remember instead
  of a folder of one-off `.sh` files.

## Directory structure

```
dotfiles/
├── AGENTS.md                 # repo-level reference for agents/future-you
├── bootstrap.sh                # curl-pipe-bash entrypoint
├── packages/                   # one directory = one category (scanned, no registry)
│   ├── core/
│   │   ├── packages.txt        # one package per line; aur: prefix → yay
│   │   └── setup/              # optional post-install hooks
│   │       └── <name>/setup.sh # plain bash, must be idempotent
│   ├── hyprland/
│   │   └── packages.txt
│   ├── dev/
│   │   └── packages.txt
│   └── gaming/
│       └── packages.txt        # add a category by adding a dir — nothing else to register
├── stow/                       # one folder per stow "package"
│   ├── hypr/.config/hypr/...
│   ├── waybar/.config/waybar/...
│   ├── shell/.bashrc, .zshrc, ...
│   └── ...
└── dots-cli/                   # the CLI tool, its own module
    ├── AGENTS.md                # CLI-internals reference
    ├── bin/
    │   └── dots                 # entrypoint, dispatches to lib/<cmd>.sh
    └── lib/
        ├── common.sh             # shared helpers (category discovery, gum wrappers)
        ├── add.sh
        ├── install.sh
        ├── remove.sh
        ├── list.sh
        ├── stow.sh
        └── sync.sh
```

## Packages: categories

Each directory under `packages/` is a category — discovered automatically by
scanning the directory, no separate registry. `packages.txt` holds one
package per line; `aur:` prefix marks an AUR package, routed to `yay` instead
of `pacman`.

```
# packages/hyprland/packages.txt
hyprland
waybar
mako
aur:swayosd
aur:hyprpicker-git
```

### Setup scripts

Optional `packages/<category>/setup/<name>/setup.sh` files run after the
category's packages are installed (`dots install <category>`). They are plain
bash, must be idempotent (they re-run on every install), and handle everything
that isn't a package: systemd user enables, `fc-cache`, wal template regen,
driver post-install steps. `dots add --setup <name> [--category <cat>]`
scaffolds a new one. `dots install --no-setup` skips them.

Category design principle: a package belongs to the category that answers
"would every machine running this repo want this?" — the session stack is
category-scoped (`hyprland`), not core, so non-Hyprland sessions stay possible.
Core holds session-agnostic tools only.

## The `dots` CLI

Lives in `dots-cli/`, added to `$PATH` via `.commonshellrc`
(`export PATH="$DOTFILES_DIR/dots-cli/bin:$PATH"`). Not stowed itself — a
tool, not a dotfile.

| Command | Behavior |
|---|---|
| `dots install [category...] [--no-setup]` | Installs packages from given categories (all, via a menu, if none given), then runs the categories' setup scripts |
| `dots add <pkg...> [--aur] [--category <name>]` | Installs the package(s) in one call, then tracks them. No `--category` → prompts via `gum choose` (existing categories + "+ new category") |
| `dots add --setup <name> [--category <name>]` | Scaffolds `packages/<cat>/setup/<name>/setup.sh` |
| `dots remove [<category> <pkg>] [--uninstall]` | Untracks from the category file. Add `--uninstall` to also remove from the system (with confirm). No arguments → searchable picker over all tracked packages |
| `dots list [category]` | Prints tracked packages, optionally scoped to one category |
| `dots stow [component...]` | Menu over `stow/*`, pre-selecting already-linked components (via `stow -n` dry-run, not a state file); force-applies with backup on conflict |
| `dots sync` | Drift check — installed-but-untracked packages, printed only, never auto-modified |

### `dots add` — the day-to-day habit

Replaces typing `sudo pacman -S <pkg>` directly. One batch, one flag set:

```bash
dots add hyprpicker --aur --category hyprland   # explicit
dots add neovim ripgrep fd                       # no category -> prompts
```

Installs first, tracks second — so a failed install never gets falsely
recorded as tracked.

## `dots stow` — conflict handling

On first run, real (non-symlinked) files that already exist on the
machine are moved to `~/.dotfiles-backup/<name>.<timestamp>`, then the
repo's version is symlinked in. This is deliberate — the repo's version
always wins over whatever happens to already be on a fresh machine.
`stow --adopt` is explicitly not used here, since it overwrites the repo
with the machine's state instead of the other way around.

## Bootstrap flow (fresh machine, one command)

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/<you>/dotfiles/main/bootstrap.sh)
```

`bootstrap.sh` stays intentionally minimal — all real logic lives in the
repo (specifically `dots-cli/`), not duplicated into the bootstrap script:

1. Bare `pacman` calls to ensure `git`, `gum`, `stow` exist (chicken/egg —
   `dots` itself lives inside the repo being cloned, so can't be used yet)
2. Clone `~/dotfiles` (or `git pull --ff-only` if it already exists)
3. Hand off: `exec dots-cli/bin/dots install`

If the one-liner ever breaks, the fallback is always manual: clone the
repo, run `dots-cli/bin/dots install` directly.

## AGENTS.md files

Two live in the repo, at different scope:
- **`AGENTS.md`** (root) — how the whole repo works: structure, categories,
  the `dots` subcommand table, bootstrap flow, rejected alternatives.
- **`dots-cli/AGENTS.md`** — CLI internals: dispatch mechanism, the
  argument-parsing convention every subcommand follows, checklist for
  adding a new subcommand.

Both are meant to be read by an agent (or future-you) before making
changes — they're the living reference this design doc summarizes.

## Explicitly rejected approaches (and why)

| Approach | Why not |
|---|---|
| Whiptail/dialog TUI | Functional but visually dated; gum gives the same interaction model, looks better, no added complexity |
| JSON/YAML state file tracking selections | Second source of truth that can drift from actual system state; querying pacman/stow directly achieves the same "remember previous choices" UX with nothing to keep in sync |
| chezmoi | Templating DSL has a real relearning cost after time away; this setup has no per-host variation that would need it |
| Ansible (previous setup) | Only ever tracked one flat package list in practice — no real orchestration was happening. Category files + pacman/yay achieve the same result more simply |
| `stow --adopt` for conflicts | Overwrites the repo's version with the machine's — backwards from the desired "repo always wins" behavior |
| Loose one-off `.sh` scripts per task | Scattered command surface, easy to forget what exists; consolidated into the `dots` CLI with discoverable subcommands instead |
| Nix / home-manager | True reproducibility, but a real learning curve and awkward to run alongside pacman-based CachyOS; revisit only if config drift becomes a genuine recurring problem |

## Open items / future extensions

- `dots remove --uninstall` confirm-flow details (exact wording, whether
  it also checks for orphaned dependencies via `pacman -Qtdq`)
- Multi-machine variation (e.g. laptop vs. desktop monitor configs) —
  investigate stow's per-host override mechanisms before reaching for
  templating
- Font installation / `fc-cache` as a pseudo-category or a `dots` post-install step
