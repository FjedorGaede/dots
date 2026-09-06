import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
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

    // Backdrop click-to-close: a MouseArea (not a TapHandler!) because
    // TapHandler fires passively — a click on a button would ALSO hit this
    // handler and close the menu before the confirm state was visible
    MouseArea {
        anchors.fill: parent
        onClicked: powerMenu.visible = false
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

    // Let keybinds open/close the home menu, e.g.:
    //   qs ipc call home toggle   (Super+H)
    IpcHandler {
        target: "home"

        function toggle(): void {
            powerMenu.visible = !powerMenu.visible;
        }

        function open(): void {
            powerMenu.visible = true;
        }

        function close(): void {
            powerMenu.visible = false;
        }
    }

    Rectangle {
        id: card
        focus: true
        Keys.onEscapePressed: powerMenu.visible = false

        // Absorb clicks on the card so they don't reach the backdrop closer
        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        property int spacing: 18
        property int padding: 18

        width: Math.max(stayRow.implicitWidth, row.implicitWidth) + card.padding * 2
        height: column.implicitHeight + card.padding * 2

        anchors.centerIn: parent
        color: Theme.background
        radius: 14

        border.color: Theme.foreground
        border.width: 1

        ColumnLayout {
            id: column
            anchors.centerIn: parent
            spacing: parent.spacing

            // ── Session ──
            Rectangle {
                id: stayRow
                Layout.fillWidth: true
                implicitWidth: stayRowLayout.implicitWidth + 24
                implicitHeight: stayRowLayout.implicitHeight + 16
                radius: 8
                color: stayHover.hovered ? Theme.hoverOverlay : "transparent"

                RowLayout {
                    id: stayRowLayout
                    anchors.centerIn: parent
                    spacing: 10

                    Text {
                        text: "\uF0F4"
                        color: StayAwakeService.enabled ? Theme.mainAccent : Theme.dimForeground
                        font { family: Theme.fontFamily; pixelSize: 20 }
                    }

                    Text {
                        text: "Stay awake"
                        color: Theme.foreground
                        font { family: Theme.fontFamily; pixelSize: 14 }
                    }

                    Text {
                        text: StayAwakeService.enabled ? "on" : "off"
                        color: StayAwakeService.enabled ? Theme.mainAccent : Theme.dimForeground
                        font { family: Theme.fontFamily; pixelSize: 12 }
                    }
                }

                MouseArea {
                    id: stayHover
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        StayAwakeService.toggle();
                        powerMenu.visible = false; // coffee cup in the bar is the feedback
                    }
                }
            }

            Divider { dividerColor: Theme.overlay }

            // ── Power ──
            RowLayout {
                id: row
                Layout.alignment: Qt.AlignHCenter
                spacing: 12

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
}
