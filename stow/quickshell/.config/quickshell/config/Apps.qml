pragma Singleton
import QtQuick
import Quickshell

// External commands the shell launches (fire-and-forget), in ONE place.
// Service-internal tools (nmcli, pgrep, brightnessctl, …) stay in their service.
Singleton {
    id: root

    function lock()     { Quickshell.execDetached(["sh", "-c", "pidof hyprlock || hyprlock"]) }
    function suspend()  { Quickshell.execDetached(["systemctl", "suspend"]) }
    function reboot()   { Quickshell.execDetached(["systemctl", "reboot"]) }
    function poweroff() { Quickshell.execDetached(["systemctl", "poweroff"]) }
    // Lua config: `hyprctl dispatch` evaluates its argument as Lua
    // (`return hl.dispatch(<arg>)`) — plain `exit` is an undefined variable.
    // Same form as the keybind in hypr/keybinds.lua (docs/GOTCHAS.md → Hyprland).
    function logout()   { Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.exit()"]) }

    function bluetoothManager()   { Quickshell.execDetached(["blueman-manager"]) }
    // Enterprise (802.1X) wifi setup. nm-connection-editor was dropped from
    // dots (see ~/dots/AGENTS.md) → nmtui's editor in the terminal
    // (terminal = shared.lua `terminal`)
    function connectionEditor()   { Quickshell.execDetached(["ghostty", "-e", "nmtui", "edit"]) }
    function openUrl(url)         { Quickshell.execDetached(["xdg-open", url]) }
    // Shell command in a terminal. Interactive shell → the rc's PATH applies
    // (`dots` is only on PATH via stow/shell/.commonshellrc); the window stays
    // open afterwards so the result can be read.
    function runInTerminal(command) {
        Quickshell.execDetached(root.terminalCommand(command))
    }
    // The argv behind runInTerminal — for callers that run it as a Process to
    // notice when the window is closed (SetupService)
    function terminalCommand(command) {
        return ["ghostty", "--wait-after-command=true", "-e",
                Quickshell.env("SHELL") || "sh", "-ic", command]
    }
    function notify(summary, body) {
        Quickshell.execDetached(["notify-send", "-a", "quickshell", summary, body])
    }
}
