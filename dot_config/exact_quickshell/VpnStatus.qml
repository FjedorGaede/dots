import QtQuick
import QtQuick.Layouts

import './theme'

RowLayout {
    id: vpn

    visible: VpnService.connected

    StatusIcon {
        text: "󰌆"
        color: Theme.mainAccent
    }

    TapHandler {
        onTapped: vpnPopup.visible = !vpnPopup.visible
    }

    HoverHandler {
        cursorShape: Qt.PointingHandCursor
        onHoveredChanged: {
            if (!vpnPopup.visible)
                tooltip.visible = hovered
        }
    }

    Tooltip {
        id: tooltip
        anchorItem: vpn
        tooltipText: "VPN: " + VpnService.interfaceName
    }

    PopupBase {
        id: vpnPopup
        anchorItem: vpn
        minWidth: 200

        Text {
            text: "VPN"
            color: Theme.mainAccent
            font.pixelSize: 14
            font.family: Theme.fontFamily
        }

        Repeater {
            model: VpnService.connections
            ListItem {
                required property var modelData
                size: ListItem.Small
                icon: modelData.active ? "󰌆" : "󰌊"
                label: modelData.name
                status: modelData.active ? ListItem.Active : ListItem.Default
                onTapped: {
                    modelData.active
                        ? VpnService.disconnect(modelData.name)
                        : VpnService.connect(modelData.name)
                    vpnPopup.visible = false
                }
            }
        }
    }
}
