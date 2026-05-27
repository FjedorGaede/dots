import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

import './theme'

RowLayout {
    id: root

    spacing: 10

    property var nameIconMap: {"obsidian": "󰇈"};

    function iconOrName(name) {
        return nameIconMap[name] ?? name;
    }

    function isWhitelistedName(name) {
        return !!nameIconMap[name];
    }

    function sortSpecialAndNamedWorkspacesToBack(arr) {
        return arr.sort((a, b) => {
            if (a.id >= 0 && b.id < 0) return -1;
            if (a.id < 0 && b.id >= 0) return 1;
            return a.id - b.id;
        });
    }

    Repeater {
        model: root.sortSpecialAndNamedWorkspacesToBack(Hyprland.workspaces.values.filter(it => it.id >= 0 || root.isWhitelistedName(it.name)))

        Text {
            required property var modelData
            property bool isActive: Hyprland.focusedWorkspace.id == modelData.id
            text: isActive ? "󱓻" : root.iconOrName(modelData.name)
            color: Theme.foreground
            Layout.preferredWidth: 15
            horizontalAlignment: Text.AlignHCenter
            font { family: Theme.fontFamily; pixelSize: 14 }

            TapHandler {
                onTapped: Hyprland.dispatch('hl.dsp.focus({workspace="' + parent.modelData.name + '"})')
            }

            HoverHandler {
                cursorShape: Qt.PointingHandCursor
            }
        }
    }
}
