import Quickshell.Networking
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts

import './_helpers/wifiUtils.js' as WifiUtils

Rectangle {
    id: root

    required property var network

    property bool securedConnection: isSecureConnection()
    property bool isConnected: root.network.connected

    property color activeConnectionBackgroundColor: "blue"
    property color activeConnectionIconColor: "white"
    property color defaultIconColor: "black"

    Layout.fillWidth: true
    implicitHeight: 24
    color: hoverHandler.hovered ? "red" : "white"
    radius: 4

    HoverHandler {
        id: hoverHandler
        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        onTapped: root.network.connect()
    }

    function isSecureConnection() {
        const insecureLevels = [WifiSecurityType.Unknown, WifiSecurityType.Open];

        const isInsecure = insecureLevels.includes(network.security);
        return !isInsecure;
    }

    MarginWrapperManager {
        margin: 4
    }

    RowLayout {

        Rectangle {
            implicitHeight: parent.height
            implicitWidth: parent.height

            radius: width / 2
            color: root.isConnected ? root.activeConnectionBackgroundColor : "transparent"

            Text {
                anchors.centerIn: parent
                text: WifiUtils.getWifiIconForSignalStrength(root.network.signalStrength * 100, root.securedConnection)
                color: root.isConnected ? root.activeConnectionIconColor : root.defaultIconColor
            }
        }

        Text {
            text: root.network.name
        }

        Item { Layout.fillWidth: true }
    }
}
