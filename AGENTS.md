# AGENTS.md — Dotfiles Rebuild Project

> **Status: TEMPORARY.** This file exists only for the duration of the rebuild and
> migration phase. When the new system is finished and migrated, it (and `TODO.md`)
> will be replaced with the final, permanent versions described in the design doc.

## What this repository is

A from-scratch redesign of the user's Linux desktop dotfiles (CachyOS + Hyprland),
replacing the old chezmoi/Ansible-based setup preserved in
`BACKUP_DO_NEVER_DELETE/` (reference-only).

**The authoritative design is `design-doc.md` in this repo. Read it before doing
anything.** This file is a summary + working rules, not a replacement.

## New architecture (short version)

- **Stack:** bash, GNU stow, gum. No DSL, no templating, no state files —
  filesystem + pacman/stow queries are the source of truth.
- **Structure:** `packages/<category>.txt` (one file = one category, `aur:` prefix
  routes to yay), `stow/<component>/` (one folder per stow package),
  `dots-cli/` (the CLI), `bootstrap.sh` (minimal curl-pipe-bash entrypoint).
- **`dots` CLI subcommands:** `install`, `add`, `remove`, `list`, `stow`, `sync`.
- **Conflict rule:** repo always wins; existing machine files get backed up to
  `~/.dotfiles-backup/`, never the reverse. `stow --adopt` is banned.
- **Bootstrap:** ensure git/gum/stow via bare pacman → clone repo →
  `exec dots-cli/bin/dots install`.

## Rules for every agent working here

1. **Never modify or delete anything in `BACKUP_DO_NEVER_DELETE/`.** It is the
   only surviving copy of the old setup. Use it to look up old config content
   (Hyprland, waybar, tmux, etc.) when building `stow/` components.
2. Follow `design-doc.md` exactly. The "explicitly rejected approaches" table
   there is final — do not reintroduce chezmoi, Ansible, state files, or
   `stow --adopt`.
3. Read `TODO.md` before starting work and keep it updated: check off completed
   items, add new todos as they come up. It is the single source of truth for
   progress.
4. Big changes (new tools, new subcommands, structural changes beyond the doc)
   must be proposed and approved before implementation.
5. Open items listed in the design doc are known-unfinished — surface decisions
   on them to the user, don't silently pick one.

## Phase overview

1. **Phase 1 — Build:** create the new repo structure, the `dots` CLI, and the
   stow components (porting config *content* from the backup where applicable).
2. **Phase 2 — Migrate:** move the user's live machine over to the new system,
   then replace this AGENTS.md/TODO.md with the permanent versions.

## Reference material

- `design-doc.md` — the design (authoritative for the new system)
- `BACKUP_DO_NEVER_DELETE/` — old system (chezmoi source state), read-only,
  source for old config content
