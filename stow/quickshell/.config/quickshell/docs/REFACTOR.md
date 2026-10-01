# Quickshell refactor plan

> Status: **all phases done and merged** (2026-09). Phase 6 fixed the §7
> bugs; stow is folded (§1) so `~/.config/quickshell` is one symlink. The
> QS_PREVIEW guards were removed at merge — for a future side-by-side session
> re-add them (§11.2) and use `tools/preview.sh` / `tools/bar-diff.py`.
> Open decisions: font unification of system-font texts, critical-battery
> color, nm-connection-editor (dropped in dots), scan-lan.sh awk regex.
> 1 baseline + preview tooling · 2 tokens, `lib/*.js`, `StyledText` ·
> 3 services + `PanelService` · 4 primitives (BarButton, GhostButton,
> ModalOverlay, NotificationCard, …) · 5 folder layout with `qs.*` imports +
> renames (§2 — the tree there is the *actual* layout now).
>
> **Naming rule:** every singleton in `services/` keeps the `Service` suffix
> (`AudioService`, `PanelService`, `LanScannerService`, …) — the bare names
> would collide with the bar indicators of the same domain
> (`indicators/Network`, `Bluetooth`, `Battery`, `Vpn`, `Sunshine`,
> `StayAwake`) and with Quickshell types (`Bluetooth`). `config/` singletons
> (`Theme`, `Paths`, `Apps`) have no suffix. Details: docs/GOTCHAS.md.
>
> Below is the original plan (written 2026-09 after a full review of all ~45
> files, ~4.6k lines); file names in §0 and §3–§9 are the pre-refactor ones.
> Goal: much better code quality, architecture and reuse —
> **the shell must look exactly the same** afterwards. Visual changes and
> behaviour-changing bug fixes are separated out (phase 6) so "looks the same"
> stays provable.

---

## 0. TL;DR

The shell works and is well commented (the comments capture real lessons).
The weaknesses are structural:

1. **No layering** — data, logic and visuals live together in bar widgets.
   `Sound.qml`, `OSD.qml` and `AudioPanel.qml` each compute volume/mute
   themselves; `WifiNetworkManager` even gets its data by being handed the
   `Network` *bar widget* (`network: network`).
2. **Copy-paste instead of components** — the bar-indicator pattern exists 8×,
   the toggle/open/close `IpcHandler` 6×, the hover button 10+×, the
   notification card 2×, two JS helpers duplicated.
3. **No design tokens** — Theme only has colors; every radius / font size /
   padding / duration is a magic number (radii 2, 5, 6, 8, 12, 14; font sizes 10–24).
4. **Flat folder + per-file stow symlinks** — every new file needs a manual
   symlink (TODO.md complains), which is why nothing was ever split into folders.
5. ~15 real bugs, mostly null-safety and dead code (§7).

---

## 1. Step zero — fix the stow layout

`~/.config/quickshell/` is a *real* directory full of per-file symlinks
(including `theme/` and `_helpers/`). Stow can't fold it because the directory
contains non-repo files (`.claude/`, `.qmlls.ini`, empty `_theme/`).

```bash
# one-time (do this at MERGE time, not during the refactor — see §11)
mv ~/.config/quickshell ~/.config/quickshell.pre-fold
cd ~/dots/stow && stow -R -t ~ quickshell      # or the dots equivalent
readlink ~/.config/quickshell                  # → ../dots/stow/quickshell/.config/quickshell
echo ".qmlls.ini" >> ~/dots/stow/quickshell/.config/quickshell/.gitignore
```

Afterwards new files/folders just work and the restructure below is cheap.
Remove the empty `_theme/` and the stray `.claude/settings.local.json`.

---

## 2. Target structure

Quickshell ≥ 0.2 (installed: 0.3.1) supports **`import qs.<dir>`** module
imports — every folder becomes a module, no hand-written qmldir, singletons are
detected via `pragma Singleton`. That replaces ~30× `import './theme'`.

