import Quickshell.Networking
import QtQuick
import QtQuick.Layouts

import './_helpers/wifiUtils.js' as WifiUtils

// TODOS
// 1. When i have my hotspot open it is not really using the correct signal strength? It is different and sometimes super low
// 2. When i connect to a wifi i need a agent. nm-applet worked but is also super intrusive. i want another one maybe? Or can i just do it on my own?
// 3. sort connected wifi to the top

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
    }
}
