import QtQuick

Rectangle {
    id: progressBar

    property color backgroundColor: "darkgray"
    property color fillColor: "black"
    property int percent: 0 // from 0 - 100

    width: 200
    height: 12
    radius: 15
    color: backgroundColor
    clip: true

    function fillWidth() {
        if (percent === 0) {
            return 0;
        }

        return Math.max(progressBar.height, progressBar.width * progressBar.percent / 100);
    }

    Rectangle {
        radius: 15
        height: parent.height
        width: progressBar.fillWidth();
        color: progressBar.fillColor
    }
}
