# Gotchas — learned the hard way

Quickshell 0.3.1 · Qt 6 · Hyprland 0.56 (Lua config) · CachyOS.
Each entry: **what** → *why*. Collected from TODO.md and code comments; the
original comments stay next to the code they explain.

## QML / Qt

- **Nerd glyphs need `font.family: Theme.fontFamily`.** → *Glyphs are
  private-use codepoints; without the family Qt falls back to whatever font
  happens to cover them and renders unrelated icons.* (modules/osd/Osd.qml)
- **Nerd glyph ink overflows its advance width.** → *Centering by
  `implicitWidth` looks lopsided. Center by ink via
  `TextMetrics.tightBoundingRect` (`InkGlyph.qml`, used by MediaIndicator), or offset manually
  (stay-awake coffee cup, `indicators/StayAwake.qml`). `tightBoundingRect.y` is relative to
  the baseline.*
- **Glyph variants have different advance widths.** → *Put toggling glyphs
  (mute/unmute, OSD icon, OSD percent) in a fixed-size box so neighbours don't
  jump.* (AudioPanel mute 22 px hit box, OSD 28/44 px boxes)
- **QQC2 `Slider` is not draggable inside Quickshell popup windows.** → *Use a
  hand-rolled `MouseArea` slider (`VolumeSlider.qml`, like omarchy
  quattro's PanelSlider).*
- **Slider value sync must be imperative.** → *A binding on the slider value
  snaps back while dragging; update `live` from `onVolChanged` only when not
  dragging.* (`VolumeRow.qml` owns the sync, `VolumeSlider.live` is the value)
- **`MouseArea` vs `TapHandler`.** → *`TapHandler` takes a passive grab: a
  click on a button also reaches a TapHandler below it (backdrop closer fired
  before the confirm state was visible), and a passive TapHandler is canceled
  by a `MouseArea`'s exclusive grab stacked below (power-menu buttons were
  dead because the card click-absorber won). Backdrop closers, click
  absorbers and the buttons above them must all be `MouseArea`s.*
  (`ModalOverlay.qml` backdrop + absorber, `IconButton`, `GhostButton
  { exclusiveGrab: true }` e.g. the LAN rescan button, HomeMenu rows,
  LanDevices rows). Shared primitives keep the handler type of the code
  they replaced: `BarButton`/`GhostButton` = HoverHandler + passive TapHandler.
- **A `TapHandler` stacked above another `TapHandler`** (ListItem action
  button) gets the tap exclusively — no manual propagation guard needed.
  Don't write to `accepted` in a TapHandler (it's not a property there — the
  write went to a global).
- **Bindings evaluate even when the parent is hidden.** → *Unguarded
  `adapter.discovering` / `focusedWorkspace.id` throw TypeErrors at startup
  when the object is null. Always use `?.`.*
- **`property bool enabled` on an Item shadows `Item.enabled`.** (old Bluetooth indicator; gone since BluetoothService)
- **Switch signal clash:** a custom `toggled` signal collides with the
  built-in one → renamed `userToggled`. Also suppress it until
  `Component.onCompleted`, otherwise the initial `checked` binding fires it
  and consumers write state back on popup open. (Toggle.qml)
- **User interaction breaks a declarative `checked` binding.** → *Restore it
  with `checked = Qt.binding(...)` in the handler so external changes (rfkill,
  nmcli, DND) stay in sync.*
- **`Layout.fillHeight` on the right-side bar pills** stretched them to the
  tallest sibling → flush with the window below. Pills keep natural height and
  are vertically centered. Likewise `BarButton` keeps its layout height at
  the 14 px base line height regardless of `size`, so bigger glyphs don't make
  their pill taller. (modules/bar/Bar.qml, BarButton.qml)
- **`RowLayout` ceil()s its children's sizes.** → *A 28.75 px wide Text in a
  RowLayout gets 29 px, so a RowLayout-centered label sits up to 1 px off a
  directly `anchors.centerIn`-ed one. `GhostButton.rowContent: false` centers a
  single glyph/label directly (fixed-size buttons); content-sized buttons use
  the RowLayout (their implicitWidth always included the ceil).*
