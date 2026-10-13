import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

import qs.components
import qs.config

RowLayout {
    id: root

    spacing: 10

    // Every screen has a bar: show only the workspaces on this bar's monitor
    readonly property string screenName: QsWindow.window?.screen?.name ?? ""

    property var nameIconMap: {"obsidian": "󰇈", "slack": "󰒱", "huddle": "󰏲", "teams": "󰊻"};

    // Chat apps put their unread state in the window title: Teams (also via
    // teams-for-linux, which mirrors the page title) prefixes "(3) ", Slack
    // "* " (unread) or "! " (mention/DM). teams-for-linux may put a download
    // progress "[34%] " in front of that.
    property var unreadTitlePattern: {
        "teams": /^(\[[^\]]*\] )?\(\d+\)/,
        "slack": /^[*!]/
    };

    function hasUnread(workspace) {
        const pattern = unreadTitlePattern[workspace.name];
        if (!pattern) return false;
        return workspace.toplevels.values.some(t => pattern.test(t.title));
    }

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
        model: root.sortSpecialAndNamedWorkspacesToBack(Hyprland.workspaces.values.filter(it => it.monitor?.name === root.screenName
                                                       && (it.id >= 0 || root.isWhitelistedName(it.name))))

        StyledText {
            required property var modelData
            // the one this monitor shows (focused or not)
            property bool isActive: modelData.active
            text: isActive ? "󱓻" : root.iconOrName(modelData.name)
            Layout.preferredWidth: 15
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: Theme.fontSize.lg

            // unread dot, top right of the icon
            Rectangle {
                visible: root.hasUnread(parent.modelData)
                width: 5
                height: 5
                radius: width / 2
                color: Theme.mainAccent
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.rightMargin: -2
            }

            TapHandler {
                onTapped: Hyprland.dispatch('hl.dsp.focus({workspace="' + parent.modelData.name + '"})')
            }

            HoverHandler {
                cursorShape: Qt.PointingHandCursor
            }
        }
    }
}
