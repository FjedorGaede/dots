import Quickshell
import Quickshell.Networking
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import './_helpers/wifiUtils.js' as WifiUtils

RowLayout {
    id: network

    property bool wifiEnabled: Networking.wifiEnabled

    property var wifiDevice: Networking.devices.values.find(d => d?.mode == WifiDeviceMode.Station)

    property bool isScanning: !!wifiDevice?.scannerEnabled
    property var allNetworks: wifiDevice?.networks.values
    property var connectedNetwork: allNetworks?.find(n => !!n?.connected)

    property bool isConnected: !!connectedNetwork
    property int signalStrength: connectedNetwork?.signalStrength * 100

    property color defaultColor: "white"

    function getWifiIcon() {
        return isConnected ? WifiUtils.getWifiIconForSignalStrength(signalStrength) : WifiUtils.DISCONNECTED_ICON;
    }

    Text {
        text: network.getWifiIcon()
        color: network.defaultColor
    }

    PanelWindow {
        id: wifiManager
        visible: true
        implicitWidth: 200
        implicitHeight: 200
        // TODO remove this
        anchors.right: true
        exclusiveZone: -1

        property var wifiDevice: network.wifiDevice
        property var allNetworks: wifiManager.wifiDevice?.networks.values
        property var knownNetworks: allNetworks?.filter(network => network.known) || []
        property var unknownNetworks: allNetworks?.filter(network => !network.known) || []

        ColumnLayout {
            width: parent.width
            spacing: 5

            Button {
                text: "Start Scanning"
                onClicked: wifiManager.wifiDevice.scannerEnabled = !wifiManager.wifiDevice.scannerEnabled
            }

            // BusyIndicator {
            //     running: wifiManager.wifiDevice.scannerEnabled
            // }

            Text {
                text: "Known Network"
            }

            Divider {}

            Repeater {
                model: wifiManager.knownNetworks

                WifiNetworkItem { 
                    required property var modelData
                    network: modelData
                }
            }

            Text {
                visible: wifiManager.unknownNetworks.length > 0
                text: "Other Networks"
            }

            Divider {
                visible: wifiManager.unknownNetworks.length > 0
            }

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
