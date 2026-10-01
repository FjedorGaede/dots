pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

import qs.config

// Idle handling — replaces hypridle. EVERYTHING idle-related lives in this
// file: timings, commands, stay-awake, lock-before-sleep, wake-up.
//
//   idle  dimAfter        → dim the backlight   (restored on activity)
//   idle  lockAfter       → lock (hyprlock)
//   idle  screenOffAfter  → screens off          (back on on activity)
//   idle  suspendAfter    → suspend — skipped while "stay awake" is on
//   system about to sleep → lock first (lid, Suspend button, systemctl …)
//   system woke up        → screens on
//   `loginctl lock-session` → lock
//   D-Bus "don't go idle" (browsers playing video, VLC, Steam, gamemode,
//     SDL/XWayland games, portal)  → all steps paused (scripts/screensaver-inhibit.py)
//   Wayland idle inhibitors (mpv, fullscreen games via window rule) → paused too
//
// NB: lock-before-sleep works by holding a logind *delay* inhibitor
// (systemd-inhibit) and releasing it once the lock is up — the same trick
// hypridle uses. See docs/GOTCHAS.md → Idle.
Singleton {
    id: root

    // ── Settings ─────────────────────────────────────────────────────────
    // Seconds of inactivity. 0 disables a step.
    readonly property int dimAfter:       240   //  4 min
    readonly property int lockAfter:      300   //  5 min
    readonly property int screenOffAfter: 360   //  6 min
    readonly property int suspendAfter:   600   // 10 min

    // Backlight level while dimmed (brightnessctl value; not 0 → OLED)
    readonly property string dimBrightness: "10"

    // Apps holding a Wayland idle inhibitor (fullscreen video, calls, …)
    // postpone all steps
    readonly property bool respectInhibitors: true

    // Honour D-Bus inhibit requests (org.freedesktop.ScreenSaver /
    // PowerManagement) — hypridle did this too
    readonly property bool respectDbusInhibitors: true

    // Commands
    readonly property var lockCmd:      ["sh", "-c", "pidof hyprlock || hyprlock"]
    readonly property var dimCmd:       ["brightnessctl", "-s", "set", root.dimBrightness]
    readonly property var undimCmd:     ["brightnessctl", "-r"]
    // Lua config: hyprctl dispatch takes an hl.dsp.* expression (GOTCHAS → Hyprland)
    readonly property var screenOffCmd: ["hyprctl", "dispatch", 'hl.dsp.dpms({ action = "off" })']
    readonly property var screenOnCmd:  ["hyprctl", "dispatch", 'hl.dsp.dpms({ action = "on" })']
    readonly property var suspendCmd:   ["systemctl", "suspend"]

    // How long to hold back sleep after starting the lock, so hyprlock is
    // mapped before the machine sleeps (logind caps this at InhibitDelayMaxSec, 5 s)
    readonly property int lockBeforeSleepDelay: 1000
    // ─────────────────────────────────────────────────────────────────────

    // Singletons are created lazily — shell.qml calls this once at startup
    function start() {}

    function lock() { Quickshell.execDetached(root.lockCmd) }

    // Dim / screen-off with state, so an inhibit arriving mid-cycle can undo them safely
    // (brightnessctl -r without a preceding -s would restore a stale value)
    property bool _dimmed: false
    property bool _screenOff: false
    function dim()       { if (!_dimmed)    { _dimmed = true;     Quickshell.execDetached(root.dimCmd) } }
    function undim()     { if (_dimmed)     { _dimmed = false;    Quickshell.execDetached(root.undimCmd) } }
    function screenOff() { if (!_screenOff) { _screenOff = true;  Quickshell.execDetached(root.screenOffCmd) } }
    function screenOn()  { if (_screenOff)  { _screenOff = false; Quickshell.execDetached(root.screenOnCmd) } }

    function suspend() {
        if (StayAwakeService.enabled) {
            Apps.notify("Stay awake", "Suspend skipped — stay-awake is on");
            return;
        }
        Quickshell.execDetached(root.suspendCmd);
    }

    // ── Idle steps ──

    IdleMonitor {
        enabled: root.dimAfter > 0 && !root.inhibited
        timeout: root.dimAfter
        respectInhibitors: root.respectInhibitors
        onIsIdleChanged: isIdle ? root.dim() : root.undim()
    }

    IdleMonitor {
        enabled: root.lockAfter > 0 && !root.inhibited
        timeout: root.lockAfter
        respectInhibitors: root.respectInhibitors
        onIsIdleChanged: if (isIdle) root.lock()
    }

    IdleMonitor {
        enabled: root.screenOffAfter > 0 && !root.inhibited
        timeout: root.screenOffAfter
        respectInhibitors: root.respectInhibitors
        onIsIdleChanged: isIdle ? root.screenOff() : root.screenOn()
    }

    IdleMonitor {
        enabled: root.suspendAfter > 0 && !root.inhibited
        timeout: root.suspendAfter
        respectInhibitors: root.respectInhibitors
        onIsIdleChanged: if (isIdle) root.suspend()
    }

    // ── Lock before sleep / wake-up (logind) ──

    // Delay inhibitor: logind waits for us (≤ 5 s) before sleeping. Held
    // while awake, released right after the lock started, re-taken on wake.
    Process {
        id: sleepInhibitor
        running: true
        command: ["systemd-inhibit", "--what=sleep", "--mode=delay",
                  "--who=quickshell", "--why=Lock the screen before sleep",
                  "sleep", "infinity"]
    }

    Timer {
        id: releaseInhibitor
        interval: root.lockBeforeSleepDelay
        onTriggered: sleepInhibitor.running = false
    }

    // logind signals, e.g.
    //   /org/freedesktop/login1: org.freedesktop.login1.Manager.PrepareForSleep (true,)
    //   /org/freedesktop/login1/session/_32: org.freedesktop.login1.Session.Lock ()
    Process {
        id: logindMonitor
        running: true
        command: ["gdbus", "monitor", "--system", "--dest", "org.freedesktop.login1"]
        stdout: SplitParser {
            onRead: line => {
                if (line.includes(".Manager.PrepareForSleep (true")) {
                    root.lock();
                    releaseInhibitor.restart();
                } else if (line.includes(".Manager.PrepareForSleep (false")) {
                    root._screenOff = false;
                    Quickshell.execDetached(root.screenOnCmd);
                    sleepInhibitor.running = true;
                } else if (line.includes(".Session.Lock ()")) {
                    // `loginctl lock-session(s)` — single-user machine, so any session
                    root.lock();
                }
            }
        }
        // gdbus should never exit; if it does, come back
        onExited: restartMonitor.restart()
    }

    Timer {
        id: restartMonitor
        interval: 2000
        onTriggered: logindMonitor.running = true
    }

    // ── D-Bus idle inhibitors ──
    // IdleMonitors are disabled while inhibited; re-enabling them restarts
    // their countdown from zero. An already-fired lock is left alone.
    property int dbusInhibitors: 0
    property string dbusInhibitorApps: ""
    readonly property bool inhibited: root.respectDbusInhibitors && root.dbusInhibitors > 0

    onInhibitedChanged: {
        console.info("IdleService: " + (inhibited
            ? "inhibited by " + (dbusInhibitorApps || "?") : "no longer inhibited"));
        if (inhibited) { root.undim(); root.screenOn(); }
    }

    Process {
        id: dbusInhibit
        running: true
        command: ["python3", Quickshell.shellPath("scripts/screensaver-inhibit.py")]
        stdout: SplitParser {
            // "inhibitors <count> <app>, <app>, …"
            onRead: line => {
                const m = /^inhibitors (\d+) ?(.*)$/.exec(line);
                if (!m) return;
                root.dbusInhibitorApps = m[2];
                root.dbusInhibitors = parseInt(m[1]);
            }
        }
        stderr: SplitParser { onRead: line => console.info("screensaver-inhibit: " + line) }
        onExited: (code) => {
            root.dbusInhibitors = 0;
            // exit 0 = someone else owns the names → don't fight over them
            if (code !== 0) restartDbusInhibit.restart();
        }
    }

    Timer {
        id: restartDbusInhibit
        interval: 5000
        onTriggered: dbusInhibit.running = true
    }
}
