import QtQuick
import QtQuick.Layouts

import qs.config

import qs.modules.bar.indicators

// Pill left of the tray for app/background-service indicators (was
// StatusBar.qml). Implicit width 0 while every indicator is hidden — Bar.qml
// collapses the pill then.
RowLayout {
    id: root
    spacing: Theme.bar.iconSpacing

    Recording {}
    Sunshine {}
    // Add more status indicators here as needed
}
