import QtQuick

Rectangle {
    id: progressBar

    property color backgroundColor: "darkgray"
    property color fillColor: "black"
    property int percent: 0 // from 0 - 100
    // Optional secondary level drawn as a translucent fill. -1 disables it.
    property int overlayPercent: -1
    property color overlayColor: Qt.rgba(1, 1, 1, 0.22)

    width: 200
    height: 12
    radius: 15
    color: backgroundColor
    clip: true

    function fillWidth() {
        if (percent === 0) {
            return 0;
        }

        // Clamp at 100 — anything above is shown by the red overlay segment
        return Math.max(progressBar.height,
                        progressBar.width * Math.min(progressBar.percent, 100) / 100);
    }

    function overlayWidth() {
        if (overlayPercent < 0) {
            return 0;
        }

        return Math.max(height, width * Math.min(overlayPercent, 100) / 100);
    }

    Rectangle {
        radius: 15
        height: parent.height
        width: progressBar.fillWidth();
        color: progressBar.fillColor
    }

    // Overlay level — declared after the fill so it paints on top of it
    // (e.g. the red over-100% volume segment must be visible over the maxed
    // fill)
    Rectangle {
        visible: progressBar.overlayPercent >= 0
        radius: 15
        height: parent.height
        width: progressBar.overlayWidth();
        color: progressBar.overlayColor
    }
}
