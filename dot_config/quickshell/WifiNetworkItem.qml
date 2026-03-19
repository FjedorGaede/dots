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

    Layout.fillWidth: true
    implicitHeight: 42
    color: getBackgroundColor()

    function getBackgroundColor() {
        if (root.isConnected) {
            return Theme.mainAccentSubtle;
        }

        if (hoverHandler.hovered) {
            return Theme.hoverOverlay;
        }

        return "transparent";
    }
    radius: 8

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

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        spacing: 10

        Text {
            text: WifiUtils.getWifiIconForSignalStrength(root.network.signalStrength * 100, root.securedConnection)
            color: root.isConnected ? Theme.mainAccent : Theme.dimForeground
            font.pixelSize: 14
            font.family: Theme.fontFamily
        }

        Text {
            text: root.network.name
            color: root.isConnected ? Theme.foreground : Theme.fadedForeground
            font.pixelSize: 13
            font.bold: root.isConnected
            font.family: Theme.fontFamily
            Layout.fillWidth: true
            elide: Text.ElideRight
        }

        Text {
            visible: root.isConnected
            text: "✓"
            color: Theme.mainAccent
            font.pixelSize: 13
            font.family: Theme.fontFamily
        }
    }
}
