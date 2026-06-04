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
            anchors.centerIn: parent
            Clock {}
        }

        RowLayout {
            anchors.right: parent.right
            anchors.rightMargin: root.borderMargin
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            BarElement {
                Layout.fillHeight: true
                StatusBar {}
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
}
