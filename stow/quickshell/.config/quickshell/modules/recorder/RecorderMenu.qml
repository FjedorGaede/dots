import QtQuick
import QtQuick.Layouts

import qs.components
import qs.config
import qs.services

// Screen recorder start menu: capture mode + audio sources + camera → Record.
// Open state lives in PanelService ("recorder"); Super+R goes through
// `qs ipc call recording toggle` (menu when idle, stop while recording).
ModalOverlay {
    id: menu
    visible: PanelService.isOpen("recorder")

    // Everything is remembered (last recording's setup = default)
    onVisibleChanged: if (visible) {
        RecorderService.refreshCameras();   // plugged in since last time?
        RecorderService.checkInstalled();   // removed since last time?
    }

    onCloseRequested: PanelService.close("recorder")

    padding: 18
    spacing: 14

    PanelHeader {
        Layout.fillWidth: true
        title: "SCREEN RECORDING"
    }

    Divider {}

    // ── Not installed: one-click install (RecorderService.install) ──
    ColumnLayout {
        visible: !RecorderService.installed
        Layout.preferredWidth: 308
        spacing: 12

        StyledText {
            Layout.fillWidth: true
            text: "The screen recorder isn't installed yet."
            font.pixelSize: Theme.fontSize.lg
            wrapMode: Text.WordWrap
        }

        StyledText {
            Layout.fillWidth: true
            text: "gpu-screen-recorder + camera support (qt6-multimedia). "
                + "Installs in a terminal — sudo asks for your password."
            color: Theme.dimForeground
            font.pixelSize: Theme.fontSize.md
            wrapMode: Text.WordWrap
        }

        GhostButton {
            Layout.fillWidth: true
            implicitHeight: 36
            exclusiveGrab: true
            icon: RecorderService.installing ? "" : "\uF019"
            text: RecorderService.installing ? "Installing… (see terminal)" : "Install"
            iconSize: Theme.fontSize.sm
            textSize: Theme.fontSize.lg
            bold: true
            idleColor: Theme.mainAccentSubtle
            hoverColor: Theme.alpha(Theme.mainAccent, 0.3)
            contentColor: Theme.mainAccent
            onClicked: RecorderService.install()
        }
    }

    // ── Mode ──
    RowLayout {
        visible: RecorderService.installed
        spacing: 10

        Repeater {
            model: [
                { mode: "region", icon: "󰆟", label: "Region" },
                { mode: "window", icon: "", label: "Window" },
                { mode: "screen", icon: "", label: "Screen" }
            ]

            delegate: Rectangle {
                id: tile
                required property var modelData
                readonly property bool selected: RecorderService.mode === modelData.mode

                implicitWidth: 96
                implicitHeight: 80
                radius: Theme.radius.md
                color: selected ? Theme.mainAccentSubtle
                     : tileArea.containsMouse ? Theme.hoverOverlay : "transparent"
                border.width: 1
                border.color: selected ? Theme.mainAccent : Theme.alpha(Theme.foreground, 0.15)

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 6

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: tile.modelData.icon
                        color: tile.selected ? Theme.mainAccent : Theme.foreground
                        font.pixelSize: Theme.fontSize.icon
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: tile.modelData.label
                        color: tile.selected ? Theme.mainAccent : Theme.fadedForeground
                        font.pixelSize: Theme.fontSize.md
                    }
                }

                // MouseArea, not TapHandler: sits above the card's click absorber
                MouseArea {
                    id: tileArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: RecorderService.mode = tile.modelData.mode
                    // Double-click = pick and record right away
                    onDoubleClicked: menu.record()
                }
            }
        }
    }

    // ── Audio + camera ──
    // Own column: the overlay's 14px spacing is too loose between the two rows
    ColumnLayout {
        visible: RecorderService.installed
        Layout.fillWidth: true
        spacing: 2

        Repeater {
            model: [
                { key: "desktopAudio", icon: "", label: "Desktop audio" },
                { key: "mic",          icon: "", label: "Microphone" },
                // Webcam bubble (WebcamBubble) — remembered, not reset on open.
                // Click cycles off → each camera → off
                { key: "webcam",       icon: "\uF03D", label: "Camera" }
            ]

            delegate: Rectangle {
                id: row
                required property var modelData
                readonly property bool checked: RecorderService[modelData.key]

                Layout.fillWidth: true
                implicitHeight: 34
                radius: Theme.radius.md
                color: rowArea.containsMouse ? Theme.hoverOverlay : "transparent"

                RowLayout {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 10

                    StyledText {
                        Layout.preferredWidth: 20
                        horizontalAlignment: Text.AlignHCenter
                        text: row.modelData.icon
                        color: row.checked ? Theme.mainAccent : Theme.dimForeground
                        font.pixelSize: Theme.fontSize.xl
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: row.modelData.label
                        font.pixelSize: Theme.fontSize.lg
                    }

                    StyledText {
                        text: !row.checked ? "off"
                            : row.modelData.key === "webcam"
                                ? (RecorderService.cameraLabel(RecorderService.activeCamera) || "on")
                                : "on"
                        color: row.checked ? Theme.mainAccent : Theme.dimForeground
                        font.pixelSize: Theme.fontSize.md
                    }
                }

                MouseArea {
                    id: rowArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (row.modelData.key === "webcam") RecorderService.cycleCamera();
                        else RecorderService[row.modelData.key] = !row.checked;
                    }
                }
            }
        }
    }

    RowLayout {
        visible: RecorderService.installed
        spacing: 8

        GhostButton {
            Layout.fillWidth: true
            implicitHeight: 36
            exclusiveGrab: true
            icon: ""
            text: "Record"
            iconSize: Theme.fontSize.sm
            textSize: Theme.fontSize.lg
            bold: true
            idleColor: Theme.alpha(Theme.red, 0.15)
            hoverColor: Theme.alpha(Theme.red, 0.3)
            contentColor: Theme.red
            onClicked: menu.record()
        }

        // Recordings folder (~/Videos/Recordings)
        GhostButton {
            implicitWidth: 36
            implicitHeight: 36
            exclusiveGrab: true
            rowContent: false
            icon: "\uF07B"
            iconSize: Theme.fontSize.lg
            idleColor: Theme.hoverOverlay
            hoverColor: Theme.alpha(Theme.foreground, 0.15)
            onClicked: {
                RecorderService.openFolder();
                PanelService.close("recorder");
            }
        }
    }

    function record() {
        PanelService.close("recorder");
        RecorderService.start();
    }
}
