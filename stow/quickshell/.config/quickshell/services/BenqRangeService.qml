pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

import qs.config

// BenQ RD320U behind the HDMI KVM needs "Broadcast RGB" = Limited, which only
// the manual `benq-fix` (sudo) can set and a reboot resets. `benq-fix --check`
// is the source of truth (no root, read-only): absent | needed | ok. Checked
// at start and whenever a monitor is added/removed — no polling.
Singleton {
    id: root

    readonly property string script: Paths.home + "/.local/bin/custom-commands/benq-fix"

    property string state: "absent"
    readonly property bool needed: root.state === "needed"

    function refresh() {
        if (checkProc.running) return;
        checkProc.running = true;
    }

    // Terminal for the sudo prompt; closing it re-checks so the icon goes away
    function fix() {
        if (fixProc.running) return;
        fixProc.command = Apps.terminalCommand(root.script);
        fixProc.running = true;
    }

    Component.onCompleted: root.refresh()

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "monitoraddedv2" || event.name === "monitorremovedv2")
                refreshSoon.restart();
        }
    }

    // the connector's EDID/status settle a moment after Hyprland's event
    Timer {
        id: refreshSoon
        interval: 2000
        onTriggered: root.refresh()
    }

    Process {
        id: checkProc
        command: [root.script, "--check"]
        stdout: StdioCollector {
            onStreamFinished: root.state = text.trim() || "absent"
        }
    }

    Process {
        id: fixProc
        onExited: root.refresh()
    }
}
