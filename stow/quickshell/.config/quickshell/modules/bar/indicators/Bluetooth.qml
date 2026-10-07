import QtQuick

import '../../../lib/icons.js' as Icons
import qs.components
import qs.config
import qs.services
import qs.modules.panels

BarButton {
    id: bluetooth

    function getIcon() {
        if (!BluetoothService.hasAdapter || !BluetoothService.enabled) {
            return Icons.bluetooth.off;
        }

        if (BluetoothService.connectedCount > 0) {
            return Icons.bluetooth.connected
        }

        return Icons.bluetooth.on
    }

    function bluetoothTooltipText() {
        if (!BluetoothService.hasAdapter) {
            return "No Bluetooth adapter found";
        }

        if (!BluetoothService.enabled) {
            return "Bluetooth disabled";
        }

        if (BluetoothService.connectedCount > 0) {
            return BluetoothService.connectedCount + " devices connected"
        }

        return "No devices connected!"
    }

    icon: bluetooth.getIcon()
    // Thin, narrow rune — needs a bigger size to match its neighbours
    iconSize: 16
    tooltipText: bluetooth.bluetoothTooltipText()
    rightClickable: true
    onClicked: PanelService.toggle("bluetooth", btManager.screenName)
    onRightClicked: Apps.bluetoothManager()

    BluetoothPanel {
        id: btManager
        anchorItem: bluetooth
    }
}
