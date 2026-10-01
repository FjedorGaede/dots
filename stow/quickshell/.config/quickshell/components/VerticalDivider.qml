import QtQuick
import QtQuick.Layouts

import qs.config

Rectangle {
    property color dividerColor: Theme.divider
    Layout.fillHeight: true
    implicitWidth: 2
    color: dividerColor
}
