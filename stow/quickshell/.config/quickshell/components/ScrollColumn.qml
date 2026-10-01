import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Vertically scrolling ColumnLayout, height capped at maxHeight
// (wifi network list, notification history).
Flickable {
    id: root

    property int maxHeight: 400
    // Space reserved left AND right of the content so the scrollbar doesn't
    // sit on top of entries (Flickable has no rightPadding): width − 2×gutter
    property int gutter: 0
    property alias spacing: column.spacing
    default property alias content: column.data

    Layout.fillWidth: true
    implicitHeight: Math.min(column.implicitHeight, root.maxHeight)
    contentHeight: column.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    // Scroll so `item` (anything inside the column) sits `margin` px below
    // the top edge, clamped to the scroll range
    function scrollTo(item, margin) {
        const y = item.mapToItem(column, 0, 0).y - (margin ?? 0);
        contentY = Math.max(0, Math.min(y, contentHeight - height));
    }

    ScrollBar.vertical: ScrollBar {
        policy: parent.contentHeight > parent.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
    }

    ColumnLayout {
        id: column
        width: parent.width - root.gutter * 2
        x: root.gutter
    }
}
