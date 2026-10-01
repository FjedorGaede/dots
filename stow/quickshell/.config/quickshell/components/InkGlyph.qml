import QtQuick

// A nerd glyph centered by its visible ink (TextMetrics.tightBoundingRect)
// instead of its advance width — nerd glyphs overflow their advance, which
// made the media pill look lopsided (docs/GOTCHAS.md). Fills its parent box;
// the box is sized by the caller (usually from `ink`).
Item {
    id: root

    property alias text: glyph.text
    property alias color: glyph.color
    property alias font: glyph.font
    // Extra horizontal nudge (optical correction, e.g. ▶)
    property real opticalShift: 0
    // Extra vertical nudge (optical correction, e.g. the power glyph whose
    // thin stem makes its ink box taller than its visual mass)
    property real opticalShiftY: 0
    // Round the x position (the play/pause glyph did, the note didn't)
    property bool roundX: false

    readonly property rect ink: metrics.tightBoundingRect

    anchors.fill: parent

    TextMetrics {
        id: metrics
        text: glyph.text
        font: glyph.font
    }

    StyledText {
        id: glyph
        readonly property real inkX: (root.width - metrics.tightBoundingRect.width) / 2
                                     - metrics.tightBoundingRect.x + root.opticalShift
        x: root.roundX ? Math.round(inkX) : inkX
        // tightBoundingRect.y is relative to the baseline
        y: Math.round((root.height - metrics.tightBoundingRect.height) / 2
                      - (baselineOffset + metrics.tightBoundingRect.y)
                      + root.opticalShiftY)
    }
}
