import Quickshell.Networking
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts

import './_helpers/wifiUtils.js' as WifiUtils
import './theme'

Rectangle {
    id: root

    required property var network

    property bool securedConnection: isSecureConnection()
    property bool isConnected: root.network.connected

    property color activeConnectionBackgroundColor: Theme.accent
    property color activeConnectionIconColor: Theme.background
    property color defaultTextColor: Theme.foreground

    Layout.fillWidth: true
    implicitHeight: 42
    color: hoverHandler.hovered ? Theme.overlay : "transparent"
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
        spacing: 8

        Rectangle {
            implicitHeight: 28
            implicitWidth: 28

            radius: width / 2
            color: root.isConnected ? root.activeConnectionBackgroundColor : "transparent"

            Text {
                anchors.centerIn: parent
                text: WifiUtils.getWifiIconForSignalStrength(root.network.signalStrength * 100, root.securedConnection)
                color: root.isConnected ? root.activeConnectionIconColor : root.defaultTextColor
                font.pixelSize: 18
            }
        }

        Text {
            text: root.network.name
            color: root.defaultTextColor
            font.pixelSize: 14
        }

        Item { Layout.fillWidth: true }
    }
}
