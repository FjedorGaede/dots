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
    implicitHeight: Theme.bar.height
    color: "transparent"

    property int borderMargin: Theme.bar.edgeMargin

    Control {
        anchors.fill: parent
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

            Pill {
                Tray {}
            }

            // Coffee cup (only while "stay awake" is on) — own pill
            StayAwake {}

            Pill {
                StatusArea {}
            }
        }
    }
}
