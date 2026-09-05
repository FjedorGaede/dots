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

    PwObjectTracker {
        objects: Pipewire.defaultAudioSource ? [Pipewire.defaultAudioSource] : []
    }

    HyprlandWindow.opacity: 0.95

    property var defaultSink: Pipewire.defaultAudioSink
    property var audio: defaultSink?.audio ?? null
    property var defaultSource: Pipewire.defaultAudioSource
    property var sourceAudio: defaultSource?.audio ?? null

    property int currentVolume: defaultSink?.audio ? Math.floor(defaultSink.audio.volume * 100) : 0
    property bool isMuted: defaultSink?.audio?.muted ?? false
    property int sourceVolume: defaultSource?.audio ? Math.floor(defaultSource.audio.volume * 100) : 0
    property bool sourceMuted: defaultSource?.audio?.muted ?? false

    property int margin: 16

    implicitHeight: 50
    implicitWidth: contentLayout.implicitWidth + margin * 2

    color: "transparent"

    property real showForSeconds: 1.4

    QtObject {
        id: osdTypes
        readonly property int volumeChanged: 0
        readonly property int mutedChanged: 1
        readonly property int brightnessChanged: 2
        readonly property int micChanged: 3
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

    function showMicOSD() {
        osd.currentType = osdTypes.micChanged
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

            spacing: 16

            property bool audioChanged: ([osdTypes.volumeChanged, osdTypes.mutedChanged].includes(osd.currentType))
            property bool brightnessChanged: osd.currentType === osdTypes.brightnessChanged
            property bool micChanged: osd.currentType === osdTypes.micChanged

            function getAudioIcon() {
                const audioLoudIcon = "";
                const audioQuietIcon = "";
                const noSoundIcon = "";

                if (osd.isMuted) return noSoundIcon;
                if (osd.currentVolume === 0) return noSoundIcon;
                if (osd.currentVolume < 70) return audioQuietIcon;
                return audioLoudIcon;
            }

            function getIcon() {
                if (audioChanged) return getAudioIcon();
                if (brightnessChanged) return "";
                if (micChanged) return osd.sourceMuted ? "󰍭" : "󰍬";
            }

            function getIconColor() {
                if (micChanged && osd.sourceMuted) return Theme.error;
                if (audioChanged && !osd.isMuted && osd.currentVolume > 100) return Theme.error;
                return Theme.foreground;
            }

            function getPercent() {
                if (audioChanged) return osd.currentVolume;
                if (brightnessChanged) return BrightnessService.percent;
                if (micChanged) return osd.sourceVolume;
                return 0;
            }

            function getPercentText() {
                if (audioChanged || micChanged) {
                    const muted = audioChanged ? osd.isMuted : osd.sourceMuted;
                    return muted ? "Muted" : getPercent() + "%";
                }
                if (brightnessChanged) return BrightnessService.percent + "%";
                return "";
            }

            function progressBarFillColor() {
                if (micChanged && osd.sourceMuted) return Theme.error;
                if (osd.isMuted) return Theme.dimForeground;
                return Theme.foreground;
            }

            function showPeak() {
                // "Overshoot" segment: volume above 100% (wpctl allows up to
                // 150%) shown as a red translucent segment, width = over-100
                // part (110% volume → 10% red)
                return audioChanged && !osd.isMuted && osd.currentVolume > 100;
            }

            Text {
                text: contentLayout.getIcon();
                color: contentLayout.getIconColor();
                font { pixelSize: 24 }
                // Fixed box so the OSD doesn't resize when the glyph changes
                Layout.preferredWidth: 28
                horizontalAlignment: Text.AlignHCenter
            }

            ProgressBar {
                height: 12
                percent: contentLayout.getPercent()
                // Red overshoot segment when the audio signal clips
                overlayPercent: contentLayout.showPeak()
                    ? osd.currentVolume - 100 : -1
                overlayColor: Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.55)
                backgroundColor: Theme.subdued
                fillColor: contentLayout.progressBarFillColor()
            }

            Text {
                text: contentLayout.getPercentText()
                color: contentLayout.getIconColor()
                font { family: Theme.fontFamily; pixelSize: 14 }
                // Fixed box so "9%" → "100%" doesn't shift the OSD size
                Layout.preferredWidth: 44
                horizontalAlignment: Text.AlignRight
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
        target: osd.sourceAudio

        function onMutedChanged() {
            if (osd.audioReady) osd.showMicOSD()
        }

        function onVolumeChanged() {
            if (osd.audioReady) osd.showMicOSD()
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
