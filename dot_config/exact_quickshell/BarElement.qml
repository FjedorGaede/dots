import QtQuick
import QtQuick.Layouts

import './theme'

Rectangle {
    default property alias content: container.children

    property int padding: 8

    id: root
    implicitHeight: container.implicitHeight + padding
    implicitWidth: container.implicitWidth + 2 * padding
    color: Theme.background
    radius: 6

    RowLayout {
        id: container
        anchors.centerIn: parent
    }
}
