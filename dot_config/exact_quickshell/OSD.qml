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

    HyprlandWindow.opacity: 0.95

    property var defaultSink: Pipewire.defaultAudioSink
    property var audio: defaultSink.audio
    property int currentVolume: Math.floor(defaultSink.audio?.volume * 100)
    property bool isMuted: defaultSink.audio?.muted
    property int margin: 16

    height: 50
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
            }

            function getPercent() {
                if (audioChanged) {
                    return osd.currentVolume
                }

                if (brightnessChanged) {
                    return BrightnessService.percent;
                }
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

            ProgressBar {
                height: 12
                percent: parent.getPercent()
                backgroundColor: parent.progressBarBackgroundColor()
                fillColor: parent.progressBarFillColor()
            }
        }
    }

    Connections {
        target: osd.audio

        function onMutedChanged() {
            osd.showMutedOSD()
        }

        function onVolumeChanged() {
            osd.showVolumeChangedOSD()
        }
    }

    Connections {
        target: BrightnessService

        function onPercentChanged() {
            osd.showBrightnessChangedOSD();
        }
    }
}
