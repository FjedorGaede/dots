import Quickshell
import Quickshell.Networking
import QtQuick
import QtQuick.Layouts

RowLayout {
    Text {
        text: Networking.backend == NetworkBackendType.None
    }
}
