import QtQuick

import qs.config

// "●○○" loading animation (ListItem Loading status, LAN scan footer).
// Only ticks while visible.
StyledText {
    id: root

    readonly property var frames: ["●○○", "○●○", "○○●", "○●○"]
    property int frame: 0

    color: Theme.dimForeground
    text: frames[frame]

    Timer {
        running: root.visible
        interval: 400
        repeat: true
        onTriggered: root.frame = (root.frame + 1) % root.frames.length
    }
}
