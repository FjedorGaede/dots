import QtQuick
import Quickshell.Networking
import QtQuick.Layouts

import './_helpers/wifiUtils.js' as WifiUtils
import './theme'

RowLayout {
    id: network

    property bool wifiEnabled: Networking.wifiEnabled

    property var wifiDevice: Networking.devices.values.find(d => d?.mode == WifiDeviceMode.Station)

    property bool isScanning: !!wifiDevice?.scannerEnabled
    property var allNetworks: wifiDevice?.networks.values
    property var connectedNetwork: allNetworks?.find(n => !!n?.connected)

    property bool isConnected: !!connectedNetwork
    property int signalStrength: connectedNetwork?.signalStrength * 100

    property color defaultColor: Theme.foreground

    function getWifiIcon() {
        return wifiEnabled ? WifiUtils.getWifiIconForSignalStrength(signalStrength) : WifiUtils.DISCONNECTED_ICON;
    }

    StatusIcon {
        text: network.getWifiIcon()
    }

    TapHandler {
        onTapped: wifiManager.visible = !wifiManager.visible
    }

    HoverHandler {
        cursorShape: Qt.PointingHandCursor
        onHoveredChanged: tooltip.visible = hovered
    }

    Tooltip {
        id: tooltip
        anchorItem: network
        tooltipText: network.connectedNetwork?.name ?? "Not connected"
    }

    WifiNetworkManager {
        id: wifiManager
        network: network
    }
}
