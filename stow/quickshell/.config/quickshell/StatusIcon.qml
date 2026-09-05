import QtQuick
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
}
