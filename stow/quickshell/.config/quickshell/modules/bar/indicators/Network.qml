import QtQuick

import '../../../lib/icons.js' as Icons
import qs.components
import qs.services
import qs.modules.panels

BarButton {
    id: network

    // State lives in NetworkService
    readonly property bool wifiEnabled: NetworkService.wifiEnabled
    readonly property var connectedNetwork: NetworkService.connectedNetwork
    readonly property bool isWifiConnected: NetworkService.wifiConnected
    readonly property bool isEthernetConnected: NetworkService.ethernetConnected
    readonly property int signalStrength: NetworkService.signalStrength
    readonly property bool restricted: NetworkService.restricted

    function getWifiIcon() {
        if (isEthernetConnected) {
            return restricted ? Icons.ethernetRestricted : Icons.ethernet;
        }

        if (wifiEnabled && isWifiConnected) {
            return restricted ? Icons.wifiRestricted : Icons.wifiIcon(signalStrength, false);
        }

        return Icons.wifiOff;
    }

    function getTooltipText() {
        if (isEthernetConnected) {
            return restricted ? "Ethernet (no internet)" : "Ethernet";
        }

        if (wifiEnabled && isWifiConnected) {
            let name = connectedNetwork?.name ?? "Unknown network";
            if (restricted) name += " (no internet)";
            return name;
        }

        return "Not connected";
    }

    icon: network.getWifiIcon()
    tooltipText: network.getTooltipText()
    onClicked: PanelService.toggle("wifi")

    WifiPanel {
        id: wifiManager
        anchorItem: network
    }
}
