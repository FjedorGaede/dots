# Screen recorder — spec & handoff

What the recorder should do, what was decided and why, and where to pick up.
Overview of the files: `README.md` (same folder). Pattern this app follows:
`~/dots/AGENTS.md` → "Apps".

## Goal

A Loom clone inside the quickshell shell (Hyprland, CachyOS): record a region,
window or screen with your face in a round webcam bubble, one click to start,
one mp4 at the end that you can paste into a chat right away.

## Behaviour (as built, user-tested and confirmed)

1. **Super+R** → menu: mode (Region / Window / Screen), desktop audio, mic,
   camera (click cycles off → each camera → off), Record.
   **Super+Shift+R** = straight to the region drag, no menu.
2. **Pick the target** (slurp / focused monitor).
3. **"ready" (camera on):** the bubble shows the live camera inside the target,
   with a **setup card** next to it:
   - camera list (check = chosen) + **No camera** (the bubble stays empty —
     "Camera off" — as a handle to move the card; recording then runs
     without bubble), Microphone, Desktop audio
   - **Start recording** (full width, red) — or Super+R
   - small ✕ in the card's top-right = cancel
   Always shown, also with the camera off (user: starting right away after
   the selection felt wrong).
4. **Recording:** the card gives way to a pill (time, pause/resume, stop). It
   fades out unless hovered or paused (it is in the video too). Same controls
   in the bar (`RecordingIndicator`).
5. **Stop** → `~/Videos/Recordings/Recording_<stamp>.mp4`, file on the
   clipboard (`text/uri-list`), notification with Open / Show folder.

Bubble interaction, both phases: **drag = move**, **scroll = resize**
(140–480 px). Kept inside the recorded target (24 px inset). No hint text,
no right-click actions (user removed both on purpose).

**Panel placement:** below the bubble if the setup card fits on screen there,
else above; clamped to the screen horizontally → the bubble can sit in any
corner. The side is decided with the card's height in both phases, so the
pill doesn't flip sides on start.

**Bubble size never depends on the panel** (it used to: the bubble grew when
the tall card was replaced by the pill — user-reported bug, fixed).

**Everything is remembered** (`~/.cache/quickshell/recorder.json`): mode, mic,
desktop audio, camera on/off, camera, bubble size + position. The last
recording's setup is the next one's default; the camera is pinned when a
recording starts (it may have been a fallback).

## Key decisions

| Decision | Why |
|---|---|
| Bubble is on screen and simply captured (Loom), no second video stream / compositing | gsr's KMS capture records every layer anyway; separate tracks (Cap, Screen Studio) would need an editor |
| Webcam picture via QtMultimedia in its own file, loaded by `Loader.source` | Optional package: a static import would break the whole shell without it |
| Cameras from `/sys/class/video4linux`: `index == 0` nodes, `IR Camera` filtered | Metadata nodes + Windows-Hello IR sensors are not webcams |
| Camera format: smallest ≥ 720p at ≥ 30 fps | The Insta360 defaults to 4K MJPEG → decode load for a ≤ 480 px bubble |
| Picture mirrored (selfie view) — also in the video | What you see is what's recorded |
| `RecorderService` stays in `services/` | Layering: `NotificationService` reads `active` (holds back toasts); services must not import modules |
| Own install script with `--check` + Install button in the menu, then `Quickshell.reload()` | "Apps" pattern; QtMultimedia is only found by a fresh QML engine |
| One process with the shell (not `qs -c recorder`) | Stage 1 of 2 — split only if the camera ever crashes the shell |

## Debugging

```
qs ipc call recording status   # phase, installed, webcam, camera, open panels, main screen
qs log | grep -iv dbus         # QML errors (a broken file → "Type X unavailable")
```

- **Nothing opens on Super+R** but `status` shows the panel open → quickshell
  hung (seen after 4 days uptime + many reloads, cause unknown): `qs kill; qs`.
- `"No camera"` for 1–2 s at preview start = the camera is still starting.
- Inline `component` declarations in `WebcamBubble.qml` failed to load as
  types after edits ("X is not a type") → setup rows are their own file
  (`SetupOption.qml`). Prefer separate files over inline components here.
- Demo of the recorder itself: run a second capture in a terminal,
  `gpu-screen-recorder -w DP-2 -f 60 -k h264 -c mp4 -a default_input -o ~/Videos/Recordings/demo.mp4`,
  Ctrl+C to stop (the recorder itself only runs once at a time).

## Status

- Works and is confirmed by the user (menu, preview, camera switching,
  panel above/below, start/stop, remembered setup).
- **Not tested:** the one-click install flow end to end (terminal → reload →
  menu reopens) — only the "not installed" view was checked.
- **Not committed** (repo rule: commit only after the user confirms). The
  recorder work spans: `modules/recorder/` (new), `services/RecorderService.qml`,
  `shell.qml`, `config/Paths.qml`, `modules/bar/AppStatusArea.qml`,
  `docs/GOTCHAS.md`, `docs/REFACTOR.md`, deleted `modules/overlays/RecorderMenu.qml`,
  `modules/bar/indicators/Recording.qml`, `scripts/screenrec-select.sh`,
  `~/dots/packages/hyprland/install/screen-recorder/`, `~/dots/AGENTS.md`
  ("Apps" section), comment in `stow/hypr/.config/hypr/keybinds.lua`.
  Already committed + pushed: `gpu-screen-recorder` removed from
  `packages/hyprland/packages.txt`.

## Next ideas (not requested yet — ask first)

- Loading state instead of "No camera" while the camera starts.
- Countdown (3-2-1) after Start recording.
- Bubble shape (round / rounded rect) and camera-only mode.
- `status` IPC is debug-only; keep or drop.
- Stage 2: own process (`qs -c recorder`), bar reads state over IPC.
- Migrate older features (dictation, bluez-tools hint) to the "Apps" pattern.
