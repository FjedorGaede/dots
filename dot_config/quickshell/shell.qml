import Quickshell
import QtQuick
import QtQuick.Layouts


PanelWindow {
    id: root
    anchors.top: true
    anchors.right: true
    anchors.left: true 
    implicitHeight: 30
    color: "#f6aede"

    RowLayout {
        anchors.fill: parent
        anchors.margins: 8

        spacing: 10

        HyprlandWorkspaces {}

        Item {
            Layout.fillWidth: true
        }

        Clock {}

        Item {
            Layout.fillWidth: true
        }

        SystemStats {}
    }
}

