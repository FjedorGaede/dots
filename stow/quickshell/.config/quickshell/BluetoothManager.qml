import Quickshell.Bluetooth
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import './theme'

PopupBase {
    id: bluetoothManager

    property var adapter: Bluetooth.defaultAdapter
    property bool hasAdapter: adapter !== null
    property var devices: adapter?.devices.values ?? []
    property var connectedDevices: devices.filter(d => d.state === BluetoothDeviceState.Connected)
    property var notConnectedDevices: devices.filter(d => d.state !== BluetoothDeviceState.Connected)
    property var pairedDevices: notConnectedDevices.filter(d => d.paired)
    property var discoveredDevices: notConnectedDevices.filter(d => !d.paired)

    property int headerSize: 14
    property color textColor: Theme.foreground

    onVisibleChanged: {
        if (!bluetoothManager.adapter) return

        if (visible) {
            // Start scanning right away, like omarchy's bluetooth panel
            bluetoothManager.adapter.discovering = true
        } else {
            bluetoothManager.adapter.discovering = false
        }
    }

    // BlueZ drops the discovery session after ~30s on its own — restart it
    // while the popup is open so new devices keep showing up.
    Timer {
        running: bluetoothManager.visible && (bluetoothManager.adapter?.enabled ?? false)
        interval: 25000
        repeat: true
        onTriggered: {
            if (bluetoothManager.adapter && bluetoothManager.adapter.enabled)
                bluetoothManager.adapter.discovering = true
        }
    }

    function toggleDiscovering() {
        if (!bluetoothManager.adapter) return;
        adapter.discovering = !adapter.discovering;
    }

    minWidth: 280

    RowLayout {
        Text {
            text: "BLUETOOTH"
            color: Theme.mainAccent
            font.pixelSize: bluetoothManager.headerSize
        }

        Item { Layout.fillWidth: true }

        Toggle {
            id: btToggle
            checked: bluetoothManager.adapter?.enabled ?? false
            enabled: bluetoothManager.hasAdapter

            onUserToggled: (value) => {
                if (bluetoothManager.adapter)
                    bluetoothManager.adapter.enabled = value
                // Restore the binding broken by user interaction
                btToggle.checked = Qt.binding(() => bluetoothManager.adapter?.enabled ?? false)
            }
        }
    }

    Text {
        visible: !bluetoothManager.hasAdapter
        text: "No Bluetooth adapter found"
        font.italic: true
        font.pixelSize: 12
        color: Theme.fadedForeground
    }

    ColumnLayout {
        visible: bluetoothManager.adapter?.enabled ?? false
        spacing: 5

        Divider {}

        Text {
            text: "CONNECTED"
            color: bluetoothManager.textColor
            font.pixelSize: bluetoothManager.headerSize
            visible: bluetoothManager.connectedDevices.length > 0
        }

        Repeater {
            model: bluetoothManager.connectedDevices
            BluetoothDeviceItem {
                required property var modelData
                device: modelData
            }
        }

        Divider {
            visible: bluetoothManager.connectedDevices.length > 0 && bluetoothManager.pairedDevices.length > 0
        }

        RowLayout {
            Text {
                text: "PAIRED DEVICES"
                color: bluetoothManager.textColor
                font.pixelSize: bluetoothManager.headerSize
                visible: bluetoothManager.pairedDevices.length > 0
            }

            Item {
                Layout.fillWidth: true
            }
        }

        Repeater {
            model: bluetoothManager.pairedDevices
            BluetoothDeviceItem {
                required property var modelData
                device: modelData
            }
        }

        Divider {}

        RowLayout {
            Text {
                text: "DISCOVERED DEVICES"
                color: bluetoothManager.textColor
                font.pixelSize: bluetoothManager.headerSize
            }

            Item {
                Layout.fillWidth: true
            }

            Button {
                background: Rectangle {
                    color: Theme.mainAccent
                    radius: 8
                }

                contentItem: Text {
                    text: (bluetoothManager.adapter?.discovering ?? false) ? "Discovering..." : "Discover"
                    color: Theme.black
                }

                HoverHandler {
                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    onTapped: bluetoothManager.toggleDiscovering()
                }
            }
        }

        Text {
            text: "Discovering disabled.."
            font.italic: true
            font.pixelSize: 12
            color: Theme.fadedForeground
            visible: !bluetoothManager.adapter.discovering
        }

        ColumnLayout {
            visible: bluetoothManager.adapter.discovering
            Repeater {
                model: bluetoothManager.discoveredDevices
                BluetoothDeviceItem {
                    required property var modelData
                    device: modelData
                }
            }
        }
    }
}
