import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

import qs.config

// Full-screen dimmed overlay with a centered card (home menu, LAN devices).
// Content goes into the card's ColumnLayout. Every close path (backdrop
// click, focus-grab loss, Escape) emits closeRequested() — the owner decides
// what "close" means (PanelService.close(...)).
PanelWindow {
    id: root

    // -1 → card sized to its content (home menu); > 0 → fixed card width,
    // content stretched to it (LAN devices: 660)
    property int cardWidth: -1
    property int padding: 18
    property alias spacing: body.spacing
    default property alias content: body.data

    signal closeRequested()

    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true

    focusable: true
    color: Theme.backdrop

    HyprlandFocusGrab {
        windows: [ root ]
        active: root.visible
        onCleared: root.closeRequested()
    }

    // Backdrop click-to-close: a MouseArea (not a TapHandler!) because
    // TapHandler fires passively — a click on a button would ALSO hit this
    // handler and close the menu before the confirm state was visible
    MouseArea {
        anchors.fill: parent
        onClicked: root.closeRequested()
    }

    Rectangle {
        id: card
        focus: true
        Keys.onEscapePressed: root.closeRequested()

        width: root.cardWidth > 0 ? root.cardWidth : body.implicitWidth + root.padding * 2
        height: body.implicitHeight + root.padding * 2

        anchors.centerIn: parent
        color: Theme.background
        radius: Theme.radius.xl

        border.color: Theme.foreground
        border.width: 1

        // Absorb clicks on the card so they don't reach the backdrop closer.
        // Buttons on the card must be MouseAreas too (exclusive grab), a
        // passive TapHandler above this gets canceled — docs/GOTCHAS.md
        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        ColumnLayout {
            id: body
            anchors.centerIn: parent
            // content-sized: plain implicit width (no explicit width, as before)
            width: root.cardWidth > 0 ? parent.width - root.padding * 2 : implicitWidth
        }
    }
}
