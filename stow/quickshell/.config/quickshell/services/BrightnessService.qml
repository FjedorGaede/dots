pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property int percent: -1
    property int value: -1
    property int max: -1
    property bool ready: false

    function _readBrightness() {
        readProc.running = true
    }

    function parseBrightnessData(data) {
        const parts = data.trim().split(",")
        root.value = parseInt(parts[2])
        root.max = parseInt(parts[4])
        root.percent = parseInt(parts[3].slice(0, -1))
        root.ready = true
    }

    Process {
        id: readProc
        command: ["brightnessctl", "-m"]
        stdout: SplitParser {
            onRead: data => root.parseBrightnessData(data)
        }
    }

    Process {
        running: true
        command: ["udevadm", "monitor", "--subsystem-match=backlight", "--udev"]
        stdout: SplitParser {
            onRead: _ => root._readBrightness()
        }
    }

    Component.onCompleted: _readBrightness()
}
