pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

import qs.config

// Resolution / refresh / scale per monitor (DisplaysMenu).
//
// apply() changes a monitor live via `hyprctl eval 'hl.monitor({...})'` and
// starts a Keep/Revert countdown; nothing is saved until keep(). Saved rules
// go to Paths.monitorOverrides (~/.local/state/hypr/monitors.lua, outside the
// dots repo) — hypr/monitors.lua loadfile()s it last, so they win over the
// defaults there. Rules match by `desc:` so they follow the physical monitor.
// Scale/mode validity idea cribbed from stevederico/omarchy-displays (MIT).
Singleton {
    id: root

    readonly property int confirmSeconds: 10

    // [{ name, description, width, height, refreshRate, scale, modes: ["2560x1600@300.00", …] }]
    property var monitors: []

    // output → { mode: "2560x1600@300.00", scale: 1.333333 }, output = outputOf(m)
    property var saved: ({})

    // Live change waiting for Keep/Revert:
    // { name, output, prev: { mode, scale }, next: { mode, scale } } | null
    property var pending: null
    property int countdown: 0

    property string lastError: ""

    // Main monitor (hypr/workspaces.lua gives it workspaces 1-9): the saved
    // description if that monitor is connected, else the laptop panel, else
    // the first monitor — same fallback order as workspaces.lua
    property string mainDescription: ""
    readonly property string mainName: {
        const ms = Hyprland.monitors.values;
        const m = ms.find(m => root.mainDescription !== "" && m.description === root.mainDescription)
               ?? ms.find(m => m.name.startsWith("eDP"))
               ?? ms[0];
        return m?.name ?? "";
    }
    // Its Quickshell screen — shell.qml's Variants creates the bar, OSD,
    // toasts and overlays there (never bind a live window's `screen:` to it)
    readonly property var mainScreen: Quickshell.screens.find(s => s.name === root.mainName) ?? null

    function setMain(m) {
        if (!m?.description || m.name === root.mainName) return;
        root.mainDescription = m.description;
        mainProc.command = ["sh", "-c",
            'mkdir -p "$(dirname "$1")" && printf "%s\\n" "$2" > "$1.tmp" && mv "$1.tmp" "$1" && hyprctl reload',
            "sh", Paths.mainMonitor, m.description];
        mainProc.running = true;
    }

    function refresh() { listProc.running = true }

    // Rule target: `desc:` follows the physical monitor; monitors without a
    // description (virtual ones) fall back to the connector name — an empty
    // `desc:` would match every monitor
    function outputOf(m) { return m.description ? "desc:" + m.description : m.name }

    // ── Modes / scales ──

    function modeOf(m) { return m.width + "x" + m.height + "@" + Number(m.refreshRate).toFixed(2) }

    function parseMode(text) {
        const match = /^(\d+)x(\d+)@(\d+(?:\.\d+)?)/.exec(String(text || ""));
        if (!match) return null;
        return { width: +match[1], height: +match[2], refresh: +match[3] };
    }

    // Unique resolutions, largest first: [{ width, height, rates: [300, 240, 60] }]
    function resolutions(m) {
        const byKey = {};
        const out = [];
        for (const text of m?.modes ?? []) {
            const p = parseMode(text);
            if (!p) continue;
            const key = p.width + "x" + p.height;
            if (!byKey[key]) {
                byKey[key] = { width: p.width, height: p.height, rates: [] };
                out.push(byKey[key]);
            }
            if (!byKey[key].rates.some(r => Math.abs(r - p.refresh) < 0.01))
                byKey[key].rates.push(p.refresh);
        }
        for (const r of out) r.rates.sort((a, b) => b - a);
        out.sort((a, b) => (b.width * b.height - a.width * a.height) || (b.width - a.width));
        return out;
    }

    function gcd(a, b) { while (b) { const t = a % b; a = b; b = t; } return a; }

    // Hyprland only takes scales that give whole logical pixels (1/120 steps):
    // round the wanted scale up to the next one that divides the mode.
    function cleanScale(scale, width, height) {
        const divisor = gcd(Math.round(width * 120), Math.round(height * 120));
        let units = Math.max(1, Math.round(scale * 120));
        while (units < divisor && divisor % units !== 0) units++;
        return Math.round(units / 120 * 1e6) / 1e6;
    }

    function scales(width, height) {
        const out = [];
        for (const s of [1, 1.25, 1.333333, 1.5, 1.6, 1.75, 2]) {
            const c = cleanScale(s, width, height);
            if (!out.some(o => sameScale(o, c))) out.push(c);
        }
        return out;
    }

    function sameScale(a, b) { return Math.abs(Number(a) - Number(b)) < 0.005 }

    function formatScale(s) { return String(Math.round(s * 100) / 100) }

    // ── Live apply + Keep/Revert ──

    function apply(m, mode, scale) {
        if (root.pending && root.pending.name !== m.name) return;
        const p = parseMode(mode);
        if (!p) return;
        const next = { mode: mode, scale: cleanScale(scale, p.width, p.height) };
        // Changing the same monitor again keeps the original state to revert to
        const prev = root.pending ? root.pending.prev : { mode: modeOf(m), scale: m.scale };
        root.lastError = "";
        root.pending = { name: m.name, output: outputOf(m), prev: prev, next: next };
        root.countdown = root.confirmSeconds;
        countdownTimer.restart();
        root._eval(m.name, next, true);
    }

    function keep() {
        if (!root.pending) return;
        const next = Object.assign({}, root.saved);
        next[root.pending.output] = root.pending.next;
        root.saved = next;
        root._clearPending();
        root._write(false);
    }

    function revert() {
        if (!root.pending) return;
        const p = root.pending;
        root._clearPending();
        root._eval(p.name, p.prev, false);
    }

    // Drop the saved rule → back to the defaults in hypr/monitors.lua
    function reset(m) {
        if (!root.saved[outputOf(m)]) return;
        const next = Object.assign({}, root.saved);
        delete next[outputOf(m)];
        root.saved = next;
        root._write(true);
    }

    function _clearPending() {
        countdownTimer.stop();
        root.pending = null;
        root.countdown = 0;
    }

    function _rule(output, s) {
        return "hl.monitor({ output = " + JSON.stringify(output)
             + ", mode = " + JSON.stringify(s.mode)
             + ", position = \"auto\", scale = " + s.scale + " })";
    }

    function _eval(name, s, revertOnError) {
        evalProc.revertOnError = revertOnError;
        evalProc.command = ["hyprctl", "eval", root._rule(name, s)];
        evalProc.running = true;
    }

    // Whole file is rewritten from `saved` (atomic: tmp + mv)
    function _write(reloadAfter) {
        const lines = ["-- Written by the quickshell Displays menu (services/DisplayService.qml).",
                       "-- Machine-local, not in git. Loaded by hypr/monitors.lua."];
        for (const output of Object.keys(root.saved))
            lines.push(root._rule(output, root.saved[output]));
        writeProc.reloadAfter = reloadAfter;
        writeProc.command = ["sh", "-c",
            'mkdir -p "$(dirname "$1")" && printf "%s\\n" "$2" > "$1.tmp" && mv "$1.tmp" "$1"',
            "sh", Paths.monitorOverrides, lines.join("\n")];
        writeProc.running = true;
    }

    Timer {
        id: countdownTimer
        interval: 1000
        repeat: true
        onTriggered: {
            root.countdown--;
            if (root.countdown <= 0) root.revert();
        }
    }

    Process {
        id: listProc
        command: ["hyprctl", "monitors", "-j"]
        stdout: StdioCollector { id: listOut }
        onExited: {
            try {
                root.monitors = JSON.parse(listOut.text)
                    .filter(m => !m.disabled)
                    .map(m => ({
                        name: m.name,
                        description: m.description,
                        width: m.width,
                        height: m.height,
                        refreshRate: m.refreshRate,
                        scale: m.scale,
                        modes: (m.availableModes ?? []).map(s => s.replace(/Hz$/, ""))
                    }));
            } catch (e) {
                root.lastError = "Could not read monitors";
            }
        }
    }

    Process {
        id: evalProc
        property bool revertOnError: false
        stdout: StdioCollector { id: evalOut }
        onExited: {
            const errors = evalOut.text.split("\n").filter(l => l.startsWith("error"));
            if (errors.length > 0) {
                root.lastError = errors[0].replace(/^error:.*?:\d+:\s*/, "");
                if (evalProc.revertOnError) root.revert();
            }
            refreshDelay.restart();
        }
    }

    // Hyprland applies the mode asynchronously
    Timer {
        id: refreshDelay
        interval: 300
        onTriggered: root.refresh()
    }

    Process {
        id: writeProc
        property bool reloadAfter: false
        onExited: code => {
            if (code !== 0) root.lastError = "Could not save " + Paths.monitorOverrides;
            else if (writeProc.reloadAfter) reloadProc.running = true;
        }
    }

    Process {
        id: mainProc
        onExited: code => {
            if (code !== 0) root.lastError = "Could not save " + Paths.mainMonitor;
        }
    }

    FileView {
        path: Paths.mainMonitor
        printErrors: false   // no file = laptop panel is main
        watchChanges: true   // also follow edits made outside the menu
        onFileChanged: reload()
        onLoaded: root.mainDescription = text().trim()
    }

    Process {
        id: reloadProc
        command: ["hyprctl", "reload"]
        onExited: refreshDelay.restart()
    }

    // Load what's saved (we wrote it, so one rule per line in a known shape)
    FileView {
        path: Paths.monitorOverrides
        printErrors: false   // no file = nothing saved yet
        onLoaded: {
            const out = {};
            const re = /output = "((?:[^"\\]|\\.)*)", mode = "([^"]+)", position = "auto", scale = ([\d.]+)/;
            for (const line of text().split("\n")) {
                const match = re.exec(line);
                if (match) out[JSON.parse('"' + match[1] + '"')] = { mode: match[2], scale: +match[3] };
            }
            root.saved = out;
        }
    }

    Component.onCompleted: refresh()
}
