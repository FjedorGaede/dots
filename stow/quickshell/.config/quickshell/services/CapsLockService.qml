pragma Singleton

import QtQuick
import QtQml
import Quickshell
import Quickshell.Io

// Caps Lock state from the keyboard LEDs (/sys/class/leds/*capslock).
//
// Hyprland emits no event for lock keys and sysfs LED files don't support
// inotify, so the LEDs are polled. Every keyboard with a capslock LED gets
// its own FileView; Caps Lock counts as on when any of them is lit.
Singleton {
    id: root

    property bool on: false
    property var ledPaths: []

    // Resolve the LED files once (input numbers differ between boots)
    Process {
        running: true
        command: ["sh", "-c", "ls -d /sys/class/leds/*capslock 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: root.ledPaths = text.split("\n").filter(p => p !== "")
                .map(p => p + "/brightness")
        }
    }

    Instantiator {
        id: leds
        model: root.ledPaths
        delegate: FileView {
            required property string modelData
            path: modelData
            blockLoading: true
            printErrors: false
        }
    }

    Timer {
        interval: 150
        repeat: true
        running: root.ledPaths.length > 0
        onTriggered: {
            let lit = false;
            for (let i = 0; i < leds.count; i++) {
                const led = leds.objectAt(i);
                led.reload();
                if (led.text().trim() !== "0") lit = true;
            }
            root.on = lit;
        }
    }
}
