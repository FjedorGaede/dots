import QtQuick

Rectangle {
    id: progressBar

    property color backgroundColor: "darkgray"
    property color fillColor: "black"
    property int percent: 0 // from 0 - 100
    // Optional secondary level (e.g. audio peak) drawn as a translucent fill
    // behind the main fill, extending to its own level. -1 disables it.
    property int overlayPercent: -1

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

    function overlayWidth() {
        if (overlayPercent < 0) {
            return 0;
        }

        return Math.max(height, width * Math.min(overlayPercent, 100) / 100);
    }

    // Peak/overlay level — declared first so the main fill paints on top
    Rectangle {
        visible: progressBar.overlayPercent >= 0
        radius: 15
        height: parent.height
        width: progressBar.overlayWidth();
        color: Qt.rgba(1, 1, 1, 0.22)
    }

    Rectangle {
        radius: 15
        height: parent.height
        width: progressBar.fillWidth();
        color: progressBar.fillColor
    }
}
