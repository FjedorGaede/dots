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

    // TextMetrics snaps the ink box outwards to whole pixels, so glyphs with
    // the same visual centre got boxes 1px apart → measure at 16x and scale
    readonly property real oversample: 16
    readonly property rect ink: Qt.rect(metrics.tightBoundingRect.x / oversample,
                                        metrics.tightBoundingRect.y / oversample,
                                        metrics.tightBoundingRect.width / oversample,
                                        metrics.tightBoundingRect.height / oversample)

    anchors.fill: parent

    TextMetrics {
        id: metrics
        text: glyph.text
        font.family: glyph.font.family
        font.pixelSize: glyph.font.pixelSize * root.oversample
    }

    StyledText {
        id: glyph
        readonly property real inkX: (root.width - root.ink.width) / 2
                                     - root.ink.x + root.opticalShift
        x: root.roundX ? Math.round(inkX) : inkX
        // tightBoundingRect.y is relative to the baseline
        y: Math.round((root.height - root.ink.height) / 2
                      - (baselineOffset + root.ink.y)
                      + root.opticalShiftY)
    }
}
