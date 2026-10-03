import QtQuick
import QtQuick.Layouts

import qs.components
import qs.config
import qs.services

// Screen recording in progress: red dot (pause glyph while paused) + elapsed
// time │ pause/resume + stop buttons. The only recording control — a
// floating one would end up in the video (docs/GOTCHAS.md).
RowLayout {
    id: root

    readonly property bool paused: RecorderService.phase === "paused"

    visible: RecorderService.active
    spacing: 0

    // Same 14px base line height as BarButton → the pill keeps the bar's
    // pill height (docs/GOTCHAS.md)
    FontMetrics {
        id: lineMetrics
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize.lg
    }
    readonly property int lineHeight: Math.ceil(lineMetrics.height)

    // Small hover-highlighted glyph button
    component Control: Rectangle {
        id: control
        property string glyph: ""
        property color glyphColor: Theme.foreground
        signal clicked()

        implicitWidth: 22
        implicitHeight: root.lineHeight
        radius: Theme.radius.xs
        color: hover.hovered ? Theme.hoverOverlay : "transparent"

        StyledText {
            anchors.centerIn: parent
            text: control.glyph
            color: control.glyphColor
            font.pixelSize: Theme.fontSize.xs
        }

        HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: control.clicked() }
    }

    // ── Status: dot + time ──
    Item {
        implicitWidth: 10
        implicitHeight: root.lineHeight

        Rectangle {
            anchors.centerIn: parent
            visible: !root.paused
            width: 8
            height: 8
            radius: 4
            color: Theme.red

            SequentialAnimation on opacity {
                running: !root.paused && root.visible
                loops: Animation.Infinite
                NumberAnimation { to: 0.35; duration: 800; easing.type: Easing.InOutQuad }
                NumberAnimation { to: 1.0; duration: 800; easing.type: Easing.InOutQuad }
            }
        }

        StyledText {
            anchors.centerIn: parent
            visible: root.paused
            text: ""
            color: Theme.yellow
            font.pixelSize: Theme.fontSize.xs
        }
    }

    StyledText {
        Layout.leftMargin: 6
        text: RecorderService.formatElapsed(RecorderService.elapsed)
        color: root.paused ? Theme.yellow : Theme.foreground
        font.pixelSize: Theme.fontSize.base
        font.features: { "tnum": 1 }   // fixed-width digits → no jitter
    }

    VerticalDivider {
        Layout.fillHeight: false
        Layout.preferredHeight: 12
        Layout.leftMargin: 8
        Layout.rightMargin: 4
        implicitWidth: 1
        dividerColor: Theme.alpha(Theme.foreground, 0.2)
    }

    // ── Controls ──
    Control {
        glyph: root.paused ? "" : ""
        onClicked: RecorderService.togglePause()
    }

    Control {
        Layout.leftMargin: 2
        glyph: ""
        glyphColor: Theme.red
        onClicked: RecorderService.stop()
    }
}
