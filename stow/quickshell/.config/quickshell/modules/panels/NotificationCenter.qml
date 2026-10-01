import QtQuick
import QtQuick.Layouts

import '../../lib/icons.js' as Icons
import qs.components
import qs.config
import qs.services
import qs.modules.notifications

// Notification history + DND toggle — opened from the bell (and
// `qs ipc call notifications …`).
PopupPanel {
    id: center
    // Open state (+ `qs ipc call notifications …`) lives in PanelService
    open: PanelService.isOpen("notifications")
    onVisibleChanged: PanelService.setOpen("notifications", visible)
    minWidth: 360
    property int maxListHeight: 400

    readonly property int count: NotificationService.trackedCount
    readonly property var notifications: NotificationService.history

    // --- Header ---
    PanelHeader {
        title: "NOTIFICATIONS"

        GhostButton {
            id: clearButton

            visible: center.count > 0
            icon: Icons.trash
            text: "Clear"
            onClicked: {
                NotificationService.clearAll()
                PanelService.close("notifications")
            }
        }

        Text {
            font.family: Theme.fontFamily
            text: "DND"
            color: Theme.foreground
            font.pixelSize: Theme.fontSize.md
        }

        Toggle {
            id: dndToggle
            checked: NotificationService.doNotDisturb

            onUserToggled: (value) => {
                NotificationService.setDoNotDisturb(value)
                dndToggle.checked = Qt.binding(() => NotificationService.doNotDisturb)
            }
        }
    }

    // --- History list ---
    ScrollColumn {
        visible: center.count > 0
        maxHeight: center.maxListHeight
        // 12px reserved (6 each side) so the scrollbar doesn't sit on
        // top of entries (rightPadding isn't valid on Flickable)
        gutter: 6
        spacing: 6

        Repeater {
            model: center.notifications

            delegate: NotificationCard {
                id: entry

                required property var modelData
                notification: modelData
                // Flat rows with just a subtle border for separation
                compact: true

                Layout.fillWidth: true

                onActionInvoked: entry.modelData.dismiss()
                onCloseClicked: entry.modelData.dismiss()
            }
        }
    }

    // --- Empty state ---
    StyledText {
        visible: center.count === 0
        text: "No notifications"
        color: Theme.dimForeground
        font { pixelSize: Theme.fontSize.md; italic: true }
    }
}
