import Quickshell
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import qs.components
import qs.config
import qs.services
import qs.modules.bar.indicators

// The top bar window. Other top-level windows (OSD, LAN devices, toasts)
// are declared as its children in shell.qml, exactly as before the move.
PanelWindow {
    id: root
    anchors.top: true
    anchors.right: true
    anchors.left: true
    // Extra click-through room below the bar for the CAPS pill's pop
    // (indicators/CapsLock.qml). Windows still only make room for the bar.
    readonly property int popRoom: 15
    implicitHeight: Theme.bar.height + popRoom
    exclusiveZone: Theme.bar.height
    mask: Region { item: barArea }
    color: "transparent"

    property int borderMargin: Theme.bar.edgeMargin

    Control {
        id: barArea
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: Theme.bar.height
        background: null

        Pill {
            anchors.left: parent.left
            anchors.leftMargin: root.borderMargin
            Workspaces {}
        }

        Pill {
            id: clockElement
            anchors.centerIn: parent
            Clock {}
        }

        // Accent "CAPS" pill, left of the clock (only while Caps Lock is on)
        CapsLock {
            anchors.right: clockElement.left
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
        }

        // Media readout, right of the clock (hidden when nothing plays)
        Pill {
            anchors.left: clockElement.right
            anchors.leftMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            visible: MediaService.activePlayer !== null
            MediaIndicator {}
        }

        // Right-side pills: no Layout.fillHeight — it stretched them to the
        // tallest sibling, making them flush with the window below. They keep
        // their natural height and are vertically centered, like the left
        // pills, which leaves the bottom gap (docs/GOTCHAS.md).
        RowLayout {
            anchors.right: parent.right
            anchors.rightMargin: root.borderMargin
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            Pill {
                id: appStatusPill
                Layout.preferredWidth: appStatus.implicitWidth > 0 ? -1 : 0
                clip: true
                AppStatusArea {
                    id: appStatus
                }
            }

            // Hidden while there are no tray items
            Pill {
                visible: tray.numberOfSystemTrayItems > 0
                Tray {
                    id: tray
                }
            }

            // Coffee cup (only while "stay awake" is on) — own pill
            StayAwake {}

            // Keyboard (only while the laptop keyboard is disabled) — own pill
            LaptopKeyboard {}

            Pill {
                StatusArea {}
            }
        }
    }
}
