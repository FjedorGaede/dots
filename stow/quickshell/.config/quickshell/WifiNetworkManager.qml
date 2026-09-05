import Quickshell.Networking
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import './_helpers/wifiUtils.js' as WifiUtils
import './theme'

PopupBase {
    id: wifiManager

    required property var network

    property var wifiDevice: network.wifiDevice
    property int fontSize: 13
    property var allNetworks: wifiDevice?.networks.values
    property var knownNetworks: allNetworks?.filter(n => n.known).sort(WifiUtils.byConnectionThenSignal) || []
    property var unknownNetworks: allNetworks?.filter(n => !n.known).sort(WifiUtils.byConnectionThenSignal) || []
    property bool isLoadingWifi: false
    property int headerSize: 14
    property color textColor: Theme.foreground
    property int maxNetworkHeight: 300

    // Password prompt state
    property var passwordNetwork: null
    property bool passwordWasKnown: false
    property bool connectPending: false

    minWidth: 320

    function enableWifi() {
        Networking.wifiEnabled = true
        isLoadingWifi = true
    }

    function disableWifi() {
        Networking.wifiEnabled = false
    }

    // True while wifi is starting up, or while any network is activating
    readonly property bool isConnecting: isLoadingWifi && (allNetworks?.length === 0 ?? true)
                                         || (allNetworks ?? []).some(n => n?.stateChanging ?? false)
    readonly property bool hideNetworksLayout: isConnecting || !Networking.wifiEnabled
    readonly property bool showPasswordView: passwordNetwork != null

    onAllNetworksChanged: {
        if (allNetworks?.length > 0)
            isLoadingWifi = false
    }

    onVisibleChanged: {
        if (visible && wifiDevice)
            wifiDevice.scannerEnabled = true
        else {
            wifiDevice.scannerEnabled = false
            cancelPassword()
        }
    }

    function requestPassword(net) {
        passwordNetwork = net
        passwordWasKnown = net.known
        passwordField.text = ""
        errorText.text = ""
        Qt.callLater(() => passwordField.forceActiveFocus())
    }

    function cancelPassword() {
        passwordNetwork = null
        passwordWasKnown = false
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
        passwordNetwork.connectWithPsk(passwordField.text)
    }

    function failConnect(message) {
        connectPending = false
        pendingTimeout.stop()
        errorText.text = message
        // NM may have saved a profile with the wrong password — clean it up
        // so the next attempt starts fresh (only if it wasn't known before).
        if (passwordNetwork && !passwordWasKnown)
            passwordNetwork.forget()
    }

    // Watch the network we're connecting to for success/failure
    Connections {
        target: wifiManager.passwordNetwork

        function onConnectedChanged() {
            if (!wifiManager.connectPending || !wifiManager.passwordNetwork) return
            if (wifiManager.passwordNetwork.connected)
                wifiManager.cancelPassword()
        }

        function onStateChanged() {
            const net = wifiManager.passwordNetwork
            if (!wifiManager.connectPending || !net) return
            if (net.connected) {
                wifiManager.cancelPassword()
                return
            }
            // Settled back to Disconnected while pending => activation failed
            if (!net.stateChanging && net.state === ConnectionState.Disconnected)
                wifiManager.failConnect("Failed to connect — check the password")
        }
    }

    Timer {
        id: pendingTimeout
        interval: 30000
        onTriggered: {
            if (wifiManager.connectPending)
                wifiManager.failConnect("Connection attempt timed out")
        }
    }

    // --- Header with WIFI toggle ---
    RowLayout {
        Text {
            text: wifiManager.showPasswordView ? "CONNECT" : "WIFI"
            color: Theme.mainAccent
            font.pixelSize: wifiManager.headerSize
        }

        Item { Layout.fillWidth: true }

        Text {
            visible: !Networking.wifiEnabled && !wifiManager.showPasswordView
            text: "Disabled"
            color: wifiManager.textColor
        }

        Text {
            visible: wifiManager.isConnecting && Networking.wifiEnabled && !wifiManager.showPasswordView
            text: "Connecting..."
            color: wifiManager.textColor
        }

        Item { Layout.minimumWidth: 2 }

        Toggle {
            id: wifiToggle
            visible: !wifiManager.showPasswordView
            checked: Networking.wifiEnabled

            onUserToggled: (value) => {
                if (value) wifiManager.enableWifi()
                else wifiManager.disableWifi()
                // User interaction broke the declarative binding — restore it
                // so external changes (rfkill, nmcli, ...) stay in sync.
                wifiToggle.checked = Qt.binding(() => Networking.wifiEnabled)
            }
        }
    }

    // --- Network list (hidden when showing password view) ---
    Flickable {
        visible: !wifiManager.hideNetworksLayout && !wifiManager.showPasswordView
        Layout.fillWidth: true
        implicitHeight: Math.min(networkContent.implicitHeight, wifiManager.maxNetworkHeight)
        contentHeight: networkContent.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ScrollBar.vertical: ScrollBar {
            policy: parent.contentHeight > parent.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
        }

        ColumnLayout {
            id: networkContent
            width: parent.width
            spacing: 5

            Divider {}

            Text {
                text: "KNOWN"
                color: wifiManager.textColor
                font.pixelSize: wifiManager.headerSize
            }

            Repeater {
                model: wifiManager.knownNetworks
                WifiNetworkItem {
                    required property var modelData
                    network: modelData
                    onPasswordRequested: net => wifiManager.requestPassword(net)
                }
            }

            ColumnLayout {
                visible: wifiManager.unknownNetworks.length > 0

                Divider {}

                Text { text: "OTHERS"; color: wifiManager.textColor; font.pixelSize: wifiManager.headerSize }

                Repeater {
                    model: wifiManager.unknownNetworks
                    WifiNetworkItem {
                        required property var modelData
                        network: modelData
                        onPasswordRequested: net => wifiManager.requestPassword(net)
                    }
                }
            }
        }
    }

    // --- Password entry view (shown when connecting to unknown network) ---
    ColumnLayout {
        visible: wifiManager.showPasswordView
        spacing: 8

        Divider {}

        Text {
            text: "Network: " + (wifiManager.passwordNetwork?.name ?? "")
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
            // Only space out the dots while typing — the placeholder should
            // render with normal spacing
            font.letterSpacing: passwordField.text.length > 0 ? 4 : 0
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

            Rectangle {
                implicitWidth: 80
                implicitHeight: 30
                radius: 6
                color: backHover.hovered ? Theme.hoverOverlay : "transparent"
                border.color: Theme.dimForeground
                border.width: 1

                HoverHandler { id: backHover; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: wifiManager.cancelPassword() }

                Text {
                    anchors.centerIn: parent
                    text: "Back"
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                }
            }

            Item { Layout.fillWidth: true }

            Rectangle {
                id: connectButton
                implicitWidth: 90
                implicitHeight: 30
                radius: 6
                color: canConnect
                       ? (connectHover.hovered ? Theme.mainAccent : Theme.hoverOverlay)
                       : Theme.hoverOverlay
                opacity: canConnect ? 1.0 : 0.5

                readonly property bool canConnect: passwordField.text.length > 0 && !wifiManager.connectPending

                function connect() {
                    if (!canConnect) return
                    wifiManager.confirmConnect()
                }

                HoverHandler { id: connectHover; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: connectButton.connect() }

                Text {
                    anchors.centerIn: parent
                    text: wifiManager.connectPending ? "Connecting…" : "Connect"
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                }
            }
        }
    }

    // --- VPN section ---
    ColumnLayout {
        visible: VpnService.connections.length > 0 && !wifiManager.showPasswordView
        spacing: 5

        Divider {}

        Text {
            text: "VPN"
            color: Theme.mainAccent
            font.pixelSize: wifiManager.headerSize
            font.family: Theme.fontFamily
        }

        Repeater {
            model: VpnService.connections
            ListItem {
                required property var modelData
                size: ListItem.Small
                icon: modelData.active ? "󰌆" : "󰌊"
                label: modelData.name
                status: modelData.active ? ListItem.Active : ListItem.Default
                onTapped: modelData.active
                    ? VpnService.disconnect(modelData.name)
                    : VpnService.connect(modelData.name)
            }
        }
    }
}
