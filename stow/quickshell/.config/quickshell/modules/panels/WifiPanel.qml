import QtQuick
import QtQuick.Layouts

import qs.components
import qs.config
import qs.services

PopupPanel {
    id: wifiManager

    // Device / network lists come from NetworkService
    readonly property var wifiDevice: NetworkService.wifiDevice
    property int fontSize: Theme.fontSize.base
    readonly property var allNetworks: NetworkService.networks
    property bool isLoadingWifi: false
    property int headerSize: Theme.fontSize.lg
    property color textColor: Theme.foreground
    property int maxNetworkHeight: 300

    minWidth: 320

    function enableWifi() {
        NetworkService.setWifiEnabled(true)
        isLoadingWifi = true
    }

    function disableWifi() {
        NetworkService.setWifiEnabled(false)
    }

    // True while wifi is starting up (no networks listed yet — undefined or
    // empty), or while any network is activating
    readonly property bool isConnecting: isLoadingWifi && (allNetworks?.length ?? 0) === 0
                                         || (allNetworks ?? []).some(n => n?.stateChanging ?? false)
    readonly property bool hideNetworksLayout: isConnecting || !NetworkService.wifiEnabled
    readonly property bool showPasswordView: passwordView.network != null

    onAllNetworksChanged: {
        if (allNetworks?.length > 0)
            isLoadingWifi = false
    }

    // Open state (+ `qs ipc call wifi …`) lives in PanelService
    open: PanelService.isOpen("wifi")

    onVisibleChanged: {
        PanelService.setOpen("wifi", visible)
        if (wifiDevice)
            wifiDevice.scannerEnabled = visible
        if (!visible)
            passwordView.cancel()
    }

    function requestPassword(net) { passwordView.open(net) }

    // --- Header with WIFI toggle ---
    PanelHeader {
        title: wifiManager.showPasswordView ? "CONNECT" : "WIFI"

        Text {
            font.family: Theme.fontFamily
            visible: !NetworkService.wifiEnabled && !wifiManager.showPasswordView
            text: "Disabled"
            color: wifiManager.textColor
        }

        Text {
            font.family: Theme.fontFamily
            visible: wifiManager.isConnecting && NetworkService.wifiEnabled && !wifiManager.showPasswordView
            text: "Connecting..."
            color: wifiManager.textColor
        }

        Item { Layout.minimumWidth: 2 }

        Toggle {
            id: wifiToggle
            visible: !wifiManager.showPasswordView
            checked: NetworkService.wifiEnabled

            onUserToggled: (value) => {
                if (value) wifiManager.enableWifi()
                else wifiManager.disableWifi()
                // User interaction broke the declarative binding — restore it
                // so external changes (rfkill, nmcli, ...) stay in sync.
                wifiToggle.checked = Qt.binding(() => NetworkService.wifiEnabled)
            }
        }
    }

    // --- Network list (hidden when showing password view) ---
    ScrollColumn {
        visible: !wifiManager.hideNetworksLayout && !wifiManager.showPasswordView
        maxHeight: wifiManager.maxNetworkHeight
        spacing: 5

        Divider {}

        SectionHeader { text: "KNOWN" }

        Repeater {
            model: NetworkService.knownNetworks
            WifiNetworkItem {
                required property var modelData
                network: modelData
                onPasswordRequested: net => wifiManager.requestPassword(net)
            }
        }

        ColumnLayout {
            visible: NetworkService.unknownNetworks.length > 0

            Divider {}

            SectionHeader { text: "OTHERS" }

            Repeater {
                model: NetworkService.unknownNetworks
                WifiNetworkItem {
                    required property var modelData
                    network: modelData
                    onPasswordRequested: net => wifiManager.requestPassword(net)
                }
            }
        }
    }

    // --- Password entry view (shown when connecting to unknown network) ---
    WifiPasswordView {
        id: passwordView
    }

    // --- VPN section ---
    ColumnLayout {
        visible: VpnService.connections.length > 0 && !wifiManager.showPasswordView
        spacing: 5

        Divider {}

        StyledText {
            text: "VPN"
            color: Theme.mainAccent
            font.pixelSize: wifiManager.headerSize
        }

        VpnList {}     // popup stays open after a tap
    }
}
