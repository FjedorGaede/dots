import QtQuick

import qs.components
import qs.config
import qs.services

// Screen share in progress (any app, via the portal): pulsing red record dot,
// same pulse as Recording. Click stops every share.
BarButton {
    id: root

    visible: ScreenShareService.active

    icon: "\uDB81\uDC4A"   // md-record
    iconColor: Theme.red
    tooltipText: ScreenShareService.count > 1
        ? `${ScreenShareService.count} screen shares — click to stop all`
        : "Screen sharing — click to stop"
    onClicked: ScreenShareService.stop()

    SequentialAnimation on opacity {
        running: root.visible
        loops: Animation.Infinite
        onStopped: root.opacity = 1
        NumberAnimation { to: 0.35; duration: 800; easing.type: Easing.InOutQuad }
        NumberAnimation { to: 1.0; duration: 800; easing.type: Easing.InOutQuad }
    }
}
