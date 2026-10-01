import Quickshell.Widgets
import Quickshell.Services.Notifications
import QtQuick
import QtQuick.Layouts

import '../../lib/icons.js' as Icons
import '../../lib/notif.js' as Notif
import qs.components
import qs.config

// One notification: icon + summary/body/app + action buttons + ✕.
// Toast (Toasts.qml) and history entry (NotificationCenter, compact)
// differ only in the metrics below — exactly the values each used before.
// Tap/expire/dismiss behaviour stays with the owner (signals).
Rectangle {
    id: root

    required property var notification
    property bool compact: false

    signal closeClicked()
    signal actionInvoked(var action)

    readonly property bool isCritical: notification.urgency === NotificationUrgency.Critical
    readonly property string iconSource: Notif.iconSource(notification)

    readonly property var m: compact
        ? ({ // history entry: flat row with a subtle border, hover highlight
             marginLeft: 14, marginRight: 10, marginTop: 8, marginBottom: 8, spacing: 10,
             icon: 20, glyph: Theme.fontSize.xl, textSpacing: 2,
             summary: Theme.fontSize.base, body: Theme.fontSize.md, bodyLines: 3, app: Theme.fontSize.xs,
             actionHeight: 24, actionFont: Theme.fontSize.sm, actionPadding: 8,
             borderWidth: 1 })
        : ({ // toast: filled card, border only when critical
             marginLeft: 14, marginRight: 14, marginTop: 14, marginBottom: 14, spacing: 12,
             icon: 34, glyph: 28, textSpacing: 4,
             summary: Theme.fontSize.xl, body: 15, bodyLines: 4, app: Theme.fontSize.md,
             actionHeight: 30, actionFont: Theme.fontSize.base, actionPadding: 10,
             borderWidth: 0 })

    implicitHeight: row.implicitHeight + m.marginTop + m.marginBottom
    radius: Theme.radius.md
    color: compact ? (hover.hovered ? Theme.hoverOverlay : "transparent") : Theme.background
    border.width: isCritical ? 1.5 : m.borderWidth
    border.color: isCritical ? Theme.criticalBorder : Theme.cardBorder

    RowLayout {
        id: row

        anchors {
            fill: parent
            leftMargin: root.m.marginLeft
            rightMargin: root.m.marginRight
            topMargin: root.m.marginTop
            bottomMargin: root.m.marginBottom
        }
        spacing: root.m.spacing

        IconImage {
            visible: root.iconSource !== ""
            source: root.iconSource
            implicitSize: root.m.icon
            Layout.alignment: Qt.AlignTop
        }

        StyledText {
            visible: root.iconSource === ""
            text: Icons.bell.empty
            color: root.isCritical ? Theme.color1 : Theme.dimForeground
            font.pixelSize: root.m.glyph
            Layout.alignment: Qt.AlignTop
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: root.m.textSpacing

            StyledText {
                text: root.notification.summary
                color: root.isCritical ? Theme.color1 : Theme.foreground
                font { pixelSize: root.m.summary; bold: true }
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            StyledText {
                visible: root.notification.body !== ""
                text: root.notification.body
                color: Theme.fadedForeground
                font.pixelSize: root.m.body
                wrapMode: Text.WordWrap
                maximumLineCount: root.m.bodyLines
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            StyledText {
                text: root.notification.appName
                color: Theme.dimForeground
                font.pixelSize: root.m.app
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            NotificationActions {
                notification: root.notification
                buttonHeight: root.m.actionHeight
                fontSize: root.m.actionFont
                hPadding: root.m.actionPadding
                onInvoked: action => root.actionInvoked(action)
            }
        }

        CloseButton {
            Layout.alignment: Qt.AlignTop
            onClicked: root.closeClicked()
        }
    }

    // History hover highlight (no cursor change). Disabled for toasts, which
    // never had one.
    HoverHandler {
        id: hover
        enabled: root.compact
    }
}
