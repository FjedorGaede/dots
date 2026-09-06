import Quickshell
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts

import './theme'

// Audio panel: default output/input volume + mute, and device pickers.
// Opened from the Sound bar icon (and `qs ipc call audio toggle`).
// Device logic cribbed from omarchy quattro's audio panel (MIT): label
// cleanup; per-app streams deliberately left out to keep this simple.
PopupBase {
    id: audioPanel

    minWidth: 300

    // ── Nodes ──
    readonly property var sinks: (Pipewire.nodes?.values ?? []).filter(
        n => n && !n.isStream && n.isSink && n.audio)
    readonly property var sources: (Pipewire.nodes?.values ?? []).filter(
        n => n && !n.isStream && !n.isSink && n.audio
             && !String(n.name ?? "").endsWith(".monitor"))
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource

    // PwNode properties are only valid while the node is bound
    PwObjectTracker {
        objects: [audioPanel.sink, audioPanel.source].filter(Boolean)
                     .concat(audioPanel.sinks, audioPanel.sources)
    }

    function deviceLabel(node) {
        let l = node?.description || node?.nickname || node?.name || "?";
        l = String(l).replace(/^sof-soundwire\s+/i, "")
                     .replace(/^built-?in audio\s+/i, "");
        return l;
    }

    // ── Reusable volume row: mute glyph + slider + percent ──
    component VolumeRow: RowLayout {
        id: vRow

        required property var node
        property string glyph
        property string mutedGlyph
        // Red overshoot feedback only makes sense for output (mic boost at
        // >100% is normal and should look the same as any other level)
        property bool overshootEnabled: false
        spacing: 10

        readonly property bool muted: node?.audio?.muted ?? false
        readonly property int vol: node?.audio ? Math.round(node.audio.volume * 100) : 0
        readonly property bool overshooting: overshootEnabled && vol > 100

        // Sync the slider when the volume changes externally (keys/OSD);
        // guarded while we are the ones dragging
        onVolChanged: if (!slider.dragging) slider.live = vol

        // Fixed-size hit box around the mute glyph: the two glyph variants
        // have different advance widths, which would push the slider on mute
        Item {
            implicitWidth: 22
            implicitHeight: 22

            Text {
                anchors.centerIn: parent
                text: vRow.muted ? vRow.mutedGlyph : vRow.glyph
                color: vRow.muted ? Theme.error : Theme.foreground
                font { family: Theme.fontFamily; pixelSize: 15 }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: if (vRow.node?.audio) vRow.node.audio.muted = !vRow.node.audio.muted
            }
        }

        // Hand-rolled slider (like omarchy's PanelSlider): QQC2 Slider was
        // not draggable inside the popup window. Range 0–150 to match the
        // wpctl/OSD overshoot; >100% renders red.
        Item {
            id: slider
            Layout.fillWidth: true
            implicitHeight: 20

            readonly property real maxVal: 150
            property real live: vRow.vol
            property bool dragging: false

            function valueFromX(x) {
                return Math.max(0, Math.min(maxVal, x / width * maxVal));
            }

            function apply(next) {
                live = next;
                if (vRow.node?.audio) vRow.node.audio.volume = next / 100;
            }

            Component.onCompleted: live = vRow.vol

            Rectangle {
                id: track
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.right: parent.right
                height: 5
                radius: 2.5
                color: Theme.overlay

                // Overshoot ZONE: translucent red track beyond 100%, so the
                // danger range is visible as an area rather than a line
                Rectangle {
                    x: parent.width * (100 / slider.maxVal)
                    width: parent.width - x
                    height: parent.height
                    radius: parent.radius
                    visible: vRow.overshootEnabled
                    color: Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.15)
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width * (slider.live / slider.maxVal)
                    height: parent.height
                    radius: parent.radius
                    // Mute is shown by the glyph, not by graying out the fill
                    color: vRow.overshooting ? Theme.error : Theme.mainAccent
                }
            }

            Rectangle {
                anchors.verticalCenter: track.verticalCenter
                x: Math.max(0, Math.min(track.width - width,
                                        track.width * (slider.live / slider.maxVal) - width / 2))
                width: 13
                height: 13
                radius: 6.5
                border.width: 2
                border.color: Theme.background
                color: vRow.overshooting ? Theme.error : Theme.foreground
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor

                onPressed: (mouse) => {
                    slider.dragging = true;
                    slider.apply(slider.valueFromX(mouse.x));
                }
                onPositionChanged: (mouse) => {
                    if (slider.dragging) slider.apply(slider.valueFromX(mouse.x));
                }
                onReleased: slider.dragging = false
                onWheel: (wheel) => {
                    slider.apply(slider.live + (wheel.angleDelta.y > 0 ? 5 : -5));
                }
            }
        }

        Text {
            text: vRow.vol + "%"
            color: vRow.overshooting ? Theme.error : Theme.foreground
            font { family: Theme.fontFamily; pixelSize: 12 }
            Layout.preferredWidth: 38
            horizontalAlignment: Text.AlignRight
        }
    }

    // ── Content ──
    Text {
        text: "OUTPUT"
        color: Theme.dimForeground
        font { family: Theme.fontFamily; pixelSize: 11; bold: true }
    }

    VolumeRow {
        Layout.fillWidth: true
        Layout.bottomMargin: 8
        node: audioPanel.sink
        glyph: "\uF028"
        mutedGlyph: "\uF026"
        overshootEnabled: true
    }

    Repeater {
        model: audioPanel.sinks

        ListItem {
            required property var modelData
            Layout.fillWidth: true
            size: ListItem.Small
            icon: "\uF028"
            label: audioPanel.deviceLabel(modelData)
            status: modelData === audioPanel.sink ? ListItem.Active : ListItem.Default

            onTapped: Pipewire.preferredDefaultAudioSink = modelData
        }
    }

    Text {
        text: "INPUT"
        color: Theme.dimForeground
        font { family: Theme.fontFamily; pixelSize: 11; bold: true }
    }

    VolumeRow {
        Layout.fillWidth: true
        Layout.bottomMargin: 8
        node: audioPanel.source
        glyph: "\uF130"
        mutedGlyph: "\uF131"
        overshootEnabled: true
    }

    Repeater {
        model: audioPanel.sources

        ListItem {
            required property var modelData
            Layout.fillWidth: true
            size: ListItem.Small
            icon: "\uF130"
            label: audioPanel.deviceLabel(modelData)
            status: modelData === audioPanel.source ? ListItem.Active : ListItem.Default

            onTapped: Pipewire.preferredDefaultAudioSource = modelData
        }
    }
}
