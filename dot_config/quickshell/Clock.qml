import QtQuick
import QtQuick.Layouts
import Quickshell

RowLayout {
    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    Text {
        id: clockText
        property bool showDate: false
        text: Qt.formatDateTime(clock.date, showDate ? "dddd - hh:mm - dd.MM.yyyy" : "hh:mm")
        color: "white"
        font { bold: true }

        MouseArea {
            anchors.fill: parent
            onClicked: clockText.showDate = !clockText.showDate
            cursorShape: Qt.PointingHandCursor
        }
    }
}
