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

    // ── Actions (shared by every tile/row below) ──

    function toggleStayAwake() {
        StayAwakeService.toggle();
        PanelService.close("home"); // coffee cup in the bar is the feedback
    }

    function toggleKeyboard() {
        KeyboardService.toggle();
        PanelService.close("home"); // keyboard icon in the bar is the feedback
    }

    function openNetwork() {
        PanelService.toggle("network");
        PanelService.close("home");
    }

    function openDisplays() {
        PanelService.close("home");
        PanelService.open("displays");
    }

    // Opens the recorder menu; while recording it stops instead
    function recordAction() {
        PanelService.close("home");
        if (RecorderService.active)
            RecorderService.stop();
        else
            PanelService.open("recorder");
    }

    function power(key) {
        switch (key) {
        case "lock":     Apps.lock(); break
        case "suspend":  Apps.suspend(); break
        case "logout":   Apps.logout(); break
        case "reboot":   if (homeMenu.requestConfirm("reboot")) Apps.reboot(); break
        case "shutdown": if (homeMenu.requestConfirm("shutdown")) Apps.poweroff(); break
        }
    }

    readonly property var powerActions: [
        { key: "lock",     label: "Lock",      icon: "", color: Theme.mainAccent },
        { key: "suspend",  label: "Suspend",   icon: "", color: Theme.blue },
        { key: "logout",   label: "Log out",   icon: "󰍃", color: Theme.yellow },
        { key: "reboot",   label: "Reboot",    icon: "󰜉", color: Theme.green },
        { key: "shutdown", label: "Shut down", icon: "󰐥", color: Theme.red },
    ]

    function powerArmed(key) { return homeMenu.confirming === key }
    function powerIcon(a)    { return powerArmed(a.key) ? "󰄬" : a.icon }
    function powerColor(a) {
        if (!powerArmed(a.key)) return a.color
        return a.key === "reboot" ? Theme.error : Theme.warning
    }
    function powerLabel(a)   { return powerArmed(a.key) ? "Confirm" : a.label }

    // Feature entries: one model, every variant renders it its own way
    readonly property var features: [
        { key: "stay",    label: "Stay awake", short: "Stay awake",      icon: "\uF0F4", toggle: true,
          on: StayAwakeService.enabled, status: StayAwakeService.enabled ? "On" : "Off",
          color: Theme.mainAccent },
        { key: "kb",      label: "Laptop keyboard", short: "Keyboard", icon: "\uF11C", toggle: true,
          on: !KeyboardService.disabled, status: KeyboardService.disabled ? "Off" : "On",
          color: Theme.mainAccent },
        { key: "network", label: "Network devices", short: "Network", icon: "\uF1EB", toggle: false,
          on: false, status: PanelService.isOpen("network") ? "Close" : "Scan",
          color: Theme.cyan },
        { key: "displays", label: "Displays", short: "Displays",       icon: "\uF108", toggle: false,
          on: false, status: "Settings", color: Theme.blue },
        { key: "record",  label: "Screen recording", short: "Recording", icon: "\uF03D", toggle: false,
          on: RecorderService.active, status: RecorderService.active ? "Stop" : "Start",
          color: Theme.red },
    ]

    function activate(key) {
        switch (key) {
        case "stay":     toggleStayAwake(); break
        case "kb":       toggleKeyboard(); break
        case "network":  openNetwork(); break
        case "displays": openDisplays(); break
        case "record":   recordAction(); break
        }
    }

    // B — settings list: grouped rows, icon chips, switches, round power buttons
    cardWidth: 440
    padding: 22
    spacing: 16

    component Row: Rectangle {
        id: r
        property var f
        Layout.fillWidth: true
        implicitHeight: 56
        radius: Theme.radius.md
        color: m.containsMouse ? Theme.hoverOverlay : "transparent"

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 14
            spacing: 14

            Rectangle {
                implicitWidth: 34
                implicitHeight: 34
                radius: Theme.radius.md
                color: Theme.alpha(r.f.color, 0.18)
                StyledText {
                    anchors.centerIn: parent
                    text: r.f.icon
                    color: r.f.color
                    font.pixelSize: Theme.fontSize.xl
                }
            }

            StyledText {
                Layout.fillWidth: true
                text: r.f.label
                font.pixelSize: Theme.fontSize.lg
            }

            // toggles: switch pill; actions: status + chevron
            Rectangle {
                visible: r.f.toggle
                implicitWidth: 36
                implicitHeight: 20
                radius: 10
                color: r.f.on ? Theme.mainAccent : Theme.alpha(Theme.foreground, 0.25)
                Behavior on color { ColorAnimation { duration: Theme.anim.fast } }
                Rectangle {
                    width: 14; height: 14; radius: 7
                    anchors.verticalCenter: parent.verticalCenter
                    x: r.f.on ? parent.width - width - 3 : 3
                    color: Theme.background
                }
            }

            StyledText {
                visible: !r.f.toggle
                text: r.f.status + "  ›"
                color: r.f.on ? r.f.color : Theme.dimForeground
                font.pixelSize: Theme.fontSize.md
            }
        }

        MouseArea {
            id: m
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: homeMenu.activate(r.f.key)
        }
    }

    component Group: Rectangle {
        default property alias rows: col.data
        Layout.fillWidth: true
        implicitHeight: col.implicitHeight + 8
        radius: Theme.radius.lg
        color: Theme.alpha(Theme.foreground, 0.04)
        ColumnLayout {
            id: col
            anchors.fill: parent
            anchors.margins: 4
            spacing: 0
        }
    }

    Group {
        Row { f: homeMenu.features[0] }
        Row { f: homeMenu.features[1] }
    }

    Group {
        Row { f: homeMenu.features[2] }
        Row { f: homeMenu.features[3] }
        Row { f: homeMenu.features[4] }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: 6
        spacing: 0

        Repeater {
            model: homeMenu.powerActions
            Item {
                id: pc
                required property var modelData
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                implicitHeight: pcol.implicitHeight

                ColumnLayout {
                    id: pcol
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 8

                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        implicitWidth: 52
                        implicitHeight: 52
                        radius: 26
                        color: homeMenu.powerColor(pc.modelData)
                        opacity: pm.containsMouse ? 0.85 : 1.0
                        // Centered by ink, not advance width — nerd glyphs
                        // overflow their advance (docs/GOTCHAS.md)
                        InkGlyph {
                            text: homeMenu.powerIcon(pc.modelData)
                            color: Theme.black
                            font.pixelSize: 22
                        }
                        MouseArea {
                            id: pm
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: homeMenu.power(pc.modelData.key)
                        }
                    }
                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: homeMenu.powerLabel(pc.modelData)
                        color: Theme.dimForeground
                        font.pixelSize: Theme.fontSize.sm
                    }
                }
            }
        }
    }
}
