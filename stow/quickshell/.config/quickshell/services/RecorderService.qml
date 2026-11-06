pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

import qs.config

// Screen recording with gpu-screen-recorder (gsr). The recorder's UI lives in
// modules/recorder/ (overview: modules/recorder/README.md): menu
// (RecorderMenu), webcam bubble (WebcamBubble), bar indicator
// (RecordingIndicator — dot, timer, pause/resume, stop).
//
//   qs ipc call recording toggle   — menu when idle, record when the camera
//                                     bubble waits ("ready"), stop while recording
//   qs ipc call recording stop | pause   — stop also cancels "ready"
//   qs ipc call recording start <region|window|screen>   — skip the menu
//
// Capture is KMS (`-w <monitor>` / `-w region`) → every layer on screen is
// recorded (docs/GOTCHAS.md). The camera uses that, Loom-style: with
// `webcam` on, a draggable webcam bubble (WebcamBubble)
// sits on screen and simply ends up in the video — one flattened file, no
// compositing. After the target is picked the bubble always waits in
// "ready" (preview + setup card, empty bubble when the camera is off), then
// Start recording; with the camera on its pill doubles as the controls.
// gsr signals: SIGUSR2 = pause/resume, SIGINT = stop + finalize the file.
Singleton {
    id: root

    // "idle" | "selecting" | "ready" | "recording" | "paused"
    property string phase: "idle"
    readonly property bool active: root.phase === "recording" || root.phase === "paused"

    // Setup (menu + the bubble's setup card) — all remembered in the state
    // file: the last recording's setup is the next one's default
    property alias mode: state.mode   // "region" | "window" | "screen"
    property alias mic: state.mic
    property alias desktopAudio: state.desktopAudio
    property alias webcam: state.webcam
    // Chosen camera (V4L2 card name, see `cameras`); "" or unplugged → the
    // first one available
    property alias camera: state.camera
    // Connected cameras (V4L2 card names), refreshed when the menu opens
    property var cameras: []
    readonly property string activeCamera: root.cameras.indexOf(root.camera) !== -1
        ? root.camera : (root.cameras[0] ?? "")

    // Webcam bubble: diameter (logical px) and position as a fraction of the
    // free space in the target (0 = left/top edge, 1 = right/bottom) → a new
    // region gets the bubble in the same corner, always inside the video
    property alias bubbleSize: state.bubbleSize
    property alias bubbleFx: state.bubbleFx
    property alias bubbleFy: state.bubbleFy

    // Picked target ({ monitor, x, y, w, h }, global logical) and the screen
    // it is on — the bubble window opens there
    property var target: null
    property var targetScreen: null
    // "ready" always (the setup card can switch the camera off and on again);
    // while recording only with the camera on
    readonly property bool bubbleShown: root.targetScreen !== null
        && (root.phase === "ready" || (root.webcam && root.active))

    property int elapsed: 0          // seconds, paused time excluded
    property string outputPath: ""

    readonly property int sigint: 2
    readonly property int sigusr2: 12

    function start() {
        if (root.phase !== "idle") return;
        // Not installed → the menu, which offers the install
        if (!root.installed) {
            PanelService.open("recorder");
            return;
        }
        root.phase = "selecting";
        // Let the menu overlay unmap first — it would end up under slurp's
        // dimming / in the first frames of a full-screen recording
        startDelay.restart();
    }

    function stop() {
        if (root.active) recProc.signal(root.sigint);
        else if (root.phase === "ready") root.phase = "idle";
    }

    // "ready" → recording (Record button in the bubble / Super+R)
    function begin() {
        if (root.phase !== "ready") return;
        // The camera shown is the one used → pin it (it may be a fallback)
        if (root.webcam && root.activeCamera !== "") root.camera = root.activeCamera;
        root.record(root.target);
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

    // ── One-click install ──
    // The recorder is a dots app: its packages come from
    // packages/hyprland/install/screen-recorder/install.sh, which also answers
    // "installed?" (--check) — one package list. Missing → the menu shows an
    // Install button instead of the controls; it runs `dots install` in a
    // floating terminal (as BluetoothService does for bluez-tools). Afterwards
    // the shell reloads: QtMultimedia is only found by a fresh QML engine.
    property bool installed: true   // optimistic: no install flash at startup
    readonly property bool installing: installProc.running
    readonly property var installCheckCommand:
        [Paths.dotsDir + "/packages/hyprland/install/screen-recorder/install.sh", "--check"]

    function checkInstalled() {
        if (!installCheck.running) installCheck.running = true;
    }

    function install() {
        if (installProc.running) return;
        installProc.command = Apps.floatingTerminalCommand(
            Paths.dotsCli + " install hyprland --only screen-recorder");
        installProc.running = true;
    }

    Process {
        id: installCheck
        running: true
        command: root.installCheckCommand
        onExited: code => root.installed = code === 0
    }

    // Terminal closed → check again; done → reload and reopen the menu
    Process {
        id: installProc
        onExited: postInstallCheck.running = true
    }

    Process {
        id: postInstallCheck
        command: root.installCheckCommand
        onExited: code => {
            root.installed = code === 0;
            if (!root.installed) return;
            Quickshell.execDetached(["sh", "-c", "sleep 1.5; qs ipc call recording toggle"]);
            Quickshell.reload(false);
        }
    }

    // Menu row: off → each camera → off
    function cycleCamera() {
        if (!root.webcam) {
            root.webcam = true;
            root.camera = root.cameras[0] ?? "";
            return;
        }
        const i = root.cameras.indexOf(root.activeCamera);
        if (i + 1 < root.cameras.length) root.camera = root.cameras[i + 1];
        else root.webcam = false;
    }

    // "Insta360 Link 2: Insta360 Link" → "Insta360 Link 2"
    function cameraLabel(name) {
        return name.split(": ")[0];
    }

    function refreshCameras() {
        camerasProc.running = true;
    }

    // Capture nodes only (index 0; index 1 = UVC metadata), without the IR
    // sensor of Windows Hello cameras ("…: IR Camera"). Also at startup:
    // `start <mode>` over IPC skips the menu
    Process {
        id: camerasProc
        running: true
        command: ["sh", "-c",
            'for d in /sys/class/video4linux/video*; do '
            + '[ "$(cat "$d/index" 2>/dev/null)" = 0 ] && cat "$d/name"; done | grep -v "IR Camera" | sed "s/ *$//"']
        stdout: StdioCollector {
            onStreamFinished: root.cameras = this.text.split("\n").filter(l => l !== "")
        }
    }

    function formatElapsed(s) {
        const m = Math.floor(s / 60), r = s % 60;
        return (m < 10 ? "0" : "") + m + ":" + (r < 10 ? "0" : "") + r;
    }

    Timer {
        id: startDelay
        interval: 250
        onTriggered: {
            selectProc.command = [Quickshell.shellPath("modules/recorder/select-target.sh"), root.mode];
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
            const t = { monitor: screen ? f[1] : "", x: n[0], y: n[1], w: n[2], h: n[3] };
            // Always "ready" first, camera or not: setup card + Start recording
            root.target = t;
            root.targetScreen = root.screenFor(t);
            root.phase = "ready";
        }
    }

    // Screen holding the target: the named monitor, else the one under the
    // target's center
    function screenFor(t) {
        const screens = Quickshell.screens;
        const cx = t.x + t.w / 2, cy = t.y + t.h / 2;
        for (let i = 0; i < screens.length; i++) {
            const s = screens[i];
            if (t.monitor !== "" ? s.name === t.monitor
                    : cx >= s.x && cx < s.x + s.width && cy >= s.y && cy < s.y + s.height)
                return s;
        }
        return DisplayService.mainScreen;
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

    FileView {
        id: stateFile
        path: Paths.recorderState
        // Bubble drags / menu toggles → saved right away
        onAdapterUpdated: stateFile.writeAdapter()
        // Write on first run only (see StayAwakeService: FileView loads async)
        onLoadFailed: (error) => {
            if (error === FileViewError.FileNotFound) stateFile.writeAdapter();
        }

        JsonAdapter {
            id: state
            property string mode: "region"
            property bool mic: false
            property bool desktopAudio: false
            property bool webcam: true
            property string camera: ""
            property int bubbleSize: 220
            property real bubbleFx: 0
            property real bubbleFy: 1
        }
    }

    IpcHandler {
        target: "recording"

        function toggle(): void {
            if (root.active) root.stop();
            else if (root.phase === "ready") root.begin();
            else if (root.phase === "idle") PanelService.toggle("recorder");
        }
        // Skip the menu: region | window | screen (audio = current menu state)
        function start(mode: string): void {
            if (["region", "window", "screen"].indexOf(mode) === -1) return;
            root.mode = mode;
            root.start();
        }
        function stop(): void { root.stop() }
        // Debugging: phase + install state
        function status(): string {
            return root.phase + " installed=" + root.installed + " webcam=" + root.webcam
                + " camera=" + root.activeCamera
                + " panels=" + JSON.stringify(PanelService.openOn) + " main=" + DisplayService.mainName;
        }
        function pause(): void { root.togglePause() }
    }
}