```
quickshell/
├── shell.qml                  # wiring only: Bar { Osd {} LanDevices {} Toasts {} }
├── config/                    # qs.config — no suffix
│   ├── Theme.qml              # colors (unchanged API) + tokens (§3)
│   ├── Paths.qml              # $HOME/.cache paths (wal, stay-awake flag, hyprlock export)
│   ├── Apps.qml               # external commands (hyprlock, systemctl, blueman-manager, xdg-open, notify-send, …)
│   └── overrides.json
├── services/                  # qs.services — pragma Singleton, zero visuals, *Service suffix
│   ├── AudioService  NetworkService  BluetoothService  BatteryService  MediaService
│   ├── BrightnessService  VpnService  SunshineService  StayAwakeService
│   ├── NotificationService  LanScannerService
│   └── PanelService           # open/close state + IPC for ALL panels (replaced ShellState)
├── components/                # qs.components — dumb primitives, never import services
│   ├── Pill  BarButton  StatusIcon  Tooltip  StyledText
│   ├── PopupPanel  ModalOverlay
│   ├── ListItem  SectionHeader  PanelHeader  ScrollColumn
│   ├── GhostButton  CloseButton  IconButton  Toggle
│   └── VolumeSlider  ProgressBar  Divider  VerticalDivider  DotsSpinner  InkGlyph
├── modules/
│   ├── bar/        Bar Workspaces Clock MediaIndicator Tray StatusArea AppStatusArea
│   │   └── indicators/  Network Sound Bluetooth Battery Vpn Sunshine Bell Home StayAwake
│   ├── panels/     AudioPanel VolumeRow · WifiPanel WifiPasswordView WifiNetworkItem ·
│   │               BluetoothPanel BluetoothDeviceItem · NotificationCenter ·
│   │               CalendarPopup · VpnPopup VpnList · SunshinePopup
│   ├── overlays/   HomeMenu LanDevices
│   ├── osd/        Osd
│   └── notifications/  Toasts NotificationCard NotificationActions
├── lib/            icons.js  fuzzy.js  dates.js  notif.js      (.pragma library, relative imports)
├── scripts/        scan-lan.sh     (moved out of the QML template string)
├── tools/          preview.sh  bar-diff.py  popup-diff.py
└── docs/           REFACTOR.md (this file)  GOTCHAS.md
```

`AppStatusArea` = the former `StatusBar.qml` (the separately collapsing pill
with the Sunshine indicator, left of the tray). `VolumeSlider` stayed a
volume-specific name (overshoot zone) instead of the planned `Slider`.
The Sunshine stop confirmation (right click) stays inline in
`indicators/Sunshine.qml`.

**Dependency rule:** `modules → components + services + config` (and other
modules, e.g. indicators → panels); `components → config` only; `services →
config` only (never UI). `PopupPanel` therefore takes a generic `open` input —
the panel module wires `PanelService.isOpen/setOpen` itself.

**Renames** (names that lie today):

| Now | Problem | New |
|---|---|---|
| `SystemStats.qml` | shows no stats — it's the status-icon row (even misled the "mystery CPU/RAM strip" hunt) | `StatusArea` |
| `PowerMenu.qml` / `PowerMenuItem.qml` | it's a home menu now (IPC target already `home`) | `HomeMenu` / `indicators/Home` |
| `WifiNetworkManager`, `BluetoothManager` | "Manager" sounds like a service; they're popups | `WifiPanel`, `BluetoothPanel` (matches `AudioPanel`) |
| `BarElement` | it's the pill | `Pill` |
| `PopupBase` | | `PopupPanel` |
| `NetworkDevices*` | confusable with NM devices | `LanDevices` / `LanScanner` |

---

## 3. Design tokens (no visual change)

Values are exactly today's magic numbers.

```qml
// config/Theme.qml (additions)
readonly property string fontFamily: "JetBrainsMono Nerd Font"   // keep for compat

readonly property QtObject fontSize: QtObject {
    readonly property int xs: 10;  readonly property int sm: 11;  readonly property int md: 12
    readonly property int base: 13; readonly property int lg: 14; readonly property int xl: 16
    readonly property int icon: 20; readonly property int osd: 24
}
readonly property QtObject radius: QtObject {
    readonly property int xs: 2;  readonly property int sm: 6;  readonly property int md: 8
    readonly property int lg: 12; readonly property int xl: 14
}
readonly property QtObject anim: QtObject {
    readonly property int fast: 100; readonly property int normal: 150; readonly property int slow: 180
}
readonly property QtObject bar: QtObject {
    readonly property int height: 30
    readonly property int edgeMargin: 4
    readonly property int pillPadding: 8
    readonly property int toastTop: height + 8     // NotificationToasts' magic `38`
}

// replaces scattered Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.15)
function alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }

// currently-hardcoded colors get names (same values → same look)
readonly property color divider:        "gray"      // Divider/VerticalDivider default
readonly property color errorBright:    "#ff6b6b"   // wifi password error — not themed today!
readonly property color criticalBorder: color1      // Bell/Toast use color1/color0/color8 raw
readonly property color cardBorder:     color0
readonly property color actionButton:   color8
```

Also in `Theme.qml`:

- **Debounce `writeLockConf()`** — at startup it runs up to 4× (`onLoaded`,
  `onMainAccentChanged`, `onHighlightChanged`, `Component.onCompleted`), each
  spawning `sh`:
  ```qml
  Timer { id: lockDebounce; interval: 50; onTriggered: root._writeLockConf() }
  function writeLockConf() { lockDebounce.restart() }
  ```
