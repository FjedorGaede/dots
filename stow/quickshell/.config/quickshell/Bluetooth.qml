import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth

import './theme'

RowLayout {
    id: bluetooth

    property var adapter: Bluetooth.defaultAdapter
    property bool hasAdapter: adapter !== null
    property bool enabled: adapter?.enabled ?? false

    property int numberDevicesConnected: (adapter?.devices.values ?? [])
                                         .map(device => device?.connected)
                                         .filter(it => !!it).length
    property bool anyDeviceConnected: numberDevicesConnected > 0

    function getIcon() {
        if (!hasAdapter || !enabled) {
            return "󰂲";
        }

        if (anyDeviceConnected) {
            return "󰂱"
        }

        return "󰂯"
    }

    function bluetoothTooltipText() {
        if (!hasAdapter) {
            return "No Bluetooth adapter found";
        }

        if (!enabled) {
            return "Bluetooth disabled";
        }

        if (anyDeviceConnected) {
            return numberDevicesConnected + " devices connected"
        }

        return "No devices connected!"
    }

    StatusIcon {
        text: bluetooth.getIcon()
        size: 15
    }

    TapHandler {
        onTapped: btManager.visible = !btManager.visible
    }

    TapHandler {
        acceptedButtons: Qt.RightButton
        onTapped: {
            Quickshell.execDetached(["blueman-manager"])
        }
    }

    HoverHandler {
        cursorShape: Qt.PointingHandCursor
        onHoveredChanged: tooltip.visible = hovered
    }

    Tooltip {
        id: tooltip
        anchorItem: bluetooth
        tooltipText: bluetooth.bluetoothTooltipText()
    }

    BluetoothManager {
        id: btManager
        anchorItem: bluetooth
    }

    // Keybinds: qs ipc call bluetooth toggle / open / close
    IpcHandler {
        target: "bluetooth"

        function toggle(): void {
            btManager.visible = !btManager.visible;
        }

        function open(): void {
            btManager.visible = true;
        }

        function close(): void {
            btManager.visible = false;
        }
    }
}
