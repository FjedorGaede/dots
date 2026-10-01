pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // Derived from the nmcli WireGuard list (one source of truth): connected
    // = a WireGuard profile is active, interfaceName = its device (e.g. wg0)
    readonly property var activeConnection: connections.find(c => c.active) ?? null
    readonly property bool connected: activeConnection !== null
    readonly property string interfaceName: activeConnection?.device ?? ""
    property var connections: []  // [{name: "wg0", active: true, device: "wg0"}, ...]

    function check() {
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

    // nmcli -t escapes ':' and '\' inside fields with a backslash
    function _splitTerse(line) {
        const out = [""]
        for (let i = 0; i < line.length; i++) {
            const ch = line[i]
            if (ch === "\\" && i + 1 < line.length) out[out.length - 1] += line[++i]
            else if (ch === ":") out.push("")
            else out[out.length - 1] += ch
        }
        return out
    }

    property var _parsedConnections: []

    Process {
        id: listProc
        command: ["nmcli", "-t", "-f", "NAME,TYPE,ACTIVE,DEVICE", "connection", "show"]
        stdout: SplitParser {
            onRead: data => {
                const parts = root._splitTerse(data)
                if (parts[1] === "wireguard") {
                    root._parsedConnections.push({
                        name: parts[0],
                        active: parts[2] === "yes",
                        device: parts[3] ?? ""
                    })
                }
            }
        }
        onExited: {
            root.connections = root._parsedConnections
            root._parsedConnections = []
        }
    }

    // `nmcli connection up/down` returns once (de)activation finished →
    // refresh then, in case the link event came before the state change
    Process {
        id: connectProc
        onExited: root.check()
    }

    Process {
        id: disconnectProc
        onExited: root.check()
    }

    // Watch for network link changes (interface up/down events). One event
    // prints several lines and link changes come in bursts → debounce.
    Timer {
        id: checkDebounce
        interval: 300
        onTriggered: root.check()
    }

    Process {
        running: true
        command: ["ip", "monitor", "link"]
        stdout: SplitParser {
            onRead: _ => checkDebounce.restart()
        }
    }

    Component.onCompleted: check()
}