- **`Text` default alignment is left** → icons in fixed-width boxes looked
  like the pill had more padding on the right. Also: `width` on a `RowLayout`
  child is ignored (layout uses implicit/preferred size) — the old
  `StatusIcon { width: 32 }` gave every status icon its own advance width,
  so gaps looked random. Equal *centers* (fixed-width slots) don't fix it
  either — the eye judges the empty space between inks, and a thin glyph
  (Bluetooth) floats in a wide gap. `BarButton` sizes its box to the glyph's
  ink (`InkGlyph.ink`) so `Theme.bar.iconSpacing` is the visible gap.
- **A `Text` with no `color` renders black** (IconButton — currently relied on
  for the look).
- **`Flickable` has no `rightPadding`** → reserve scrollbar space by making the
  content narrower (`width: parent.width - 12; x: 6`).
- **Qt 6 has no calendar widget** (Qt Labs Calendar dropped) → `CalendarPopup`
  is a plain `Grid` + Date math. Some locales have no standalone month names →
  fall back to `Qt.formatDate(d, "MMMM")`. QML `Locale.standaloneMonthName()`
  / `monthName()` take **0-based** months (JS `getMonth()` as-is; verified —
  `+ 1` showed October in September, December only worked via the fallback).
- **`.js` imports without `.pragma library`** get one copy per importing
  component.

## Quickshell

- **`StandardPaths.homeLocation` is undefined in QML.** → *Use
  `Quickshell.env("HOME")`. The original pywal FileView silently read
  `undefined/.cache/wal/colors.json` and always fell back.*
- **`FileView.text` is a function here, not a property** → `walView.text()`.
- **Parse-guard watched JSON.** → *wal writes the file non-atomically; a
  half-written file must keep the current scheme, not reset it.* (Theme.qml)
- **New `pragma Singleton` files only register after a full `qs`
  restart**, not on hot reload (any directory).
- **`import qs.<dir>` module imports** (Quickshell ≥ 0.2): Quickshell
  synthesizes a qmldir per directory under the shell root (`pragma Singleton`
  files become singletons). → *A hand-written `qmldir` in a directory
  disables the synthesis for that directory ("Found qmldir file, qmldir
  synthesization will be disabled") — don't add one (the old `theme/qmldir`
  was deleted). Files in the same directory see each other implicitly; other
  directories need `import qs.x.y` (e.g. `qs.modules.bar.indicators`).
  JS libraries are imported by relative path (`import "../../lib/icons.js"
  as Icons`). `Qt.resolvedUrl("overrides.json")` in `config/Theme.qml` still
  resolves next to the file (VFS rewrite to the real path);
  `Quickshell.shellPath("scripts/…")` is relative to the shell root.
  Debug: `qs log -p <path> -r "quickshell.qmlscanner.debug=true"`.*
- **Naming: every singleton in `services/` ends in `Service`**
  (`AudioService`, `PanelService`, `LanScannerService`, …). → *The bare
  domain names collide: half of them are also bar indicators
  (`indicators/Network`, `Bluetooth`, `Battery`, `Vpn`, `Sunshine`,
  `StayAwake`) — the indicator imports its own service, and inside
  `Battery.qml` the name `Battery` would be the file itself — and
  `Bluetooth` is also the `Quickshell.Bluetooth` singleton. One uniform
  suffix beats a per-service exception list. Singletons in `config/`
  (`Theme`, `Paths`, `Apps`) have no suffix.*
- **An enum is referenced through the file's type name** (`Osd.Volume` in
  `Osd.qml`) → renaming the file means renaming those references.
- **New files must exist in the stow repo AND be symlinked** while
  `~/.config/quickshell` is a real dir of per-file symlinks (relative depth
  differs per directory). A stow run once overwrote a live-edited file with the
  old repo version (calendar was lost) → always edit inside the stow repo.
  (Fixed for good by folding the stow package — REFACTOR.md §1.)
