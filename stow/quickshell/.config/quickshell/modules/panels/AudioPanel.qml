import QtQuick
import QtQuick.Layouts

import qs.components
import qs.config
import qs.services

// Audio panel: default output/input volume + mute, and device pickers.
// Opened from the Sound bar icon (and `qs ipc call audio toggle`).
// Device logic cribbed from omarchy quattro's audio panel (MIT): label
// cleanup; per-app streams deliberately left out to keep this simple.
PopupPanel {
    id: audioPanel

    minWidth: 300

    // Open state (+ `qs ipc call audio …`) lives in PanelService;
    // Osd.qml reads it to stay hidden while this panel is open
    open: PanelService.isOpenOn("audio", screenName)
    onVisibleChanged: PanelService.setOpen("audio", visible, screenName)

    // Nodes, device labels and the PwObjectTracker live in AudioService

    // Volume rows (mute glyph + slider + percent) live in VolumeRow.qml

    component SubHeader: StyledText {
        color: Theme.dimForeground
        font { pixelSize: Theme.fontSize.sm; bold: true }
    }

    // ── Content ──
    PanelHeader { title: "AUDIO" }

    Divider {}

    SubHeader { text: "OUTPUT" }

    VolumeRow {
        Layout.fillWidth: true
        Layout.bottomMargin: 8
        node: AudioService.sink
        glyph: "\uF028"
        mutedGlyph: "\uF026"
        overshootEnabled: true
    }

    // Bluetooth output stuck in hands-free (HFP): mono call audio. Only
    // shown in that state; the headset mic doesn't work in Hi-Fi (A2DP)
    RowLayout {
        visible: AudioService.sinkHandsFree
        Layout.fillWidth: true
        Layout.bottomMargin: 8
        spacing: 8

        StyledText {
            text: "Hands-free mode · mono"
            color: Theme.warning
            font.pixelSize: Theme.fontSize.sm
            Layout.fillWidth: true
        }

        DotsSpinner {
            visible: AudioService.switchingToHiFi
            font.pixelSize: Theme.fontSize.sm
        }

        GhostButton {
            visible: !AudioService.switchingToHiFi
            text: "Switch to Hi-Fi"
            onClicked: AudioService.switchToHiFi(AudioService.sink)
        }
    }

    Repeater {
        model: AudioService.sinks

        ListItem {
            required property var modelData
            Layout.fillWidth: true
            size: ListItem.Small
            icon: "\uF028"
            label: AudioService.deviceLabel(modelData)
            status: modelData === AudioService.sink ? ListItem.Active : ListItem.Default

            onTapped: AudioService.setDefaultSink(modelData)
        }
    }

    SubHeader { text: "INPUT" }

    VolumeRow {
        Layout.fillWidth: true
        Layout.bottomMargin: 8
        node: AudioService.source
        glyph: "\uF130"
        mutedGlyph: "\uF131"
        overshootEnabled: true
    }

    Repeater {
        model: AudioService.sources

        ListItem {
            required property var modelData
            Layout.fillWidth: true
            size: ListItem.Small
            icon: "\uF130"
            label: AudioService.deviceLabel(modelData)
            status: modelData === AudioService.source ? ListItem.Active : ListItem.Default

            onTapped: AudioService.setDefaultSource(modelData)
        }
    }
}
