import Quickshell
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts

import qs.config

PopupWindow {
    id: root

    required property var anchorItem
    property int margin: 8
    property int minWidth: 0
    property bool bordered: false
    property int radius: Theme.radius.xs
    property color borderColor: Theme.mainAccent

    default property alias content: layout.data

    // Optional external open state, e.g. for a PanelService panel:
    //     open: PanelService.isOpen("audio")
    //     onVisibleChanged: PanelService.setOpen("audio", visible)
    // Synced imperatively in both directions instead of
    // `visible: PanelService.isOpen(...)`: the popup hides itself (Escape
    // below, focus-grab loss inside Quickshell), which would otherwise
    // break/desync a declarative binding. (Components don't import services —
    // the owning module wires the two lines above.)
    property bool open: false
    onOpenChanged: visible = open

    // Screen of the bar this popup hangs from (every screen has a bar) —
    // for PanelService.isOpenOn(name, screenName)
    readonly property string screenName: anchor.window?.screen?.name ?? ""

    anchor.item: anchorItem
    anchor.edges: Edges.Bottom
    anchor.gravity: Edges.Bottom
    anchor.rect.height: anchorItem.height + margin
    anchor.rect.width: anchorItem.width

    color: "transparent"
    visible: false

    implicitWidth: Math.max(layout.implicitWidth + margin * 2, minWidth)
    implicitHeight: layout.implicitHeight + margin * 2

    grabFocus: true

    Rectangle {
        MarginWrapperManager {
            margin: root.margin
        }

        anchors.fill: parent
        color: Theme.background
        radius: root.radius
        border.width: root.bordered ? 1.5 : 0
        border.color: root.borderColor

        focus: true
        Keys.onEscapePressed: root.visible = false

        ColumnLayout {
            id: layout
            spacing: 5
        }
    }
}
