import QtQuick

import qs.components
import qs.config

// VPN profile list — opened from the Vpn indicator
PopupPanel {
    id: vpnPopup
    minWidth: 200

    StyledText {
        text: "VPN"
        color: Theme.mainAccent
        font.pixelSize: Theme.fontSize.lg
    }

    VpnList {
        onToggled: vpnPopup.visible = false
    }
}
