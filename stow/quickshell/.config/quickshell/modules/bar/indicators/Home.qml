import QtQuick

import qs.components
import qs.services
import qs.modules.overlays

BarButton {
    id: home

    icon: "󰐥"
    // Thin outline glyph — optically small at the shared 14px
    iconSize: 16
    tooltipText: "Power Menu"
    onClicked: PanelService.open("home")

    HomeMenu {
        id: homeMenu
    }
}
