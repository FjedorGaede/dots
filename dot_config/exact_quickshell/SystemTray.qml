import Quickshell.Widgets
import Quickshell.Services.SystemTray
import QtQuick
import QtQuick.Layouts

import './theme'

RowLayout {
    id: systemTray

    property var items: SystemTray.items
    property var numberOfSystemTrayItems: items.values.length
    property bool showSystemTrayIcons: true

    spacing: 8

    // HoverHandler {
    //     cursorShape: Qt.PointingHandCursor
    // }
    //
    TapHandler {
        onTapped: parent.showSystemTrayIcons = !parent.showSystemTrayIcons
    }

    function chevronIcon() {
        return showSystemTrayIcons ? "" : ""
    }

    RowLayout {
        visible: parent.showSystemTrayIcons
        Repeater {
            model: systemTray.items

            RowLayout {
                id: systemTrayIcon
                required property var modelData

                function test() {
                    console.log("modelData.id", modelData.id);
                    console.log("modelData.icon", modelData.icon);
                    console.log("modelData.tooltipTitle", modelData.tooltipTitle);

                    return true
                }

                IconImage {
                    source: systemTrayIcon.modelData.icon
                    implicitSize: 18
                    visible: parent.test()

                    HoverHandler {
                        cursorShape: Qt.PointingHandCursor
                    }
                }
            }

        }
    }

    VerticalDivider {}

    RowLayout {
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
