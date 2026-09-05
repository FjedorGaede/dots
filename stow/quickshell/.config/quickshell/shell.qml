//@ pragma UseQApplication
import Quickshell
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

PanelWindow {
    id: root
    anchors.top: true
    anchors.right: true
    anchors.left: true
    implicitHeight: 30
    color: "transparent"

    property int borderMargin: 4

    Control {
        anchors.fill: parent
        background: null

        BarElement {
            anchors.left: parent.left
            anchors.leftMargin: root.borderMargin
            HyprlandWorkspaces {}
        }

        BarElement {
            id: clockElement
            anchors.centerIn: parent
            Clock {}
        }

        // Media readout, right of the clock (hidden when nothing plays)
        BarElement {
            anchors.left: clockElement.right
            anchors.leftMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            MediaPlayer {}
        }

        RowLayout {
            anchors.right: parent.right
            anchors.rightMargin: root.borderMargin
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            BarElement {
                id: statusBarElement
                Layout.fillHeight: true
                Layout.preferredWidth: statusBar.implicitWidth > 0 ? -1 : 0
                clip: true
                StatusBar {
                    id: statusBar
                }
            }

            BarElement {
                Layout.fillHeight: true
                SystemTray {}
            }

            BarElement {
                Layout.fillHeight: true
                SystemStats {}
            }
        }
    }

    OSD {}

    NotificationToasts {}
}
