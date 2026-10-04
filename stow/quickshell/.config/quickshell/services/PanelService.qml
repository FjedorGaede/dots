pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Open/close state for every panel + their IPC targets (replaces ShellState
// and the six copy-pasted IpcHandler blocks).
//
//   qs ipc call <audio|wifi|bluetooth|notifications|home|network|calendar|recorder|displays> <toggle|open|close>
//
// Per-panel booleans on purpose (not a single `current` string): several
// panels may be open at the same time, exactly as before — mutual exclusion
// would be a behaviour change.
Singleton {
    id: root

    readonly property var panels: ["audio", "wifi", "bluetooth", "notifications", "home", "network", "calendar", "recorder", "displays"]

    // name → bool. Replaced (never mutated) so bindings on isOpen() update.
    property var openPanels: ({})

    function isOpen(name) { return !!root.openPanels[name] }

    function setOpen(name, value) {
        if (root.isOpen(name) === !!value) return;
        const next = Object.assign({}, root.openPanels);
        next[name] = !!value;
        root.openPanels = next;
    }

    function toggle(name) { root.setOpen(name, !root.isOpen(name)) }
    function open(name)   { root.setOpen(name, true) }
    function close(name)  { root.setOpen(name, false) }

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
