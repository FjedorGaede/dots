pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

import qs.config

// "Stay awake" — inhibits the idle suspend (services/IdleService.qml) while enabled (e.g. so
// long-running agents are not killed when you walk away). Dim/lock/screen-off
// behave as usual; only `systemctl suspend` is skipped.
//
// State is file-backed (~/.cache/quickshell/stay-awake.json) so it survives
// shell reloads. IdleService checks `enabled` before suspending.
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

    function notify(summary, body) { Apps.notify(summary, body) }

    Timer {
        running: root.enabled
        repeat: true
        interval: root.reminderMinutes * 60 * 1000
        onTriggered: root.notify("Stay awake", "Suspend is still inhibited")
    }

    FileView {
        id: view
        path: Paths.stayAwakeFlag
        watchChanges: true

        // Write the state file on first run.
        // NB: only on FileNotFound — FileView loads asynchronously, so checking
        // `loaded` in Component.onCompleted clobbered the saved state with the
        // default on every full restart.
        onLoadFailed: (error) => {
            if (error === FileViewError.FileNotFound) view.writeAdapter();
        }

        JsonAdapter {
            id: adapter
            property bool enabled: false
        }
    }

}
