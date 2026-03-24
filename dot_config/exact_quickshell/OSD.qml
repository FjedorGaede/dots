import Quickshell
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire

PanelWindow {
    id: osd
    visible: false

    property real showForSeconds: 1

    QtObject {
        id: osdType
        readonly property int volumeChanged: 0
        readonly property int mutedChanged: 1
        readonly property int brightnessChanged: 1
    }

    property int osdType

    Timer {
        id: hideTimer
        interval: osd.showForSeconds * 1000
        onTriggered: osd.visible = false
    }

    function show() {
        visible = true
        hideTimer.restart()
    }

    function showMutedOSD() {
        console.log("muted changed")
        osd.osdType = osdType.mutedChanged;
        show();
    }

    function showVolumeChangedOSD() {
        console.log("vol changed")
        osd.osdType = osdType.volumeChanged;
        show();
    }

    Text {
        visible: osd.osdType === osdType.mutedChanged
        text: "muted"
    }

    Text {
        visible: osd.osdType === osdType.volumeChanged
        text: "volume"
    }

    Connections {
        target: Pipewire.defaultAudioSink.audio

        function onMutedChanged() {
            osd.showMutedOSD();
        }

        function onVolumeChanged() {
            osd.showVolumeChangedOSD();
        }
    }
}
