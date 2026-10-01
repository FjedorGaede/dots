import Quickshell.Networking
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import qs.components
import qs.config

// Wifi password prompt (unknown secured network) inside the wifi panel:
// password field, Back / Connect, and watching the activation for
// success / failure / timeout. open(net) shows it, cancel() hides it again.
ColumnLayout {
    id: root

    // Network being connected to; null = view hidden
    property var network: null
    property bool wasKnown: false
    property bool connectPending: false

    visible: root.network != null
    spacing: 8

    function open(net) {
        network = net
        wasKnown = net.known
        passwordField.text = ""
        errorText.text = ""
        Qt.callLater(() => passwordField.forceActiveFocus())
    }

    function cancel() {
        network = null
        wasKnown = false
        connectPending = false
        pendingTimeout.stop()
        passwordField.text = ""
        errorText.text = ""
    }

    function confirmConnect() {
        if (!connectButton.canConnect) return
        errorText.text = ""
        connectPending = true
        pendingTimeout.restart()
        // Native NetworkManager activation — no nmcli subprocess needed
        network.connectWithPsk(passwordField.text)
    }

    function failConnect(message) {
        connectPending = false
        pendingTimeout.stop()
        errorText.text = message
        // NM may have saved a profile with the wrong password — clean it up
        // so the next attempt starts fresh (only if it wasn't known before).
        if (network && !wasKnown)
            network.forget()
    }

    // Watch the network we're connecting to for success/failure
    Connections {
        target: root.network

        function onConnectedChanged() {
            if (!root.connectPending || !root.network) return
            if (root.network.connected)
                root.cancel()
        }

        function onStateChanged() {
            const net = root.network
            if (!root.connectPending || !net) return
            if (net.connected) {
                root.cancel()
                return
            }
            // Settled back to Disconnected while pending => activation failed
            if (!net.stateChanging && net.state === ConnectionState.Disconnected)
                root.failConnect("Failed to connect — check the password")
        }
    }

    Timer {
        id: pendingTimeout
        interval: 30000
        onTriggered: {
            if (root.connectPending)
                root.failConnect("Connection attempt timed out")
        }
    }

    Divider {}

    StyledText {
        text: "Network: " + (root.network?.name ?? "")
        font.pixelSize: Theme.fontSize.base
        elide: Text.ElideRight
        Layout.fillWidth: true
    }

    TextField {
        id: passwordField
        Layout.fillWidth: true
        color: Theme.foreground
        echoMode: TextInput.Password
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize.base
        // Only space out the dots while typing — the placeholder should
        // render with normal spacing
        font.letterSpacing: passwordField.text.length > 0 ? 4 : 0
        leftPadding: 10
        rightPadding: 10
        placeholderText: "Password"
        placeholderTextColor: Theme.dimForeground

        background: Rectangle {
            radius: Theme.radius.sm
            color: Theme.hoverOverlay
            border.color: passwordField.activeFocus ? Theme.mainAccent : "transparent"
            border.width: 1
        }

        onAccepted: connectButton.connect()
    }

    StyledText {
        id: errorText
        Layout.fillWidth: true
        color: Theme.errorBright
        font.pixelSize: Theme.fontSize.md
        wrapMode: Text.WordWrap
        visible: text.length > 0
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        GhostButton {
            implicitWidth: 80
            implicitHeight: 30
            rowContent: false
            border.color: Theme.dimForeground
            border.width: 1
            text: "Back"
            textSize: Theme.fontSize.md
            contentColor: Theme.foreground      // not dimmed
            onClicked: root.cancel()
        }

        Item { Layout.fillWidth: true }

        Rectangle {
            id: connectButton
            implicitWidth: 90
            implicitHeight: 30
            radius: Theme.radius.sm
            color: canConnect
                   ? (connectHover.hovered ? Theme.mainAccent : Theme.hoverOverlay)
                   : Theme.hoverOverlay
            opacity: canConnect ? 1.0 : 0.5

            readonly property bool canConnect: passwordField.text.length > 0 && !root.connectPending

            function connect() {
                if (!canConnect) return
                root.confirmConnect()
            }

            HoverHandler { id: connectHover; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: connectButton.connect() }

            StyledText {
                anchors.centerIn: parent
                text: root.connectPending ? "Connecting…" : "Connect"
                font.pixelSize: Theme.fontSize.md
            }
        }
    }
}