- **Consider `FileView.setText()`** instead of building a `sh -c "printf …"`
  string. Verify whether FileView creates parent dirs; if not, keep a one-time
  `mkdir -p`.

`StyledText` kills ~60× `font { family: Theme.fontFamily; pixelSize: … }`:

```qml
// components/StyledText.qml
import QtQuick
import qs.config
Text {
    color: Theme.foreground
    font.family: Theme.fontFamily   // REQUIRED for nerd glyphs (see GOTCHAS)
    font.pixelSize: Theme.fontSize.lg
}
```

> ⚠️ Texts that currently set **no** font family (render in the system default):
> `Tooltip`, "NOTIFICATIONS"/"DND" headers, BLUETOOTH/WIFI/KNOWN/OTHERS headers,
> the Discover button, "Disabled"/"Connecting...". To stay pixel-identical
> they must stay plain `Text` during phases 1–5. Unifying the font is a
> deliberate phase-6 change.

---

## 4. Services — one source of truth per domain

### 4.1 `services/Audio.qml`

Today three files compute volume/mute and **disagree**: `Sound`/`OSD` use
`Math.floor`, `AudioPanel` uses `Math.round` → OSD can say 74 % while the panel
says 75 %.

```qml
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

Singleton {
    id: root

    readonly property PwNode sink:   Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource

    readonly property var sinks: (Pipewire.nodes?.values ?? [])
        .filter(n => n && !n.isStream && n.isSink && n.audio)
    readonly property var sources: (Pipewire.nodes?.values ?? [])
        .filter(n => n && !n.isStream && !n.isSink && n.audio
                     && !String(n.name ?? "").endsWith(".monitor"))

    readonly property int  volume:    percentOf(sink)
    readonly property bool muted:     sink?.audio?.muted ?? false
    readonly property int  micVolume: percentOf(source)
    readonly property bool micMuted:  source?.audio?.muted ?? false

    // NB: phases 1–5 keep each caller's current rounding (floor vs round);
    // unifying it is a phase-6 fix.
    function percentOf(node) { return node?.audio ? Math.round(node.audio.volume * 100) : 0 }
    function setVolume(node, pct) { if (node?.audio) node.audio.volume = pct / 100 }
    function toggleMute(node)     { if (node?.audio) node.audio.muted = !node.audio.muted }
    function setDefaultSink(n)    { Pipewire.preferredDefaultAudioSink = n }
    function setDefaultSource(n)  { Pipewire.preferredDefaultAudioSource = n }

    function deviceLabel(node) {
        return String(node?.description || node?.nickname || node?.name || "?")
            .replace(/^sof-soundwire\s+/i, "").replace(/^built-?in audio\s+/i, "");
    }

    // one tracker for everyone (today: 4 trackers in 3 files)
    PwObjectTracker {
        objects: [root.sink, root.source].filter(Boolean).concat(root.sinks, root.sources)
    }
}
```

### 4.2 Others, same pattern

| Service | Absorbs |
|---|---|
| `Network` | `wifiDevice`, `ethernetDevice`, `connectedNetwork`, `signalStrength`, `restricted`, known/unknown lists (today in `Network.qml` + `WifiNetworkManager`) |
| `Bluetooth` | `adapter`, device groups (connected/paired/discovered), `connectedCount`, discovery keep-alive timer |
| `Battery` | UPower state booleans, `percentage`, `critical`, `changeRate` |
| `Media` | `activePlayer` + `lastPlaying` (today in `MediaPlayer`; `shell.qml` reaches into `mediaPlayer.activePlayer`) |
| `Vpn` | already a service — see §7 #13 |

Services are wired through bindings, e.g.
`Pill { visible: Media.activePlayer !== null; MediaIndicator {} }` — no child ids.

### 4.3 Icons in one place — `lib/icons.js`

Volume icons exist in Sound + OSD, bell icon 3×, BT icons 2×, VPN icons 3×,
forget-lock 2×, battery lists inline in `Power.qml`.

```js
// lib/icons.js
.pragma library   // ← missing in both current .js files → one copy per importing component

function bucket(value, max, n) {
    // clamped: today >100 % battery or NaN signal would index out of range
    return Math.max(0, Math.min(n - 1, Math.floor(value * (n - 1) / max)));
}

const volume = { loud: "…", quiet: "…", off: "…" };        // copy glyphs from Sound.qml
function volumeIcon(pct, muted) {
    if (muted || pct === 0) return volume.off;
    return pct < 70 ? volume.quiet : volume.loud;
}

const wifi       = [/* 5 glyphs from wifiUtils.js */];
const wifiSecure = [/* 5 glyphs */];
function wifiIcon(signal, secure) { return (secure ? wifiSecure : wifi)[bucket(signal, 100, 5)]; }

const batteryCharging    = [/* 10 glyphs from Power.qml */];
const batteryDischarging = [/* 10 glyphs */];
function batteryIcon(pct, charging) {
    const set = charging ? batteryCharging : batteryDischarging;
    return set[bucket(pct, 100, set.length)];
}

const bluetooth = { off: "󰂲", on: "󰂯", connected: "󰂱" };
const bell = { empty: "󰂚", unread: "󱅫" };
const vpn  = { on: "󰌆", off: "󰌊" };
const forget = "󰌸";
```

