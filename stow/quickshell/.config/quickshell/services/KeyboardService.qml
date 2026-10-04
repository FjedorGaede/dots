pragma Singleton
import QtQuick
import Quickshell

import qs.config

// Built-in laptop keyboard on/off (e.g. while an external keyboard sits on
// top of it). Toggled via Hyprland's per-device `enabled` option.
//
// Hyprland doesn't expose a device's enabled state, so it is tracked here.
// NOT persisted: a Hyprland restart/reload re-enables the device anyway, so
// on shell start the keyboard is forced back on to keep both in sync.
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
            Apps.notify("Laptop keyboard off", "Click the keyboard icon in the bar to turn it back on");
    }

    Component.onCompleted: setDisabled(false)
}
