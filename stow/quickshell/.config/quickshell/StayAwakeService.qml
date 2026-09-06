pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// "Stay awake" — inhibits hypridle's suspend while enabled (e.g. so
// long-running agents are not killed when you walk away). Dim/lock/screen-off
// behave as usual; only `systemctl suspend` is skipped.
//
// State is file-backed (~/.cache/quickshell/stay-awake.json) so it survives
// shell reloads. The hypridle suspend listener runs a wrapper script that
// greps this file — see ~/.config/hypr/scripts/suspend-or-skip.sh.
Singleton {
    id: root

    readonly property bool enabled: adapter.enabled

    // Periodic reminder so it never silently stays on for days
    readonly property int reminderMinutes: 60

    function toggle() {
        adapter.enabled = !adapter.enabled;
        view.writeAdapter();
        if (adapter.enabled) {
            notify("Stay awake on", "Suspend inhibited — remember to turn it off");
        }
    }

    function notify(summary, body) {
        Quickshell.execDetached(["notify-send", "-a", "quickshell", summary, body]);
    }

    Timer {
        running: root.enabled
        repeat: true
        interval: root.reminderMinutes * 60 * 1000
        onTriggered: root.notify("Stay awake", "Suspend is still inhibited")
    }

    FileView {
        id: view
        // NB: StandardPaths.homeLocation is undefined in QML — use $HOME directly
        path: Quickshell.env("HOME") + "/.cache/quickshell/stay-awake.json"
        watchChanges: true

        JsonAdapter {
            id: adapter
            property bool enabled: false
        }
    }

    // Write the flag file on first run so hypridle's grep always finds it
    Component.onCompleted: if (!view.loaded) view.writeAdapter()
}
