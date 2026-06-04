import QtQuick
import QtQuick.Layouts

import './theme'

RowLayout {
    id: sunshine

    visible: SunshineService.running

    StatusIcon {
        text: ""
        color: Theme.yellow
    }

    TapHandler {
        onTapped: sunshinePopup.visible = !sunshinePopup.visible
    }

    TapHandler {
        acceptedButtons: Qt.RightButton
        onTapped: {
            stopConfirm.visible = true
        }
    }

    HoverHandler {
        cursorShape: Qt.PointingHandCursor
    }

    PopupBase {
        id: sunshinePopup
        anchorItem: sunshine
        minWidth: 180

        Text {
            text: "Sunshine"
            color: Theme.yellow
            font.pixelSize: 14
            font.family: Theme.fontFamily
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

    PopupBase {
        id: stopConfirm
        anchorItem: sunshine
        minWidth: 160

        Text {
            text: "Stop Sunshine?"
            color: Theme.warning
            font.pixelSize: 13
            font.family: Theme.fontFamily
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