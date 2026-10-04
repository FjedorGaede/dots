import QtQuick

import qs.components
import qs.config
import qs.services

// Keyboard — only visible while the built-in laptop keyboard is disabled;
// click turns it back on. Own pill, same build as StayAwake.qml.
Rectangle {
    id: keyboardPill
    // No Layout.fillHeight (see the right-side RowLayout in Bar.qml)

    visible: KeyboardService.disabled
    color: Theme.background
    radius: Theme.radius.sm
    implicitWidth: 32
    // Same height as the other bar pills (see StayAwake.qml)
    implicitHeight: Math.ceil(lineMetrics.height) + Theme.bar.pillPadding

    FontMetrics {
        id: lineMetrics
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize.lg
    }

    // Center by ink, not advance width (docs/GOTCHAS.md → Nerd glyph ink)
    InkGlyph {
        text: "\uF11C"
        color: Theme.mainAccent
        font.pixelSize: Theme.fontSize.base
    }

    TapHandler { onTapped: KeyboardService.setDisabled(false) }

    HoverHandler {
        cursorShape: Qt.PointingHandCursor
        onHoveredChanged: keyboardTooltip.visible = hovered
    }

    Tooltip {
        id: keyboardTooltip
        anchorItem: keyboardPill
        tooltipText: "Laptop keyboard disabled (click to enable)"
    }
}
