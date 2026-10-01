import QtQuick

import '../../lib/icons.js' as Icons
import qs.components
import qs.services

// One ListItem per NetworkManager VPN profile; tap connects/disconnects.
// A Repeater root: the rows become siblings in the caller's ColumnLayout
// (VpnPopup, wifi panel VPN section).
Repeater {
    id: root

    // After the connect/disconnect request (the Vpn indicator closes its popup)
    signal toggled()

    model: VpnService.connections

    ListItem {
        required property var modelData
        size: ListItem.Small
        icon: modelData.active ? Icons.vpn.on : Icons.vpn.off
        label: modelData.name
        status: modelData.active ? ListItem.Active : ListItem.Default
        onTapped: {
            modelData.active
                ? VpnService.disconnect(modelData.name)
                : VpnService.connect(modelData.name)
            root.toggled()
        }
    }
}
