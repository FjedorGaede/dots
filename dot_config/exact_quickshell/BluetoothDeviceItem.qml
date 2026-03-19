import Quickshell.Bluetooth
import QtQuick

import './theme'

ListItem {
    id: listItem

    required property var device

    readonly property bool isConnected:  device.state === BluetoothDeviceState.Connected
    readonly property bool isConnecting: device.state === BluetoothDeviceState.Connecting
                                      || device.state === BluetoothDeviceState.Disconnecting

    status: isConnecting ? ListItem.Loading
          : isConnected  ? ListItem.Active
          : ListItem.Default

    icon:  isConnected ? "󰂱" : "󰂯"
    label: device.name

    onTapped:      isConnected ? device.disconnect() : device.connect()
    onRightTapped: menu.visible = !menu.visible

    PopupBase {
        anchorItem: listItem
        id: menu
        visible: false
        bordered: true
        radius: 6

        minWidth: 150

        Text {
            text: "Device"
            font.pixelSize: 16
            font.family: Theme.fontFamily
            color: Theme.foreground
        }

        Divider {}

        ListItem {
            size: ListItem.Small
            label: "Forget"
            onTapped: listItem.device.forget()
        }
    }
}
