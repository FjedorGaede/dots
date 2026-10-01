import QtQuick

import qs.components
import qs.config
import qs.services

// Coffee cup — only visible while "stay awake" is on (suspend
// inhibited); click turns it off again. Own pill (same look as
// Pill) so the padding is identical on both sides.
Rectangle {
    id: stayAwakePill
    // No Layout.fillHeight (see the right-side RowLayout in Bar.qml)

    visible: StayAwakeService.enabled
    color: Theme.background
    radius: Theme.radius.sm
    // Ink is 1.2em wide (≈15.6px at size 13); pill = ink + 16
    implicitWidth: 32
    // Same height as the other bar pills: Pill = content + pillPadding, and
    // their content (BarButton) is laid out at the 14px base line height
    implicitHeight: Math.ceil(lineMetrics.height) + Theme.bar.pillPadding

    FontMetrics {
        id: lineMetrics
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize.lg
    }

    // The mug-saucer glyph's ink hangs right of its 0.6em advance
    // cell (ink starts at cell origin), so place the box so the
    // ink — not the cell — sits centered: 8 + 15.6/2 = ~12 from
    // pill left → horizontalCenterOffset ≈ -4
    StyledText {
        id: stayIcon
        anchors.centerIn: parent
        text: "\uF0F4"
        color: Theme.mainAccent
        font.pixelSize: Theme.fontSize.base
    }

    TapHandler { onTapped: StayAwakeService.toggle() }

    HoverHandler {
        cursorShape: Qt.PointingHandCursor
        onHoveredChanged: stayTooltip.visible = hovered
    }

    Tooltip {
        id: stayTooltip
        anchorItem: stayAwakePill
        tooltipText: "Stay awake — suspend inhibited (click to disable)"
    }
}
