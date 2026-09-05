import Quickshell.Bluetooth
import QtQuick

ListItem {
    id: listItem

    required property var device

    readonly property bool isPaired:     device.paired || device.bonded
    readonly property bool isConnected:  device.state === BluetoothDeviceState.Connected
    readonly property bool isConnecting: device.state === BluetoothDeviceState.Connecting
    readonly property bool isPairing:    device.pairing

    // Some devices report UUIDs or MAC addresses as their name — fall back
    // through deviceName and finally the address so the row is never empty.
    readonly property string deviceLabel: {
        const name = (device.name ?? "").trim();
        if (name !== "" && name !== device.address) return name;
        const alt = (device.deviceName ?? "").trim();
        if (alt !== "") return alt;
        return device.address ?? "Unknown device";
    }

    status: (isConnecting || isPairing) ? ListItem.Loading
          : isConnected  ? ListItem.Active
          : ListItem.Default

    icon:  isConnected ? "󰂱" : "󰂯"
    label: deviceLabel + (device.batteryAvailable
           ? "  󰂄 " + Math.round(device.battery * 100) + "%"
           : "")

    function onTapped() {
        if (isConnecting || isPairing) {
            return;
        }

        if (isConnected) {
            device.disconnect();
            return;
        }

        // omarchy pattern: connect anything paired/bonded, pair the rest
        if (isPaired || device.trusted) {
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
