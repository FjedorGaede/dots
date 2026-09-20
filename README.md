# dots

Personal dotfiles: bash + GNU stow + gum. Everything on the machine is managed
from this repo — packages, configs, theming, and the CLI that ties it together.

## The CLI

```
Machine setup (rare):     dots install · dots stow · dots list · dots sync
Packages (auto-commit):   dots add · dots remove
Components:               dots stow · dots stow-add · dots stow-remove
Daily:                    dots edit · dots theme
Git:                      dots git   (lazygit — pull = p, push = Shift+P)
```

- `dots install [category...]` — install packages, run `packages/<cat>/setup/*/setup.sh`
- `dots stow [component...]` — link configs into $HOME (conflicts are backed up to `~/.dotfiles-backup/`)
- `dots stow-add [--all] <name|path> [path]` — import a live config (default `~/.config/<name>`)
  as a new stow component: pick what to track from a list, nested .git is vendored;
  stows + commits + pushes
- `dots stow-remove [--yes] <component...>` — detach a component (unstow, copy
  repo content back over the live symlinks, remove from repo)
- `dots edit [component]` — open $EDITOR in the stow tree (descends into the real config folder)
- `dots theme [name]` — apply a pywal16 colorscheme (dracula by default; accent via quickshell overrides)

New machine: run `bootstrap.sh` (see below), then this README's checklist.

## Layout

```
packages/<category>/packages.txt   one package per line, aur: prefix → yay
packages/<category>/setup/         idempotent post-install hooks (yay, neovim, nvim-config)
stow/<component>/                  one stow package per config area
dots-cli/                          the CLI (see dots-cli/AGENTS.md for internals)
dots-cli/theming/                  theme engine + per-app adapters
```

## Fresh machine after bootstrap

bootstrap.sh covers packages, configs and the first theme. Manual follow-ups:

1. **SSH key for GitHub**: `ssh-keygen -t ed25519` → add at github.com/settings/keys
2. **Switch the dots remote to SSH** (push access):
   `git -C ~/dots remote set-url origin git@github.com:FjedorGaede/dots.git`
3. `gh auth login` (for `my-repos` and GitHub CLI usage)
4. brave-search skill deps: `cd ~/.config/pi/agent/skills/brave-search && npm ci`
5. hostname: `sudo hostnamectl set-hostname <name>`

That's it — no special cases. Every config (including neovim) lives in `stow/`,
is edited via `dots edit` and committed via `dots git`.
