import QtQuick

import './theme'

Rectangle {
    id: root

    property int size: 36
    property int glyphSize: 15
    signal clicked()

    implicitWidth: size
    implicitHeight: size
    radius: 6
    color: hover.hovered ? Theme.hoverOverlay : "transparent"

    HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: root.clicked() }

    Text {
        anchors.centerIn: parent
        text: "✕"
        color: hover.hovered ? Theme.foreground : Theme.dimForeground
        font { family: Theme.fontFamily; pixelSize: root.glyphSize }
    }
}
