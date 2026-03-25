import Quickshell.Networking
import QtQuick
import QtQuick.Layouts

import './theme'

PopupBase {
    id: wifiManager

    required property var network

    property var wifiDevice: network.wifiDevice
    property int fontSize: 13
    property var allNetworks: wifiDevice?.networks.values
    property var knownNetworks: allNetworks?.filter(n => n.known) || []
    property var unknownNetworks: allNetworks?.filter(n => !n.known) || []
    property bool isLoadingWifi: false
    property int headerSize: 14
    property color textColor: Theme.foreground

    minWidth: 320

    function enableWifi() {
        Networking.wifiEnabled = true
        isLoadingWifi = true
    }

    function disableWifi() {
        Networking.wifiEnabled = false
    }

    readonly property bool isConnecting: isLoadingWifi && (allNetworks?.length === 0 ?? true)
    readonly property bool hideNetworksLayout: isConnecting || !Networking.wifiEnabled

    onAllNetworksChanged: {
        if (allNetworks?.length > 0)
            isLoadingWifi = false
    }

    onVisibleChanged: {
        if (visible && wifiDevice)
            wifiDevice.scannerEnabled = true
        else
            wifiDevice.scannerEnabled = false
    }

    RowLayout {
        Text {
            text: "WIFI"
            color: Theme.mainAccent
            font.pixelSize: wifiManager.headerSize
        }

        Item { Layout.fillWidth: true }

        Text {
            visible: !Networking.wifiEnabled
            text: "Disabled"
            color: wifiManager.textColor
        }

        Text {
            visible: wifiManager.isConnecting && Networking.wifiEnabled
            text: "Connecting..."
            color: wifiManager.textColor
        }

        Item { Layout.minimumWidth: 2 }

        Toggle {
            checked: Networking.wifiEnabled
            onCheckedChanged: checked ? wifiManager.enableWifi() : wifiManager.disableWifi()
        }
    }

    ColumnLayout {
        visible: !wifiManager.hideNetworksLayout

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
                }
            }
        }
    }
}
