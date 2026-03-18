import QtQuick
import QtQuick.Layouts

RowLayout {
    id: stats
    spacing: 6

    Network {}
    Sound {}
    Bluetooth {}
    Power {}
    Notification {}
}
