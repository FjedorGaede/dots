pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

import qs.config

// Screen recording with gpu-screen-recorder (gsr). Menu: modules/overlays/
// RecorderMenu.qml; control while recording: bar indicator
// (modules/bar/indicators/Recording.qml — dot, timer, pause/resume, stop).
//
//   qs ipc call recording toggle   — menu when idle, stop while recording
//   qs ipc call recording stop | pause
//   qs ipc call recording start <region|window|screen>   — skip the menu
//
// Capture is KMS (`-w <monitor>` / `-w region`) → every layer on screen is
// recorded, so there is no floating control (docs/GOTCHAS.md).
// gsr signals: SIGUSR2 = pause/resume, SIGINT = stop + finalize the file.
Singleton {
    id: root

    // "idle" | "selecting" | "recording" | "paused"
    property string phase: "idle"
    readonly property bool active: root.phase === "recording" || root.phase === "paused"

    // Menu choices. Audio is reset to off whenever the menu opens.
    property string mode: "region"   // "region" | "window" | "screen"
    property bool mic: false
    property bool desktopAudio: false

    property int elapsed: 0          // seconds, paused time excluded
    property string outputPath: ""

    readonly property int sigint: 2
    readonly property int sigusr2: 12

    function start() {
        if (root.phase !== "idle") return;
        root.phase = "selecting";
        // Let the menu overlay unmap first — it would end up under slurp's
        // dimming / in the first frames of a full-screen recording
        startDelay.restart();
    }

    function stop() {
        if (root.active) recProc.signal(root.sigint);
    }

    function togglePause() {
        if (!root.active) return;
        recProc.signal(root.sigusr2);
        root.phase = root.phase === "paused" ? "recording" : "paused";
    }

    // Created on demand — it only exists after the first recording
    function openFolder() {
        Quickshell.execDetached(["sh", "-c", 'mkdir -p "$0" && xdg-open "$0"', Paths.recordings]);
    }

    function formatElapsed(s) {
        const m = Math.floor(s / 60), r = s % 60;
        return (m < 10 ? "0" : "") + m + ":" + (r < 10 ? "0" : "") + r;
    }

    Timer {
        id: startDelay
        interval: 250
        onTriggered: {
            selectProc.command = [Quickshell.shellPath("scripts/screenrec-select.sh"), root.mode];
            selectProc.running = true;
        }
    }

    Process {
        id: selectProc
        stdout: StdioCollector { id: selectOut }
        onExited: code => {
            // "screen <monitor> x y w h" | "region x y w h"
            const f = selectOut.text.trim().split(/\s+/);
            if (code !== 0 || f.length < 5) {          // Escape in slurp
                root.phase = "idle";
                return;
            }
            const screen = f[0] === "screen";
            const n = f.slice(screen ? 2 : 1).map(Number);
            root.record({ monitor: screen ? f[1] : "", x: n[0], y: n[1], w: n[2], h: n[3] });
        }
    }

    // t: { monitor, x, y, w, h } — monitor set → whole output, else the
    // global logical rect
    function record(t) {
        const stamp = Qt.formatDateTime(new Date(), "yyyy-MM-dd_HH-mm-ss");
        root.outputPath = Paths.recordings + "/Recording_" + stamp + ".mp4";

        const args = ["gpu-screen-recorder"];
        if (t.monitor !== "")
            args.push("-w", t.monitor);
        else
            args.push("-w", "region", "-region", t.w + "x" + t.h + "+" + t.x + "+" + t.y);
        // 60 fps even on the 240 Hz panel; h264 plays everywhere (chat apps)
        args.push("-f", "60", "-k", "h264", "-c", "mp4");
        // Both sources → one merged track
        const audio = [];
        if (root.desktopAudio) audio.push("default_output");
        if (root.mic) audio.push("default_input");
        if (audio.length > 0) args.push("-a", audio.join("|"));
        args.push("-o", root.outputPath);

        // exec → the Process pid is gsr itself, so signal() reaches it
        recProc.command = ["sh", "-c", 'mkdir -p "$0" && exec "$@"', Paths.recordings].concat(args);
        root.elapsed = 0;
        root.phase = "recording";
        recProc.running = true;
    }

    Process {
        id: recProc
        stderr: StdioCollector { id: recErr }
        onExited: code => {
            root.phase = "idle";
            if (code === 0) {
                root.notifySaved(root.outputPath);
            } else {
                const lines = recErr.text.trim().split("\n");
                const err = lines.filter(l => l.indexOf("error") !== -1).slice(-2).join("\n");
                Apps.notify("Recording failed", err || ("gpu-screen-recorder exited with " + code));
            }
        }
    }

    // The file goes on the clipboard as a file reference (text/uri-list, what
    // file managers copy) → paste straight into Slack/Discord/the browser.
    // "Open" plays the file, "Show folder" opens the recordings dir;
    // notify-send blocks until an action is chosen → detached shell.
    function notifySaved(path) {
        Quickshell.execDetached(["sh", "-c",
            'printf "file://%s\\n" "$0" | wl-copy -t text/uri-list; '
            + 'a=$(notify-send -a "Screen recorder" '
            + '-A open=Open -A folder="Show folder" "Recording saved · copied to clipboard" "$0") || exit 0; '
            + 'case "$a" in open) xdg-open "$0" ;; folder) xdg-open "${0%/*}" ;; esac',
            path]);
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.phase === "recording"
        onTriggered: root.elapsed++
    }

    IpcHandler {
        target: "recording"

        function toggle(): void {
            if (root.active) root.stop();
            else if (root.phase === "idle") PanelService.toggle("recorder");
        }
        // Skip the menu: region | window | screen (audio = current menu state)
        function start(mode: string): void {
            if (["region", "window", "screen"].indexOf(mode) === -1) return;
            root.mode = mode;
            root.start();
        }
        function stop(): void { root.stop() }
        function pause(): void { root.togglePause() }
    }
}
