# Webcam (Insta360 Link)

Control an Insta360 Link / Link 2 from the home menu: AI mode, gimbal +
presets, image settings. A dots app (`docs/APPS.md`). Replaces the Windows /
macOS "Insta360 Link Controller".

## Parts

| File | Role |
|---|---|
| `services/Insta360Service.qml` | Camera state (polled), write queue (slider drags coalesce), mode + presets, install state, IPC `status` |
| `Insta360Menu.qml` | Menu: live preview, mode, gimbal pad, zoom, 3 presets, image sliders + switches |
| `Preview.qml` | Live picture; "Mirror" button flips the preview only (remembered, `mirrorPreview`), never the camera output. (QtMultimedia, loaded by URL → without qt6-multimedia only the preview stays empty). Runs only while the menu is open |
| `link.py` | The only camera access. `status` (JSON), `set NAME=VALUE`, `mode`, `frame`, `gestures`, `noise` |

Wiring outside this folder: `shell.qml` (menu), `services/PanelService.qml`
(panel `insta360`), `modules/overlays/HomeMenu.qml` (tile "Webcam", only
while the camera is plugged in; refreshes the camera on open),
`config/Paths.qml` (`insta360State`).

## How the camera is reached

- Pan, tilt, zoom, focus, image: standard UVC controls → `v4l2-ctl`.
  Angles are arcseconds (3600 = 1°). Pad step: 2°.
- AI modes, gestures, noise cancellation: the vendor extension
  unit 9 (`faf1672d-…`), via the `UVCIOC_CTRL_QUERY` ioctl.
  Selector 2 = mode (bytes 0/1; the firmware takes it only while streaming
  and after a handshake: normal → 0.6 s → mode, re-asserted until it reads
  back — as in github.com/jweaver60/link-studio), 5 = gestures, 7 = noise
  cancellation. 19 = tracking framing (1 head, 2 upper, 3 full) is accepted
  and read back but changed nothing visible on the Link 2 — not in the menu.
- Byte values taken from github.com/battistaar/insta360_link_control
  (read, not run) and checked on a Link 2 (`2e1a:4c04`).

## Safety

`link.py` writes only selectors 2, 5, 7, 19 and a fixed list of v4l2 controls.
Never write selector 17 (switches the USB mode — no webcam until replug) or
12 (serial number).

## Behaviour to know

- **The gimbal only moves while an app streams.** Without one the camera
  parks; writes are accepted but ignored. The menu's preview is that stream,
  so opening the menu wakes it; closing releases the camera. If a call
  already holds the camera, the preview stays empty (one streamer per
  camera) but the controls still work.
- **Mode readback:** byte 0 of selector 2 is the mode, but `0xFF` while it
  switches — then the last mode set (`~/.cache/quickshell/insta360.json`)
  is shown.
- Going to a preset switches to Normal first (tracking would move away).

```
qs ipc call insta360 open | close | toggle
qs ipc call webcam status
qs ipc call webcam gestures false   # off (and keep it off after replugs)
python3 -I link.py status          # from this folder
```

## Limits

- Hand gestures can only be turned **off** (selector 5 = 0): that also
  clears the firmware's gesture bindings, only a replug brings them back
  (a USB reset via `usbreset` does not — tested). Switching them on in the
  menu shows that hint.
  The wish is remembered (`gesturesOff`); while set, the service checks every
  15 s and turns them off again after a replug.
- No firmware update (Windows app only).
- First camera only.

## Install

`packages/apps/install/insta360/install.sh` (v4l-utils, python, qt6-multimedia, qt6-multimedia-ffmpeg;
`--check`).
