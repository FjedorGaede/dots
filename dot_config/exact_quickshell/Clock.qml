import QtQuick
import QtQuick.Layouts
import Quickshell

import './theme'

RowLayout {
    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    Text {
        id: clockText
        property bool showDate: false
        text: Qt.formatDateTime(clock.date, showDate ? "dddd - hh:mm - dd.MM.yyyy" : "hh:mm")
        color: Theme.foreground
        font { family: Theme.fontFamily; pixelSize: 14 }

        MouseArea {
            anchors.fill: parent
            onClicked: clockText.showDate = !clockText.showDate
            cursorShape: Qt.PointingHandCursor
        }
    }
}
