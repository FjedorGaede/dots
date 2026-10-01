import QtQuick

import '../../../lib/icons.js' as Icons
import qs.components
import qs.services
import qs.modules.panels

BarButton {
    id: bell

    readonly property int count: NotificationService.trackedCount

    icon: bell.count > 0 ? Icons.bell.unread : Icons.bell.empty
    tooltipText: bell.count > 0 ? bell.count + " notifications" : "No notifications"
    onClicked: PanelService.toggle("notifications")

    NotificationCenter {
        anchorItem: bell
    }
}
