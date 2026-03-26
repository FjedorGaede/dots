import QtQuick
import QtQuick.Layouts

RowLayout {
    id: powerMenuItem

    StatusIcon {
        size: 16
        text: "󰐥"
    }

    TapHandler {
        onTapped: powerMenu.visible = true
    }

    HoverHandler {
        cursorShape: Qt.PointingHandCursor
        onHoveredChanged: tooltip.visible = hovered
    }

    Tooltip {
        id: tooltip
        anchorItem: powerMenuItem
        tooltipText: "Power Menu"
    }

    PowerMenu {
        id: powerMenu
    }
}
