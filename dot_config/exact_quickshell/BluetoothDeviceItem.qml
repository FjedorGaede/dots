import Quickshell.Bluetooth
import QtQuick
import QtQuick.Layouts
import './theme'

Rectangle {
    id: root

    required property var device

    property bool isConnected: root.device.state === BluetoothDeviceState.Connected
    property bool isConnecting: root.device.state === BluetoothDeviceState.Connecting || root.device.state === BluetoothDeviceState.Disconnecting

    function getDeviceIcon() {
        return isConnected ? "󰂱" : "󰂯";
    }

    function getBackgroundColor() {
        if (root.isConnected) {
            return Theme.mainAccentSubtle;
        }

        if (hoverHandler.hovered) {
            return Theme.hoverOverlay;
        }

        return "transparent";
    }

    Layout.fillWidth: true
    implicitHeight: 40
    radius: 8
    color: getBackgroundColor()

    HoverHandler {
        id: hoverHandler
        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        enabled: !root.isConnecting
        onTapped: root.isConnected ? root.device.disconnect() : root.device.connect()
    }

    TapHandler {
        acceptedButtons: Qt.RightButton
        onTapped: console.warn("test")
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        spacing: 10

        Text {
            text: root.getDeviceIcon()
            color: root.isConnected ? Theme.mainAccent : Theme.dimForeground
            font.pixelSize: 14
            font.family: Theme.fontFamily
        }

        Text {
            text: root.device.name
            color: root.isConnected ? Theme.foreground : Theme.fadedForeground
            font.pixelSize: 13
            font.bold: root.isConnected
            font.family: Theme.fontFamily
            Layout.fillWidth: true
            elide: Text.ElideRight
        }

        Text {
            visible: root.isConnecting
            color: Theme.dimForeground
            font.pixelSize: 12
            font.family: Theme.fontFamily

            property var frames: ["●○○", "○●○", "○○●", "○●○"]
            property int frame: 0
            text: frames[frame]

            Timer {
                running: parent.visible
                interval: 400
                repeat: true
                onTriggered: parent.frame = (parent.frame + 1) % parent.frames.length
            }
        }

        Text {
            visible: root.isConnected
            text: "✓"
            color: Theme.mainAccent
            font.pixelSize: 16
            font.family: Theme.fontFamily
        }
    }
}
