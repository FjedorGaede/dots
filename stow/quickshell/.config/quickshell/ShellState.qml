pragma Singleton
import QtQuick
import Quickshell

// Cross-file UI state that individual components can't see through ids
// (e.g. OSD.qml needs to know whether the AudioPanel is open).
Singleton {
    id: root

    // While the audio panel is open, the OSD is redundant — and mapping/
    // unmapping the OSD layer surface dismisses the panel's popup grab.
    property bool audioPanelOpen: false

    // Network device list overlay (NetworkDevices.qml). Set from the home
    // menu's network button and the network panel's own IPC target.
    property bool networkPanelOpen: false
}
