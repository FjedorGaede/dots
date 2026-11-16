pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

import qs.config

// Insta360 Link webcam: gimbal, AI modes, image settings. UI in
// modules/insta360/ (overview: modules/insta360/README.md). Every camera
// access is modules/insta360/link.py — it only writes known-safe controls.
//
//   qs ipc call insta360 open | close | toggle   (PanelService)
//   qs ipc call webcam status
//   qs ipc call webcam gestures false
//
// The camera is polled only while its menu is open (and once whenever the
// home menu opens, for the tile).
Singleton {
    id: root

    // "absent" | "ready" | "error"
    property string phase: "absent"
    readonly property bool present: root.phase !== "absent"

    property string name: ""
    property string device: ""
    // Some app streams from the camera — the gimbal only moves then
    property bool streaming: false
    // v4l2 controls: { name: { value, min, max, step, default, inactive } }
    property var controls: ({})
    property string frame: ""     // head | upper | full
    property bool noise: false
    property bool gestures: false   // camera reports hand gestures enabled
    // Wanted state: off is re-applied whenever the camera shows up with
    // gestures on again (a replug resets it to the firmware defaults)
    readonly property bool gesturesOff: state.gesturesOff
    property string error: ""

    // Mode: read back from the camera; while it switches (0xFF) the last
    // one set is kept
    readonly property string mode: state.mode
    readonly property var presets: state.presets

    readonly property var modes: [
        { key: "normal",     label: "Normal" },
        { key: "track",      label: "Tracking" },
        { key: "whiteboard", label: "Whiteboard" },
        { key: "overhead",   label: "Overhead" },
        { key: "deskview",   label: "DeskView" },
    ]

    readonly property string helper: Quickshell.shellPath("modules/insta360/link.py")

    function ctrl(name) { return root.controls[name] ?? null }
    function value(name) { return root.controls[name]?.value ?? 0 }

    function refresh() {
        if (!statusProc.running) statusProc.running = true;
    }

    // ── Writes: one helper at a time, slider drags coalesce ──
    property var pending: ({})
    property var pendingCmds: []

    function set(name, val) {
        const c = root.controls[name];
        if (c) {
            val = Math.max(c.min, Math.min(c.max, Math.round(val / c.step) * c.step));
            // Optimistic: the UI follows at once, the next status confirms
            const next = Object.assign({}, root.controls);
            next[name] = Object.assign({}, c, { value: val });
            root.controls = next;
        }
        const p = Object.assign({}, root.pending);
        p[name] = val;
        root.pending = p;
        root.flush();
    }

    function run(args) {
        root.pendingCmds = root.pendingCmds.concat([args]);
        root.flush();
    }

    function flush() {
        if (writeProc.running) return;
        let args = null;
        const keys = Object.keys(root.pending);
        if (keys.length > 0) {
            args = ["set"].concat(keys.map(k => k + "=" + root.pending[k]));
            root.pending = {};
        } else if (root.pendingCmds.length > 0) {
            args = root.pendingCmds[0];
            root.pendingCmds = root.pendingCmds.slice(1);
        }
        if (!args) return;
        writeProc.command = ["python3", "-I", root.helper].concat(args);
        writeProc.running = true;
    }

    // ── Gimbal ──
    readonly property int degree: 3600   // the camera works in arcseconds

    function nudge(dPan, dTilt) {
        if (dPan) root.set("pan_absolute", root.value("pan_absolute") + dPan * root.degree);
        if (dTilt) root.set("tilt_absolute", root.value("tilt_absolute") + dTilt * root.degree);
    }

    function center() {
        root.set("pan_absolute", 0);
        root.set("tilt_absolute", 0);
        root.set("zoom_absolute", 100);
    }

    function setMode(key) {
        state.mode = key;
        root.run(["mode", key]);
    }

    function setFrame(key) {
        root.frame = key;
        root.run(["frame", key]);
    }

    function setNoise(on) {
        root.noise = on;
        root.run(["noise", on ? "on" : "off"]);
    }

    // Off only — on again needs a replug: the firmware clears its gesture
    // bindings when they go off and won't take them back (a USB reset
    // doesn't restore them either). Turning the wish back on just stops the
    // re-apply; the menu asks for a replug.
    function setGesturesOff(off) {
        state.gesturesOff = off;
        if (off && root.gestures) {
            root.gestures = false;
            root.run(["gestures", "off"]);
        }
    }

    // Presets: slot index → { pan, tilt, zoom }
    function savePreset(slot) {
        const list = (state.presets ?? []).slice();
        while (list.length <= slot) list.push(null);
        list[slot] = { pan: root.value("pan_absolute"), tilt: root.value("tilt_absolute"),
                       zoom: root.value("zoom_absolute") };
        state.presets = list;
    }

    function goPreset(slot) {
        const p = state.presets?.[slot];
        if (!p) return;
        if (root.mode !== "normal") root.setMode("normal");   // tracking would move it away again
        root.set("pan_absolute", p.pan);
        root.set("tilt_absolute", p.tilt);
        root.set("zoom_absolute", p.zoom);
    }

    function resetImage() {
        for (const n of ["brightness", "contrast", "saturation", "sharpness", "hue"])
            if (root.controls[n]) root.set(n, root.controls[n].default);
    }

    Process {
        id: statusProc
        command: ["python3", "-I", root.helper, "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                let s;
                try { s = JSON.parse(this.text); } catch (e) { return; }
                if (!s.present) { root.phase = "absent"; return; }
                root.name = s.name;
                root.device = s.device;
                root.streaming = s.streaming;
                // A write still queued would be undone by the older values
                if (!writeProc.running && Object.keys(root.pending).length === 0)
                    root.controls = s.controls;
                root.frame = s.frame;
                root.noise = s.noise;
                root.gestures = s.gestures;
                if (s.mode !== "" && !writeProc.running && root.pendingCmds.length === 0) state.mode = s.mode;
                root.phase = "ready";
                if (state.gesturesOff && s.gestures) root.run(["gestures", "off"]);
            }
        }
        stderr: StdioCollector {
            onStreamFinished: if (this.text.trim() !== "") {
                root.error = this.text.trim().split("\n").pop();
                root.phase = "error";
            }
        }
    }

    Process {
        id: writeProc
        stderr: StdioCollector {
            onStreamFinished: if (this.text.trim() !== "") root.error = this.text.trim().split("\n").pop()
        }
        onExited: code => {
            if (code === 0) root.error = "";
            root.flush();
        }
    }

    Timer {
        interval: 2000
        repeat: true
        running: PanelService.isOpen("insta360")
        onTriggered: root.refresh()
    }

    // Gestures off wanted → catch a replug within ~15 s even with the menu closed
    Timer {
        interval: 15000
        repeat: true
        running: state.gesturesOff && root.installed && !PanelService.isOpen("insta360")
        onTriggered: root.refresh()
    }

    FileView {
        id: stateFile
        path: Paths.insta360State
        onAdapterUpdated: stateFile.writeAdapter()
        onLoadFailed: (error) => {
            if (error === FileViewError.FileNotFound) stateFile.writeAdapter();
        }

        JsonAdapter {
            id: state
            property string mode: "normal"
            property var presets: []
            property bool gesturesOff: false
        }
    }

    // ── One-click install (docs/APPS.md) ──
    property bool installed: true   // optimistic: no install flash at startup
    readonly property bool installing: installProc.running
    readonly property var installCheckCommand:
        [Paths.dotsDir + "/packages/hyprland/install/insta360/install.sh", "--check"]

    function checkInstalled() {
        if (!installCheck.running) installCheck.running = true;
    }

    function install() {
        if (installProc.running) return;
        installProc.command = Apps.floatingTerminalCommand(
            Paths.dotsCli + " install hyprland --only insta360");
        installProc.running = true;
    }

    Process {
        id: installCheck
        running: true
        command: root.installCheckCommand
        onExited: code => {
            root.installed = code === 0;
            if (root.installed) root.refresh();
        }
    }

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
            Quickshell.execDetached(["sh", "-c", "sleep 1.5; qs ipc call insta360 open"]);
            Quickshell.reload(false);
        }
    }

    IpcHandler {
        target: "webcam"

        function gestures(on: bool): void { root.setGesturesOff(!on); }

        function status(): string {
            return root.phase + " installed=" + root.installed + " device=" + root.device
                + " streaming=" + root.streaming + " mode=" + root.mode + " frame=" + root.frame
                + " gestures=" + root.gestures + " gesturesOff=" + root.gesturesOff
                + " pan=" + root.value("pan_absolute") + " tilt=" + root.value("tilt_absolute")
                + " zoom=" + root.value("zoom_absolute") + " error=" + root.error;
        }
    }
}
