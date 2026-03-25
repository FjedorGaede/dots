import Quickshell.Networking
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import './_helpers/wifiUtils.js' as WifiUtils
import './theme'

ColumnLayout {
    id: root

    required property var network

    readonly property bool isSecure: ![WifiSecurityType.Unknown, WifiSecurityType.Open]
                                       .includes(network.security)
    property bool showPasswordField: false
    onShowPasswordFieldChanged: if (showPasswordField) passwordField.forceActiveFocus()

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
                root.showPasswordField = !root.showPasswordField
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

    RowLayout {
        visible: root.showPasswordField
        Layout.fillWidth: true
        Layout.leftMargin: 10
        Layout.rightMargin: 10
        Layout.bottomMargin: 4
        spacing: 8

        TextField {
            id: passwordField
            Layout.fillWidth: true
            color: Theme.foreground
            echoMode: TextInput.Password
            font.family: Theme.fontFamily
            font.pixelSize: 13
            font.letterSpacing: 4
            leftPadding: 10
            rightPadding: 10

            background: Rectangle {
                radius: 6
                color: Theme.hoverOverlay
                border.color: passwordField.activeFocus ? Theme.mainAccent : "transparent"
                border.width: 1
            }

            onAccepted: connectButton.connect()
            Keys.onEscapePressed: root.showPasswordField = false
        }

        Process {
            id: connectProc
            command: ["nmcli", "dev", "wifi", "connect", root.network.name, "password", passwordField.text]
            onRunningChanged: {
                if (!running) {
                    root.showPasswordField = false;
                }
            }
        }

        Rectangle {
            id: connectButton
            implicitWidth: 32
            implicitHeight: 32
            radius: 6
            color: connectHover.hovered ? Theme.hoverOverlay : "transparent"

            function connect() {
                if (passwordField.text.length > 0)
                    connectProc.running = true
            }

            HoverHandler { id: connectHover; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: connectButton.connect() }

            Text {
                anchors.centerIn: parent
                text: "󰌑"
                color: Theme.dimForeground
                font.family: Theme.fontFamily
                font.pixelSize: 16
            }
        }
    }
}
