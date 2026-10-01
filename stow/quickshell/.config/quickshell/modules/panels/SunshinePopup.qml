import QtQuick

import qs.components
import qs.config
import qs.services

// Sunshine status + stop — opened from the Sunshine indicator (left click;
// the right-click stop confirmation stays inline in indicators/Sunshine.qml)
PopupPanel {
    id: sunshinePopup
    minWidth: 180

    StyledText {
        text: "Sunshine"
        color: Theme.yellow
        font.pixelSize: Theme.fontSize.lg
    }

    ListItem {
        size: ListItem.Small
        icon: ""
        label: "Sunshine is running"
        status: ListItem.Active
    }

    ListItem {
        size: ListItem.Small
        icon: ""
        label: "Stop Sunshine"
        actionIcon: ""
        onTapped: {
            SunshineService.stop()
            sunshinePopup.visible = false
        }
    }
}
