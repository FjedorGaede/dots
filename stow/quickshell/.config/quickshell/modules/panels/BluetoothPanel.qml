import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import qs.components
import qs.config
import qs.services

PopupPanel {
    id: bluetoothManager

    // Adapter + device groups come from BluetoothService

    // Open state (+ `qs ipc call bluetooth …`) lives in PanelService
    open: PanelService.isOpenOn("bluetooth", screenName)

    onVisibleChanged: {
        PanelService.setOpen("bluetooth", visible, screenName)
        if (!BluetoothService.adapter) return

        if (visible) {
            // Start scanning right away, like omarchy's bluetooth panel
            BluetoothService.adapter.discovering = true
        } else {
            BluetoothService.adapter.discovering = false
        }
    }

    // BlueZ drops the discovery session after ~30s on its own — restart it
    // while the popup is open so new devices keep showing up.
    Timer {
        running: bluetoothManager.visible && (BluetoothService.adapter?.enabled ?? false)
        interval: 25000
        repeat: true
        onTriggered: {
            if (BluetoothService.adapter && BluetoothService.adapter.enabled)
                BluetoothService.adapter.discovering = true
        }
    }

    function toggleDiscovering() {
        if (!BluetoothService.adapter) return;
        BluetoothService.adapter.discovering = !BluetoothService.adapter.discovering;
    }

    minWidth: 280

    PanelHeader {
        title: "BLUETOOTH"

        Toggle {
            id: btToggle
            checked: BluetoothService.adapter?.enabled ?? false
            enabled: BluetoothService.hasAdapter

            onUserToggled: (value) => {
                if (BluetoothService.adapter)
                    BluetoothService.adapter.enabled = value
                // Restore the binding broken by user interaction
                btToggle.checked = Qt.binding(() => BluetoothService.adapter?.enabled ?? false)
            }
        }
    }

    Text {
        font.family: Theme.fontFamily
        visible: !BluetoothService.hasAdapter
        text: "No Bluetooth adapter found"
        font.italic: true
        font.pixelSize: Theme.fontSize.md
        color: Theme.fadedForeground
    }

    ColumnLayout {
        visible: BluetoothService.adapter?.enabled ?? false
        spacing: 5

        Divider {}

        SectionHeader {
            text: "CONNECTED"
            visible: BluetoothService.connectedDevices.length > 0
        }

        Repeater {
            model: BluetoothService.connectedDevices
            BluetoothDeviceItem {
                required property var modelData
                device: modelData
            }
        }

        Divider {
            visible: BluetoothService.connectedDevices.length > 0 && BluetoothService.pairedDevices.length > 0
        }

        RowLayout {
            SectionHeader {
                text: "PAIRED DEVICES"
                visible: BluetoothService.pairedDevices.length > 0
            }

            Item {
                Layout.fillWidth: true
            }
        }

        Repeater {
            model: BluetoothService.pairedDevices
            BluetoothDeviceItem {
                required property var modelData
                device: modelData
            }
        }

        Divider {}

        RowLayout {
            SectionHeader { text: "DISCOVERED DEVICES" }

            Item {
                Layout.fillWidth: true
            }

            Button {
                background: Rectangle {
                    color: Theme.mainAccent
                    radius: Theme.radius.md
                }

                contentItem: Text {
                    font.family: Theme.fontFamily
                    text: (BluetoothService.adapter?.discovering ?? false) ? "Discovering..." : "Discover"
                    color: Theme.black
                }

                HoverHandler {
                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    onTapped: bluetoothManager.toggleDiscovering()
                }
            }
        }

        Text {
            font.family: Theme.fontFamily
            text: "Discovering disabled.."
            font.italic: true
            font.pixelSize: Theme.fontSize.md
            color: Theme.fadedForeground
            visible: !(BluetoothService.adapter?.discovering ?? false)
        }

        ColumnLayout {
            visible: BluetoothService.adapter?.discovering ?? false
            Repeater {
                model: BluetoothService.discoveredDevices
                BluetoothDeviceItem {
                    required property var modelData
                    device: modelData
                }
            }
        }
    }
}
