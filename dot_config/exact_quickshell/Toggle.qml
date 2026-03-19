import QtQuick
import QtQuick.Controls

import './theme'

Switch {
    id: root

    property int customWidth: 30
    property int customHeight: 16

    signal toggled(bool value)
    onCheckedChanged: root.toggled(checked)

    indicator: Rectangle {
        property var offsetCircle: 4

        anchors.verticalCenter: parent?.verticalCenter
        implicitWidth: root.customWidth
        implicitHeight: root.customHeight
        radius: height / 2
        color: root.checked ? Theme.mainAccent: Theme.foreground

        Rectangle {
            x: root.checked ? parent.width - width - parent.offsetCircle / 2 : parent.offsetCircle / 2
            anchors.verticalCenter: parent.verticalCenter
            height: parent.height - parent.offsetCircle
            width: parent.height - parent.offsetCircle
            radius: width / 2
            color: Theme.background

            Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.InOutQuad } }
        }
    }
}
