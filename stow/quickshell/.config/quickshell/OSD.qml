import Quickshell
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import Quickshell.Hyprland

import './theme'

PanelWindow {
    id: osd
    visible: false

    exclusiveZone: 0
    anchors.bottom: true
    margins {
        bottom: 100
    }

    PwObjectTracker {
        objects: Pipewire.defaultAudioSink ? [Pipewire.defaultAudioSink] : []
    }

    // Live output level metering. Only enabled while the OSD is shown so
    // PipeWire isn't polled constantly. `peak` is 0..1, max across channels.
    PwNodePeakMonitor {
        id: peakMonitor
        node: osd.defaultSink
        enabled: osd.visible
    }

    HyprlandWindow.opacity: 0.95

    property var defaultSink: Pipewire.defaultAudioSink
    property var audio: defaultSink?.audio ?? null
    property int currentVolume: defaultSink?.audio ? Math.floor(defaultSink.audio.volume * 100) : 0
    property bool isMuted: defaultSink?.audio?.muted ?? false
    property int margin: 16

    implicitHeight: 50
    implicitWidth: contentLayout.implicitWidth + margin * 2

    color: "transparent"

    property real showForSeconds: 1

    QtObject {
        id: osdTypes
        readonly property int volumeChanged: 0
        readonly property int mutedChanged: 1
        readonly property int brightnessChanged: 2
    }

    property int currentType: osdTypes.volumeChanged
    property bool audioReady: false

    Timer {
        interval: 1000
        running: true
        onTriggered: osd.audioReady = true
    }

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
        osd.currentType = osdTypes.mutedChanged
        show()
    }

    function showVolumeChangedOSD() {
        osd.currentType = osdTypes.volumeChanged
        show()
    }

    function showBrightnessChangedOSD() {
        osd.currentType = osdTypes.brightnessChanged
        show()
    }

    Rectangle {
        anchors.fill: parent
        radius: 12
        color: Theme.background

        RowLayout {
            id: contentLayout
            width: parent.width

            anchors {
                left: parent.left
                right: parent.right
                verticalCenter: parent.verticalCenter
                leftMargin: osd.margin
                rightMargin: osd.margin
            }

            property bool audioChanged: ([osdTypes.volumeChanged, osdTypes.mutedChanged].includes(osd.currentType))
            property bool brightnessChanged: ([osdTypes.brightnessChanged].includes(osd.currentType))

            function getAudioIcon() {
                const audioLoudIcon = "";
                const audioQuiteIcon = "";

                const noSoundIcon = "";
                if (osd.isMuted) {
                    return noSoundIcon;
                }

                if (osd.currentVolume === 0) {
                    return noSoundIcon;
                }

                if (osd.currentVolume < 70) {
                    return audioQuiteIcon;
                }

                return audioLoudIcon;
            }

            function getIcon() {
                if (audioChanged) {
                    return getAudioIcon();
                }

                if (brightnessChanged) {
                    return "";
                }

                return "xxx";
            }

            function getPercent() {
                if (audioChanged) {
                    return osd.currentVolume
                }

                if (brightnessChanged) {
                    return BrightnessService.percent;
                }

                return 0;
            }

            function progressBarBackgroundColor() {
                return Theme.subdued;
            }

            function progressBarFillColor() {
                if (osd.isMuted) {
                    return Theme.dimForeground
                }

                return Theme.foreground;
            }


            Text {
                text: parent.getIcon();
                color: Theme.foreground
                font { pixelSize: 32 }
                Layout.preferredWidth: 22
                horizontalAlignment: Text.AlignHCenter
            }

            Item { implicitWidth: 16 }

            ColumnLayout {
                spacing: 3

                ProgressBar {
                    height: 12
                    percent: contentLayout.getPercent()
                    backgroundColor: contentLayout.progressBarBackgroundColor()
                    fillColor: contentLayout.progressBarFillColor()
                }

                // Live peak meter. Turns red when the output is clipping.
                ProgressBar {
                    height: 4
                    percent: peakMonitor.enabled ? Math.round(peakMonitor.peak * 100) : 0
                    backgroundColor: contentLayout.progressBarBackgroundColor()
                    fillColor: peakMonitor.peak > 0.98 ? Theme.color1 : Theme.dimForeground
                }
            }
        }
    }

    Connections {
        target: osd.audio

        function onMutedChanged() {
            if (osd.audioReady) osd.showMutedOSD()
        }

        function onVolumeChanged() {
            if (osd.audioReady) osd.showVolumeChangedOSD()
        }
    }

    Connections {
        target: BrightnessService

        function onPercentChanged() {
            if (BrightnessService.ready)
                osd.showBrightnessChangedOSD();
        }
    }
}
