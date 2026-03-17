import Quickshell
import QtQuick
import QtQuick.Layouts

import './theme'


PanelWindow {
    id: root
    anchors.top: true
    anchors.right: true
    anchors.left: true
    implicitHeight: 30
    color: "transparent"

    property int borderMargin: 4

    BarElement {
        anchors.left: parent.left
        anchors.leftMargin: root.borderMargin
        HyprlandWorkspaces {}
    }

    BarElement {
        anchors.centerIn: parent
        Clock {}
    }

    BarElement {
        anchors.right: parent.right
        anchors.rightMargin: root.borderMargin
        SystemStats {}
    }
}
