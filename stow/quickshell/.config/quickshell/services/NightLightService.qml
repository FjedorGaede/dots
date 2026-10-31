pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Night light (blue-light filter) via hyprsunset (started in hypr/autostart.lua).
// The schedule lives in hypr/hyprsunset.conf (warm 19:00–7:00); the toggle
// here is a manual override that holds until the next scheduled switch.
//
// hyprsunset emits no events, so its state is polled (`identity get` →
// "true" = normal colors, "false" = warm). If hyprsunset isn't running,
// hyprctl prints an error instead → `available` goes false.
Singleton {
    id: root

    // Same value as the evening profile in hypr/hyprsunset.conf
    readonly property int warmTemperature: 4500

    property bool available: false
    property bool on: false

    function setOn(warm) {
        root.on = warm; // optimistic, the next poll corrects it
        Quickshell.execDetached(warm
            ? ["hyprctl", "hyprsunset", "temperature", String(root.warmTemperature)]
            : ["hyprctl", "hyprsunset", "identity", "true"]);
    }

    function toggle() { setOn(!root.on) }

    // Back to whatever the schedule says right now
    function resetToSchedule() {
        Quickshell.execDetached(["hyprctl", "hyprsunset", "reset"]);
        poll.restart();
    }

    Process {
        id: identityProc
        command: ["hyprctl", "hyprsunset", "identity", "get"]
        stdout: StdioCollector {
            onStreamFinished: {
                const t = text.trim();
                root.available = t === "true" || t === "false";
                if (root.available) root.on = t === "false";
            }
        }
    }

    Timer {
        id: poll
        interval: 30000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: if (!identityProc.running) identityProc.running = true
    }

    // `qs ipc call nightlight <on|off|toggle|reset|status>`
    IpcHandler {
        target: "nightlight"

        function on(): void     { root.setOn(true) }
        function off(): void    { root.setOn(false) }
        function toggle(): void { root.toggle() }
        function reset(): void  { root.resetToSchedule() }
        function status(): string { return root.on ? "1" : "0" }
    }
}
