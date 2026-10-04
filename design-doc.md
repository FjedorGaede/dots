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
dots/
├── AGENTS.md                 # repo-level reference for agents/future-you
├── bootstrap.sh                # curl-pipe-bash entrypoint
├── packages/                   # one directory = one category (scanned, no registry)
│   ├── core/
│   │   ├── packages.txt        # one package per line; aur: prefix → yay
│   │   └── install/            # optional install scripts
│   │       └── <name>/install.sh # plain bash, must be idempotent
│   ├── hyprland/
│   │   ├── packages.txt
│   │   └── install/ly/install.sh
│   ├── dev/
│   │   └── packages.txt
│   └── gaming/
│       └── packages.txt        # add a category by adding a dir — nothing else to register
├── setup/                      # interactive per-machine steps (dots setup)
│   ├── git/setup.sh            # global user.name/user.email
│   ├── ssh/setup.sh            # ~/.ssh/id_ed25519 (no passphrase)
│   ├── github/setup.sh         # gh login + upload the ssh key
│   ├── dots-remote/setup.sh    # ~/dots origin https → ssh
│   └── calendar/setup.sh
├── stow/                       # one folder per stow "package"
│   ├── hypr/.config/hypr/...
│   ├── quickshell/.config/quickshell/...
│   ├── shell/.bashrc, .zshrc, ...
│   └── ...
└── dots-cli/                   # the CLI tool, its own module
    ├── AGENTS.md                # CLI-internals reference
    ├── bin/
    │   └── dots                 # entrypoint, dispatches to lib/<cmd>.sh
    └── lib/
        ├── common.sh             # shared helpers (category discovery, gum wrappers)
        └── <cmd>.sh              # one file per command (install, setup, add, remove,
                                  #   list, stow, stow-add, stow-remove, sync, theme,
                                  #   calendar, edit, git) — see dots-cli/AGENTS.md
