import QtQuick
import QtQuick.Layouts

RowLayout {
    id: stats
    spacing: 6

    property string ssid: "..."
    property int rssi: 0
    property int signalStrength: 0

    Network {}
    Sound {}
    Bluetooth {}
    Power {}
}
