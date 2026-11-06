# Screen recorder

Spec, decisions and where to continue: `SPEC.md`.

Loom-style screen recording: pick a region / window / screen, place your
webcam bubble, record. One flattened mp4 — the bubble is simply on screen
while gpu-screen-recorder captures it (KMS capture, docs/GOTCHAS.md).

## Parts

| File | Role |
|---|---|
| `services/RecorderService.qml` | State machine + gsr process + IPC `recording`. Stays in `services/` (layering: `NotificationService` reads `RecorderService.active` to hold back toasts) |
| `RecorderMenu.qml` | Start menu: mode, desktop audio, mic, camera (click cycles off → each camera → off) |
| `select-target.sh` | Target picker (slurp / focused monitor) → global logical rect |
| `WebcamBubble.qml` | Round webcam bubble; "ready": setup card (camera, mic, desktop audio, Start recording), recording: pill (time, pause, stop) — below the bubble, above when there is no room; drag = move, scroll = resize |
| `SetupOption.qml` | One selectable row of the setup card |
| `WebcamFeed.qml` | The camera picture (QtMultimedia). Loaded by URL → without qt6-multimedia only the bubble stays empty |
| `RecordingIndicator.qml` | Bar pill while recording (dot, timer, pause/resume, stop) — in `AppStatusArea` |

Wiring outside this folder: `shell.qml` (menu + bubble), `modules/bar/AppStatusArea.qml`
(indicator), `HomeMenu.qml` (start/stop tile), `config/Paths.qml`
(`recordings`, `recorderState`), Hyprland binds in `hypr/keybinds.lua`.

## Flow

`idle` → menu (Super+R) → `selecting` (slurp) → `ready` (camera on: bubble
preview, place it, pick camera/audio, Start recording or Super+R) → `recording` ⇄ `paused` → stop →
file in `~/Videos/Recordings`, copied to the clipboard.
`ready` comes every time; camera off → empty bubble there, no bubble while recording.

```
qs ipc call recording toggle                    # menu / record from ready / stop
qs ipc call recording start region|window|screen
qs ipc call recording stop | pause              # stop also cancels ready
```

## State

`~/.cache/quickshell/recorder.json`: the last setup — mode, mic, desktop
audio, camera on/off, camera (V4L2 card name; pinned when a recording
starts), bubble size and position (fraction of the free space in the target →
same corner in every new region).

Cameras come from `/sys/class/video4linux` (capture nodes, IR sensors
filtered out), re-read whenever the menu opens.

## Install

An app in the dots sense (`~/dots/AGENTS.md` "Apps"):
`packages/hyprland/install/screen-recorder/install.sh` installs
gpu-screen-recorder, qt6-multimedia, qt6-multimedia-ffmpeg; `--check` tells
whether they are there. Not installed → the menu shows an Install button
(floating terminal, `dots install hyprland --only screen-recorder`), then the
shell reloads and reopens the menu.

## Later: own process

If the camera code ever takes the shell down, this folder + the service can
become a separate config (`qs -c recorder`). The bar indicator would then read
the state over IPC instead of the singleton.