`getIntervalIndex.js` and its copy inside `wifiUtils.js` disappear
(typo `numberOfIntevals` in both).

---

## 5. Reusable primitives

### 5.1 `BarButton` — the 8× pattern

Every indicator (`Network`, `Sound`, `Bluetooth`, `Power`, `VpnStatus`,
`SunshineStatus`, `NotificationBell`, `PowerMenuItem`) is: RowLayout +
StatusIcon + TapHandler (+ right TapHandler) + HoverHandler(cursor) + Tooltip
with imperative `tooltip.visible = hovered` + popup child.

```qml
// components/BarButton.qml
import QtQuick
import QtQuick.Layouts
import qs.config

RowLayout {
    id: root

    property alias icon: glyph.text
    property alias iconSize: glyph.size
    property alias iconColor: glyph.color
    property string tooltip: ""
    property var popup: null             // anything with `visible`
    property bool clickable: true

    signal clicked()
    signal rightClicked()

    StatusIcon { id: glyph }

    TapHandler {
        enabled: root.clickable
        onTapped: root.popup ? (root.popup.visible = !root.popup.visible) : root.clicked()
    }
    TapHandler { acceptedButtons: Qt.RightButton; onTapped: root.rightClicked() }
    HoverHandler { id: hover; cursorShape: root.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor }

    // declarative + hidden while the popup is open (only VpnStatus does that today)
    Tooltip {
        anchorItem: root
        tooltipText: root.tooltip
        visible: hover.hovered && root.tooltip !== "" && !(root.popup?.visible ?? false)
    }
}
```

`Bluetooth.qml` goes from 97 → ~20 lines:

```qml
import Quickshell
import qs.components
import qs.services
import qs.modules.panels
import "../../lib/icons.js" as Icons

BarButton {
    id: root
    iconSize: 15
    icon: !Bluetooth.enabled ? Icons.bluetooth.off
        : Bluetooth.connectedCount > 0 ? Icons.bluetooth.connected : Icons.bluetooth.on
    tooltip: !Bluetooth.adapter ? "No Bluetooth adapter found"
           : !Bluetooth.enabled ? "Bluetooth disabled"
           : Bluetooth.connectedCount > 0 ? Bluetooth.connectedCount + " devices connected"
           : "No devices connected!"
    popup: panel
    onRightClicked: Quickshell.execDetached(Apps.bluetoothManager)

    BluetoothPanel { id: panel; anchorItem: root }
}
```

(Hidden-tooltip-while-popup-open is a tiny behaviour change for the other
indicators — acceptable, or gate it behind a property if strictness matters.)

### 5.2 `Panels` — central panel state + IPC

6× this block:

```qml
IpcHandler { target: "x"
    function toggle(): void { p.visible = !p.visible }
    function open(): void   { p.visible = true }
    function close(): void  { p.visible = false } }
```

plus `ShellState` exists only because ids aren't visible across files.

```qml
// services/Panels.qml
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property string current: ""   // "", "audio", "wifi", "bluetooth", "notifications", "home", "network"

    function isOpen(name) { return current === name }
    function toggle(name) { current = (current === name) ? "" : name }
    function open(name)   { current = name }
    function close(name)  { if (!name || current === name) current = "" }

    // same CLI surface as today: `qs ipc call wifi toggle` etc. keep working
    Instantiator {
        model: ["audio", "wifi", "bluetooth", "notifications", "home", "network"]
        delegate: IpcHandler {
            required property string modelData
            target: modelData
            function toggle(): void { root.toggle(modelData) }
            function open(): void   { root.open(modelData) }
            function close(): void  { root.close(modelData) }
        }
    }
}
```

> Verify `IpcHandler` inside `Instantiator` registers on 0.3.1 (`qs ipc show`).
> Fallback: six 1-line `PanelIpc { target: "wifi" }` instances of a tiny component.

`PopupPanel` hooks in:

```qml
// components/PopupPanel.qml (PopupBase + panelId)
property string panelId: ""
visible: panelId !== "" && Panels.current === panelId
// grab loss / Escape set visible=false internally → report back instead of breaking the binding
onVisibleChanged: if (!visible && panelId !== "") Panels.close(panelId)
function close() { panelId !== "" ? Panels.close(panelId) : (visible = false) }
```

