pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

// Default sink/source, device lists and volume/mute state in ONE place
// (Sound.qml, Osd.qml and AudioPanel.qml used to compute it each on their own).
Singleton {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource

    readonly property var sinks: (Pipewire.nodes?.values ?? []).filter(
        n => n && !n.isStream && n.isSink && n.audio)
    readonly property var sources: (Pipewire.nodes?.values ?? []).filter(
        n => n && !n.isStream && !n.isSink && n.audio
             && !String(n.name ?? "").endsWith(".monitor"))

    // All percentages (bar icon/tooltip, OSD, audio panel) are Math.round —
    // one rule everywhere, see percentOf()
    readonly property int volume: percentOf(sink)
    readonly property bool muted: sink?.audio?.muted ?? false
    readonly property int micVolume: percentOf(source)
    readonly property bool micMuted: source?.audio?.muted ?? false

    // Rounded percent of any node (bar, OSD, audio panel rows)
    function percentOf(node) { return node?.audio ? Math.round(node.audio.volume * 100) : 0 }
    function setVolume(node, pct) { if (node?.audio) node.audio.volume = pct / 100 }
    function toggleMute(node) { if (node?.audio) node.audio.muted = !node.audio.muted }
    function setDefaultSink(node) { Pipewire.preferredDefaultAudioSink = node }
    function setDefaultSource(node) { Pipewire.preferredDefaultAudioSource = node }

    // Bluetooth headset in HSP/HFP ("hands-free"): mono, call quality. The
    // mode is a card profile above the node, so read it off the node props
    readonly property bool sinkHandsFree: isHandsFree(sink)
    function isHandsFree(node) {
        const p = node?.properties ?? {};
        return String(p["api.bluez5.profile"] ?? "").startsWith("headset")
            || String(p["factory.name"] ?? "").includes(".sco.");
    }

    // Back to A2DP. Connecting the "Audio Sink" UUID first matters: when the
    // A2DP link timed out at connect time (Bose + BlueZ), no a2dp profile is
    // offered at all and set-card-profile alone would fail
    function switchToHiFi(node) {
        const addr = String(node?.properties?.["api.bluez5.address"] ?? "");
        if (!addr || hiFiProc.running) return;
        hiFiProc.command = ["sh", "-c",
            'bluetoothctl connect "$1" 0000110b-0000-1000-8000-00805f9b34fb >/dev/null 2>&1; '
          + 'sleep 1; pactl set-card-profile "bluez_card.$(echo "$1" | tr : _)" a2dp-sink',
            "sh", addr];
        hiFiProc.running = true;
    }
    readonly property bool switchingToHiFi: hiFiProc.running

    Process { id: hiFiProc }

    function deviceLabel(node) {
        let l = node?.description || node?.nickname || node?.name || "?";
        l = String(l).replace(/^sof-soundwire\s+/i, "")
                     .replace(/^built-?in audio\s+/i, "");
        return l;
    }

    // PwNode properties are only valid while the node is bound — ONE tracker
    // for everyone, covering all candidate sinks/sources (device pickers),
    // not just the defaults (docs/GOTCHAS.md)
    PwObjectTracker {
        objects: [root.sink, root.source].filter(Boolean)
                     .concat(root.sinks, root.sources)
    }
}
