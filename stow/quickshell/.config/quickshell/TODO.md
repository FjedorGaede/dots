# TODO

## Done (2026-09 session)

- [x] Network/Bluetooth robustness pass (null-safety, toggle binding fixes, native
      `pair()` / `connectWithPsk()`, busy states, signal sorting, captive-portal icon,
      ethernet support, BT battery %, wrong-password cleanup, auto discovery)
- [x] Removed dead files (`wifi.sh`, `WifiPasswordPrompt.qml`)
- [x] StatusIcon centering (pill spacing asymmetry)
- [x] Placeholder letter-spacing in wifi password field
- [x] Native notifications replacing swaync (`NotificationService`, `NotificationToasts`,
      `NotificationBell`, `CloseButton`) — toast fading, history, DND, IPC (`notifications toggle`),
      critical styling, avatar/image support (`image` hint), icon-name resolution
      via `Quickshell.iconPath()`
- [x] swaync removed from Hyprland autostart; Super+Shift+N bound to the new popup
- [x] Fixed `Toggle` signal clash (`toggled` → `userToggled`)

## Bugs (log noise / small)

- [x] `Sound.qml` / `OSD.qml`: `TypeError: Cannot read property 'audio' of null`
      — guarded (`defaultSink?.audio`, fallback 0/false)
- [x] `ListItem.qml` (~line 127): removed invalid write to global property `accepted`
      in the actionButton TapHandler
- [x] `Theme.qml`: pywal FileView initially removed (parse errors), then
      RESTORED properly (2026-09, user wants pywal) — see theme layering below
- [x] `OSD.qml` (line 9): `height` → `implicitHeight`
- [x] Removed `dangling wal watcher` noise: wal integration kept — see theme
      layering under "Next up"

## Small features

- [x] IPC for the wifi & bluetooth popups (like `notifications toggle`) —
      `qs ipc call wifi|bluetooth toggle|open|close`; no Hyprland keybinds (not wanted)
- [x] Audio peak metering: `PwNodePeakMonitor` — thin live level bar under the
      volume bar in the OSD, red when clipping; monitor only enabled while the
      OSD is visible
- [ ] (POSTPONED 2026-09 — not wanted for now) Idle inhibitor indicator:
      wayland idle inhibitor (0.3.0) as a bar toggle ("stay awake" while
      watching/presenting). Quickshell.Wayland.IdleInhibitor { window, enabled }
      attached to the bar window would be the whole implementation.
- [x] Notification actions: `actionsSupported: true` + action buttons (capped
      at 3) in toast + history via `action.invoke()`; toast body tap invokes the
      "default" action when the app provides one, otherwise dismisses
- [x] Notification inline replies: implemented, then REMOVED by decision
      (2026-09) — toast inputs lose focus on every new notification and the
      feature felt useless; `inlineReplySupported` is off again. Action
      buttons were kept instead (brightened: `Theme.color0` bg, bold text).
- [x] Wifi tooltip (band/frequency): dropped by decision (2026-09) — not wanted

## Next up (2026-09 session, agreed scope) — order: B → C → D → A

- [x] **Theme layering (2026-09)** — 3 layers: static Catppuccin fallback →
      pywal (`~/.cache/wal/colors.json`, live-watched, parse-guarded) →
      `theme/overrides.json` (user: fixed hex = keep mine, `"colorN"` = follow
      scheme; drives `mainAccent`/`highlight`). Resolved accent exported to
      `~/.cache/quickshell-theme/hyprlock.conf` (`$qs_accent`/`$qs_highlight`),
      sourced by hyprlock.conf; input-field `outer_color` now uses the accent.
      Wal color0–15/background/foreground/cursor now flow into the bar too.
      GOTCHA (why this never worked before): `StandardPaths.homeLocation` is
      undefined in QML — the original March FileView silently read from
      `undefined/.cache/wal/colors.json` and always fell back. Also FileView
      `.text` is a function here, not a property. Verified live with
      `wal -l --theme catppuccin-latte`.
