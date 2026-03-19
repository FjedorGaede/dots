import Quickshell.Networking
import QtQuick

import './_helpers/wifiUtils.js' as WifiUtils

ListItem {
    required property var network

    readonly property bool isSecure: ![WifiSecurityType.Unknown, WifiSecurityType.Open]
                                       .includes(network.security)

    status: network.connected ? ListItem.Active : ListItem.Default
    icon:   WifiUtils.getWifiIconForSignalStrength(network.signalStrength * 100, isSecure)
    label:  network.name

    onTapped: network.connect()
}
