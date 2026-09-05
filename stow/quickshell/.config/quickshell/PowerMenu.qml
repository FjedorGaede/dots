import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

import './theme'

PanelWindow {
    id: powerMenu
    visible: false

    // Two-click confirmation for the destructive actions: first click arms
    // the button (check mark, red), second click executes, 3s later it disarms.
    property string confirming: ""
    onVisibleChanged: if (!visible) confirming = ""

    Timer {
        id: confirmReset
        interval: 3000
        onTriggered: powerMenu.confirming = ""
    }

    function requestConfirm(action) {
        if (powerMenu.confirming === action) {
            powerMenu.confirming = ""
            return true
        }
        powerMenu.confirming = action
        confirmReset.restart()
        return false
    }

    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true

    focusable: true
    color: Theme.backdrop

    HyprlandFocusGrab {
        windows: [ powerMenu ]
        active: powerMenu.visible
        onCleared: powerMenu.visible = false
    }

    Item {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: powerMenu.visible = false

        TapHandler {
            onTapped: powerMenu.visible = false
        }
    }

    Rectangle {
        MouseArea {
            anchors.fill: parent
            onClicked: {} // absorb event just
        }

        property int spacing: 18

        width: row.implicitWidth + spacing * 4
        height: row.implicitHeight + spacing * 4

        anchors.centerIn: parent
        color: Theme.background
        radius: 14

        border.color: Theme.foreground
        border.width: 1

        RowLayout {
            id: row
            anchors.centerIn: parent
            spacing: parent.spacing

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
                color: powerMenu.confirming === "reboot" ? Theme.error : Theme.green
                icon: powerMenu.confirming === "reboot" ? "󰄬" : "󰜉"
                tapCallback: () => {
                    if (powerMenu.requestConfirm("reboot"))
                        Quickshell.execDetached(["systemctl", "reboot"])
                }
            }

            IconButton {
                color: powerMenu.confirming === "shutdown" ? Theme.warning : Theme.red
                icon: powerMenu.confirming === "shutdown" ? "󰄬" : "󰐥"
                tapCallback: () => {
                    if (powerMenu.requestConfirm("shutdown"))
                        Quickshell.execDetached(["systemctl", "poweroff"])
                }
            }
        }
    }
}
