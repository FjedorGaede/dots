import QtQuick

import qs.config

// Big colored square button (home menu power row)
Rectangle {
    id: iconButton

    property int size: 56
    property string icon: ""

    signal clicked()

    width: size
    height: size
    radius: Theme.radius.md
    opacity: hoverHandler.hovered ? 0.85 : 1.0

    Behavior on opacity { NumberAnimation { duration: Theme.anim.fast } }

    // MouseArea (not TapHandler!) so it takes an exclusive grab and wins
    // against any MouseArea stacked below (e.g. the power menu click absorber)
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: iconButton.clicked()
    }

    HoverHandler { id: hoverHandler; cursorShape: Qt.PointingHandCursor }

    Text {
        font { pixelSize: Math.max(12, Math.round(iconButton.size * 0.44)) }
        anchors.centerIn: parent
        text: iconButton.icon
        // Plain Text without a family, black glyph: that's the look (a Text
        // with no color renders black — made explicit, same value)
        color: Theme.black
    }
}
