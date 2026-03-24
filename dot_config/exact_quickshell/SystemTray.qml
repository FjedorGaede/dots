import Quickshell
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import QtQuick
import QtQuick.Layouts

import './theme'

RowLayout {
    id: systemTray

    property var items: SystemTray.items
    property var numberOfSystemTrayItems: items.values.length
    property bool showSystemTrayIcons: false

    spacing: 8

    function chevronIcon() {
        return showSystemTrayIcons ? "" : "";
    }

    RowLayout {
        visible: systemTray.showSystemTrayIcons
        Repeater {
            model: systemTray.items

            RowLayout {
                id: systemTrayIcon
                required property var modelData

                IconImage {
                    source: systemTrayIcon.modelData.icon
                    implicitSize: 18

                    HoverHandler {
                        cursorShape: Qt.PointingHandCursor
                        onHoveredChanged: tooltip.visible = hovered && !!systemTrayIcon.modelData.tooltipTitle
                    }

                    TapHandler {
                        onTapped: () => {
                            if (!systemTrayIcon.modelData.onlyMenu) {
                                systemTrayIcon.modelData.activate()
                            }
                        }
                    }

                    TapHandler {
                        acceptedButtons: Qt.RightButton
                        onTapped: (eventPoint) => {
                            if (systemTrayIcon.modelData.hasMenu) {
                                systemTrayIcon.modelData.display(systemTray.QsWindow.window, eventPoint.scenePosition.x, eventPoint.scenePosition.y)
                            }
                        }
                    }
                }

                Tooltip {
                    id: tooltip
                    anchorItem: systemTrayIcon
                    visible: false
                    tooltipText: systemTrayIcon.modelData.tooltipTitle
                }
            }
        }
    }

    VerticalDivider {
        visible: systemTray.showSystemTrayIcons
    }

    RowLayout {
        HoverHandler {
            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            onTapped: systemTray.showSystemTrayIcons = !systemTray.showSystemTrayIcons
        }

        Text {
            text: systemTray.chevronIcon()
            color: Theme.foreground
            font { family: Theme.fontFamily; pixelSize: 10 }
        }

        Text {
            text: systemTray.numberOfSystemTrayItems
            color: Theme.foreground
            font { family: Theme.fontFamily; pixelSize: 14 }
        }
    }
}
