pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Networking

import '../lib/network.js' as NetUtils

// Wifi/ethernet state in ONE place (used to live in the Network bar widget,
// which the wifi panel (then WifiNetworkManager) was handed as `network: network`).
Singleton {
    id: root

    readonly property bool wifiEnabled: Networking.wifiEnabled

    readonly property var wifiDevice: Networking.devices.values.find(d => d?.mode == WifiDeviceMode.Station)
    readonly property var ethernetDevice: Networking.devices.values.find(d => d?.type == DeviceType.Wired)

    readonly property var networks: wifiDevice?.networks.values
    readonly property var connectedNetwork: networks?.find(n => !!n?.connected)

    readonly property var knownNetworks: networks?.filter(n => n.known).sort(NetUtils.byConnectionThenSignal) || []
    readonly property var unknownNetworks: networks?.filter(n => !n.known).sort(NetUtils.byConnectionThenSignal) || []

    readonly property bool wifiConnected: !!connectedNetwork
    readonly property bool ethernetConnected: ethernetDevice?.connected ?? false
    readonly property bool connected: wifiConnected || ethernetConnected

    // Guard against NaN while disconnected
    readonly property int signalStrength: connectedNetwork ? Math.round(connectedNetwork.signalStrength * 100) : 0

    // NetworkManager connectivity check: captive portal / limited connectivity
    // get their own icon instead of pretending we have internet access.
    readonly property bool restricted: Networking.connectivity == NetworkConnectivity.Portal
                                       || Networking.connectivity == NetworkConnectivity.Limited

    function setWifiEnabled(on) { Networking.wifiEnabled = on }
}
