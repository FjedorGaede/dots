import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import './theme'

PanelWindow {
    id: prompt

    property var targetNetwork: null

    visible: false

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    focusable: true
    color: Theme.backdrop

    HyprlandFocusGrab {
        windows: [ prompt ]
        active: prompt.visible
        onCleared: prompt.close()
    }

    function open(network) {
        targetNetwork = network
        passwordField.text = ""
        errorText.text = ""
        visible = true
        Qt.callLater(() => passwordField.forceActiveFocus())
    }

    function close() {
        visible = false
        targetNetwork = null
        passwordField.text = ""
        errorText.text = ""
    }

    Item {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: prompt.close()

        TapHandler {
            onTapped: prompt.close()
        }
    }

    Rectangle {
        id: dialog
        anchors.centerIn: parent
        implicitWidth: 380
        implicitHeight: content.implicitHeight + 32
        color: Theme.background
        radius: 8
        border.width: 1.5
        border.color: Theme.mainAccent

        MouseArea {
            anchors.fill: parent
            onClicked: {} // absorb clicks so backdrop doesn't close us
        }

        ColumnLayout {
            id: content
            anchors.fill: parent
            anchors.margins: 16
            spacing: 10

            Text {
                text: "Connect to Wi-Fi"
                color: Theme.mainAccent
                font.pixelSize: 15
                font.family: Theme.fontFamily
            }

            Text {
                text: prompt.targetNetwork?.name ?? ""
                color: Theme.foreground
                font.pixelSize: 13
                font.family: Theme.fontFamily
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

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
                placeholderText: "Password"
                placeholderTextColor: Theme.dimForeground

                background: Rectangle {
                    radius: 6
                    color: Theme.hoverOverlay
                    border.color: passwordField.activeFocus ? Theme.mainAccent : "transparent"
                    border.width: 1
                }

                onAccepted: connectButton.connect()
            }

            Text {
                id: errorText
                Layout.fillWidth: true
                color: "#ff6b6b"
                font.pixelSize: 12
                font.family: Theme.fontFamily
                wrapMode: Text.WordWrap
                visible: text.length > 0
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Item { Layout.fillWidth: true }

                Rectangle {
                    id: cancelButton
                    implicitWidth: 80
                    implicitHeight: 30
                    radius: 6
                    color: cancelHover.hovered ? Theme.hoverOverlay : "transparent"
                    border.color: Theme.dimForeground
                    border.width: 1

                    HoverHandler { id: cancelHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: prompt.close() }

                    Text {
                        anchors.centerIn: parent
                        text: "Cancel"
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                    }
                }

                Rectangle {
                    id: connectButton
                    implicitWidth: 90
                    implicitHeight: 30
                    radius: 6
                    color: canConnect
                           ? (connectHover.hovered ? Theme.mainAccent : Theme.hoverOverlay)
                           : Theme.hoverOverlay
                    opacity: canConnect ? 1.0 : 0.5

                    readonly property bool canConnect: passwordField.text.length > 0 && !connectProc.running

                    function connect() {
                        if (!canConnect) return
                        errorText.text = ""
                        connectProc.running = true
                    }

                    HoverHandler { id: connectHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: connectButton.connect() }

                    Text {
                        anchors.centerIn: parent
                        text: connectProc.running ? "Connecting…" : "Connect"
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                    }
                }
            }
        }
    }

    Process {
        id: connectProc
        command: prompt.targetNetwork
                 ? ["nmcli", "dev", "wifi", "connect", prompt.targetNetwork.name, "password", passwordField.text]
                 : []

        stderr: StdioCollector { id: errCollector }

        onExited: (code) => {
            if (code === 0) {
                prompt.close()
            } else {
                const msg = errCollector.text.trim()
                errorText.text = msg.length > 0 ? msg : "Failed to connect"
            }
        }
    }
}
