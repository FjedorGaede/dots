# USB flasher

Write an ISO / image to a USB stick from the home menu. A dots app
(`docs/APPS.md`).

## Parts

| File | Role |
|---|---|
| `services/FlasherService.qml` | Phase, image + stick lists, `pkexec flash.sh`, progress parsing, install state, IPC `flash` |
| `FlasherMenu.qml` | Menu: image list, stick list, Flash (click twice), progress, done/error |
| `flash.sh` | Runs as root: re-checks the target, unmounts it, `dd … status=progress`, `sync` |

Wiring outside this folder: `shell.qml` (menu), `services/PanelService.qml`
(panel `flasher`), `modules/overlays/HomeMenu.qml` (tile "Flash USB stick",
shows % while flashing).

## Flow

Home menu → **Flash USB stick** → pick image + stick → **Flash** → button
turns red "Erase SanDisk … (61.5 GB)?" → click again → menu hides for the
polkit password (the dialog would sit under our overlay) → reopens once data
is written (or with the error if cancelled) →
progress → notification "USB stick ready". The menu can be closed while it
writes.

`idle` → `flashing` → `done` | `error` → "Flash another" → `idle`

```
qs ipc call flasher open | close | toggle
qs ipc call flash status
```

## Safety

- The menu lists only whole disks with `TRAN=usb` and `RM=1` or `HOTPLUG=1`.
- `flash.sh` checks the same again as root, plus: image fits, no partition
  mounted on `/`, `/boot`, `/efi`, `/home` or as swap.
- Two clicks needed; the confirm names model and size.

## Limits

- Images are found in `~/Downloads` and `~` (depth 2), newest first, max 6
  shown. No file dialog (none installed).
- Only raw `.iso` / `.img`. Compressed images (`.img.xz`) are not offered.
- No cancel: `dd` runs as root, the shell can't signal it.
- Progress comes from `/sys/block/<dev>/stat` (sectors written), not from
  dd: its `status=progress` output does not reach the shell through pkexec.

## Install

`packages/hyprland/install/usb-flasher/install.sh` (util-linux, coreutils,
polkit; `--check`). Polkit agent: hyprpolkitagent from the hyprland
category.
