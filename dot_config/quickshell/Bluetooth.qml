import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Hyprland

import './theme'

RowLayout {
    id: bluetooth

    property var adapter: Bluetooth.defaultAdapter
    property bool enabled: adapter.enabled
    property int numberDevicesConnected: adapter.devices.values.map(device => device.connected).filter(it => !!it).length
    property bool anyDeviceConnected: numberDevicesConnected > 0

    property color defaultColor: Theme.foreground

    function getIcon() {
        if (!enabled) {
            return "󰂲";
        }

        if (anyDeviceConnected) {
            return "󰂱"
        }

        return "󰂯"
    }

    function bluetoothTooltipText() {
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
}
