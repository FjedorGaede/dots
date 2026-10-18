pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io

import qs.config

// Default adapter + device groups in ONE place (bar icon + panel).
// The discovery keep-alive is tied to panel visibility and stays in
// BluetoothPanel.qml.
Singleton {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool hasAdapter: adapter !== null
    // Lives here now instead of a `property bool enabled` on the bar widget,
    // which shadowed Item.enabled (docs/GOTCHAS.md)
    readonly property bool enabled: adapter?.enabled ?? false

    readonly property var devices: adapter?.devices.values ?? []
    readonly property var connectedDevices: devices.filter(d => d.state === BluetoothDeviceState.Connected)
    readonly property var notConnectedDevices: devices.filter(d => d.state !== BluetoothDeviceState.Connected)
    readonly property var pairedDevices: notConnectedDevices.filter(d => d.paired)
    readonly property var discoveredDevices: notConnectedDevices.filter(d => !d.paired)

    // Bar icon/tooltip count (uses `device.connected`, as it always did)
    readonly property int connectedCount: devices.map(device => device?.connected)
                                                 .filter(it => !!it).length

    // Pairing agent: bt-agent (bluez-tools) runs as bt-agent.service, set up by
    // packages/core/install/bluez-tools. Without it, devices that need a pairing
    // confirmation (keyboards, phones) fail silently — the panel shows a hint.
    property bool agentInstalled: true   // optimistic: no hint flash at startup

    function checkAgent() {
        if (!agentCheck.running) agentCheck.running = true
    }

    // Floating terminal; closing it re-checks, so the hint disappears at once.
    // bluez-tools is tracked in core: `--only bluez-tools` installs the package
    // and runs its install script (enables bt-agent.service).
    function installAgent() {
        if (agentInstallProc.running) return
        agentInstallProc.command = Apps.floatingTerminalCommand(
            Paths.dotsCli + " install core --only bluez-tools")
        agentInstallProc.running = true
    }

    Process {
        id: agentCheck
        running: true
        command: ["sh", "-c", "command -v bt-agent"]
        onExited: (code) => root.agentInstalled = code === 0
    }

    Process {
        id: agentInstallProc
        onExited: root.checkAgent()
    }
}
