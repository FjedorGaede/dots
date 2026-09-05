# AGENTS.md — dots CLI internals

Reference for anyone changing the CLI. The repo-level `AGENTS.md` and the design
doc describe *what* the CLI does; this file describes *how it's built*.

## Layout

```
dots-cli/
├── bin/dots          # entrypoint: resolves DOTFILES_DIR/LIB_DIR, sources common.sh, calls main "$@"
├── lib/
│   ├── common.sh     # helpers + main() dispatch — no commands live here
│   ├── install.sh    # cmd_install
│   ├── add.sh        # cmd_add
│   ├── remove.sh     # cmd_remove
│   ├── list.sh       # cmd_list
│   ├── stow.sh       # cmd_stow
│   ├── sync.sh       # cmd_sync
│   ├── theme.sh      # cmd_theme (thin CLI surface — logic lives in theming/)
│   └── edit.sh       # cmd_edit
└── theming/          # theming engine + per-app adapters (see README.md + section below)
    ├── apply-theme.sh  # THE owner of all theming code: wal + adapters + notify
    ├── adapters/       # executable scripts run per theme change
    │   └── hyprland.sh
    └── README.md
```

## Dispatch mechanism

`bin/dots` only sets `DOTFILES_DIR` / `LIB_DIR`, sources `lib/common.sh`, and
calls `main "$@"`. `main` in `common.sh` maps the first argument to
`lib/<cmd>.sh`, sources it, and calls `cmd_<cmd>` with the remaining arguments.
Unknown commands print usage and exit 1. There is no argument parsing in
`bin/dots` itself.

## Conventions every subcommand follows

- One file per command: `lib/<name>.sh` exposing exactly one public function
  `cmd_<name>`; everything else is file-local helpers.
- Every file starts with `set -euo pipefail` (inherited via `common.sh`, but
  each file states it anyway so it's self-contained when read).
- `DOTFILES_DIR`, `PACKAGES_DIR`, `STOW_DIR`, `BACKUP_DIR` and all helper
  functions (`die`, `info`, `warn`, `require_gum`, `gum_*`, `categories`,
  `category_dir`, `category_file`, `packages_in_category`, `setup_scripts`,
  `is_aur`, `pkg_name`, `stow_components`, `is_linked`, `backup_conflicts`)
  come from `common.sh`.
- Errors: `die "message"` (prints to stderr, exit 1). Progress: `info`.
  Non-fatal failures: `warn` — never silently ignore a failure.
- Interactive bits must go through the `gum_*` wrappers, and must call
  `require_gum` first. Commands that can run fully from arguments (e.g.
  `dots install core`, `dots add foo --category dev` in scripts) must not
  require gum.
- Flags before/after positionals are parsed per-command with a `while`/`case`
  loop (see `add.sh`); unknown flags `die` rather than being ignored.
- No state files anywhere — query pacman/stow/filesystem instead.
- `set -u` safety: always use `"${arr[@]:-}"` or check array length before
  expanding possibly-empty arrays; use `[ -n "${assoc[$k]:-}" ]` for
  associative lookups.

## Adding a new subcommand — checklist

1. Create `lib/<name>.sh` with a `cmd_<name>` function following the
   conventions above.
2. Add `<name>` to the `case` in `main` (`common.sh`).
3. Add a row to the usage table in `usage()` (`common.sh`).
4. Add a row to the command table in the repo-level `AGENTS.md` and
   `design-doc.md` if the command is user-facing.
5. If the command needs a new helper used by 2+ commands, move it into
   `common.sh`; if it's single-use, keep it file-local.
6. Test with shellcheck and a dry run before committing.

## Theming: `dots theme` and the adapter architecture

Ownership: **all theming code lives in `dots-cli/theming/`** —
`apply-theme.sh` is the engine (wal invocation, adapter iteration, notify);
`lib/theme.sh` is only the CLI surface (flag parsing + `gum filter` picker)
and invokes the engine. Other callers — e.g. a future
`packages/<cat>/setup/theme/setup.sh` that re-applies the theme during
`dots install` — likewise just call `apply-theme.sh [-l] <name>` directly.
Adapters follow the same filesystem-as-registry pattern as `packages/` and
`stow/`: the `theming/adapters/` directory listing IS the list, no config
file.

Flow of `apply-theme.sh`:

1. Run `wal --theme <name>` — regenerates `~/.cache/wal` and renders
   `~/.config/wal/templates/`. Anything that only consumes wal templates or
   the cache needs NO adapter (example: quickshell's `Theme.qml` uses
   `FileView watchChanges` on `colors.json` — reloads live, no adapter).
2. Run every executable `theming/adapters/*.sh` in sorted order with the
   theme name as `$1`. Adapter stdout/stderr goes to a temp log; a failed
   adapter is a `warn`, remaining adapters still run; any failure makes the
   script fail at the end.
3. `notify-send` summary.

### Extending theming to a new program — checklist

1. Ask first: **does the app actually need an adapter?** If it reads wal
   templates or watches `~/.cache/wal` live, wal already covers it. Only apps
   that load wal colors once at startup (example: hyprland's `shared.lua`
   parses `colors-hyprland.conf` at config load) or need an app-specific
   reload action need one.
2. Create `dots-cli/theming/adapters/<app>.sh`, executable. Keep it tiny and
   idempotent:
   - start with `set -euo pipefail`,
   - exit 0 early when the app isn't installed or not running (adapters must
     be no-ops on machines without the app — see `adapters/hyprland.sh`),
   - do the app-specific reload/apply, print nothing on success.
3. `chmod +x` it. **Disable** without deleting: `chmod -x <app>.sh`.
4. Update the app table in `theming/README.md`.
5. Test without touching the real colorscheme: `WAL_BIN=echo dots theme x`
   (the `WAL_BIN` override stubs out wal itself), or invoke
   `dots-cli/theming/apply-theme.sh` directly.

## Invariants (do not break)

- **Repo wins on conflict.** `stow --adopt` is banned; conflicts are backed up
  to `~/.dotfiles-backup/<component>.<timestamp>/` and the repo's version is
  stowed.
- **Install first, track second** (`add`) — a failed install must not be
  recorded.
- **`sync` never mutates** — it prints, nothing else.
- **Filesystem is the source of truth** — categories are discovered by scanning
  `packages/*/` (dir + `packages.txt`), components by scanning `stow/*`, theme
  adapters by scanning `dots-cli/theming/adapters/*`; no registries.
