import QtQuick

Rectangle {
    id: iconButton

    property int size: 56

    property string icon: "xxxx"
    property var tapCallback

    width: size
    height: size
    radius: 8
    opacity: hoverHandler.hovered ? 0.85 : 1.0

    Behavior on opacity { NumberAnimation { duration: 100 } }

    // MouseArea (not TapHandler!) so it takes an exclusive grab and wins
    // against any MouseArea stacked below (e.g. the power menu click absorber)
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: if (iconButton.tapCallback) iconButton.tapCallback()
    }

    HoverHandler { id: hoverHandler; cursorShape: Qt.PointingHandCursor }

    Text {
        font { pixelSize: Math.max(12, Math.round(iconButton.size * 0.44)) }
        anchors.centerIn: parent
        text: iconButton.icon
    }
}
