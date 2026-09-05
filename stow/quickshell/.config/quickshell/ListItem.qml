import QtQuick
import QtQuick.Layouts

import './theme'

Rectangle {
    id: root

    enum Size   { Small, Normal, Large }
    enum Status { Default, Active, Loading }

    property int size:   ListItem.Normal
    property int status: ListItem.Default
    property string icon: ""
    property string label: ""
    property string actionIcon: ""

    signal tapped()
    signal rightTapped()
    signal actionTapped()

    readonly property var _sizeMetrics: ({
        [ListItem.Small]:  { height: 32, iconSize: 12, labelSize: 11, checkSize: 13, padding:  8, spacing:  8 },
        [ListItem.Normal]: { height: 40, iconSize: 14, labelSize: 13, checkSize: 16, padding: 10, spacing: 10 },
        [ListItem.Large]:  { height: 52, iconSize: 17, labelSize: 15, checkSize: 18, padding: 12, spacing: 12 },
    })

    readonly property var _m: _sizeMetrics[size]

    Layout.fillWidth: true
    implicitHeight: _m.height
    radius: 8

    color: {
        if (status === ListItem.Active) return Theme.mainAccentSubtle
        if (hoverHandler.hovered)       return Theme.hoverOverlay
        return "transparent"
    }

    Behavior on color {
        ColorAnimation { duration: 100 }
    }

    HoverHandler {
        id: hoverHandler
        cursorShape: Qt.PointingHandCursor
        onHoveredChanged: actionButton.visible = hovered && root.actionIcon != ""
    }

    TapHandler {
        enabled: root.status !== ListItem.Loading
        onTapped: root.tapped()
    }

    TapHandler {
        acceptedButtons: Qt.RightButton
        onTapped: root.rightTapped()
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: root._m.padding
        anchors.rightMargin: root._m.padding
        spacing: root._m.spacing

        Text {
            visible: root.icon !== ""
            text: root.icon
            color: root.status === ListItem.Active ? Theme.mainAccent : Theme.dimForeground
            font.pixelSize: root._m.iconSize
            font.family: Theme.fontFamily
        }

        Text {
            text: root.label
            color: Theme.foreground
            font.pixelSize: root._m.labelSize
            font.bold: root.status === ListItem.Active
            font.family: Theme.fontFamily
            Layout.fillWidth: true
            elide: Text.ElideRight
        }

        Text {
            visible: root.status === ListItem.Loading
            color: Theme.dimForeground
            font.pixelSize: root._m.labelSize
            font.family: Theme.fontFamily

            property var frames: ["●○○", "○●○", "○○●", "○●○"]
            property int frame: 0
            text: frames[frame]

            Timer {
                running: parent.visible
                interval: 400
                repeat: true
                onTriggered: parent.frame = (parent.frame + 1) % parent.frames.length
            }
        }

        Text {
            visible: root.status === ListItem.Active
            text: "✓"
            color: Theme.mainAccent
            font.pixelSize: root._m.checkSize
            font.family: Theme.fontFamily
        }

        Rectangle {
            id: actionButton
            visible: false
            implicitWidth: root._m.height - 8
            implicitHeight: root._m.height - 8
            radius: 6
            color: actionButtonHover.hovered ? Theme.hoverOverlay : "transparent"

            HoverHandler {
                id: actionButtonHover
                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                onTapped: {
                    // TapHandler here is above the item's TapHandler, so this tap
                    // won't reach it — no manual propagation guard needed.
                    root.actionTapped()
                }
            }

            Text {
                anchors.centerIn: parent
                text: root.actionIcon
                color: Theme.dimForeground
                font.pixelSize: root._m.iconSize
                font.family: Theme.fontFamily
            }
        }
    }
}
