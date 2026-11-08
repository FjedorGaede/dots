# Apps — how we build features in the shell

An **app** is one user-facing feature of the quickshell shell (screen
recorder, USB flasher, …). Not a separate program: it runs inside the shell.
But it is built as **one unit** that can be found, installed, understood and
(later) moved out as a whole.

Reference implementations:
- `modules/recorder/` — big app (state machine, optional QML module, bar indicator)
- `modules/flasher/` — small app (one menu, one root helper script)

## The idea

- **One folder per app.** Everything you need to understand it is in one place.
- **Its packages are its own.** Installing the app = installing exactly its
  packages, nothing hidden in global lists.
- **The UI knows if it's installed.** Missing → one Install button, never a
  broken menu.
- **Never take the shell down.** Optional deps are loaded by URL, so a
  missing package empties one part, not the whole bar.
- **Safe by default.** Destructive or root actions re-check their input
  themselves and need an explicit confirm.

## Layout

| Part | Where | What |
|---|---|---|
| Feature folder | `modules/<app>/` | All UI (menu, overlays, bar indicator), helper scripts, `README.md` |
| Service | `services/<App>Service.qml` | Singleton: state, processes, IPC, install state. Stays in `services/` — services must not import modules (layering, `docs/REFACTOR.md`) |
| Install script | `~/dots/packages/hyprland/install/<app>/install.sh` | Installs the app's own packages, idempotent, answers `--check` |
| Wiring | `shell.qml`, `PanelService.panels`, `HomeMenu.qml`, `config/Paths.qml`, `hypr/keybinds.lua` | Only what's needed to reach the app — listed in the app's README |

## Setup / install flow

1. `install.sh --check` → exit 0 = all packages there, no output. This is the
   **one** package list; QML never repeats it.
2. The service keeps `installed` (optimistic `true`). It runs `--check` at
   startup and every time the app's menu opens.
3. Not installed → the menu shows **Install** instead of its controls. It runs
   `dots install hyprland --only <app>` in a floating terminal
   (`Apps.floatingTerminalCommand`; sudo asks there).
4. Terminal closed → `--check` again. Success → `Quickshell.reload()` (new QML
   modules need a fresh engine), then reopen the menu over IPC.
5. Keybinds that skip the menu open the menu instead while not installed.

Shared tools (slurp, wl-clipboard, jq, …) stay in `packages.txt`. Only what
the app alone needs goes into its script.

## Conventions

- **Entry point:** a tile in the home menu and/or a keybind. Open state lives
  in `PanelService` (`qs ipc call <app> open|toggle|close`).
- **State machine:** one `phase` string in the service (`idle`, `…`, `done`,
  `error`). The UI only renders the phase.
- **IPC:** `qs ipc call <target> status` returns phase + installed + key
  fields — for debugging without a UI.
- **Remembered setup:** `~/.cache/quickshell/<app>.json` via
  `FileView` + `JsonAdapter`, path in `config/Paths.qml`. Last setup = next
  default.
- **Root actions:** a script in the feature folder, run with `pkexec`. It
  validates its arguments itself; the UI filter is only convenience.
- **Feedback:** long jobs show progress in the menu and in the home-menu tile;
  the end is a notification (`Apps.notify`), so the menu may be closed.
- **Docs:** `README.md` in the folder (parts, flow, IPC, state, install,
  wiring outside the folder). Bigger apps add `SPEC.md` (decisions + why,
  handoff).

## Checklist for a new app

- [ ] `modules/<app>/` with menu + `README.md`
- [ ] `services/<App>Service.qml` with `phase`, `installed`, `install()`, IPC `status`
- [ ] `packages/hyprland/install/<app>/install.sh` with `--check`, executable
- [ ] Panel name in `PanelService.panels`, menu in `shell.qml`
- [ ] Home-menu tile (and keybind if useful)
- [ ] Optional QML modules only via `Loader { source: "…" }`
- [ ] Tested: not-installed path, happy path, error path

## Later: own process

If an app ever needs crash isolation or should be shared alone, its folder +
service become a separate config (`qs -c <app>`). The bar then reads its
state over IPC instead of the singleton.

Older features (dictation, the bluez-tools hint) only partly follow this —
migrate them when touched.
