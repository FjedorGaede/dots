import Quickshell.Networking
import QtQuick
import QtQuick.Layouts

import './_helpers/wifiUtils.js' as WifiUtils
import './theme'

ColumnLayout {
    id: root

    required property var network

    readonly property bool isSecure: ![WifiSecurityType.Unknown, WifiSecurityType.Open]
                                       .includes(network.security)

    signal passwordRequested(var network)

    spacing: 1
    Layout.fillWidth: true

    ListItem {
        Layout.fillWidth: true

        status: root.network.connected ? ListItem.Active : ListItem.Default
        icon:   WifiUtils.getWifiIconForSignalStrength(root.network.signalStrength * 100, root.isSecure)
        label:  root.network.name

        onTapped: {
            if (root.network.connected) {
                root.network.disconnect()
            } else if (!root.network.known && root.isSecure) {
                root.passwordRequested(root.network)
            } else {
                root.network.connect()
            }
        }

        actionIcon: root.network.known ? "󰌸" : ""
        onActionTapped: {
            if (root.network.known) {
                root.network.forget()
            }
        }
    }
}
