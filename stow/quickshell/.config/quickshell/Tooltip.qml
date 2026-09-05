import QtQuick
import Quickshell
import Quickshell.Hyprland

import './theme'

PopupWindow {
    id: popup

    required property var anchorItem
    required property string tooltipText

    property int margin: 4

    anchor.item: anchorItem
    anchor.edges: Edges.Bottom
    anchor.gravity: Edges.Bottom
    anchor.rect.height: anchorItem.height + margin * 2
    anchor.rect.width: anchorItem.width

    visible: false

    implicitHeight: content.implicitHeight + margin * 2
    implicitWidth: content.implicitWidth + margin * 2

    color: Theme.background

    HyprlandWindow.opacity: 0.85

    Text {
        id: content
        anchors.centerIn: parent
        text: popup.tooltipText
        color: Theme.foreground
    }
}
