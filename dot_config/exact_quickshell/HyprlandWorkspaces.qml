import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

import './theme'

RowLayout {
    id: workspaces

    spacing: 10

    Repeater {
        model: Hyprland.workspaces.values.filter(it => it.id >= 0)

        Text {
            required property var modelData
            property bool isActive: Hyprland.focusedWorkspace.id == modelData.id
            text: isActive ? "󱓻" : modelData.id
            color: Theme.foreground
            Layout.preferredWidth: 15
            horizontalAlignment: Text.AlignHCenter
            font { family: Theme.fontFamily; pixelSize: 14 }

            TapHandler {
                onTapped: Hyprland.dispatch("hl.dsp.focus({workspace=" + parent.modelData.id + "})")
            }

            HoverHandler {
                cursorShape: Qt.PointingHandCursor
            }
        }
    }
}
