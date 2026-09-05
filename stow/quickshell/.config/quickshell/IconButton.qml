import QtQuick

Rectangle {
    id: iconButton

    property int size: 72

    property string icon: "xxxx"
    property var tapCallback

    width: size
    height: size
    radius: 8
    opacity: hoverHandler.hovered ? 0.85 : 1.0

    Behavior on opacity { NumberAnimation { duration: 100 } }

    TapHandler { onTapped: if (iconButton.tapCallback) iconButton.tapCallback() }

    HoverHandler { id: hoverHandler; cursorShape: Qt.PointingHandCursor }

    Text {
        font { pixelSize: 32 }
        anchors.centerIn: parent
        text: iconButton.icon
    }
}
