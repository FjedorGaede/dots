pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

import qs.config

// Built-in laptop keyboard on/off (e.g. while an external keyboard sits on
// top of it). Toggled via Hyprland's per-device `enabled` option.
//
// Hyprland doesn't expose a device's enabled state, so it is tracked here.
// NOT persisted: a Hyprland restart/reload re-enables the device anyway, so
// on shell start the keyboard is forced back on to keep both in sync.
//
// The disable is at the compositor level, so it also silences the lock screen
// (hyprlock gets no events) — hypr/hyprlock.conf adds a clickable label that
// calls `qs ipc call keyboard enable` (the IpcHandler below) as an escape hatch.
Singleton {
    id: root

    readonly property string device: "at-translated-set-2-keyboard"
    property bool disabled: false

    function setDisabled(off) {
        root.disabled = off;
        // Lua config: `hyprctl keyword` is gone, `eval` runs Lua (docs/GOTCHAS.md → Hyprland)
        Quickshell.execDetached(["hyprctl", "eval",
            `hl.device({ name = "${root.device}", enabled = ${!off} })`]);
    }

    function toggle() {
        setDisabled(!root.disabled);
        if (root.disabled)
            Apps.notify("Laptop keyboard off",
                "Click the keyboard icon in the bar (or the label on the lock screen) to turn it back on");
    }

    // CLI / hyprlock label escape hatch: `qs ipc call keyboard <enable|disable|toggle>`
    IpcHandler {
        target: "keyboard"

        function enable(): void  { root.setDisabled(false) }
        function disable(): void { root.setDisabled(true) }
        function toggle(): void  { root.toggle() }
        function status(): string { return root.disabled ? "1" : "0" }
    }

    Component.onCompleted: setDisabled(false)
}
