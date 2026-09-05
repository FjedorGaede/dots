import Quickshell
import Quickshell.Networking
import QtQuick
import QtQuick.Layouts

import './_helpers/wifiUtils.js' as WifiUtils
import './theme'

ColumnLayout {
    id: root

    required property var network

    readonly property bool isOpen: [WifiSecurityType.Unknown, WifiSecurityType.Open, WifiSecurityType.Owe]
                                   .includes(network.security)
    readonly property bool isSecure: !root.isOpen

    // Enterprise networks (802.1X) need identity + certificate setup, which a
    // plain password prompt can't provide — hand off to nm-connection-editor.
    readonly property bool isEnterprise: [WifiSecurityType.WpaEap, WifiSecurityType.Wpa2Eap]
                                         .includes(network.security)

    signal passwordRequested(var network)

    spacing: 1
    Layout.fillWidth: true

    ListItem {
        Layout.fillWidth: true

        status: root.network.stateChanging ? ListItem.Loading
              : root.network.connected     ? ListItem.Active
              : ListItem.Default
        icon:   WifiUtils.getWifiIconForSignalStrength(root.network.signalStrength * 100, root.isSecure)
        label:  root.network.name

        onTapped: {
            if (root.network.connected) {
                root.network.disconnect();
                return;
            }

            if (root.network.stateChanging) {
                return;
            }

            if (root.isEnterprise) {
                Quickshell.execDetached(["nm-connection-editor"]);
                return;
            }

            if (!root.network.known && root.isSecure) {
                root.passwordRequested(root.network);
                return;
            }

            root.network.connect();
        }

        actionIcon: root.network.known ? "󰌸" : ""
        onActionTapped: {
            if (root.network.known) {
                root.network.forget()
            }
        }
    }
}
