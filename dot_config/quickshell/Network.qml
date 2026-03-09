import Quickshell
import Quickshell.Networking
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

import './_helpers/getIntervalIndex.js' as Util

RowLayout {
    id: network

    property bool wifiEnabled: Networking.wifiEnabled

    property var wifiDevice: Networking.devices.values.find(d => d?.mode == WifiDeviceMode.Station)

    property bool isScanning: !!wifiDevice?.scannerEnabled
    property var allNetworks: wifiDevice?.networks.values
    property var connectedNetwork: allNetworks.find(n => !!n?.connected)

    property bool isConnected: !!connectedNetwork
    property int signalStrength: connectedNetwork?.signalStrength * 100

    property color defaultColor: "white"

    function getIcon() {
        const wifiIcons = ["󰤯", "󰤟", "󰤢", "󰤥", "󰤨"];
        const disconnectedIcon = "󰖪"

        console.log("allNetworks", allNetworks.map(n => n.name))

        if (!isConnected) {
            return disconnectedIcon;
        }

        return wifiIcons[Util.getIntervalIndex(signalStrength, 100, wifiIcons.length)]
    }

    Text {
        text: network.getIcon()
        color: network.defaultColor
    }

    PanelWindow {
        id: wifiManager
        visible: true
        implicitWidth: 200
        implicitHeight: 200

        property var rawWifiNetworkList:  []
        property var wifiNetworksList:  []
        property var wifiDevice: network.wifiDevice

        function processRawWifiList() {
            wifiNetworksList = rawWifiNetworkList.map(wifiNetworkData => {
                const parts = wifiNetworkData.split(":");

                if (parts.length < 3) {
                    console.error(`I could not split ${wifiNetworkData} into three parts`);
                }

                const [signalStrength, security, ...rest] = parts;
                const ssid = rest.join(":");

                console.log(`${ssid}: ${signalStrength} - ${security}`)


                return { ssid, signalStrength, security };
            });

            rawWifiNetworkList = [];
        }

        Process {
            id: wifiscan
            // Claude:
            // List all APs (terse, SSID/signal/security), drop unnamed networks (empty SSID),
            // sort by signal descending, then deduplicate by SSID keeping the strongest entry. 
            command: ["bash", "-c", "nmcli -t -f SIGNAL,SECURITY,SSID dev wifi list | grep -v ':$' | sort -t: -k1 -rn | sort -t: -k3,3 -u"]
            stdout: SplitParser {
                onRead: line => {
                    if (!wifiManager.rawWifiNetworkList) {
                        wifiManager.rawWifiNetworkList = [];
                    }

                    wifiManager.rawWifiNetworkList.push(line);
                }
            }
            onExited: wifiManager.processRawWifiList()

            running: true
        }

        ColumnLayout {
            width: parent.width
            spacing: 5

            Repeater {
                model: wifiManager.wifiNetworksList

                Rectangle {
                    required property var modelData

                    Layout.fillWidth: true
                    implicitHeight: 15
                    color: hoverHandler.hovered ? "red" : "white"
                    border.color: "black"

                    HoverHandler {
                        id: hoverHandler
                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        onTapped: wifiManager.wifiDevice.scannerEnabled = true
                    }

                    Text {
                        text: `${parent.modelData.ssid} - ${parent.modelData.signalStrength}`
                    }
                }
            }
        }

        // MouseArea {
        //     anchors.fill: parent
        //     hoverEnabled: true
        //     cursorShape: Qt.PointingHandCursor
        //     onClicked: wifiscan.running = true
        // }
    }
}
