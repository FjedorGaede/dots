import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris

import './theme'

// Compact media indicator next to the clock.
// Collapsed: a single static music note (accent-colored while playing) —
//   identical metrics to the clock so the pills look the same.
//   Click the note to expand: play/pause button + "Artist – Title".
//   Scroll up/down → next/previous track (works in both states).
// Hidden entirely when no media player is active.

RowLayout {
    id: root

    // Prefer whichever player is actually playing. If none is playing (e.g.
    // you paused a YouTube video), keep controlling the LAST player that was
    // playing instead of some arbitrary first player (like Spotify).
    property var lastPlaying: null

    readonly property var activePlayer: {
        const list = Mpris.players.values;
        const playing = list.find(p => p && p.isPlaying);
        if (playing) return playing;
        if (root.lastPlaying && list.includes(root.lastPlaying)) return root.lastPlaying;
        return list[0] ?? null;
    }

    onActivePlayerChanged: {
        if (activePlayer && activePlayer.isPlaying) lastPlaying = activePlayer;
    }

    readonly property bool playing: activePlayer?.isPlaying ?? false
    property bool expanded: false

    readonly property string trackText: {
        if (!activePlayer) return "";
        const artist = activePlayer.trackArtist;
        return artist ? artist + " – " + activePlayer.trackTitle : activePlayer.trackTitle;
    }

    visible: root.activePlayer !== null

    spacing: 6

    // Static music note — click expands/collapses the widget
    Text {
        text: "󰝚"
        color: root.playing ? Theme.mainAccent : Theme.dimForeground
        font { family: Theme.fontFamily; pixelSize: 14 }

        TapHandler {
            cursorShape: Qt.PointingHandCursor
            onTapped: root.expanded = !root.expanded
        }

        HoverHandler { cursorShape: Qt.PointingHandCursor }
    }

    // Play/pause button — always visible, hover + pointer cursor
    Rectangle {
        implicitWidth: 18
        implicitHeight: 18
        radius: 5
        color: ppHover.hovered ? Theme.hoverOverlay : "transparent"

        Text {
            anchors.centerIn: parent
            text: root.playing ? "󰏤" : "󰐊"
            color: root.playing ? Theme.mainAccent : Theme.foreground
            font { family: Theme.fontFamily; pixelSize: 12 }
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
    Text {
        visible: root.expanded
        text: root.trackText
        color: Theme.foreground
        elide: Text.ElideRight
        Layout.maximumWidth: 220
        font { family: Theme.fontFamily; pixelSize: 13 }
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
