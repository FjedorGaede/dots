# theming/

The theming engine and its per-app adapters. Everything theming-related lives
here; callers (the `dots theme` CLI in `../lib/theme.sh`, future setup
scripts) only resolve a theme name and invoke `apply-theme.sh`.

```
theming/
├── apply-theme.sh   # the engine: wal + adapters + notify — THE place that owns the code
├── adapters/        # one script per app that needs to react to a theme change
│   └── hyprland.sh
└── README.md
```

## Usage

```
dots-cli/theming/apply-theme.sh [-l] <theme-name>
```

1. `wal --theme <name>` regenerates `~/.cache/wal` and renders
   `~/.config/wal/templates/`. Anything that only consumes wal templates or
   the cache needs NO adapter (wal/pywal16 handles it).
2. Every **executable** `adapters/*.sh` runs in sorted order with the theme
   name as `$1`. Stdout/stderr goes to a temp log; a failed adapter is a
   warning, remaining adapters still run; any failure fails the script.
3. `notify-send` summary.

## Adapter contract

- File name: `<app>.sh`, executable, run in sorted order.
- Invocation: `adapter.sh <theme-name>`; `~/.cache/wal` is already fresh when
  the adapter runs.
- Exit 0 even if the app isn't installed/running — adapters must be no-ops
  on machines that don't run the app (see `adapters/hyprland.sh`).
- The directory listing is the registry — the same filesystem-as-state
  pattern as `packages/` and `stow/`. **Enable**: `chmod +x`. **Disable**
  without deleting: `chmod -x`. **Add**: drop `<app>.sh` in, `chmod +x`, done.

## Which apps need an adapter at all?

| App | Picks up wal how? | Adapter needed? |
|---|---|---|
| hyprland | parses `colors-hyprland.conf` once at startup (shared.lua) | yes — `hyprctl reload` |
| quickshell | `Theme.qml` watches `colors.json` live, but `qs` CLI has no reload (only log/list/kill/ipc) and QML that reads colors at instantiation doesn't re-run | yes — `qs kill` + `qs -d` |
| anything else using wal templates | wal itself renders + reloads on apply | no |

## Testing without touching the real colorscheme

```
WAL_BIN=echo dots-cli/theming/apply-theme.sh some-theme
```

(`WAL_BIN` overrides the wal binary — `echo` stubs it out.)
