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
// Every screen gets a bar; its popups (audio, wifi, calendar, ...) open on the
// screen you clicked (PanelService.isOpenOn). The OSD, toasts, home menu and
// the other overlays exist once, on the main monitor (DisplayService.mainScreen,
// picked in the Displays menu).
//
// Variants creates windows for a screen and, when the screens / main monitor
// change, destroys them and creates fresh ones — never bind `screen:` of a live
// window to something that can change: Quickshell 0.3.1 segfaults in
// QWindow::setScreen (docs/GOTCHAS.md).
Scope {
    // Idle handling (dim/lock/screen-off/suspend, lock-before-sleep) — see services/IdleService.qml
    Component.onCompleted: IdleService.start()

    Variants {
        model: Quickshell.screens

        delegate: Bar {
            required property var modelData
            screen: modelData
        }
    }

    Variants {
        model: DisplayService.mainScreen ? [DisplayService.mainScreen] : []

        delegate: Scope {
            id: main
            required property var modelData

            Osd { screen: main.modelData }

            Toasts { screen: main.modelData }

            HomeMenu { screen: main.modelData }

            LanDevices { screen: main.modelData }

            RecorderMenu { screen: main.modelData }

            DisplaysMenu { screen: main.modelData }
        }
    }
}