- **`PwObjectTracker` must bind every node you read.** → *`PwNode` properties
  (audio.volume, muted, …) are only valid while the node is tracked — include
  all candidate sinks/sources in device pickers, not just the default.*
- **OSD map/unmap kills popup grabs.** → *Mapping/unmapping the OSD layer
  surface churns focus and dismisses a `grabFocus` popup (~1.4 s after a
  drag in the audio panel). The OSD is suppressed while the audio panel is
  open (`PanelService.isOpen("audio")`).*
- **The toast window is always mapped, with a fixed size.** → *Unmapping on
  empty churned the layer surface → Hyprland refocused and sometimes dismissed
  the (exclusive-keyboard) bell popup. Resizing produced a "squeezing" effect.
  Empty area is click-through via `mask: Region { item: toastsList }`.*
- **Only one process can own `org.freedesktop.Notifications`.** → *While
  swaync (or another qs instance) holds the name we receive nothing;
  Quickshell registers automatically once it's free. The refactor preview
  instance therefore shows no toasts.*
- **Notification objects can outlive their D-Bus object** (after hot reload) →
  guard with `try { typeof n.dismiss === "function" }`.
- **Toast cap uses `hideToast`, not `dismissToast`** → the oldest toast leaves
  the screen but stays in history. Transient notifications are dismissed on
  hide (per spec). Many apps send an unnamed `"default"` action → toast body
  tap invokes it.
- **Inline notification replies were removed** → toast inputs lose focus on
  every new notification.
- **`IpcHandler` in an `Instantiator` works, but every declared property
  (e.g. `required property string modelData`) and its change signal become
  part of the IPC interface.** → *PanelService uses the delegate's context
  `modelData` instead so `qs ipc show` lists only toggle/open/close.*
- **A `PopupWindow` with `grabFocus` hides itself** (grab loss, Escape →
  `visible = false`). → *Don't bind `visible` declaratively to shared state;
  `PopupPanel.open` → `visible` is synced imperatively, and the panel writes
  back with `onVisibleChanged: PanelService.setOpen(<id>, visible)`
  (AudioPanel, WifiPanel, BluetoothPanel, NotificationCenter).*
- **A `Process` child's stdin is an open pipe, not a tty.** → *Tools that
  switch behaviour on that hang silently: `slurp` waits to read predefined
  boxes from stdin and never shows its overlay. Redirect `</dev/null`
  (`scripts/screenrec-select.sh`).*
- **`IpcHandler` targets are per instance** → `qs ipc -p <path> call …`
  addresses a specific instance.

## Hyprland

- **Hyprland 0.56 with Lua config: `hyprctl dispatch` args are parsed as Lua**
  (`return hl.dispatch(<arg>)`). → *Use the `hl.dsp.*` form, e.g.
  `hyprctl dispatch 'hl.dsp.exit()'` (`config/Apps.qml` `logout()`, same as the
  keybind in `hypr/keybinds.lua`), `Hyprland.dispatch('hl.dsp.focus({workspace="3"})')`
  (Workspaces). Plain `hyprctl dispatch exit` fails: `exit` is an undefined Lua
  variable. TODO.md item C once switched `hl.dsp.exit()` → `exit` as a "fix" —
  that was wrong (the power-menu buttons were likely dead for a different reason
  at the time: the MouseArea-vs-TapHandler grab, see above).*
- **Idle = `services/IdleService.qml`** (hypridle was dropped). All timings and
  commands are in its settings block. Stay-awake is checked directly before the
  idle suspend (the old `stay-awake.json` grep script is gone).
  *Lock before sleep*: the service holds a logind **delay** inhibitor
  (`systemd-inhibit --mode=delay … sleep infinity`) and watches
  `gdbus monitor --system --dest org.freedesktop.login1`; on
  `PrepareForSleep(true)` it starts the lock, then releases the inhibitor after
  1 s (logind waits ≤ `InhibitDelayMaxSec`, 5 s); on `(false)` it turns screens
  on and re-takes the inhibitor. `Session.Lock` (`loginctl lock-session`) also
  locks. *Consequence: locking depends on quickshell running.*
