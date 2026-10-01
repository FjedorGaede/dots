import QtQuick

import '../../../lib/icons.js' as Icons
import qs.components
import qs.config
import qs.services
import qs.modules.panels

BarButton {
    id: vpn

    visible: VpnService.connected

    icon: Icons.vpn.on
    iconColor: Theme.mainAccent
    tooltipText: "VPN: " + VpnService.interfaceName
    // Only this indicator leaves its tooltip alone while the popup is open
    tooltipBlocked: vpnPopup.visible
    onClicked: vpnPopup.visible = !vpnPopup.visible

    VpnPopup {
        id: vpnPopup
        anchorItem: vpn
    }
}
