import QtQuick

import qs.config

// Hand-rolled slider (like omarchy's PanelSlider): QQC2 Slider was not
// draggable inside the popup window (docs/GOTCHAS.md). Range 0–maxVal
// (150, matching the wpctl/OSD overshoot); >100% renders red.
//
// `live` is the displayed value. The owner syncs it IMPERATIVELY from the
// real volume, and only while !dragging — a binding would snap back mid-drag.
Item {
    id: slider

    readonly property real maxVal: 150
    property real live: 0
    property bool dragging: false
    // Draw the translucent red zone beyond 100%
    property bool overshootEnabled: false
    // Current value is in the red (fill + knob turn red)
    property bool overshooting: false

    // User moved the slider to `value` (0–maxVal)
    signal moved(real value)

    implicitHeight: 20

    function valueFromX(x) {
        return Math.max(0, Math.min(maxVal, x / width * maxVal));
    }

    function apply(next) {
        live = next;
        slider.moved(next);
    }

    Rectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.right: parent.right
        height: 5
        radius: 2.5
        color: Theme.overlay

        // Overshoot ZONE: translucent red track beyond 100%, so the
        // danger range is visible as an area rather than a line
        Rectangle {
            x: parent.width * (100 / slider.maxVal)
            width: parent.width - x
            height: parent.height
            radius: parent.radius
            visible: slider.overshootEnabled
            color: Theme.alpha(Theme.error, 0.15)
        }

        Rectangle {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width * (slider.live / slider.maxVal)
            height: parent.height
            radius: parent.radius
            // Mute is shown by the glyph, not by graying out the fill
            color: slider.overshooting ? Theme.error : Theme.mainAccent
        }
    }

    Rectangle {
        anchors.verticalCenter: track.verticalCenter
        x: Math.max(0, Math.min(track.width - width,
                                track.width * (slider.live / slider.maxVal) - width / 2))
        width: 13
        height: 13
        radius: 6.5
        border.width: 2
        border.color: Theme.background
        color: slider.overshooting ? Theme.error : Theme.foreground
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onPressed: (mouse) => {
            slider.dragging = true;
            slider.apply(slider.valueFromX(mouse.x));
        }
        onPositionChanged: (mouse) => {
            if (slider.dragging) slider.apply(slider.valueFromX(mouse.x));
        }
        onReleased: slider.dragging = false
        onWheel: (wheel) => {
            slider.apply(slider.live + (wheel.angleDelta.y > 0 ? 5 : -5));
        }
    }
}
