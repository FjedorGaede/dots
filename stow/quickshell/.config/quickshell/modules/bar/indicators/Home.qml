import Quickshell
import QtQuick

import qs.components
import qs.services

BarButton {
    id: home

    icon: "󰐥"
    // Thin outline glyph — optically small at the shared 14px
    iconSize: 16
    tooltipText: "Power Menu"
    // opens on the screen of the bar that was clicked (shell.qml)
    onClicked: PanelService.open("home", QsWindow.window?.screen?.name)
}
