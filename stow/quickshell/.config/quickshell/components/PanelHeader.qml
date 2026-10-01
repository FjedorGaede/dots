import QtQuick
import QtQuick.Layouts

import qs.config

// Popup title row: accent title, spacer, then whatever the caller declares
// (toggles, buttons) — trailing children are simply appended to the row.
RowLayout {
    property alias title: titleText.text

    Text {
        font.family: Theme.fontFamily
        id: titleText
        color: Theme.mainAccent
        font.pixelSize: Theme.fontSize.lg
    }

    Item { Layout.fillWidth: true }
}
