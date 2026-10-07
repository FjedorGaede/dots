pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Open/close state for every panel + their IPC targets (replaces ShellState
// and the six copy-pasted IpcHandler blocks).
//
//   qs ipc call <audio|wifi|bluetooth|notifications|home|network|calendar|recorder|displays> <toggle|open|close>
//
// Every screen has a bar, so a panel is open ON a screen: the bar button
// passes its screen name, IPC/keyboard (no screen) means the main monitor.
// A panel's copy in each bar shows only when it's open on that bar's screen
// (isOpenOn); opening it on another screen moves it there. isOpen() = open
// anywhere. The main-only overlays (home, network, recorder, displays) only
// exist on the main monitor and just use isOpen().
//
// Per-panel state on purpose (not a single `current` string): several
// panels may be open at the same time, exactly as before — mutual exclusion
// would be a behaviour change.
Singleton {
    id: root

    readonly property var panels: ["audio", "wifi", "bluetooth", "notifications", "home", "network", "calendar", "recorder", "displays"]

    // name → screen name it's open on (missing = closed). Replaced (never
    // mutated) so bindings on isOpen()/isOpenOn() update.
    property var openOn: ({})

    function _screen(screen) { return screen || DisplayService.mainName }

    function isOpen(name) { return !!root.openOn[name] }
    function isOpenOn(name, screen) { return root.openOn[name] === root._screen(screen) }

    // Closing with a screen only closes the copy on that screen — a popup that
    // hides because the panel moved to another screen must not close it there
    function setOpen(name, value, screen) {
        const next = Object.assign({}, root.openOn);
        if (value) {
            if (root.isOpenOn(name, screen)) return;
            next[name] = root._screen(screen);
        } else {
            if (!root.isOpen(name) || (screen && !root.isOpenOn(name, screen))) return;
            delete next[name];
        }
        root.openOn = next;
    }

    function toggle(name, screen) { root.setOpen(name, !root.isOpenOn(name, screen), screen) }
    function open(name, screen)   { root.setOpen(name, true, screen) }
    function close(name, screen)  { root.setOpen(name, false, screen) }

    Instantiator {
        model: root.panels

        // No `required property modelData`: every declared property/signal
        // shows up in the IPC interface (`qs ipc show`) — use the delegate's
        // context `modelData` instead.
        delegate: IpcHandler {
            target: modelData

            function toggle(): void { root.toggle(modelData) }
            function open(): void { root.open(modelData) }
            function close(): void { root.close(modelData) }
        }
    }
}
