import QtQuick
import QtQuick.Layouts

import qs.components
import qs.config

// Selectable row in the webcam bubble's setup card: glyph, label, check
// when on (camera list, microphone, desktop audio)
Rectangle {
    id: option
    property string glyph: ""
    property string label: ""
    property bool checked: false
    signal clicked()

    implicitHeight: 30
    radius: Theme.radius.md
    color: optionArea.containsMouse ? Theme.hoverOverlay : "transparent"

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        spacing: 8

        StyledText {
            Layout.preferredWidth: 18
            horizontalAlignment: Text.AlignHCenter
            text: option.glyph
            color: option.checked ? Theme.mainAccent : Theme.dimForeground
            font.pixelSize: Theme.fontSize.md
        }
        StyledText {
            Layout.fillWidth: true
            text: option.label
            elide: Text.ElideRight
            color: option.checked ? Theme.foreground : Theme.fadedForeground
            font.pixelSize: Theme.fontSize.base
        }
        StyledText {
            text: option.checked ? "\uF00C" : ""
            color: Theme.mainAccent
            font.pixelSize: Theme.fontSize.sm
        }
    }

    MouseArea {
        id: optionArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: option.clicked()
    }
}
