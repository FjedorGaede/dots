import QtQuick
import QtQuick.Layouts

import '../../../lib/icons.js' as Icons
import qs.components
import qs.config
import qs.services

// Caps Lock — only visible while Caps Lock is on. Own pill, filled with the
// accent colour so it stands out (same height as StayAwake.qml).
Rectangle {
    id: capsPill
    // No Layout.fillHeight (see the right-side RowLayout in Bar.qml)

    visible: CapsLockService.on
    color: Theme.mainAccent
    radius: Theme.radius.sm
    implicitWidth: row.implicitWidth + 2 * Theme.bar.pillPadding
    implicitHeight: Math.ceil(lineMetrics.height) + Theme.bar.pillPadding

    FontMetrics {
        id: lineMetrics
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize.lg
    }

    // Pop every 2 s: the pill grows and springs back. It grows from its
    // top-right corner — down into the bar window's click-through headroom
    // (Bar.qml popRoom) and away from the clock instead of over it.
    transformOrigin: Item.TopRight

    SequentialAnimation {
        running: capsPill.visible
        loops: Animation.Infinite
        onStopped: capsPill.scale = 1

        NumberAnimation {
            target: capsPill; property: "scale"
            to: 1.35
            duration: 160; easing.type: Easing.OutQuad
        }
        NumberAnimation {
            target: capsPill; property: "scale"
            to: 1
            duration: 600; easing.type: Easing.OutElastic
            easing.amplitude: 1.0; easing.period: 0.5
        }
        PauseAnimation { duration: 1240 }
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 4

        StyledText {
            text: Icons.capsLock
            color: Theme.background
            font.pixelSize: Theme.fontSize.base
        }

        StyledText {
            text: "CAPS"
            color: Theme.background
            font.pixelSize: Theme.fontSize.base
            font.bold: true
        }
    }
}
