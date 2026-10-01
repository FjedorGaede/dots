pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Bluetooth

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
}
