pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

// Active portal screen shares (Meet, Slack, Discord, OBS, ...). Every share
// is a PipeWire video node owned by xdg-desktop-portal-hyprland — Chromium's
// share-dialog preview counts too, it is a real capture.
Singleton {
    id: root

    readonly property var nodes: (Pipewire.nodes?.values ?? []).filter(
        n => n && n.name === "xdg-desktop-portal-hyprland")
    readonly property int count: nodes.length
    readonly property bool active: count > 0

    // Stops ALL shares: Chromium via its own "Stop sharing" bar, everything
    // else by cutting the PipeWire stream (scripts/screenshare-stop.sh)
    function stop() {
        if (!active || stopProc.running) return;
        stopProc.running = true;
    }

    Process {
        id: stopProc
        command: ["bash", Quickshell.shellPath("scripts/screenshare-stop.sh")]
    }
}