```

## Packages: categories

Each directory under `packages/` is a category — discovered automatically by
scanning the directory, no separate registry. `packages.txt` holds one
package per line; `aur:` prefix marks an AUR package, routed to `yay` instead
of `pacman`.

```
# packages/hyprland/packages.txt
hyprland
quickshell
ly
aur:walker
aur:elephant
```

Category design principle: a package belongs to the category that answers
"would every machine running this repo want this?" — the session stack is
category-scoped (`hyprland`), not core, so non-Hyprland sessions stay possible.
Core holds session-agnostic tools only.

### Install scripts

Optional `packages/<category>/install/<name>/install.sh` files run after the
category's packages are installed (`dots install <category>`). They are plain
bash, must be idempotent (they re-run on every install), and handle everything
that isn't a pacman/yay package: systemd enables, `fc-cache`, wal template
regen, driver post-install steps, tools with their own installer (claude, pi).
`dots add --script <name> [--category <cat>]` scaffolds a new one.
`dots install --packages-only` skips them; `--pick` chooses packages and
scripts from one menu (a package and a script with the same name are one
entry, package first).

### Setup steps

`setup/<name>/setup.sh` holds per-machine steps that need a human — logins,
secrets — and so are not part of `dots install` (e.g. the calendar's Google
login). `dots setup` shows a menu with each step's status; contract:
`setup.sh status` prints one line, exit 0 = done; no argument = run it.
Steps run their prerequisite when it's missing (dots-remote → github → ssh
→ git). git and ssh are part of bootstrap; github, dots-remote and calendar
are left for later. The quickshell bar shows a wrench while a step is open
(`dots setup --status`, polled only while something is open); a step can
be ignored (`dots setup --ignore`, the CLI's one local state file).

## The `dots` CLI

Lives in `dots-cli/`, added to `$PATH` via `.commonshellrc`
(`export PATH="$DOTFILES_DIR/dots-cli/bin:$PATH"`). Not stowed itself — a
tool, not a dotfile.

| Command | Behavior |
|---|---|
| `dots install [category...] [--packages-only] [--pick]` | Installs packages from given categories (all, via a menu, if none given), then runs the categories' install scripts |
| `dots install <category> --only <item,...>` | Non-interactive twin of `--pick`: installs only the named packages/install scripts of one category; unknown names abort |
| `dots setup [name...]` | Runs interactive per-machine steps from `setup/` (no name = menu with ✔/✘ status) |
| `dots add <pkg...> [--aur] [--category <name>]` | Installs the package(s) in one call, then tracks them. No `--category` → prompts via `gum choose` (existing categories + "+ new category") |
| `dots add --script <name> [--category <name>]` | Scaffolds `packages/<cat>/install/<name>/install.sh` |
| `dots remove [<category> <pkg>] [--uninstall]` | Untracks from the category file. Add `--uninstall` to also remove from the system (with confirm). No arguments → searchable picker over all tracked packages |
| `dots list [category]` | Prints tracked packages, optionally scoped to one category. `--categories`: category names only; `<category> --items`: packages + install scripts (the names `--only` takes) |
| `dots stow [component...]` | Menu over `stow/*`, pre-selecting already-linked components (via `stow -n` dry-run, not a state file); force-applies with backup on conflict |
| `dots stow-add [--all] [--dry-run] <name\|path> [path]` | Import a live config dir (default `~/.config/<name>`; a bare path also works — name = basename) into `stow/<name>/` as a new component: **whitelist selection** in an fzf tree picker — toggle a dir to track it whole (`x`/space) or open it (`l`, back with `h`) to pick single files/subdirs at any depth (state-ish ones unselected; `--all` = everything except sockets), on an existing component it extends it (tracked files pre-selected + locked, only new files copied), nested `.git` dirs vendored, then backup-on-conflict stow + surgical auto-commit (`--dry-run`/`-n`: picker + report, nothing written). The import-side twin of `dots stow` |
| `dots stow-remove [--yes] <component...>` | Detach: unstow, copy every tracked file back to its live path (replacing the symlinks — machine content == repo content, no backup involved), `rm -rf stow/<comp>`, auto-commit |
| `dots sync` | Drift check — installed-but-untracked packages, printed only, never auto-modified |
| `dots calendar [client\|login\|logout\|list]` | Connects Google Calendar to the quickshell calendar (no command = gum menu). Thin surface like `dots theme`: logic lives in the quickshell component's `scripts/gcal-sync.py`. The OAuth client JSON and tokens are secrets → `~/.local/share/quickshell/`, never in the repo; a new machine re-runs `client` + `login` (`dots setup calendar` does both) |

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
bash <(curl -fsSL https://raw.githubusercontent.com/FjedorGaede/dots/main/bootstrap.sh)
```

(Not `curl ... | bash`: the script is interactive — sudo and gum need the
terminal on stdin. `DOTFILES_BRANCH=<branch>` clones another branch.)

`bootstrap.sh` stays thin — all real logic lives in `dots-cli/`:

1. Sanity checks (interactive TTY, Arch/CachyOS, not root), `sudo -v` plus a
   background keepalive so long AUR builds never stop at a sudo prompt
2. `pacman -Syu`, then bare `pacman` for `git gum stow base-devel`
   (chicken/egg — `dots` lives inside the repo being cloned)
3. Clone `~/dots` (or `git pull --ff-only` if it already exists)
4. **All questions up front**: git name + email; which optional categories
   to choose from (`dots list --categories` minus the always-installed
   `core` + `hyprland`); per chosen category, which items
   (`dots list <cat> --items`, nothing pre-selected)
5. `dots setup git` (answers passed via `GIT_NAME`/`GIT_EMAIL`) and
   `dots setup ssh` — no prompts; from here on it runs unattended
6. `dots install core hyprland` (core first — its yay install script
   provisions the AUR helper), then `dots install <cat> --only <items>`
7. `dots stow all`
8. First run: dracula theme via `dots theme` (only when wal is installed),
   `sudo chsh` to zsh

Bootstrap only consumes the CLI; it never gets CLI behavior of its own. The
remaining `dots setup` steps (github, dots-remote, calendar) need a browser
or more and are deliberately left for later.

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
