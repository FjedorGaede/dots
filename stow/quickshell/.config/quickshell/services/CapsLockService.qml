pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Caps Lock state from Hyprland's main keyboard (`hyprctl devices -j`), the
// same source end-4 / omarchy use. Hyprland emits no event for lock keys, so
// it's polled. (The old /sys/class/leds approach broke on dock reconnects:
// the keyboard got a new inputN, the watched LED file vanished and the empty
// read counted as "on".)
Singleton {
    id: root

    property bool on: false

    Process {
        id: devicesProc
        command: ["hyprctl", "devices", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const kbs = JSON.parse(text).keyboards ?? [];
                    const main = kbs.find(k => k.main) ?? kbs[0];
                    root.on = main?.capsLock ?? false;
                } catch (e) {
                    // Half-read / hyprctl error → keep the current state
                }
            }
        }
    }

    Timer {
        interval: 300
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: if (!devicesProc.running) devicesProc.running = true
    }
}
