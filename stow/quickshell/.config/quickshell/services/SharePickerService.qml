pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Bridge between xdg-desktop-portal-hyprland and the share picker overlay.
// scripts/share-picker.sh (xdph's custom_picker_binary) calls
//   qs ipc call sharepicker open <fifo> <XDPH_WINDOW_SHARING_LIST>
// and blocks on the fifo; choose()/cancel() write the answer line into it.
Singleton {
    id: root

    property bool pending: false
    property string fifo: ""
    // [{ handle, cls, title, address }] — address = Hyprland window address
    // as a number (matches HyprlandToplevel.address)
    property var windows: []

    // "<handle>[HC>]<class>[HT>]<title>[HE>]<address>[HA>]" repeated, handle
    // and address in decimal (xdph ScreencopyShared.cpp buildWindowList)
    function parseWindows(list) {
        return list.split("[HA>]").filter(e => e !== "").map(e => {
            const [handle, rest1] = e.split("[HC>]");
            const [cls, rest2] = (rest1 ?? "").split("[HT>]");
            const [title, address] = (rest2 ?? "").split("[HE>]");
            return { handle: handle, cls: cls ?? "", title: title ?? "", address: Number(address ?? 0) };
        });
    }

    // Selection without the "[SELECTION]/" prefix, e.g. "screen:DP-2",
    // "window:123456", "region:eDP-1@10,10,800,600"
    function choose(selection) {
        root._answer(selection);
    }

    function cancel() {
        root._answer("");
    }

    function _answer(line) {
        if (!root.pending) return;
        root.pending = false;
        // timeout: never hang if the script already gave up (fifo w/o reader)
        Quickshell.execDetached(["timeout", "3", "sh", "-c", 'printf "%s\\n" "$1" > "$0"',
            root.fifo, line]);
    }

    IpcHandler {
        target: "sharepicker"

        function open(fifo: string, windows: string): void {
            if (root.pending) root.cancel();   // stale request — never leave a reader hanging
            root.fifo = fifo;
            root.windows = root.parseWindows(windows);
            root.pending = true;
        }
        function cancel(): void { root.cancel() }
    }
}
