pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

import qs.config

// Per-machine setup steps of the dots CLI (github, calendar, ...) for the bar's
// setup indicator. `dots setup --status` is the source of truth — nothing is
// decided here. Checked once 30s after start (network up → github's check
// works); the 15 min poll only runs while a step is open, so once everything
// is done or ignored nothing runs until the next start.
Singleton {
    id: root

    // [{ name, state: "open" | "ignored" | "done", text }] — open first
    property var steps: []
    readonly property var openSteps: root.steps.filter(s => s.state === "open")
    property bool loading: false

    function refresh() {
        if (statusProc.running) return;
        root.loading = true;
        statusProc.running = true;
    }

    // Setups ask questions (gum, gh login) → a terminal. Watched as a Process:
    // closing the window refreshes, so a finished step disappears at once.
    function run(name) {
        const cmd = Paths.dotsCli + " setup " + name;
        if (terminalProc.running) {   // one watched terminal at a time
            Apps.runInTerminal(cmd);
            return;
        }
        terminalProc.command = Apps.terminalCommand(cmd);
        terminalProc.running = true;
    }

    function ignore(name)   { root.setIgnored(name, true) }
    function unignore(name) { root.setIgnored(name, false) }

    function setIgnored(name, ignored) {
        // optimistic: the row moves right away, the refresh after confirms it
        root.steps = root.sorted(root.steps.map(s =>
            s.name === name && s.state !== "done"
                ? Object.assign({}, s, { state: ignored ? "ignored" : "open" }) : s));
        Quickshell.execDetached([Paths.dotsCli, "setup", ignored ? "--ignore" : "--unignore", name]);
        refreshSoon.restart();
    }

    function sorted(list) {
        const rank = { open: 0, ignored: 1, done: 2 };
        return list.slice().sort((a, b) => rank[a.state] - rank[b.state] || a.name.localeCompare(b.name));
    }

    function parse(text) {
        const out = [];
        for (const line of text.split("\n")) {
            if (!line.trim()) continue;
            // tab-separated: name \t done|open|ignored \t status text
            const f = line.split("\t");
            out.push({ name: f[0], state: f[1] ?? "open", text: f[2] ?? "" });
        }
        root.steps = root.sorted(out);
    }

    Process {
        id: statusProc
        command: [Paths.dotsCli, "setup", "--status"]
        stdout: StdioCollector {
            onStreamFinished: root.parse(text)
        }
        onExited: root.loading = false
    }

    Process {
        id: terminalProc
        onExited: root.refresh()
    }

    // after --ignore/--unignore (detached — give it a moment to write)
    Timer {
        id: refreshSoon
        interval: 500
        onTriggered: root.refresh()
    }

    Timer {
        interval: 30 * 1000
        running: true
        onTriggered: root.refresh()
    }

    Timer {
        interval: 15 * 60 * 1000
        running: root.openSteps.length > 0
        repeat: true
        onTriggered: root.refresh()
    }
}
