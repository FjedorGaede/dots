pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

import qs.config

// System update health for the bar's update indicator: stale system (last
// completed `pacman -Syu` ≥ 7 days ago, red from 14), broken mirror, or a
// pending reboot after a kernel update. scripts/updates-check.sh is the source
// of truth (no root, read-only — checkupdates syncs into a temp db). Checked
// 60s after start (network up), every 2h, and after the update terminal closes.
Singleton {
    id: root

    readonly property string script: Quickshell.shellPath("scripts/updates-check.sh")

    readonly property int warnDays: 7
    readonly property int alertDays: 14

    property int updates: 0
    property int days: -1          // -1: no completed -Syu in the log
    property string mirror: "ok"   // ok | error | offline
    property bool reboot: false

    // -1 with pending updates counts as stale (log rotated / fresh install)
    readonly property bool stale: root.updates > 0 && (root.days < 0 || root.days >= root.warnDays)
    readonly property bool mirrorBroken: root.mirror === "error"
    readonly property bool needsAction: root.stale || root.mirrorBroken || root.reboot
    readonly property bool critical: root.mirrorBroken || (root.stale && (root.days < 0 || root.days >= root.alertDays))

    function refresh() {
        if (checkProc.running) return;
        checkProc.running = true;
    }

    // Mirror broken → re-rank mirrors first (stale mirrorlist is the usual
    // cause of 404s), then the full upgrade. Reboot alone → only a hint.
    function act() {
        if (!root.stale && !root.mirrorBroken) {
            if (root.reboot)
                Apps.notify("Reboot pending", "The kernel was updated — reboot to load it.");
            return;
        }
        if (updateProc.running) return;
        const cmd = root.mirrorBroken
            ? "sudo cachyos-rate-mirrors && sudo pacman -Syu"
            : "sudo pacman -Syu";
        updateProc.command = Apps.floatingTerminalCommand(cmd);
        updateProc.running = true;
    }

    function parse(text) {
        for (const line of text.split("\n")) {
            const f = line.split("\t");
            if (f.length < 2) continue;
            switch (f[0]) {
            case "updates": root.updates = parseInt(f[1]) || 0; break;
            case "days":    root.days = parseInt(f[1]); break;
            case "mirror":  root.mirror = f[1]; break;
            case "reboot":  root.reboot = f[1] === "1"; break;
            }
        }
    }

    Process {
        id: checkProc
        command: [root.script]
        stdout: StdioCollector {
            onStreamFinished: root.parse(text)
        }
    }

    Process {
        id: updateProc
        onExited: root.refresh()
    }

    Timer {
        interval: 60 * 1000
        running: true
        onTriggered: root.refresh()
    }

    Timer {
        interval: 2 * 60 * 60 * 1000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }
}
