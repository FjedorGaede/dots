# TODO

## Done (2026-09 session, later)

- [x] **Stay awake / home menu (2026-09)** — power menu became a home menu:
      "Stay awake" toggle row on top (coffee cup + on/off state, click toggles
      + closes), divider, power buttons below (shrunk 72→56, glyph now scales
      with button size). Implementation: `StayAwakeService.qml` singleton with
      file-backed flag (`~/.cache/quickshell/stay-awake.json`, JsonAdapter,
      survives reloads) + hourly reminder notification; hypridle suspend
      listener now runs `scripts/suspend-or-skip.sh` which greps the flag and
      skips suspend with a notification (IdleInhibitor idea dropped — hypridle
      uses ext-idle-notify and ignores Wayland inhibitors). Coffee-cup bar
      indicator (StatusBar) only while on, click = off. NOTE: new files must
      be created in the stow repo + manually symlinked (relative depth differs
      per directory!); new root-level pragma Singletons only register after a
      full `qs` restart, not on hot reload.

- [x] Media pill empty state — `BarElement` wrapper in shell.qml now hides with
      the `MediaPlayer` (`visible: mediaPlayer.activePlayer !== null`), so no
      empty pill is left next to the clock when nothing is playing
- [x] Power menu buttons dead (click = menu just closed) — `IconButton`'s
      passive `TapHandler` was canceled by the card click-absorber `MouseArea`'s
      exclusive grab; replaced with a `MouseArea` (exclusive grab, button stacked
      above the absorber wins). Removed the redundant full-screen `Item` +
      `TapHandler` closer (backdrop `MouseArea` + Escape remain); DEBUG text and
      console.log lines removed

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

- [ ] **UNEXPLAINED: "no gap below the tray" / mystery CPU-RAM strip (2026-09)**
      USER-OBSERVED, CAUSE UNKNOWN. Do not re-diagnose from the armchair —
      capture state when it is visible:
      `sh -c 'grim /tmp/state.png; hyprctl layers > /tmp/layers.txt; hyprctl clients -j > /tmp/clients.json'`
      Facts established so far:
      - User repeatedly sees (screenshots 22:04, 22:15, 22:35, 22:40): no
        vertical gap between the bar's right side (tray/system-stats pills) and
        the window below; left side (workspaces/clock/media) shows a gap. Also
        a strip of colored pills (CPU %, RAM, date-time, battery) below the
        bar on the right side in some screenshots.
      - After removing `Layout.fillHeight` from the right-side BarElements:
        tray icon glyphs y12–27 vs workspaces y11–24 (physical px) — pills
        measured centered and symmetric.
      - Bar layer verified 1920x30 logical (full width at scale 1.333);
        tiled windows start at y=30; only 2 quickshell layer surfaces exist
        (bar + toasts/popup window at 1476,68 436x700); single qs instance.
      - Ruled out: waybar/conky/eww/astal processes, second quickshell
        instance, any CPU/RAM element in the config (none exists).
      - The colored strip's origin is UNCONFIRMED. Candidate explanations
        offered during the session (tmux status line, waybar, reload
        artifacts) were REJECTED by the user or did not hold up. Treat all
        prior theories as unproven.

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
- [x] **Own audio control panel (2026-09, v1)** — replaced pavucontrol on the
      Sound bar icon. `AudioPanel.qml` (PopupBase anchored to the Sound icon,
      also `qs ipc call audio toggle|open|close`): OUTPUT/INPUT sections, each
      with volume slider + mute button + device picker (active device =
      ListItem.Active ✓, click switches via `Pipewire.preferredDefaultAudioSink
      /Source`; monitor sources filtered out).
      GOTCHAS (all learned the hard way):
      - QQC2 Slider is NOT draggable inside quickshell popup windows — use a
        hand-rolled MouseArea slider (like omarchy quattro's PanelSlider)
      - Slider sync must be imperative (no binding on `value` — it snaps back)
      - PwObjectTracker must bind all candidate nodes (properties invalid
        otherwise)
      - OSD is suppressed while the panel is open (`ShellState.audioPanelOpen`
        singleton): OSD map/unmap churn dismisses the grabFocus popup ~1.4s
        after a drag
      - Mute glyph variants have different advance widths → fixed 22px hit box
        so toggling mute doesn't push the slider
      - Mute must NOT gray the slider (red glyph shows state); mic boost >100%
        is normal, so overshoot coloring is on both rows, red zone is only
        15% opacity
      Per-app streams postponed. pavucontrol still installed but unused.
      Reference: omarchy quattro `shell/plugins/panels/audio` (MIT, Model.js
      logic cribbed); omarchy master's answer is the wiremix TUI.
- [ ] **B. Icon polish pass** — unify bar icon sizes (14px baseline: Sound 13,
      Bluetooth 15, battery 13 today); fix `IconButton` unset text color (renders
      black) + hover state; remove Power.qml `" "` spacing hack; OSD fallback
      icon is literal `"xxx"`; audit right-side bar row paddings
- [x] **C. Power menu (2026-09)** — shutdown wired up (was a `console.warn`
      stub!); two-click confirm for reboot/shutdown (button → check mark + red
      for 3s, second click executes, other clicks/close disarms); also fixed
      broken exit action (`hyprctl dispatch "hl.dsp.exit()"` → `exit`).
      Design intentionally unchanged — user likes it.
- [x] **D. OSDs (2026-09)** — mic-mute OSD added (`XF86AudioMicMute`, shows
      mic icon + percent, red accents when muted, tracks `defaultAudioSource`);
      single volume bar with the peak meter now drawn as a translucent overlay
      INSIDE the bar (second bar removed); percentage text right of the bar
      ("75%" / "Muted"), also for brightness; hide timer 1s→1.4s
- [ ] OSD leftovers — review the 1s `audioReady` delay hack (startup noise
      guard); gap between bar and percent text (fixed-width box = stable size
      but visible dead space)
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

- [ ] Evaluate walker + elephant — walker is the current launcher (Super+D,
      `shared.lua: menu = "walker"`), rofi handles smart search. Question: do
      we actually need walker (and its elephant backend daemon) at all, or is
      rofi/fuzzel/anyrun enough? If keeping walker: does it still need
      elephant running, or do the used features work without it?
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
