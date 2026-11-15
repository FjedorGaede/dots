---
name: dots
description: Orients the agent in the user's dotfiles repo ~/dots (CachyOS + Hyprland, managed by the `dots` CLI with bash + GNU stow + gum). Use when the user says "dots", "dotfiles", or "look in dots", or when a task changes configs under ~/.config or ~/.local/bin, installs or removes packages, or touches theming, Hyprland, Quickshell, nvim, tmux, shell or pi config.
---

# dots — the user's dotfiles

`~/dots` is a git repo that owns this machine's setup: packages, configs,
theming and the `dots` CLI (on `$PATH`). Most of `~/.config/*` and
`~/.local/bin/*` are **stow symlinks into `~/dots/stow/<component>/`**.
Editing a live config edits the repo.

## First step

Read `~/dots/AGENTS.md` before changing anything. It has the full command
table, structure and working rules. This skill is only a pointer.

## Hard rules (summary — AGENTS.md wins)

1. Packages only via `dots add <pkg> [--aur] [--category <c>]`. Never raw
   `pacman -S` / `yay -S`. Never hand-edit `packages/*/packages.txt`.
2. New config dirs go in via `dots stow-add <name>`. `stow --adopt` is banned.
3. Repo wins on conflict. Machine files are backed up to `~/.dotfiles-backup/`.
4. No templating, no state files, no loose scripts — everything through `dots`.
5. `sudo` steps (`dots add`, `dots install`) are run by the user — the agent
   has no TTY. Hand them the exact command.
6. Commit only after the user confirms it works. Big/structural changes:
   propose first.

## Find out what exists (don't guess)

```bash
readlink -f ~/.config/<app>      # is it managed? which component?
ls ~/dots/stow                   # stow components
dots list --categories           # package categories
dots list <category> --items     # packages + install scripts
dots help                        # all commands
```

## Which doc for which task

| Task | Read |
|---|---|
| Anything in the repo, CLI usage | `~/dots/AGENTS.md` |
| Changing the `dots` CLI, theming adapters, prefs internals | `~/dots/dots-cli/AGENTS.md` |
| Why things are the way they are, rejected ideas | `~/dots/design-doc.md` |
| Quickshell features / "apps" | `~/dots/stow/quickshell/.config/quickshell/docs/APPS.md` |
| Quickshell pitfalls | `~/dots/stow/quickshell/.config/quickshell/docs/GOTCHAS.md` |
| App settings that can't be stowed (Vivaldi) | `~/dots/prefs/README.md` |
| Colorschemes | `~/dots/dots-cli/theming/README.md` |
