import QtQuick
import QtQuick.Layouts

RowLayout {
    id: stats
    spacing: 10

    VpnStatus {}
    Network {}
    Sound {}
    Bluetooth {}
    Power {}
    NotificationBell {}
    PowerMenuItem {}
}
