import Quickshell
import QtQuick

import qs.config
import qs.services

// Toast overlay: notifications appear top-right, below the bar.
// Becomes active as soon as this shell owns the D-Bus notification name
// (i.e. once swaync is stopped).
//
// The window has a FIXED size so the compositor never resizes it (which
// produced a "squeezing" effect) — the empty area is made click-through
// with the window mask. Transitions are pure fades, no scaling.
PanelWindow {
    id: toastWindow

    readonly property int toastWidth: 420
    readonly property int margin: 8

    exclusiveZone: 0
    anchors.top: true
    anchors.right: true
    margins {
        top: Theme.bar.toastTop
        right: toastWindow.margin
    }

    color: "transparent"
    // Always mapped on purpose: unmapping on empty toasts churned the layer
    // surface on every appear/disappear, which made Hyprland refocus and
    // sometimes dismiss the (exclusive-keyboard) bell popup.
    // With no toasts the window is fully transparent and the mask is empty,
    // so it neither renders nor blocks input.

    implicitWidth: toastWindow.toastWidth + toastWindow.margin * 2
    implicitHeight: 700

    // Only the actual toasts receive mouse input, not the empty space
    mask: Region { item: toastsList }

    // Newest on top, capped by the service
    readonly property var displayToasts: NotificationService.toasts.slice().reverse()

    ListView {
        id: toastsList

        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            leftMargin: toastWindow.margin
            rightMargin: toastWindow.margin
        }
        height: contentHeight
        interactive: false
        spacing: 8
        model: ScriptModel {
            values: toastWindow.displayToasts
        }

        add: Transition {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.anim.slow }
        }
        remove: Transition {
            NumberAnimation { property: "opacity"; to: 0; duration: Theme.anim.normal }
        }
        displaced: Transition {
            NumberAnimation { property: "y"; duration: Theme.anim.normal; easing.type: Easing.OutCubic }
        }

        delegate: NotificationCard {
            id: toast

            required property var modelData
            notification: modelData

            readonly property int expireAfter: isCritical ? 0
                : (modelData.expireTimeout > 0 ? modelData.expireTimeout : NotificationService.defaultExpire)
            // Many apps send an unnamed "default" action ("open this"); the
            // toast body tap should trigger it instead of just dismissing.
            readonly property var defaultAction:
                (modelData.actions ?? []).find(a => a.identifier === "default") ?? null

            width: ListView.view.width

            onActionInvoked: NotificationService.dismissToast(toast.modelData)
            onCloseClicked: NotificationService.dismissToast(toast.modelData)

            Timer {
                running: toast.expireAfter > 0
                interval: toast.expireAfter
                onTriggered: NotificationService.hideToast(toast.modelData)
            }

            TapHandler {
                onTapped: {
                    if (toast.defaultAction) toast.defaultAction.invoke();
                    NotificationService.dismissToast(toast.modelData)
                }
            }
        }
    }
}
