import QtQuick
import QtQuick.Layouts

import qs.config

Rectangle {
    default property alias content: container.children

    property int padding: Theme.bar.pillPadding

    id: root
    implicitHeight: container.implicitHeight + padding
    implicitWidth: container.implicitWidth + 2 * padding
    color: Theme.background
    radius: Theme.radius.sm

    RowLayout {
        id: container
        anchors.centerIn: parent
    }
}
