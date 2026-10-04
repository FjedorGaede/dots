import QtQuick
import QtQuick.Layouts

import qs.components
import qs.config
import qs.services

// Displays: resolution, refresh rate and scale per monitor.
// A change is applied live with a Keep/Revert countdown; Keep saves it
// machine-locally (DisplayService → ~/.local/state/hypr/monitors.lua).
// Open state lives in PanelService ("displays"), opened from the home menu.
ModalOverlay {
    id: menu
    visible: PanelService.isOpen("displays")

    // Closing with an unconfirmed change reverts it (like the timeout)
    onVisibleChanged: {
        resOpen = false;
        if (visible) {
            DisplayService.lastError = "";
            DisplayService.refresh();
        } else {
            DisplayService.revert();
        }
    }

    onCloseRequested: PanelService.close("displays")

    cardWidth: 420
    padding: 18
    spacing: 14

    property string selectedName: ""
    readonly property var monitor: DisplayService.monitors.find(m => m.name === selectedName)
                                   ?? DisplayService.monitors[0] ?? null
    readonly property var resolutions: DisplayService.resolutions(monitor)
    readonly property var currentRes: resolutions.find(r => r.width === monitor?.width && r.height === monitor?.height) ?? null
    readonly property bool busy: DisplayService.pending !== null
    readonly property bool isSaved: !!monitor && !!DisplayService.saved[DisplayService.outputOf(monitor)]
    property bool resOpen: false
    onSelectedNameChanged: resOpen = false

    function setMode(width, height, refresh) {
        DisplayService.apply(monitor, width + "x" + height + "@" + Number(refresh).toFixed(2),
                             DisplayService.cleanScale(monitor.scale, width, height));
    }

    function setScale(scale) {
        DisplayService.apply(monitor, DisplayService.modeOf(monitor), scale);
    }

    component SubHeader: StyledText {
        color: Theme.dimForeground
        font { pixelSize: Theme.fontSize.sm; bold: true }
    }

    // Selectable pill; MouseArea (not TapHandler) — sits above the card's
    // click absorber (docs/GOTCHAS.md "MouseArea vs TapHandler")
    component Chip: Rectangle {
        id: chip
        property string label: ""
        property bool selected: false
        property bool locked: false
        signal clicked()

        implicitWidth: chipText.implicitWidth + 20
        implicitHeight: 28
        radius: Theme.radius.sm
        opacity: locked && !selected ? 0.4 : 1
        color: selected ? Theme.mainAccentSubtle
             : chipArea.containsMouse && !locked ? Theme.hoverOverlay : "transparent"
        border.width: 1
        border.color: selected ? Theme.mainAccent : Theme.alpha(Theme.foreground, 0.15)

        StyledText {
            id: chipText
            anchors.centerIn: parent
            text: chip.label
            color: chip.selected ? Theme.mainAccent : Theme.foreground
            font.pixelSize: Theme.fontSize.md
        }

        MouseArea {
            id: chipArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: chip.locked ? Qt.ArrowCursor : Qt.PointingHandCursor
            onClicked: if (!chip.locked && !chip.selected) chip.clicked()
        }
    }

    PanelHeader {
        Layout.fillWidth: true
        title: "DISPLAYS"
    }

    Divider {}

    // ── Monitor picker (only with more than one) ──
    Flow {
        visible: DisplayService.monitors.length > 1
        Layout.fillWidth: true
        spacing: 8

        Repeater {
            model: DisplayService.monitors

            Chip {
                required property var modelData
                label: modelData.name
                selected: modelData.name === menu.monitor?.name
                locked: menu.busy
                onClicked: menu.selectedName = modelData.name
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        StyledText {
            Layout.fillWidth: true
            text: menu.monitor ? (menu.monitor.description || menu.monitor.name) : "No monitors"
            color: Theme.fadedForeground
            font.pixelSize: Theme.fontSize.md
            elide: Text.ElideRight
        }

        StyledText {
            visible: menu.isSaved
            text: "saved"
            color: Theme.mainAccent
            font.pixelSize: Theme.fontSize.sm
        }
    }

    // ── Resolution ──
    SubHeader { text: "RESOLUTION" }

    // Dropdown: current resolution as a button, the list floats over the
    // rows below (z above its later siblings; the card doesn't clip)
    Rectangle {
        id: resButton
        Layout.fillWidth: true
        implicitHeight: 34
        z: 10
        radius: Theme.radius.md
        color: resButtonArea.containsMouse ? Theme.hoverOverlay : "transparent"
        border.width: 1
        border.color: menu.resOpen ? Theme.mainAccent : Theme.alpha(Theme.foreground, 0.15)

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12

            StyledText {
                Layout.fillWidth: true
                text: menu.monitor ? menu.monitor.width + " × " + menu.monitor.height : "—"
                font.pixelSize: Theme.fontSize.base
            }

            StyledText {
                text: menu.resOpen ? "\uF077" : "\uF078"
                color: Theme.dimForeground
                font.pixelSize: Theme.fontSize.sm
            }
        }

        MouseArea {
            id: resButtonArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: menu.resOpen = !menu.resOpen
        }

        Rectangle {
            visible: menu.resOpen
            y: parent.height + 4
            width: parent.width
            height: resList.implicitHeight + 8
            radius: Theme.radius.md
            color: Theme.background
            border.width: 1
            border.color: Theme.alpha(Theme.foreground, 0.15)

            // Swallow clicks between rows so they don't reach the absorber
            MouseArea { anchors.fill: parent }

            ColumnLayout {
                id: resList
                x: 4
                y: 4
                width: parent.width - 8
                spacing: 0

                Repeater {
                    model: menu.resolutions

                    delegate: Rectangle {
                        id: resRow
                        required property var modelData
                        readonly property bool selected: modelData.width === menu.monitor?.width
                                                        && modelData.height === menu.monitor?.height

                        Layout.fillWidth: true
                        implicitHeight: 28
                        radius: Theme.radius.sm
                        color: selected ? Theme.mainAccentSubtle
                             : resArea.containsMouse ? Theme.hoverOverlay : "transparent"

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8

                            StyledText {
                                Layout.fillWidth: true
                                text: resRow.modelData.width + " × " + resRow.modelData.height
                                color: resRow.selected ? Theme.mainAccent : Theme.foreground
                                font { pixelSize: Theme.fontSize.base; bold: resRow.selected }
                            }

                            StyledText {
                                text: Math.round(resRow.modelData.rates[0]) + " Hz"
                                color: Theme.dimForeground
                                font.pixelSize: Theme.fontSize.sm
                            }
                        }

                        MouseArea {
                            id: resArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                menu.resOpen = false;
                                if (!resRow.selected)
                                    menu.setMode(resRow.modelData.width, resRow.modelData.height, resRow.modelData.rates[0]);
                            }
                        }
                    }
                }
            }
        }
    }

    // ── Refresh rate ──
    SubHeader { text: "REFRESH RATE" }

    Flow {
        Layout.fillWidth: true
        spacing: 8

        Repeater {
            model: menu.currentRes?.rates ?? []

            Chip {
                required property var modelData
                label: Math.round(modelData) + " Hz"
                selected: Math.abs(modelData - (menu.monitor?.refreshRate ?? 0)) < 0.5
                onClicked: menu.setMode(menu.monitor.width, menu.monitor.height, modelData)
            }
        }
    }

    // ── Scale ──
    SubHeader { text: "SCALE" }

    Flow {
        Layout.fillWidth: true
        spacing: 8

        Repeater {
            model: menu.monitor ? DisplayService.scales(menu.monitor.width, menu.monitor.height) : []

            Chip {
                required property var modelData
                label: DisplayService.formatScale(modelData) + "×"
                selected: DisplayService.sameScale(modelData, menu.monitor?.scale ?? 0)
                onClicked: menu.setScale(modelData)
            }
        }
    }

    StyledText {
        visible: DisplayService.lastError !== ""
        Layout.fillWidth: true
        text: DisplayService.lastError
        color: Theme.error
        font.pixelSize: Theme.fontSize.sm
        wrapMode: Text.Wrap
    }

    Divider { dividerColor: Theme.overlay }

    // ── Keep / Revert while a change is pending, else Reset ──
    RowLayout {
        visible: menu.busy
        Layout.fillWidth: true
        spacing: 8

        StyledText {
            Layout.fillWidth: true
            text: "Keep these settings? " + DisplayService.countdown + "s"
            font.pixelSize: Theme.fontSize.base
        }

        GhostButton {
            implicitHeight: 32
            hPadding: 14
            exclusiveGrab: true
            text: "Revert"
            textSize: Theme.fontSize.md
            idleColor: Theme.hoverOverlay
            onClicked: DisplayService.revert()
        }

        GhostButton {
            implicitHeight: 32
            hPadding: 14
            exclusiveGrab: true
            text: "Keep"
            textSize: Theme.fontSize.md
            bold: true
            idleColor: Theme.mainAccentSubtle
            hoverColor: Theme.alpha(Theme.mainAccent, 0.3)
            contentColor: Theme.mainAccent
            onClicked: DisplayService.keep()
        }
    }

    RowLayout {
        visible: !menu.busy
        Layout.fillWidth: true

        StyledText {
            Layout.fillWidth: true
            text: menu.isSaved ? "Saved on this machine" : "Using defaults from monitors.lua"
            color: Theme.dimForeground
            font.pixelSize: Theme.fontSize.sm
        }

        GhostButton {
            visible: menu.isSaved
            implicitHeight: 28
            exclusiveGrab: true
            icon: "\uF0E2"
            text: "Reset"
            iconSize: Theme.fontSize.sm
            textSize: Theme.fontSize.md
            onClicked: DisplayService.reset(menu.monitor)
        }
    }
}
