import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

import './theme'

RowLayout {
    id: workspaces

    spacing: 10

    Repeater {
        model: 9

        Text {
            required property int index  // explicitly declare it
            property var relatedWorkspaceId: index + 1
            property var ws: Hyprland.workspaces.values.find(w => w.id == relatedWorkspaceId)
            property bool isActive: Hyprland.focusedWorkspace.id == relatedWorkspaceId
            text: isActive ? "󱓻" : relatedWorkspaceId
            color: Theme.foreground
            Layout.preferredWidth: 15
            horizontalAlignment: Text.AlignHCenter
            font { pixelSize: 14; bold: true; }

            MouseArea {
                anchors.fill: parent
                onClicked: Hyprland.dispatch("workspace " + (index + 1))
                cursorShape: Qt.PointingHandCursor
            }
        }
    }
}
