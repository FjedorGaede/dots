import QtQuick
import QtQuick.Layouts

import qs.components
import qs.config
import qs.services

ModalOverlay {
    id: homeMenu
    // Open state (+ `qs ipc call home …`, Super+H) lives in PanelService.
    // Nothing hides this window behind our back (unlike PopupWindow grabs),
    // so a plain binding is enough.
    visible: PanelService.isOpen("home")

    // Two-click confirmation for the destructive actions: first click arms
    // the button (check mark, red), second click executes, 3s later it disarms.
    property string confirming: ""
    onVisibleChanged: if (!visible) confirming = ""

    Timer {
        id: confirmReset
        interval: 3000
        onTriggered: homeMenu.confirming = ""
    }

    function requestConfirm(action) {
        if (homeMenu.confirming === action) {
            homeMenu.confirming = ""
            return true
        }
        homeMenu.confirming = action
        confirmReset.restart()
        return false
    }

    // Backdrop click, focus-grab loss and Escape all end up here
    onCloseRequested: PanelService.close("home")

    // Card = content width (widest row) + 2 × 18 padding
    padding: 18
    spacing: 18

    // ── Session ──
    Rectangle {
        id: stayRow
        Layout.fillWidth: true
        implicitWidth: stayRowLayout.implicitWidth + 24
        implicitHeight: stayRowLayout.implicitHeight + 16
        radius: Theme.radius.md
        color: stayHover.containsMouse ? Theme.hoverOverlay : "transparent"

        RowLayout {
            id: stayRowLayout
            anchors.centerIn: parent
            spacing: 10

            StyledText {
                text: "\uF0F4"
                color: StayAwakeService.enabled ? Theme.mainAccent : Theme.dimForeground
                font.pixelSize: Theme.fontSize.icon
            }

            StyledText {
                text: "Stay awake"
                font.pixelSize: Theme.fontSize.lg
            }

            StyledText {
                text: StayAwakeService.enabled ? "on" : "off"
                color: StayAwakeService.enabled ? Theme.mainAccent : Theme.dimForeground
                font.pixelSize: Theme.fontSize.md
            }
        }

        MouseArea {
            id: stayHover
            anchors.fill: parent
            hoverEnabled: true   // MouseArea has no `hovered` — containsMouse needs this
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                StayAwakeService.toggle();
                PanelService.close("home"); // coffee cup in the bar is the feedback
            }
        }
    }

    // ── Network ──
    Rectangle {
        id: netRow
        Layout.fillWidth: true
        implicitWidth: netRowLayout.implicitWidth + 24
        implicitHeight: netRowLayout.implicitHeight + 16
        radius: Theme.radius.md
        color: netHover.containsMouse ? Theme.hoverOverlay : "transparent"

        RowLayout {
            id: netRowLayout
            anchors.centerIn: parent
            spacing: 10

            StyledText {
                text: "\uF1EB"
                color: Theme.cyan
                font.pixelSize: Theme.fontSize.icon
            }

            StyledText {
                text: "Network devices"
                font.pixelSize: Theme.fontSize.lg
            }

            StyledText {
                text: PanelService.isOpen("network") ? "close" : "scan"
                color: Theme.dimForeground
                font.pixelSize: Theme.fontSize.md
            }
        }

        MouseArea {
            id: netHover
            anchors.fill: parent
            hoverEnabled: true   // MouseArea has no `hovered` — containsMouse needs this
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                PanelService.toggle("network");
                PanelService.close("home");
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
            onClicked: Apps.lock()
        }

        IconButton {
            color: Theme.blue
            icon: ""
            onClicked: Apps.suspend()
        }

        IconButton {
            color: Theme.yellow
            icon: "󰍃"
            onClicked: Apps.logout()
        }

        IconButton {
            color: homeMenu.confirming === "reboot" ? Theme.error : Theme.green
            icon: homeMenu.confirming === "reboot" ? "󰄬" : "󰜉"
            onClicked: {
                if (homeMenu.requestConfirm("reboot"))
                    Apps.reboot()
            }
        }

        IconButton {
            color: homeMenu.confirming === "shutdown" ? Theme.warning : Theme.red
            icon: homeMenu.confirming === "shutdown" ? "󰄬" : "󰐥"
            onClicked: {
                if (homeMenu.requestConfirm("shutdown"))
                    Apps.poweroff()
            }
        }
    }
}
