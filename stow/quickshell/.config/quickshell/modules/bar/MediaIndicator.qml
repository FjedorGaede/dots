import QtQuick
import QtQuick.Layouts

import qs.components
import qs.config
import qs.services

// Compact media indicator next to the clock.
// Collapsed: a single static music note (accent-colored while playing) —
//   identical metrics to the clock so the pills look the same.
//   Click the note to expand: play/pause button + "Artist – Title".
//   Scroll up/down → next/previous track (works in both states).
// Hidden entirely when no media player is active.

RowLayout {
    id: root

    // Player selection (activePlayer / lastPlaying) lives in MediaService
    readonly property var activePlayer: MediaService.activePlayer
    readonly property bool playing: MediaService.playing
    readonly property string trackText: MediaService.trackText
    property bool expanded: false

    visible: root.activePlayer !== null

    spacing: 4

    // Static music note — click expands/collapses the widget
    // Both icons sit in boxes sized to their visible ink (+2px each side) and
    // are centered by ink (tightBoundingRect), not font advance — Nerd Font
    // glyphs overflow their advance, which made the pill look lopsided.
    Item {
        implicitWidth: Math.ceil(noteGlyph.ink.width) + 4
        implicitHeight: 18

        InkGlyph {
            id: noteGlyph
            text: "󰝚"
            color: root.playing ? Theme.mainAccent : Theme.dimForeground
            font.pixelSize: Theme.fontSize.lg
        }

        TapHandler {
            cursorShape: Qt.PointingHandCursor
            onTapped: root.expanded = !root.expanded
        }

        HoverHandler { cursorShape: Qt.PointingHandCursor }
    }

    // Play/pause button — always visible, hover + pointer cursor
    // Width = widest of play/pause ink (so the pill doesn't jitter on toggle)
    // + 2px each side; the 18×18 hover highlight overflows into the padding.
    Item {
        implicitWidth: Math.ceil(Math.max(ppGlyph.ink.width,
                                          ppAltMetrics.tightBoundingRect.width)) + 4
        implicitHeight: 18

        Rectangle {
            anchors.centerIn: parent
            width: 18
            height: 18
            radius: 5
            color: ppHover.hovered ? Theme.hoverOverlay : "transparent"
        }

        TextMetrics {
            id: ppAltMetrics
            text: root.playing ? "󰐊" : "󰏤"
            font: ppGlyph.font
        }

        InkGlyph {
            id: ppGlyph
            text: root.playing ? "󰏤" : "󰐊"
            color: root.playing ? Theme.mainAccent : Theme.foreground
            font.pixelSize: Theme.fontSize.lg
            // ▶ carries its visual weight on the flat left side — nudge it
            // right so it *looks* centered (standard optical correction).
            opticalShift: root.playing ? 0 : ink.width / 8
            roundX: true
        }

        HoverHandler { id: ppHover; cursorShape: Qt.PointingHandCursor }

        TapHandler {
            onTapped: {
                const p = root.activePlayer;
                if (!p) return;
                if (root.playing) { if (p.canPause) p.pause(); }
                else if (p.canPlay) p.play();
                else if (p.canTogglePlaying) p.togglePlaying();
            }
        }
    }

    // Track readout — only visible in the expanded state
    StyledText {
        visible: root.expanded
        text: root.trackText
        elide: Text.ElideRight
        Layout.maximumWidth: 220
        font.pixelSize: Theme.fontSize.base
    }

    WheelHandler {
        onWheel: (wheel) => {
            if (!root.activePlayer) return;
            if (wheel.angleDelta.y > 0 && root.activePlayer.canGoNext)
                root.activePlayer.next();
            else if (wheel.angleDelta.y < 0 && root.activePlayer.canGoPrevious)
                root.activePlayer.previous();
        }
    }

    Tooltip {
        id: tooltip
        anchorItem: root
        tooltipText: root.activePlayer
            ? (root.trackText + " — " + root.activePlayer.identity + " · scroll: next/prev")
            : ""
    }

    HoverHandler {
        id: hoverHandler
        onHoveredChanged: tooltip.visible = hovered && root.activePlayer !== null
    }
}
