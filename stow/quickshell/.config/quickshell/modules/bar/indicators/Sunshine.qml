import QtQuick

import qs.components
import qs.config
import qs.services
import qs.modules.panels

BarButton {
    id: sunshine

    visible: SunshineService.running

    icon: ""
    iconColor: Theme.yellow
    // no tooltip (tooltipText stays "")
    rightClickable: true
    onClicked: sunshinePopup.visible = !sunshinePopup.visible
    onRightClicked: stopConfirm.visible = true

    SunshinePopup {
        id: sunshinePopup
        anchorItem: sunshine
    }

    PopupPanel {
        id: stopConfirm
        anchorItem: sunshine
        minWidth: 160

        StyledText {
            text: "Stop Sunshine?"
            color: Theme.warning
            font.pixelSize: Theme.fontSize.base
        }

        ListItem {
            size: ListItem.Small
            icon: ""
            label: "Cancel"
            onTapped: stopConfirm.visible = false
        }

        ListItem {
            size: ListItem.Small
            icon: ""
            label: "Stop"
            onTapped: {
                SunshineService.stop()
                stopConfirm.visible = false
            }
        }
    }
}
