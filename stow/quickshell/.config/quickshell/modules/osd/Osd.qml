import Quickshell
import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland

import '../../lib/icons.js' as Icons
import qs.components
import qs.config
import qs.services

PanelWindow {
    id: osd
    visible: false

    exclusiveZone: 0
    anchors.bottom: true
    margins {
        bottom: 100
    }

    HyprlandWindow.opacity: 0.95

    // Connections targets: the default sink/source audio objects
    property var audio: AudioService.sink?.audio ?? null
    property var sourceAudio: AudioService.source?.audio ?? null

    property int currentVolume: AudioService.volume
    property bool isMuted: AudioService.muted
    property int sourceVolume: AudioService.micVolume
    property bool sourceMuted: AudioService.micMuted

    property int margin: 16

    implicitHeight: 50
    implicitWidth: contentLayout.implicitWidth + margin * 2

    color: "transparent"

    property real showForSeconds: 1.4

    enum Kind { Volume, Mute, Brightness, Mic }

    property int currentType: Osd.Volume
    // Caps Lock view. A bool, not an enum kind: a new enum member reads as
    // undefined after a Quickshell hot reload.
    property bool showingCaps: false

    // Everything the OSD shows for the current kind, in one place.
    // NB (kept as-is): the bar fill is dimmed whenever the SINK is muted,
    // even for brightness / an unmuted mic.
    readonly property var view: {
        if (osd.showingCaps) return {
            icon: Icons.capsLock,
            color: Theme.mainAccent,
            percent: 0,
            text: "Caps Lock on",
            fill: Theme.foreground,
            overlay: -1
        };
        switch (osd.currentType) {
        case Osd.Brightness:
            return {
                icon: Icons.brightness,
                color: Theme.foreground,
                percent: BrightnessService.percent,
                text: BrightnessService.percent + "%",
                fill: osd.isMuted ? Theme.dimForeground : Theme.foreground,
                overlay: -1
            };
        case Osd.Mic:
            return {
                icon: osd.sourceMuted ? Icons.mic.muted : Icons.mic.on,
                color: osd.sourceMuted ? Theme.error : Theme.foreground,
                percent: osd.sourceVolume,
                text: osd.sourceMuted ? "Muted" : osd.sourceVolume + "%",
                fill: osd.sourceMuted ? Theme.error
                    : osd.isMuted ? Theme.dimForeground : Theme.foreground,
                overlay: -1
            };
        default: { // Osd.Volume, Osd.Mute
            // "Overshoot" segment: volume above 100% (wpctl allows up to
            // 150%) shown as a red translucent segment, width = over-100
            // part (110% volume → 10% red)
            const peak = !osd.isMuted && osd.currentVolume > 100;
            return {
                icon: Icons.volumeIcon(osd.currentVolume, osd.isMuted),
                color: peak ? Theme.error : Theme.foreground,
                percent: osd.currentVolume,
                text: osd.isMuted ? "Muted" : osd.currentVolume + "%",
                fill: osd.isMuted ? Theme.dimForeground : Theme.foreground,
                overlay: peak ? osd.currentVolume - 100 : -1
            };
        }
        }
    }
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
        // While the audio panel is open the OSD is redundant, and mapping/
        // unmapping this window dismisses the panel's popup grab (focus
        // churn) — see PanelService / docs/GOTCHAS.md
        if (PanelService.isOpen("audio")) return;
        visible = true
        hideTimer.restart()
    }

    function showMutedOSD() {
        osd.showingCaps = false
        osd.currentType = Osd.Mute
        show()
    }

    function showVolumeChangedOSD() {
        osd.showingCaps = false
        osd.currentType = Osd.Volume
        show()
    }

    function showBrightnessChangedOSD() {
        osd.showingCaps = false
        osd.currentType = Osd.Brightness
        show()
    }

    function showMicOSD() {
        osd.showingCaps = false
        osd.currentType = Osd.Mic
        show()
    }

    function showCapsLockOSD() {
        osd.showingCaps = true
        show()
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radius.lg
        color: Theme.background

        RowLayout {
            id: contentLayout
            // (no `width: parent.width` — it conflicted with the left/right
            // anchors, which win anyway: width == implicitWidth either way)

            anchors {
                left: parent.left
                right: parent.right
                verticalCenter: parent.verticalCenter
                leftMargin: osd.margin
                rightMargin: osd.margin
            }

            spacing: 16

            StyledText {
                text: osd.view.icon
                color: osd.view.color
                // StyledText sets the nerd font family — REQUIRED for these
                // glyphs (see the NB in StyledText.qml / docs/GOTCHAS.md)
                font.pixelSize: Theme.fontSize.osd
                // Fixed box so the OSD doesn't resize when the glyph changes
                Layout.preferredWidth: 28
                horizontalAlignment: Text.AlignHCenter
            }

            ProgressBar {
                visible: !osd.showingCaps
                height: 12
                percent: osd.view.percent
                // Red overshoot segment when the audio signal clips
                overlayPercent: osd.view.overlay
                overlayColor: Theme.alpha(Theme.error, 0.55)
                backgroundColor: Theme.subdued
                fillColor: osd.view.fill
            }

            StyledText {
                text: osd.view.text
                color: osd.view.color
                font.pixelSize: Theme.fontSize.lg
                // Fixed box so "9%" → "100%" doesn't shift the OSD size
                // Caps Lock (no bar): the OSD wraps the text
                Layout.preferredWidth: osd.showingCaps ? implicitWidth : 44
                horizontalAlignment: osd.showingCaps ? Text.AlignLeft : Text.AlignRight
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
        target: CapsLockService

        function onOnChanged() {
            if (CapsLockService.on && osd.audioReady) osd.showCapsLockOSD();
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
