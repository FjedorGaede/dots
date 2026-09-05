import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire

import './theme'

// Note: Muted and audio level on 0 is not the same. You can have your Audio Level to 50% and still mute it

RowLayout {
    id: sound

    PwObjectTracker {
        objects: Pipewire.defaultAudioSink ? [Pipewire.defaultAudioSink] : []
    }

    property var defaultSink: Pipewire.defaultAudioSink
    property int currentVolume: defaultSink?.audio ? Math.floor(defaultSink.audio.volume * 100) : 0

    property bool isMuted: defaultSink?.audio?.muted ?? false
    property color defaultColor: Theme.foreground
    property color mutedColor: Theme.subdued

    function getIcon() {
        const audioLoudIcon = "";
        const audioQuiteIcon = "";
        const noSoundIcon = "";

        if (isMuted) {
            return noSoundIcon;
        }

        if (currentVolume === 0) {
            return noSoundIcon;
        }

        if (currentVolume < 70) {
            return audioQuiteIcon;
        }

        return audioLoudIcon;
    }

    function getColor() {
        if (isMuted) {
            return mutedColor;
        }

        return defaultColor;
    }

    StatusIcon {
        text: sound.getIcon()
        size: 13
    }

    TapHandler {
        onTapped: Quickshell.execDetached(["sh", "-c", "GTK_THEME=Adwaita-dark pavucontrol -t 3"])
    }

    HoverHandler {
        onHoveredChanged: audioTooltip.visible = hovered
        cursorShape: Qt.PointingHandCursor
    }

    Tooltip {
        id: audioTooltip
        anchorItem: sound
        tooltipText: sound.currentVolume + "%"
    }
}
