pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool running: false

    function check() {
        checkProc.running = true
    }

    function stop() {
        stopProc.running = true
    }

    Process {
        id: checkProc
        command: ["pgrep", "-x", "sunshine"]
        onExited: (code, status) => {
            root.running = (code === 0)
        }
    }

    Process {
        id: stopProc
        command: ["pkill", "-x", "sunshine"]
        onExited: root.check()
    }

    // Poll every 5 seconds
    Timer {
        running: true
        interval: 5000
        repeat: true
        onTriggered: root.check()
    }

    Component.onCompleted: check()
}