Gains: `ShellState.audioPanelOpen` → `Panels.isOpen("audio")`; the OSD rule no
longer relies on `Sound.qml` remembering to set a flag; prerequisite for
multi-monitor (§8). Side effect: at most one panel open at a time (with
`grabFocus` that's effectively already the case — confirm).

### 5.3 `ModalOverlay` — HomeMenu & LanDevices are the same window

Both repeat: full-screen `PanelWindow`, backdrop `MouseArea` closer,
`HyprlandFocusGrab`, centered card (radius 14, 1 px foreground border),
click-absorbing `MouseArea`, Escape.

```qml
// components/ModalOverlay.qml
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import qs.config

PanelWindow {
    id: root
    property int cardWidth: -1           // -1 → size to content (HomeMenu), 660 for LanDevices
    property int padding: 18
    property alias spacing: body.spacing
    default property alias content: body.data
    signal closeRequested()

    anchors { top: true; bottom: true; left: true; right: true }
    focusable: true
    color: Theme.backdrop

    HyprlandFocusGrab { windows: [root]; active: root.visible; onCleared: root.closeRequested() }

    // MouseArea (not TapHandler) on purpose — exclusive grab; see docs/GOTCHAS.md
    MouseArea { anchors.fill: parent; onClicked: root.closeRequested() }

    Rectangle {
        anchors.centerIn: parent
        width: root.cardWidth > 0 ? root.cardWidth : body.implicitWidth + root.padding * 2
        height: body.implicitHeight + root.padding * 2
        color: Theme.background
        radius: Theme.radius.xl
        border { color: Theme.foreground; width: 1 }
        focus: true
        Keys.onEscapePressed: root.closeRequested()

        MouseArea { anchors.fill: parent }          // absorb card clicks

        ColumnLayout {
            id: body
            anchors.centerIn: parent
            width: root.cardWidth > 0 ? parent.width - root.padding * 2 : implicitWidth
        }
    }
}
```

### 5.4 `GhostButton` — the transparent→hover button (10+ copies)

`CloseButton`, calendar `<`/`>`, bell "Clear", wifi "Back"/"Connect", LAN
rescan, both action-button copies (toast + bell), home-menu rows.

```qml
// components/GhostButton.qml
import QtQuick
import QtQuick.Layouts
import qs.config

Rectangle {
    id: root
    property string icon: ""
    property string text: ""
    property int iconSize: Theme.fontSize.md
    property int textSize: Theme.fontSize.sm
    property bool bold: false
    property int hPadding: 8
    property color idleColor: "transparent"     // Theme.actionButton for notif actions
    property bool dimWhenIdle: true
    signal clicked()

    readonly property bool hovered: mouse.containsMouse
    readonly property color fg: (!dimWhenIdle || hovered) ? Theme.foreground : Theme.dimForeground

    implicitWidth: row.implicitWidth + hPadding * 2
    implicitHeight: 26
    radius: Theme.radius.sm
    color: hovered ? Theme.hoverOverlay : idleColor

    // the ONE place that encodes the MouseArea-vs-TapHandler lesson
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 4
        StyledText { visible: root.icon !== ""; text: root.icon; color: root.fg; font.pixelSize: root.iconSize; font.bold: root.bold }
        StyledText { visible: root.text !== ""; text: root.text; color: root.fg; font.pixelSize: root.textSize; font.bold: root.bold }
    }
}
```

```qml
// CloseButton.qml becomes
GhostButton { icon: "✕"; iconSize: 15; implicitWidth: 36; implicitHeight: 36 }

// calendar arrows
GhostButton { text: "<"; textSize: 13; bold: true; implicitWidth: 24; implicitHeight: 24
              onClicked: cal.shiftMonth(-1) }
```

`IconButton` fixes: `property var tapCallback` → `signal clicked()`
(idiomatic, `onClicked:` in HomeMenu); its Text has no `color` (renders black)
and no family — keep black for the look but make it explicit
(`color: Theme.black`); drop the `"xxxx"` default; drop the duplicate
HoverHandler cursor.

### 5.5 `NotificationCard` — toast and history are ~90 % identical

`NotificationToasts` delegate (150 lines) vs `NotificationBell` entry (135
lines): same card, different sizes; `iconSource` logic verbatim-duplicated,
action-button block duplicated.

```qml
// modules/notifications/NotificationCard.qml
Rectangle {
    id: root
    required property var notification
    property bool compact: false          // true = history list
    signal dismissRequested()
    signal actionInvoked()

    // exactly today's numbers, named
    readonly property var m: compact
        ? ({ icon: 20, glyph: 16, summary: 13, body: 12, app: 10, lines: 3, actH: 24, actFont: 11, actPad: 16, gap: 10 })
        : ({ icon: 34, glyph: 28, summary: 16, body: 15, app: 12, lines: 4, actH: 30, actFont: 13, actPad: 20, gap: 12 })

    readonly property bool critical: notification.urgency === NotificationUrgency.Critical
    readonly property string iconSource: Notif.iconSource(notification)   // lib/notif.js
    …
    NotificationActions { actions: root.notification.actions; buttonHeight: root.m.actH; … }
}
```

`Toasts.qml` / `NotificationCenter.qml` then only differ in their container
(fading ListView + timer vs. Flickable + header). Note the differing margins /
border / hover rules between the two — encode them in `m`, don't "harmonize".

### 5.6 Smaller primitives

| Component | Replaces |
|---|---|
| `SectionHeader { text: "OUTPUT" }` | ~12 header Texts (OUTPUT, INPUT, KNOWN, OTHERS, CONNECTED, PAIRED DEVICES, …) |
| `PanelHeader { title; default property alias trailing }` | header row + `Item { Layout.fillWidth }` + Toggle in Wifi/BT/Bell |
| `ScrollColumn { maxHeight: 400 }` | Flickable + ScrollBar policy + ColumnLayout (Wifi, Bell) |
| `DotsSpinner` | `●○○` frame animation in `ListItem` and `NetworkDevices` |
| `InkGlyph { text; opticalShift }` | the `TextMetrics.tightBoundingRect` centering, twice in `MediaPlayer` |
| `Slider` | the hand-rolled slider inside `AudioPanel`'s inline `VolumeRow` |
| `VpnList` | the VPN `Repeater { ListItem … }` in `VpnStatus` **and** `WifiNetworkManager` |
| `Pill { fixedWidth; verticalPadding }` | the hand-built `stayAwakePill` in `shell.qml` (see §7 #18) |

`ListItem` is good (Size/Status enums, metrics table). Only: make
`actionButton.visible` declarative
(`hoverHandler.hovered && root.actionIcon !== ""`) and use `DotsSpinner`.

---

## 6. Splitting the big files

- **`WifiNetworkManager.qml` (358 lines)** → the password flow
  (`passwordNetwork`, `passwordWasKnown`, `connectPending`, timeout,
  `Connections`, fail/cleanup) becomes `WifiPasswordView.qml`
  (`required property var network; signal done()`). The panel keeps
  header + list + VPN section. `required property var network` (the bar
  widget!) → `Network.*` service.
- **`Clock.qml` (202 lines)** → `Clock.qml` (~30) + `CalendarPopup.qml`;
  date math (`firstOfMonth`, `daysInMonth`, `mondayIndex`, `sameDay`) →
  `lib/dates.js`.
- **`NetworkDevices` + service** → `fuzzyScore` → `lib/fuzzy.js` (reusable for
  a launcher / polkit picker). The **55-line bash script in a template string**
  with `\$` escaping → `scripts/scan-lan.sh`:
  ```qml
  Process { command: ["bash", Quickshell.shellDir + "/scripts/scan-lan.sh"] … }
  ```
  shellcheck-able, runnable by hand, the "don't fix the backslashes" warning
  disappears. Drop unused `lastScanAt`.
- **`OSD.qml`** → `QtObject osdTypes` → real `enum Kind { Volume, Mute, Brightness, Mic }`;
  the six `contentLayout.getX()` functions → one computed `view` object:
  ```qml
  readonly property var view: {
      switch (kind) {
      case Osd.Brightness: return { icon: "…", pct: Brightness.percent, text: Brightness.percent + "%",
                                    color: Theme.foreground, fill: Theme.foreground, over: -1 };
      case Osd.Mic: …
      default: …   // Icons.volumeIcon(Audio.volume, Audio.muted)
      }
  }
  ```
  `contentLayout` sets `width: parent.width` **and** left/right anchors
  (conflict) — drop `width`.

---

## 7. Bugs & latent issues (fix in phase 6 unless purely internal)

| # | Where | Issue |
|---|---|---|
| 1 | `WifiNetworkManager` L52 | `if (visible && wifiDevice) … else { wifiDevice.scannerEnabled = false }` → TypeError on open/close without a wifi device |
| 2 | `WifiNetworkManager` L42 | `(allNetworks?.length === 0 ?? true)` — `===` yields a boolean, `?? true` is dead; `isConnecting` wrong when `allNetworks` undefined |
| 3 | `BluetoothManager` L168/172 | `bluetoothManager.adapter.discovering` without `?.` → throws without adapter (bindings evaluate even when parent hidden) |
| 4 | `Bluetooth.qml` L14 | `property bool enabled` **shadows `Item.enabled`** |
| 5 | `BluetoothDeviceItem` | `function onTapped()` *and* `onTapped: onTapped()` — function named like a handler; rename `handleTap()` |
| 6 | `Power.qml` `icon()` | returns `undefined` for `PendingCharge` / `Unknown` / `Empty` → bar shows **"undefined 80%"** (PendingCharge is common with charge thresholds) |
| 7 | `Power.qml`, `Sound.qml` | `getColor()`, `criticalColor`, `defaultColor`, `mutedColor` **never used** — critical battery color was never wired. Delete, or wire deliberately (visual change) |
| 8 | `HyprlandWorkspaces` L35 | `Hyprland.focusedWorkspace.id` unguarded → TypeError at startup |
| 9 | `HyprlandWorkspaces` L43 | uses `hl.dsp.focus({...})`; TODO says the `hl.dsp.exit()` form was *broken* and switched to plain `exit`. Verify and pick one convention |
| 10 | `NetworkDevices` L92 | `ipKey(a) < ipKey(b)` compares **arrays** (stringified) → `.10` sorts before `.9` |
| 11 | `Clock.qml` | `SystemClock.Seconds` but no seconds shown → 60× more re-evaluations; use `Minutes`. `isToday` uses non-reactive `new Date()` → stale after midnight; bind to `clock.date` |
| 12 | Sound/OSD vs AudioPanel | floor vs round → percentages differ by 1 (§4.1) |
| 13 | `VpnService` | `wg show interfaces` is a second truth next to the already-parsed `nmcli … ACTIVE` — derive `connected`/`interfaceName` from nmcli. `ip monitor link` fires `check()` (2 processes) on *every* link event → debounce (300 ms Timer) |
| 14 | `NotificationService.hideToast` | one dead notification wipes **all** toasts (`root.toasts = []`); toasts don't react to apps *retracting* a notification (`closed` signal). `hideToast`/`dismissToast` duplicate splice logic → `_removeToast(n)` |
| 15 | `NotificationService` | `doNotDisturb` resets on reload — persist via FileView+JsonAdapter like `StayAwakeService` |
| 16 | `AudioPanel` L46 | comment says overshoot "only for output", INPUT row sets `overshootEnabled: true` (intended per TODO) → fix comment |
| 17 | `WifiNetworkItem` | launches `nm-connection-editor`, which `~/dots/AGENTS.md` lists as **deliberately dropped** and which isn't in `packages/` — works here by accident |
| 18 | `stayAwakePill` in `shell.qml` | height = `icon.implicitHeight + 16` (≈33 px) vs `+8` for other pills — taller than the 30 px bar. **Not** a diagnosis of the "no gap" mystery, but a measurable fact to include in the next capture (only while stay-awake is on) |
| 19 | `shell.qml` | the "Layout.fillHeight removed…" comment pasted 4× — say it once in `Pill`/GOTCHAS |

---

## 8. Smaller quality points

- **Type properties**: `property PwNode sink`, `property BluetoothAdapter adapter`,
  `required property BluetoothDevice device` instead of `var` → qmlls
  completion + qmllint catches #1–#4.
- **`readonly property` over `function getX()` in bindings** (Power, Sound,
  OSD, Bluetooth, Network) — cached, declarative, explicit deps.
- **Tooltips**: 9× imperative `onHoveredChanged: tooltip.visible = hovered` →
  declarative (free with `BarButton`).
- **External commands** in `config/Apps.qml`
  (`lock: ["hyprlock"]`, `bluetoothManager: ["blueman-manager"]`, …) — one
  place to audit and swap.
- **Paths**: `Quickshell.env("HOME") + "/.cache/..."` 3× with the same NB
  comment → `Paths` singleton (respect `XDG_CACHE_HOME`, but keep
  `stay-awake.json` at the path hypridle's `suspend-or-skip.sh` greps).
- **Multi-monitor**: the bar is a single `PanelWindow`. `Variants { model: Quickshell.screens }`
  is only safe *after* IPC/state moved into singletons (§5.2), otherwise every
  monitor registers duplicate IPC targets.
- **Unused imports** (e.g. `Quickshell` in `Sound.qml`) — qmllint finds them.
- **`Toggle`**: `property var offsetCircle` → `real`; `customWidth` → `trackWidth`.

---

## 9. Docs & tooling

- **`TODO.md` is changelog + backlog + knowledge base at once.** The
  learned-the-hard-way items (QQC2 Slider not draggable in popups,
  `FileView.text` is a function, `StandardPaths.homeLocation` undefined,
  MouseArea vs TapHandler grabs, new root singletons need a full restart, OSD
  map/unmap kills popup grab, always-mapped toast window, nerd glyphs need
  `font.family`, PwObjectTracker must bind all nodes, imperative slider sync)
  → **`docs/GOTCHAS.md`**. TODO.md stays backlog only; git log is the changelog.
- **Lint**: `qmllint -I /usr/lib/qt6/qml **/*.qml` (or via qmlls) — as a
  `dots` subcommand or pre-commit hook.
- **Visual regression** — see §11.

---

## 10. Phases (each shippable and verifiable on its own)

1. **Baseline** — worktree, preview instance, screenshot harness, qmllint
   baseline, `docs/GOTCHAS.md`. No QML changes. ✅
2. **Tokens + `lib/*.js` (`.pragma library`) + `StyledText`** — mechanical;
   screenshot diff must be 0. ✅
3. **Services** (Audio, Network, Bluetooth, Battery, Media) **+ `Panels`**
   (keep IPC target names). ✅
4. **Primitives**: BarButton, GhostButton, ModalOverlay, NotificationCard,
   PopupPanel, small ones — replace duplicates file by file. ✅
5. **Folder move + renames** → `qs.*` imports (needs full `qs` restart for new singletons). ✅
6. **Bug fixes from §7 + deliberate visual changes** (rounding, undefined
   battery icon, font unification, critical color) — separate commits so the
   refactor's "looks identical" claim stays provable.

Expected: ~4.6k → ~3.0–3.3k lines; biggest wins bar indicators (−350),
notifications (−150), overlays (−80), IPC/state (−60).

---

## 11. Implementation workflow (live side-by-side preview)

### 11.1 Isolation

- Work happens in a **git worktree** of `~/dots` on branch `qs-refactor`:
  `git -C ~/dots worktree add ~/dots-qs-refactor -b qs-refactor`
- Refactored config lives at
  `~/dots-qs-refactor/stow/quickshell/.config/quickshell/`.
- The live shell (`~/.config/quickshell` → `~/dots/stow/...`) is **never touched**
  during the refactor. No stow runs. The stow fold (§1) happens at merge time.

### 11.2 Preview instance

A second quickshell instance runs the worktree config:

```bash
QS_PREVIEW=1 qs -p ~/dots-qs-refactor/stow/quickshell/.config/quickshell -d
```

- Quickshell hot-reloads it on every file save → the difference is visible
  immediately. (New `pragma Singleton` files need a restart of the preview:
  `qs -p <path> kill` then start again.)
- **Placement**: the preview bar is a second top-anchored layer surface with an
  exclusive zone → Hyprland stacks it **directly below** the live bar
  (y = 30). If it overlaps instead, add in the refactored `Bar.qml`:
  `margins.top: Quickshell.env("QS_PREVIEW") ? Theme.bar.height : 0`.
- **Preview-only suppressions** (gated on `Quickshell.env("QS_PREVIEW")`, to be
  removed before merge — keep them in ONE place, e.g. `config/Preview.qml`):
  - OSD disabled (otherwise two OSDs stack on every volume key)
  - `Theme.writeLockConf()` disabled (don't race the live shell on hyprlock.conf)
  - `StayAwake` must not write the flag file on startup
  - `NotificationService` must not write the DND state file (`~/.cache/quickshell/notifications.json`)
  - IPC targets are per-instance already (`qs ipc -p <path> call …` for the preview)
- **Known limitations**: only one process can own
  `org.freedesktop.Notifications` → the preview shows no toasts / history
  (test notifications by temporarily stopping the live shell, or at the end).
  Tray items register with both hosts — fine.

### 11.3 Verification per phase

```bash
P=~/dots-qs-refactor/stow/quickshell/.config/quickshell
shot() {  # $1 = before|after — captures live bar (y=0) and preview bar (y=30)
  grim -g "0,0 1920x30"  "/tmp/qs-$1-live.png"
  grim -g "0,30 1920x30" "/tmp/qs-$1-preview.png"
}
shot now
magick compare -metric AE /tmp/qs-now-live.png /tmp/qs-now-preview.png /tmp/qs-diff.png; echo
# popups (preview instance):
for p in audio wifi bluetooth notifications home network; do
  qs ipc -p "$P" call $p open; sleep 0.4; grim "/tmp/qs-preview-$p.png"; qs ipc -p "$P" call $p close
done
```

The live bar is the reference: preview − live should be 0 px (modulo the
clock minute and live data like tray/media). Also check `qs log -p "$P"` for
new warnings/TypeErrors after each phase.

### 11.4 Rules for the implementing agent

- Only edit inside `~/dots-qs-refactor/`. Never touch `~/.config/quickshell`,
  never run stow, never kill the live `qs` instance.
- One commit per phase (or per sub-step), message prefix `qs:`.
- Phases 1–5 must be visually identical; anything that changes pixels or
  behaviour goes to phase 6 and is listed in the commit message.
- Keep existing explanatory comments (the gotchas) — move them, don't drop them.
- Check the preview log after every step; zero new warnings.
- Stop and report after each phase with: diff summary, screenshot-diff result,
  new/removed warnings.
