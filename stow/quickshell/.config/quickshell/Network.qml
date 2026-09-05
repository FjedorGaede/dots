import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import QtQuick.Layouts

import './_helpers/wifiUtils.js' as WifiUtils
import './theme'

RowLayout {
    id: network

    property bool wifiEnabled: Networking.wifiEnabled

    property var wifiDevice: Networking.devices.values.find(d => d?.mode == WifiDeviceMode.Station)
    property var ethernetDevice: Networking.devices.values.find(d => d?.type == DeviceType.Wired)

    property var allNetworks: wifiDevice?.networks.values
    property var connectedNetwork: allNetworks?.find(n => !!n?.connected)

    property bool isWifiConnected: !!connectedNetwork
    property bool isEthernetConnected: ethernetDevice?.connected ?? false
    property bool isConnected: isWifiConnected || isEthernetConnected

    // Guard against NaN while disconnected
    property int signalStrength: connectedNetwork ? Math.round(connectedNetwork.signalStrength * 100) : 0

    // NetworkManager connectivity check: captive portal / limited connectivity
    // get their own icon instead of pretending we have internet access.
    property bool restricted: Networking.connectivity == NetworkConnectivity.Portal
                              || Networking.connectivity == NetworkConnectivity.Limited

    function getWifiIcon() {
        if (isEthernetConnected) {
            return restricted ? "󰈂" : "󰈀";
        }

        if (wifiEnabled && isWifiConnected) {
            return restricted ? "󰤩" : WifiUtils.getWifiIconForSignalStrength(signalStrength);
        }

        return WifiUtils.DISCONNECTED_ICON;
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
        tooltipText: network.getTooltipText()
    }

    WifiNetworkManager {
        id: wifiManager
        network: network
        anchorItem: network
    }

    // Keybinds: qs ipc call wifi toggle / open / close
    IpcHandler {
        target: "wifi"

        function toggle(): void {
            wifiManager.visible = !wifiManager.visible;
        }

        function open(): void {
            wifiManager.visible = true;
        }

        function close(): void {
            wifiManager.visible = false;
        }
    }
}
