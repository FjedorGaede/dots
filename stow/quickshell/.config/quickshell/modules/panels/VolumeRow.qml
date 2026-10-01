import QtQuick
import QtQuick.Layouts

import qs.components
import qs.config
import qs.services

// Audio panel row: mute glyph + volume slider + percent, for one PwNode.
RowLayout {
    id: vRow

    required property var node
    property string glyph
    property string mutedGlyph
    // Red overshoot feedback above 100 %. The audio panel enables it on both
    // rows on purpose (OUTPUT and INPUT — mic boost >100 % is normal, hence
    // only a 15 % opacity red zone, see VolumeSlider)
    property bool overshootEnabled: false
    spacing: 10

    readonly property bool muted: node?.audio?.muted ?? false
    readonly property int vol: AudioService.percentOf(node)
    readonly property bool overshooting: overshootEnabled && vol > 100

    // Sync the slider when the volume changes externally (keys/OSD);
    // guarded while we are the ones dragging
    onVolChanged: if (!slider.dragging) slider.live = vol

    // Fixed-size hit box around the mute glyph: the two glyph variants
    // have different advance widths, which would push the slider on mute
    Item {
        implicitWidth: 22
        implicitHeight: 22

        StyledText {
            anchors.centerIn: parent
            text: vRow.muted ? vRow.mutedGlyph : vRow.glyph
            color: vRow.muted ? Theme.error : Theme.foreground
            font.pixelSize: 15
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: AudioService.toggleMute(vRow.node)
        }
    }

    VolumeSlider {
        id: slider
        Layout.fillWidth: true
        overshootEnabled: vRow.overshootEnabled
        overshooting: vRow.overshooting

        live: vRow.vol
        // Break the binding right away — from here on `live` is only synced
        // imperatively (onVolChanged above) so dragging never snaps back
        Component.onCompleted: live = vRow.vol

        onMoved: (value) => AudioService.setVolume(vRow.node, value)
    }

    StyledText {
        text: vRow.vol + "%"
        color: vRow.overshooting ? Theme.error : Theme.foreground
        font.pixelSize: Theme.fontSize.md
        Layout.preferredWidth: 38
        horizontalAlignment: Text.AlignRight
    }
}