- **D-Bus idle inhibits** (browsers playing video, VLC, Steam, gamemode, SDL
  under XWayland, xdg-desktop-portal) go to `org.freedesktop.ScreenSaver` /
  `org.freedesktop.PowerManagement` — hypridle owned those; Quickshell has no
  D-Bus server API, so `scripts/screensaver-inhibit.py` (PyGObject) owns them and
  reports the count to IdleService, which pauses all steps while > 0.
  Chromium/VLC only probe with NameHasOwner (no D-Bus activation), so the
  daemon must already be running — IdleService starts it. Inhibits die with
  their client. Without it, videos in the browser triggered dim/lock.
- **Gamepads are invisible to Wayland idle** (games read the device directly).
  Fix used: Hyprland window rule `idle_inhibit = "fullscreen"` for
  `steam_app_*` / `steam.app.*` (hypr/window-rules.lua) + D-Bus inhibits from
  Steam/SDL. Windowed/browser games with a controller are not covered.
- **dpms**: `hyprctl dispatch 'hl.dsp.dpms({ action = "off" })'` / `"on"` —
  the old `hyprctl dispatch dpms off` fails under the Lua config.
- **The bar layer's exclusive zone** is what places windows at y=30; a second
  top-anchored layer (preview instance) stacks directly below it.
- **Screen recording can't hide our own layers.** → *gpu-screen-recorder's
  portal capture (`-w portal`) fails here: xdph and gsr can't agree on a
  dmabuf ("DMA-BUF fixation failed … falling back to SHM") and gsr refuses SHM
  frames. KMS capture (`-w <monitor>` / `-w region`) works but grabs the
  composited output — every layer is in it. Hyprland's `no_screen_share`
  layer rule only affects screencopy/portal clients and paints the layer
  **black**, it doesn't remove it (tested with grim). So there is no
  floating recording control; the bar indicator is the only one (the bar is
  in full-screen recordings anyway).*
- **gsr `-region WxH+X+Y` takes global logical coordinates** (scales them
  itself: 600x300 at scale 1.33 → 800x400 video) — slurp's output is passed
  through unchanged (`scripts/screenrec-select.sh`).

## Services / system

- **BlueZ drops the discovery session after ~30 s** → restart it every 25 s
  while the panel is open.
- **NetworkManager may save a profile with a wrong password** → forget it after
  a failed attempt, but only if the network wasn't known before.
- **Enterprise (802.1X) wifi** needs identity/cert setup a password prompt
  can't provide → handed off to `nm-connection-editor` (note: that package is
  deliberately dropped from the dotfiles — REFACTOR.md §7 #17).
- **Bluetooth devices may report a UUID/MAC as their name** → fall back to
  `deviceName`, then the address.
- **LAN scan lives in `scripts/scan-lan.sh`** (it used to be a JS template
  string). The template silently turned the awk regex `/^[0-9]+\./` into
  `/^[0-9]+./` — kept as-is for identical behaviour, see the NB in the script.
  FritzBox publishes DHCP names via reverse DNS; mDNS is the fallback.
- **OSD startup noise** → audio signals fire during initial binding; a 1 s
  `audioReady` delay guards against a spurious OSD at startup.
- **Mic boost > 100 % is normal** → overshoot coloring on both audio rows, red
  zone only 15 % opacity; mute must not gray the slider (the red glyph shows it).
- **Never re-bind `screen:` of a live window** → Quickshell 0.3.1 segfaults in
  `QWindow::setScreen` when e.g. `screen: DisplayService.mainScreen` changes
  under an existing window (happened on a hot reload). Windows that belong to
  a screen are created by a `Variants` over that screen (shell.qml): changing
  the main monitor destroys them and creates fresh ones. Inside a window, take
  the screen from the window itself (`QsWindow.window.screen` in an item,
  `anchor.window.screen` in a popup — see `bar/Workspaces.qml`,
  `components/PopupPanel.qml`) — fixed for that window's lifetime.
