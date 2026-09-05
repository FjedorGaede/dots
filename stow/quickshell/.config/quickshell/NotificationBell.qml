import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import './theme'

RowLayout {
    id: bell

    readonly property int count: NotificationService.trackedCount

    StatusIcon {
        text: bell.count > 0 ? "󱅫" : "󰂚"
    }

    TapHandler {
        onTapped: center.visible = !center.visible
    }

    HoverHandler {
        cursorShape: Qt.PointingHandCursor
        onHoveredChanged: tooltip.visible = hovered
    }

    Tooltip {
        id: tooltip
        anchorItem: bell
        tooltipText: bell.count > 0 ? bell.count + " notifications" : "No notifications"
    }

    PopupBase {
        id: center
        anchorItem: bell
        minWidth: 360
        property int headerSize: 14
        property int maxListHeight: 400

        readonly property var notifications: NotificationService.history

        // --- Header ---
        RowLayout {
            Text {
                text: "NOTIFICATIONS"
                color: Theme.mainAccent
                font.pixelSize: center.headerSize
            }

            Item { Layout.fillWidth: true }

            Rectangle {
                id: clearButton

                visible: bell.count > 0
                implicitWidth: clearRow.implicitWidth + 16
                implicitHeight: 26
                radius: 6
                color: clearHover.hovered ? Theme.hoverOverlay : "transparent"

                HoverHandler { id: clearHover; cursorShape: Qt.PointingHandCursor }
                TapHandler {
                    onTapped: {
                        NotificationService.clearAll()
                        center.visible = false
                    }
                }

                RowLayout {
                    id: clearRow
                    anchors.centerIn: parent
                    spacing: 4

                    Text {
                        text: "󰆴"
                        color: clearHover.hovered ? Theme.foreground : Theme.dimForeground
                        font { family: Theme.fontFamily; pixelSize: 12 }
                    }

                    Text {
                        text: "Clear"
                        color: clearHover.hovered ? Theme.foreground : Theme.dimForeground
                        font { family: Theme.fontFamily; pixelSize: 11 }
                    }
                }
            }

            Text {
                text: "DND"
                color: Theme.foreground
                font.pixelSize: 12
            }

            Toggle {
                id: dndToggle
                checked: NotificationService.doNotDisturb

                onUserToggled: (value) => {
                    NotificationService.doNotDisturb = value
                    dndToggle.checked = Qt.binding(() => NotificationService.doNotDisturb)
                }
            }
        }

        // --- History list ---
        Flickable {
            visible: bell.count > 0
            Layout.fillWidth: true
            implicitHeight: Math.min(listContent.implicitHeight, center.maxListHeight)
            contentHeight: listContent.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ScrollBar.vertical: ScrollBar {
                policy: parent.contentHeight > parent.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
            }

            ColumnLayout {
                id: listContent
                // 12px reserved on the right so the scrollbar doesn't sit
                // on top of entries (rightPadding isn't valid on Flickable)
                width: parent.width - 12
                x: 6
                spacing: 6

                Repeater {
                    model: center.notifications

                    delegate: Rectangle {
                        id: entry

                        required property var modelData

                        readonly property bool isCritical: modelData.urgency === NotificationUrgency.Critical

                        readonly property string iconSource: {
                            // Prefer the attached image (e.g. chat avatars)
                            if (modelData.image !== "") return modelData.image;

                            const icon = modelData.appIcon;
                            if (icon === "") return "";
                            if (icon.startsWith("/") || icon.startsWith("file:")) return icon;
                            return Quickshell.iconPath(icon, true); // "" when not found
                        }

                        Layout.fillWidth: true
                        implicitHeight: entryRow.implicitHeight + 16
                        radius: 8
                        // Flat rows with just a subtle border for separation
                        color: entryHover.hovered ? Theme.hoverOverlay : "transparent"
                        border.width: isCritical ? 1.5 : 1
                        border.color: isCritical ? Theme.color1 : Theme.color0

                        RowLayout {
                            id: entryRow

                            anchors {
                                fill: parent
                                leftMargin: 14
                                rightMargin: 10
                                topMargin: 8
                                bottomMargin: 8
                            }
                            spacing: 10

                            IconImage {
                                visible: entry.iconSource !== ""
                                source: entry.iconSource
                                implicitSize: 20
                                Layout.alignment: Qt.AlignTop
                            }

                            Text {
                                visible: entry.iconSource === ""
                                text: "󰂚"
                                color: entry.isCritical ? Theme.color1 : Theme.dimForeground
                                font { family: Theme.fontFamily; pixelSize: 16 }
                                Layout.alignment: Qt.AlignTop
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                Text {
                                    text: entry.modelData.summary
                                    color: entry.isCritical ? Theme.color1 : Theme.foreground
                                    font { family: Theme.fontFamily; pixelSize: 13; bold: true }
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                Text {
                                    visible: entry.modelData.body !== ""
                                    text: entry.modelData.body
                                    color: Theme.fadedForeground
                                    font { family: Theme.fontFamily; pixelSize: 12 }
                                    wrapMode: Text.WordWrap
                                    maximumLineCount: 3
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                Text {
                                    text: entry.modelData.appName
                                    color: Theme.dimForeground
                                    font { family: Theme.fontFamily; pixelSize: 10 }
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                // Action buttons advertised by the app
                                RowLayout {
                                    visible: (entry.modelData.actions ?? []).length > 0
                                    spacing: 6
                                    Layout.fillWidth: true
                                    Layout.topMargin: 4

                                    Repeater {
                                        model: (entry.modelData.actions ?? []).slice(0, 3)

                                        delegate: Rectangle {
                                            id: bellActionButton

                                            required property var modelData

                                            implicitWidth: bellActionRow.implicitWidth + 16
                                            implicitHeight: 24
                                            radius: 6
                                            color: bellActionHover.hovered
                                                ? Theme.hoverOverlay : Theme.color8

                                            RowLayout {
                                                id: bellActionRow
                                                anchors.centerIn: parent
                                                spacing: 4

                                                Text {
                                                    text: bellActionButton.modelData.text !== ""
                                                        ? bellActionButton.modelData.text
                                                        : bellActionButton.modelData.identifier
                                                    color: Theme.foreground
                                                    font { family: Theme.fontFamily; pixelSize: 11; bold: true }
                                                }
                                            }

                                            HoverHandler { id: bellActionHover; cursorShape: Qt.PointingHandCursor }
                                            TapHandler {
                                                onTapped: {
                                                    bellActionButton.modelData.invoke()
                                                    entry.modelData.dismiss()
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            CloseButton {
                                Layout.alignment: Qt.AlignTop
                                onClicked: entry.modelData.dismiss()
                            }
                        }

                        HoverHandler { id: entryHover }
                    }
                }
            }
        }

        // --- Empty state ---
        Text {
            visible: bell.count === 0
            text: "No notifications"
            color: Theme.dimForeground
            font { family: Theme.fontFamily; pixelSize: 12; italic: true }
        }
    }

    // Let keybinds open/close this panel, e.g.:
    //   qs ipc call notifications toggle
    IpcHandler {
        target: "notifications"

        function toggle(): void {
            center.visible = !center.visible;
        }

        function open(): void {
            center.visible = true;
        }

        function close(): void {
            center.visible = false;
        }
    }
}
