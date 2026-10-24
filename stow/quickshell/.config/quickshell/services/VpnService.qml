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

    // --- Import (VpnImportView) ---

    // WireGuard configs found by scanConfigs(): absolute paths
    property var foundConfigs: []
    property bool importing: false
    property string importError: ""
    // Fired after a successful import (the view closes itself)
    signal imported(string name)

    // NM names the interface after the profile → kernel ifname rules
    function isValidName(name) {
        return /^[A-Za-z0-9_=+.-]{1,15}$/.test(name)
    }

    // Profile name suggestion from a config path: basename without .conf,
    // invalid characters → '-', cut to 15
    function suggestName(path) {
        const base = path.split("/").pop().replace(/\.conf$/i, "")
        const name = base.replace(/[^A-Za-z0-9_=+.-]/g, "-").slice(0, 15)
        return name !== "" ? name : "wg0"
    }

    function scanConfigs() {
        scanProc.running = true
    }

    function importConfig(path, name) {
        if (root.importing) return
        root.importError = ""
        if (!root.isValidName(name)) {
            root.importError = "Name: 1–15 characters, a-z 0-9 _ - . = +"
            return
        }
        if (root.connections.some(c => c.name === name)) {
            root.importError = "A VPN named \"" + name + "\" already exists"
            return
        }
        root.importing = true
        importProc.name = name
        importProc.command = ["sh", "-c", importProc.script, "sh", path, name]
        importProc.running = true
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

    // *.conf files with an [Interface] section directly in ~/Downloads and ~
    Process {
        id: scanProc
        command: ["sh", "-c",
            'find "$HOME/Downloads" "$HOME" -maxdepth 1 -type f -iname "*.conf" ' +
            '-exec grep -lis "^\\[Interface\\]" {} + 2>/dev/null']
        stdout: StdioCollector {
            onStreamFinished: root.foundConfigs = text.split("\n").filter(l => l !== "")
        }
    }

    // nmcli takes the interface (= profile) name from the file name → import
    // a copy named <name>.conf; profile doesn't autoconnect (would also come
    // up at home). Errors via stdout (2>&1): StdioCollector may finish after
    // onExited, so success is a marker line, not the exit code.
    // Config has DNS → route *all* lookups through the tunnel ("~.", negative
    // priority beats the uplink's DNS). Otherwise resolved only asks it for
    // the search domain (fritz.box) and names that only the home DNS knows
    // go to the hotspot/carrier DNS instead.
    Process {
        id: importProc
        property string name: ""
        readonly property string script: `
            set -e
            exec 2>&1
            d=$(mktemp -d)
            trap 'rm -rf "$d"' EXIT
            cp -- "$1" "$d/$2.conf"
            nmcli connection import type wireguard file "$d/$2.conf"
            nmcli connection modify "$2" connection.autoconnect no
            if [ -n "$(nmcli -g ipv4.dns,ipv6.dns connection show "$2" | tr -d '\n')" ]; then
                nmcli connection modify "$2" \
                    +ipv4.dns-search "~." ipv4.dns-priority -10 \
                    +ipv6.dns-search "~." ipv6.dns-priority -10
            fi
            echo __OK__`
        stdout: StdioCollector {
            onStreamFinished: {
                const out = text.trim()
                root.importing = false
                root.check()
                if (out.endsWith("__OK__")) {
                    root.imported(importProc.name)
                } else {
                    root.importError = out.replace(/^Error: /m, "") || "Import failed"
                }
            }
        }
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
