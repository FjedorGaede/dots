//@ pragma UseQApplication
import Quickshell
import QtQuick

import qs.modules.bar
import qs.modules.osd
import qs.modules.overlays
import qs.modules.notifications
import qs.services

// Wiring only. Layout: docs/REFACTOR.md §2 (config/ services/ components/
// modules/ lib/ scripts/).
//
// Everything lives on the main monitor (DisplayService.mainScreen, picked in
// the Displays menu). Variants creates the windows for that screen and, when
// the main monitor changes, destroys them and creates fresh ones on the new
// one — never bind `screen:` of a live window to something that can change:
// Quickshell 0.3.1 segfaults in QWindow::setScreen (docs/GOTCHAS.md).
Scope {
    // Idle handling (dim/lock/screen-off/suspend, lock-before-sleep) — see services/IdleService.qml
    Component.onCompleted: IdleService.start()

    Variants {
        model: DisplayService.mainScreen ? [DisplayService.mainScreen] : []

        delegate: Scope {
            id: main
            required property var modelData

            Bar { screen: main.modelData }

            Osd { screen: main.modelData }

            LanDevices { screen: main.modelData }

            Toasts { screen: main.modelData }

            RecorderMenu { screen: main.modelData }

            DisplaysMenu { screen: main.modelData }
        }
    }
}
