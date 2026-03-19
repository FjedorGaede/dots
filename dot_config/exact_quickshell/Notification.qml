import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

import './theme'

RowLayout {
    id: notification

    property int notificationCount: 0

    Process {
        command: ["swaync-client", "--subscribe"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                const state = JSON.parse(data)
                notification.notificationCount = state.count
            }
        }
    }

    StatusIcon {
        text: notification.notificationCount > 0 ? "󱅫" : "󰂚"
    }

    TapHandler {
        onTapped: Quickshell.execDetached(["swaync-client", "-t"])
    }

    HoverHandler {
        cursorShape: Qt.PointingHandCursor
        onHoveredChanged: tooltip.visible = hovered
    }

    Tooltip {
        id: tooltip
        anchorItem: notification
        tooltipText: (notification.notificationCount > 0 ? notification.notificationCount : "no") + " notifications"
    }
}
