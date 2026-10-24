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
    readonly property bool showVpnImport: vpnImport.active
    // Password prompt or VPN import replaces the lists
    readonly property bool showSubView: showPasswordView || showVpnImport

    onAllNetworksChanged: {
        if (allNetworks?.length > 0)
            isLoadingWifi = false
    }

    // Open state (+ `qs ipc call wifi …`) lives in PanelService
    readonly property bool requested: PanelService.isOpenOn("wifi", screenName)
    // A popup resized within a few ms of mapping can show its first frame at
    // the wrong scale (docs/GOTCHAS.md). Without the scanner Quickshell lists
    // only known/active networks; enabling it adds the others one by one
    // (~2 ms apart, done after ~6 ms), with no "done" signal → scanner on
    // when requested, map once the list is quiet for 20 ms (at most 100 ms).
    property bool listSettled: false
    open: requested && listSettled

    onRequestedChanged: {
        listSettled = false
        if (!requested) return
        if (wifiDevice && NetworkService.wifiEnabled) {
            wifiDevice.scannerEnabled = true
            settleTimer.restart()
            settleCap.restart()
        } else {
            listSettled = true
        }
    }

    Timer {
        id: settleTimer
        interval: 20
        onTriggered: { settleCap.stop(); wifiManager.listSettled = true }
    }
    Timer {
        id: settleCap
        interval: 100
        onTriggered: { settleTimer.stop(); wifiManager.listSettled = true }
    }
    Connections {
        target: NetworkService
        function onNetworksChanged() {
            if (settleTimer.running) settleTimer.restart()
        }
    }

    onVisibleChanged: {
        PanelService.setOpen("wifi", visible, screenName)
        if (wifiDevice)
            wifiDevice.scannerEnabled = visible || requested
        if (!visible) {
            passwordView.cancel()
            vpnImport.cancel()
        }
    }

    function requestPassword(net) { passwordView.open(net) }

    // --- Header with WIFI toggle ---
    PanelHeader {
        title: wifiManager.showPasswordView ? "CONNECT"
             : wifiManager.showVpnImport ? "ADD VPN"
             : "WIFI"

        Text {
            font.family: Theme.fontFamily
            visible: !NetworkService.wifiEnabled && !wifiManager.showSubView
            text: "Disabled"
            color: wifiManager.textColor
        }

        Text {
            font.family: Theme.fontFamily
            visible: wifiManager.isConnecting && NetworkService.wifiEnabled && !wifiManager.showSubView
            text: "Connecting..."
            color: wifiManager.textColor
        }

        Item { Layout.minimumWidth: 2 }

        Toggle {
            id: wifiToggle
            visible: !wifiManager.showSubView
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
        visible: !wifiManager.hideNetworksLayout && !wifiManager.showSubView
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

    // --- VPN import view ("+ Add VPN") ---
    VpnImportView {
        id: vpnImport
    }

    // --- VPN section ---
    ColumnLayout {
        visible: !wifiManager.showSubView
        spacing: 5

        Divider {}

        StyledText {
            text: "VPN"
            color: Theme.mainAccent
            font.pixelSize: wifiManager.headerSize
        }

        VpnList {}     // popup stays open after a tap

        GhostButton {
            Layout.fillWidth: true
            leftAligned: true
            text: "+ Add VPN"
            textSize: Theme.fontSize.md
            onClicked: vpnImport.open()
        }
    }
}
