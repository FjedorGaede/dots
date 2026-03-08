import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire

// Note: Muted and audio level on 0 is not the same. You can have your Audio Level to 50% and still mute it 

RowLayout {
    id: sound

    PwObjectTracker {
        objects: Pipewire.defaultAudioSink ? [Pipewire.defaultAudioSink] : []
    }

    property var defaultSink: Pipewire.defaultAudioSink
    property int currentVolume: Math.floor(defaultSink.audio?.volume * 100)
    property bool isMuted: defaultSink.audio?.muted

    property color defaultColor: "white"
    property color mutedColor: "gray"

    function getIcon() {
        const audioLoudIcon = "";
        const audioQuiteIcon = "";
        const noSoundIcon = "";

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

    Text {
        text: sound.getIcon()
        color: sound.getColor()
    }

    MouseArea {
        Layout.fillWidth: false
        Layout.fillHeight: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Quickshell.execDetached(["sh", "-c", "GTK_THEME=Adwaita-dark pavucontrol -t 3"])
        hoverEnabled: true
        onHoveredChanged: audioPopup.visible = containsMouse
    }

    PopupWindow {
        id: audioPopup

        anchor.item: sound
        anchor.edges: Edges.Bottom
        visible: false

        implicitHeight: content.implicitHeight
        implicitWidth: content.implicitWidth

        Text {
            id: content
            text: sound.currentVolume + "%"
        }
    }
}
