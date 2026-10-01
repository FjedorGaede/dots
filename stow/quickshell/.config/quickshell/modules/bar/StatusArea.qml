import QtQuick
import QtQuick.Layouts

import qs.config

import qs.modules.bar.indicators

// Right-most pill: the system status icons (was SystemStats.qml — it never
// showed stats).
RowLayout {
    id: stats
    spacing: Theme.bar.iconSpacing

    Vpn {}
    Network {}
    Sound {}
    Bluetooth {}
    Battery {}
    Bell {}
    Home {}
}
