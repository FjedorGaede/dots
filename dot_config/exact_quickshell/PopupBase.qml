import Quickshell
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts

import './theme'

PopupWindow {
    id: root

    required property var anchorItem
    property int margin: 8
    property int minWidth: 0

    default property alias content: layout.data

    anchor.item: anchorItem
    anchor.edges: Edges.Bottom
    anchor.gravity: Edges.Bottom
    anchor.rect.height: anchorItem.height + margin
    anchor.rect.width: anchorItem.width

    color: "transparent"
    visible: false

    implicitWidth: Math.max(layout.implicitWidth + margin * 2, minWidth)
    implicitHeight: layout.implicitHeight + margin * 2

    Rectangle {
        MarginWrapperManager {
            margin: root.margin
        }

        anchors.fill: parent
        color: Theme.background
        radius: 2

        ColumnLayout {
            id: layout
            spacing: 5
        }
    }
}
