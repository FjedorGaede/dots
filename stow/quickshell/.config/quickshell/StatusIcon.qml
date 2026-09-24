import QtQuick
import QtQuick.Layouts
import './theme'

Text {
    property int size: 14

    color: Theme.foreground
    font.family: Theme.fontFamily
    font.pixelSize: size

    // Center the glyph in the fixed-width box; Qt's default is left-aligned,
    // which made the bar pills look like they had more space on the right
    horizontalAlignment: Text.AlignHCenter

    width: 32

    // Keep the layout height at the base (14px) line height regardless of
    // `size`, so larger glyphs (e.g. the 16px power icon) don't make their
    // bar pill taller than the others and eat the gap to the window below.
    // The glyph is still rendered at full size, vertically centered.
    FontMetrics {
        id: baseMetrics
        font.family: Theme.fontFamily
        font.pixelSize: 14
    }
    Layout.preferredHeight: Math.ceil(baseMetrics.height)
    verticalAlignment: Text.AlignVCenter
}
