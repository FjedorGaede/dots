import QtQuick
import './theme'

Text {
    property int size: 14

    color: Theme.foreground
    font.family: Theme.fontFamily
    font.pixelSize: size
}
