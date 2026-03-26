import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

import './theme'

PanelWindow {
    id: powerMenu
    visible: false
    color: "transparent"

    property int spacing: 18

    width: row.implicitWidth + spacing * 4
    height: row.implicitHeight + spacing * 4

    Rectangle {
        focus: true
        Keys.onEscapePressed: powerMenu.visible = false

        anchors.fill: parent
        color: Theme.background
        radius: 14

        border.color: Theme.foreground
        border.width: 1

        RowLayout {
            id: row
            anchors.centerIn: parent
            spacing: powerMenu.spacing

            IconButton {
                color: Theme.mainAccent
                icon: ""
                tapCallback: () => Quickshell.execDetached(["hyprlock"])
            }

            IconButton {
                color: Theme.blue
                icon: ""
                tapCallback: () => Quickshell.execDetached(["systemctl", "suspend"])
            }

            IconButton {
                color: Theme.yellow
                icon: "󰍃"
                tapCallback: () => Quickshell.execDetached(["hyprctl", "dispatch", "exit"])
            }

            IconButton {
                color: Theme.green
                icon: "󰜉"
                tapCallback: () => Quickshell.execDetached(["systemctl", "reboot"])
            }

            IconButton {
                color: Theme.red
                icon:  "󰐥"
                tapCallback: () => console.warn("##### THIS SHOULD NOT BE CALLED SHUTDOWN")
            }
        }
    }
}
