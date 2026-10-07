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

    // Custom button labels for actions whose app-sent text is unhelpful.
    // First matching rule wins. Fields:
    //   app     – notification appName (exact)
    //   summary – notification title (exact); omit to match any
    //   action  – action identifier the app sends
    //   label   – text to show instead
    // To find an app's identifiers: dbus-monitor --session "interface='org.freedesktop.Notifications',member='Notify'"
    readonly property var labelRules: [
        { app: "Vivaldi", summary: "Download Complete", action: "default", label: "Show in Files" },
    ]

    function labelFor(action) {
        const n = root.notification;
        const rule = root.labelRules.find(r =>
            r.app === n.appName
            && (r.summary === undefined || r.summary === n.summary)
            && r.action === action.identifier);
        if (rule) return rule.label;
        return action.text !== "" ? action.text : action.identifier;
    }

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
            text: root.labelFor(modelData)
            textSize: root.fontSize
            bold: true

            onClicked: {
                modelData.invoke()
                root.invoked(modelData)
            }
        }
    }
}
