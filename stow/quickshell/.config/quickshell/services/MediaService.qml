pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Mpris

// Which MPRIS player the bar controls.
Singleton {
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

    readonly property string trackText: {
        if (!activePlayer) return "";
        const artist = activePlayer.trackArtist;
        return artist ? artist + " – " + activePlayer.trackTitle : activePlayer.trackTitle;
    }
}
