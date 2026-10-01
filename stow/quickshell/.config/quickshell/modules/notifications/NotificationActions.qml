import QtQuick
import QtQuick.Layouts

import qs.components
import qs.config

// Action buttons advertised by the app ("Mark as read", …) — toast + history.
// Capped at 3 so a chatty app can't blow up the card.
RowLayout {
    id: root

    required property var notification
    property int buttonHeight: 30
    property int fontSize: Theme.fontSize.base
    property int hPadding: 10       // button width = label + 2 × hPadding

    // Emitted after action.invoke() — the caller dismisses the notification
    signal invoked(var action)

    visible: (root.notification.actions ?? []).length > 0
    spacing: 6
    Layout.fillWidth: true
    Layout.topMargin: 4

    Repeater {
        model: (root.notification.actions ?? []).slice(0, 3)

        delegate: GhostButton {
            required property var modelData

            implicitHeight: root.buttonHeight
            hPadding: root.hPadding
            idleColor: Theme.actionButton
            contentColor: Theme.foreground
            text: modelData.text !== "" ? modelData.text : modelData.identifier
            textSize: root.fontSize
            bold: true

            onClicked: {
                modelData.invoke()
                root.invoked(modelData)
            }
        }
    }
}
