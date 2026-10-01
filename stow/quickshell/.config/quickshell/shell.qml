//@ pragma UseQApplication
import Quickshell
import QtQuick

import qs.modules.bar
import qs.modules.osd
import qs.modules.overlays
import qs.modules.notifications
import qs.services

// Wiring only. Layout: docs/REFACTOR.md §2 (config/ services/ components/
// modules/ lib/ scripts/). The OSD, LAN-devices overlay and toasts stay
// children of the bar window, as they were before the folder move.
Bar {
    // Idle handling (dim/lock/screen-off/suspend, lock-before-sleep) — see services/IdleService.qml
    Component.onCompleted: IdleService.start()

    Osd {}

    LanDevices {}

    Toasts {}
}
