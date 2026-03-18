import QtQuick
import QtQuick.Layouts

RowLayout {
    id: stats
    spacing: 10

    Network {}
    Sound {}
    Bluetooth {}
    Power {}
    Notification {}
}
