import Quickshell.Bluetooth
import QtQuick
import QtQuick.Layouts

import './theme'

PopupBase {
    id: bluetoothManager

    property var adapter: Bluetooth.defaultAdapter
    property var devices: adapter?.devices.values ?? []
    property var connectedDevices: devices.filter(d => d.state === BluetoothDeviceState.Connected)
    property var otherDevices: devices.filter(d => d.state !== BluetoothDeviceState.Connected)

    property int headerSize: 14
    property color textColor: Theme.foreground

    minWidth: 280

    RowLayout {
        Text {
            text: "BLUETOOTH"
            color: Theme.mainAccent
            font.pixelSize: bluetoothManager.headerSize
        }

        Item { Layout.fillWidth: true }

        Toggle {
            checked: bluetoothManager.adapter?.enabled ?? false
            onCheckedChanged: bluetoothManager.adapter.enabled = checked
        }
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
            visible: bluetoothManager.connectedDevices.length > 0 && bluetoothManager.otherDevices.length > 0
        }

        Text {
            text: "OTHER DEVICES"
            color: bluetoothManager.textColor
            font.pixelSize: bluetoothManager.headerSize
            visible: bluetoothManager.otherDevices.length > 0
        }

        Repeater {
            model: bluetoothManager.otherDevices
            BluetoothDeviceItem {
                required property var modelData
                device: modelData
            }
        }
    }
}
