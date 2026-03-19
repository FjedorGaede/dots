import Quickshell.Bluetooth
import QtQuick

ListItem {
    id: listItem

    required property var device

    readonly property bool isPaired:     device.paired
    readonly property bool isConnected:  device.state === BluetoothDeviceState.Connected
    readonly property bool isConnecting: device.state === BluetoothDeviceState.Connecting
    readonly property bool isPairing: device.pairing

    status: (isConnecting || isPairing) ? ListItem.Loading
          : isConnected  ? ListItem.Active
          : ListItem.Default

    icon:  isConnected ? "󰂱" : "󰂯"
    label: device.name

    function onTapped() {
        if (isConnected) {
            device.disconnect();
            return;
        }

        if (isPaired) {
            device.connect();
            return;
        }

        device.pair();
    }

    actionIcon: (isPaired && !isConnected) ? "󰌸" : ""
    onActionTapped: {
        if (!isPaired || isConnected) {
            return;
        }

        device.forget()
    }

    onTapped: onTapped()
}
