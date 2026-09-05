import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications
import QtQuick
import QtQuick.Layouts

import './theme'

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
        top: 38
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
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 180 }
        }
        remove: Transition {
            NumberAnimation { property: "opacity"; to: 0; duration: 150 }
        }
        displaced: Transition {
            NumberAnimation { property: "y"; duration: 150; easing.type: Easing.OutCubic }
        }

        delegate: Rectangle {
            id: toast

            required property var modelData

            readonly property bool isCritical: modelData.urgency === NotificationUrgency.Critical
            readonly property string iconSource: {
                // Prefer the attached image — chat apps send the sender's
                // avatar/picture here (e.g. Telegram)
                if (modelData.image !== "") return modelData.image;

                const icon = modelData.appIcon;
                if (icon === "") return "";
                if (icon.startsWith("/") || icon.startsWith("file:")) return icon;
                return Quickshell.iconPath(icon, true); // "" when not found
            }
            readonly property int expireAfter: isCritical ? 0
                : (modelData.expireTimeout > 0 ? modelData.expireTimeout : NotificationService.defaultExpire)
            // Many apps send an unnamed "default" action ("open this"); the
            // toast body tap should trigger it instead of just dismissing.
            readonly property var defaultAction:
                (modelData.actions ?? []).find(a => a.identifier === "default") ?? null

            width: ListView.view.width
            implicitHeight: toastRow.implicitHeight + 28
            radius: 8
            color: Theme.background
            border.width: isCritical ? 1.5 : 0
            border.color: Theme.color1

            RowLayout {
                id: toastRow

                anchors {
                    fill: parent
                    margins: 14
                }
                spacing: 12

                IconImage {
                    visible: toast.iconSource !== ""
                    source: toast.iconSource
                    implicitSize: 34
                    Layout.alignment: Qt.AlignTop
                }

                Text {
                    visible: toast.iconSource === ""
                    text: "󰂚"
                    color: toast.isCritical ? Theme.color1 : Theme.dimForeground
                    font { family: Theme.fontFamily; pixelSize: 28 }
                    Layout.alignment: Qt.AlignTop
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Text {
                        text: toast.modelData.summary
                        color: toast.isCritical ? Theme.color1 : Theme.foreground
                        font { family: Theme.fontFamily; pixelSize: 16; bold: true }
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    Text {
                        visible: toast.modelData.body !== ""
                        text: toast.modelData.body
                        color: Theme.fadedForeground
                        font { family: Theme.fontFamily; pixelSize: 15 }
                        wrapMode: Text.WordWrap
                        maximumLineCount: 4
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    Text {
                        text: toast.modelData.appName
                        color: Theme.dimForeground
                        font { family: Theme.fontFamily; pixelSize: 12 }
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    // Action buttons advertised by the app ("Mark as read", …)
                    RowLayout {
                        visible: (toast.modelData.actions ?? []).length > 0
                        spacing: 6
                        Layout.fillWidth: true
                        Layout.topMargin: 4

                        Repeater {
                            // Cap at 3 so a chatty app can't blow up the toast
                            model: (toast.modelData.actions ?? []).slice(0, 3)

                            delegate: Rectangle {
                                id: toastActionButton

                                required property var modelData

                                implicitWidth: toastActionRow.implicitWidth + 20
                                implicitHeight: 30
                                radius: 6
                                color: toastActionHover.hovered
                                    ? Theme.hoverOverlay : Theme.color8

                                RowLayout {
                                    id: toastActionRow
                                    anchors.centerIn: parent
                                    spacing: 4

                                    Text {
                                        text: toastActionButton.modelData.text !== ""
                                            ? toastActionButton.modelData.text
                                            : toastActionButton.modelData.identifier
                                        color: Theme.foreground
                                        font { family: Theme.fontFamily; pixelSize: 13; bold: true }
                                    }
                                }

                                HoverHandler { id: toastActionHover; cursorShape: Qt.PointingHandCursor }
                                TapHandler {
                                    onTapped: {
                                        toastActionButton.modelData.invoke()
                                        NotificationService.dismissToast(toast.modelData)
                                    }
                                }
                            }
                        }
                    }
                }

                CloseButton {
                    Layout.alignment: Qt.AlignTop
                    onClicked: NotificationService.dismissToast(toast.modelData)
                }
            }

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
