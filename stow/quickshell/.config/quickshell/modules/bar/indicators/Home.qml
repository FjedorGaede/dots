import QtQuick

import qs.components
import qs.services

BarButton {
    id: home

    icon: "󰐥"
    // Thin outline glyph — optically small at the shared 14px
    iconSize: 16
    tooltipText: "Power Menu"
    // the home menu lives on the main monitor only (shell.qml)
    onClicked: PanelService.open("home")
}