- [x] Calendar popup on the clock — right-click opens a month calendar
      (custom Grid + Date math, Qt6 has no calendar widget): Monday-first
      locale-aware weekday header, < / > month navigation with robust month
      names, today highlighted with accent, adjacent-month days shown dimmed.
      NOTE: was briefly lost when a stow run overwrote the live file with the
      old repo version — rewritten directly into the stow repo.
- [ ] **B. Icon polish pass** — unify bar icon sizes (14px baseline: Sound 13,
      Bluetooth 15, battery 13 today); fix `IconButton` unset text color (renders
      black) + hover state; remove Power.qml `" "` spacing hack; OSD fallback
      icon is literal `"xxx"`; audit right-side bar row paddings
- [ ] **C. Power menu** — wire up real shutdown (currently a `console.warn`
      stub!); two-click confirm for shutdown/reboot (button switches to
      checkmark state); styling: labels under icons, no harsh full-opacity
      1px border
- [x] **D. OSDs (2026-09)** — mic-mute OSD added (`XF86AudioMicMute`, shows
      mic icon + percent, red accents when muted, tracks `defaultAudioSource`);
      single volume bar with the peak meter now drawn as a translucent overlay
      INSIDE the bar (second bar removed); percentage text right of the bar
      ("75%" / "Muted"), also for brightness; hide timer 1s→1.4s
- [ ] OSD leftovers — review the 1s `audioReady` delay hack (startup noise
      guard) and "xxx" fallback icon in getIcon()
- [x] Notification toasts too small to read comfortably — bumped ~20–25%:
      width 340→420, summary 13→16, body 12→15, appName 10→12, icon 26→34,
      action buttons 24→30 tall / 11→13 font, CloseButton 30→36
- [x] **A. Media player widget** — done, see below

- [x] **A. Media player widget (2026-09)** — `MediaPlayer.qml` in a BarElement
      right of the clock: play/pause glyph + "Artist – Title" (MPRIS via
      `Quickshell.Services.Mpris`), prefers the playing player, hidden when no
      player. Left-click play/pause, scroll next/prev, right-click raise.
      Based on omarchy's waybar media module.
- [ ] **A2. Media player popup (ideas)** — album art, seekable progress bar,
      full controls, player picker when multiple players are running

## Bigger ideas (omarchy-inspired)

- [ ] Network panel: header stats — throughput, ping/latency, packet loss
      (omarchy polls `/proc/net/dev` + `ping`, slow poll ~4s)
- [ ] Network panel: wifi band selector (pin 2.4/5 GHz)
- [ ] Network panel: DNS provider selection
- [ ] Bluetooth panel: per-device action verification (omarchy-style
      "connecting…/forgetting…" state tracking that confirms BlueZ actually
      applied the action)
- [ ] Bluetooth pairing agent for numeric-comparison devices (phones/keyboards):
      native confirm dialog would need a D-Bus agent (~200 lines) — currently
      such devices fail silently; interim fix: run `blueman-agent` in background
- [ ] Native polkit agent (0.3.0 Polkit support) — replace hyprpolkitagent
      someday for full visual consistency
      ASSESSMENT (2026-09): easy. Quickshell exposes the whole flow as a QML
      type — properties: message, iconName, actionId, identities/selectedIdentity,
      isResponseRequired, inputPrompt, supplementaryMessage/IsError (wrong
      password), isSuccessful/isCancelled/failed; invokables: submit(value),
      cancelAuthenticationRequest(). No D-Bus/security work needed. Build only
      the dialog (~150–250 lines): reuse the wifi password TextField + Back/
      Connect buttons + ListItem identity picker. Migration: instantiate agent
      in shell.qml, then remove the hyprpolkitagent line from autostart.lua
      (only one agent may be registered). CAVEAT: this is the security-critical
      dialog — must be unambiguous and never be broken/mid-reload when sudo
      fires. Swap only after some real-world testing, keep hyprpolkitagent
      until then.
