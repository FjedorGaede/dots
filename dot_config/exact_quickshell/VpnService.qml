pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool connected: false
    property string interfaceName: ""
    property var connections: []  // [{name: "wg0", active: true}, ...]

    property bool _gotOutput: false

    function check() {
        root._gotOutput = false
        checkProc.running = true
        listProc.running = true
    }

    function connect(name) {
        connectProc.command = ["nmcli", "connection", "up", name]
        connectProc.running = true
    }

    function disconnect(name) {
        disconnectProc.command = ["nmcli", "connection", "down", name]
        disconnectProc.running = true
    }

    Process {
        id: checkProc
        command: ["wg", "show", "interfaces"]
        stdout: SplitParser {
            onRead: data => {
                const trimmed = data.trim()
                if (trimmed.length > 0) {
                    root._gotOutput = true
                    root.connected = true
                    root.interfaceName = trimmed.split("\n")[0] ?? ""
                }
            }
        }
        onExited: (code, status) => {
            if (!root._gotOutput || code !== 0) {
                root.connected = false
                root.interfaceName = ""
            }
        }
    }

    property var _parsedConnections: []

    Process {
        id: listProc
        command: ["nmcli", "-t", "-f", "NAME,TYPE,ACTIVE", "connection", "show"]
        stdout: SplitParser {
            onRead: data => {
                const parts = data.split(":")
                if (parts[1] === "wireguard") {
                    root._parsedConnections.push({
                        name: parts[0],
                        active: parts[2] === "yes"
                    })
                }
            }
        }
        onExited: {
            root.connections = root._parsedConnections
            root._parsedConnections = []
        }
    }

    Process {
        id: connectProc
    }

    Process {
        id: disconnectProc
    }

    // Watch for network link changes (interface up/down events)
    Process {
        running: true
        command: ["ip", "monitor", "link"]
        stdout: SplitParser {
            onRead: _ => root.check()
        }
    }

    Component.onCompleted: check()
}
