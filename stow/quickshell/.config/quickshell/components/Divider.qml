import QtQuick
import QtQuick.Layouts

import qs.config

Rectangle {
    property color dividerColor: Theme.divider
    Layout.fillWidth: true
    implicitHeight: 1
    color: dividerColor
}
