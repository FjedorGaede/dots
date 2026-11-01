pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Dictation state from whispy-daemon (dots: packages/hyprland/install/dictation).
// The daemon writes $XDG_RUNTIME_DIR/whispy/state.json:
//   { state: idle|recording|transcribing|success|error, rms, error_message, timestamp }
// The keybinds drive whispy-client directly (hypr/keybinds.lua); this service
// only reads. success/error are written once → held for a moment, then idle.
Singleton {
    id: root

    property string state: "idle"
    property real rms: 0                 // raw mic RMS, speech peaks ~0.015
    property string errorMessage: ""
    readonly property bool active: state !== "idle"

    readonly property int holdSuccessMs: 600
    readonly property int holdErrorMs: 2000
    // Only `recording` is refreshed continuously (RMS ticks) → older = daemon died
    readonly property int staleMs: 5000
    property real stamp: 0

    function toggle() { Quickshell.execDetached(["whispy-client", "toggle"]); }
    function cancel() { Quickshell.execDetached(["whispy-client", "cancel"]); }

    function apply(raw) {
        if (!raw) return;
        let j;
        try {
            j = JSON.parse(raw);
        } catch (e) {
            return; // half-read → keep the current state
        }
        const st = String(j.state ?? "idle");
        root.stamp = typeof j.timestamp === "number" ? j.timestamp : Date.now() / 1000;
        root.rms = typeof j.rms === "number" ? j.rms : 0;
        if (j.error_message) root.errorMessage = String(j.error_message);
        root.state = st === "recording" && root.isStale() ? "idle" : st;

        if (root.state === "success") hold.holdFor(root.holdSuccessMs);
        else if (root.state === "error") hold.holdFor(root.holdErrorMs);
        else hold.stop();
    }

    function isStale() { return (Date.now() / 1000 - root.stamp) * 1000 > root.staleMs; }

    FileView {
        id: stateFile
        path: Quickshell.env("XDG_RUNTIME_DIR") + "/whispy/state.json"
        printErrors: false   // missing until the daemon runs
        onTextChanged: root.apply(text())
    }

    // The daemon replaces the file atomically (tmp + rename), which breaks
    // FileView's inotify watch after the first write → poll instead. reload()
    // on unchanged content doesn't fire onTextChanged. Fast only while active.
    Timer {
        interval: root.active ? 50 : 200
        running: true
        repeat: true
        onTriggered: {
            stateFile.reload();
            if (root.state === "recording" && root.isStale()) root.state = "idle";
        }
    }

    Timer {
        id: hold
        function holdFor(ms) { interval = ms; restart(); }
        onTriggered: root.state = "idle"
    }
}
