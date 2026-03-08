import Quickshell
import Quickshell.Networking
import QtQuick
import QtQuick.Layouts

import './_helpers/getIntervalIndex.js' as Util

RowLayout {
    id: network

    property bool wifiEnabled: Networking.wifiEnabled
    property var wifiDevice: Networking.devices.values.find(d => d?.mode == WifiDeviceMode.Station)
    property bool isScanning: !!wifiDevice?.scannerEnabled
    property var connectedNetwork: wifiDevice?.networks.values.find(n => !!n?.connected)
    property bool isConnected: !!connectedNetwork
    property int signalStrength: connectedNetwork?.signalStrength * 100

    property color defaultColor: "white"

    function getIcon() {
        const wifiIcons = ["󰤯", "󰤟", "󰤢", "󰤥", "󰤨"];
        const disconnectedIcon = "󰖪"

        if (!isConnected) {
            return disconnectedIcon;
        }

        return wifiIcons[Util.getIntervalIndex(signalStrength, 100, wifiIcons.length)]
    }

    Text {
        text: network.getIcon()
        color: network.defaultColor
    }
}
