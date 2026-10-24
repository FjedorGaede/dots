import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import '../../lib/icons.js' as Icons
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
        if (visible) BluetoothService.checkAgent()
        if (!BluetoothService.adapter) return

        // Start scanning right away, like omarchy's bluetooth panel.
        // Pairable only while open: bt-agent auto-accepts every pair request
        // (NoInputNoOutput), so outside this window bluez must refuse them.
        BluetoothService.adapter.discovering = visible
        BluetoothService.adapter.pairable = visible
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

    // No pairing agent → keyboards/phones can't pair. Click = install in a
    // floating terminal (BluetoothService.installAgent)
    ListItem {
        visible: BluetoothService.hasAdapter && !BluetoothService.agentInstalled
        size: ListItem.Small
        icon: Icons.bluetooth.warning
        label: "bluez-tools not installed — click to install"
        onTapped: BluetoothService.installAgent()
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

        // Each section brings its own divider and is hidden while empty →
        // no stacked dividers when nothing was ever paired
        ColumnLayout {
            visible: BluetoothService.connectedDevices.length > 0
            Layout.fillWidth: true
            spacing: 5

            Divider {}

            SectionHeader { text: "CONNECTED" }

            Repeater {
                model: BluetoothService.connectedDevices
                BluetoothDeviceItem {
                    required property var modelData
                    device: modelData
                }
            }
        }

        ColumnLayout {
            visible: BluetoothService.pairedDevices.length > 0
            Layout.fillWidth: true
            spacing: 5

            Divider {}

            SectionHeader { text: "PAIRED DEVICES" }

            Repeater {
                model: BluetoothService.pairedDevices
                BluetoothDeviceItem {
                    required property var modelData
                    device: modelData
                }
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

        // One status line for both states: discovery switches on as the panel
        // opens, so swapping text instead of showing/hiding keeps the size
        // stable while it maps (docs/GOTCHAS.md, popup resize flash)
        Text {
            readonly property bool discovering: BluetoothService.adapter?.discovering ?? false
            font.family: Theme.fontFamily
            text: discovering ? "Searching for devices…" : "Discovery is off"
            font.italic: true
            font.pixelSize: Theme.fontSize.md
            color: Theme.fadedForeground
            visible: !discovering || BluetoothService.discoveredDevices.length === 0
        }

        ColumnLayout {
            Layout.fillWidth: true
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
