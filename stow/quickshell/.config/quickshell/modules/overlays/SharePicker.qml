import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

import qs.components
import qs.config
import qs.services

// Screen share picker for xdg-desktop-portal-hyprland (replaces
// hyprland-share-picker): screens + windows with preview snapshots, region
// via slurp. One click shares. Open state = SharePickerService.pending (set
// by scripts/share-picker.sh over IPC); every close path cancels the share.
ModalOverlay {
    id: menu

    // Hidden while slurp's overlay is up; the request stays pending
    property bool selectingRegion: false

    visible: SharePickerService.pending && !selectingRegion
    cardWidth: 900
    padding: 18
    spacing: 14

    onCloseRequested: if (!selectingRegion) SharePickerService.cancel()

    // One tile size for screens and windows; previews are fitted into the
    // fixed 16:10 box (aspect kept)
    readonly property int tileWidth: 200
    readonly property int windowColumns: 4

    // Hyprland addresses come as hex strings, xdph sends decimal numbers
    function toplevelFor(address) {
        return Hyprland.toplevels.values.find(
            t => Number("0x" + String(t.address).replace(/^0x/, "")) === address) ?? null;
    }

    function pickRegion() {
        menu.selectingRegion = true;
        slurpProc.running = true;
    }

    // Global logical "%o %x %y %w %h" → output-relative, like the stock picker
    Process {
        id: slurpProc
        command: ["sh", "-c", 'slurp -f "%o %x %y %w %h" </dev/null']
        stdout: StdioCollector {
            onStreamFinished: {
                const [output, x, y, w, h] = text.trim().split(" ");
                const screen = Quickshell.screens.find(s => s.name === output);
                if (screen && Number(w) > 0 && Number(h) > 0) {
                    SharePickerService.choose(`region:${output}@${x - screen.x},${y - screen.y},${w},${h}`);
                }
                // slurp cancelled → back to the picker
                menu.selectingRegion = false;
            }
        }
    }

    PanelHeader {
        Layout.fillWidth: true
        title: "SHARE"

        GhostButton {
            exclusiveGrab: true
            icon: "󰆟"
            text: "Region"
            iconSize: Theme.fontSize.md
            textSize: Theme.fontSize.md
            onClicked: menu.pickRegion()
        }

        CloseButton {
            size: 26
            glyphSize: Theme.fontSize.md
            exclusiveGrab: true
            onClicked: SharePickerService.cancel()
        }
    }

    Divider {}

    // Recreated on every open → fresh snapshots (live: false captures once)
    Loader {
        Layout.fillWidth: true
        active: menu.visible

        sourceComponent: ColumnLayout {
            spacing: 14

            SectionHeader { text: "SCREENS" }

            RowLayout {
                spacing: 12

                Repeater {
                    model: Quickshell.screens

                    delegate: PreviewTile {
                        required property var modelData
                        tileWidth: menu.tileWidth
                        source: modelData
                        icon: "󰍹"
                        label: modelData.model ? `${modelData.name} · ${modelData.model}` : modelData.name
                        onPicked: SharePickerService.choose(`screen:${modelData.name}`)
                    }
                }
            }

            SectionHeader {
                visible: SharePickerService.windows.length > 0
                text: "WINDOWS"
            }

            ScrollColumn {
                visible: SharePickerService.windows.length > 0
                maxHeight: 460

                GridLayout {
                    columns: menu.windowColumns
                    columnSpacing: 12
                    rowSpacing: 12

                    Repeater {
                        model: SharePickerService.windows

                        delegate: PreviewTile {
                            required property var modelData
                            readonly property var toplevel: menu.toplevelFor(modelData.address)

                            tileWidth: menu.tileWidth
                            source: toplevel?.wayland ?? null
                            icon: ""
                            label: modelData.title || modelData.cls
                            sublabel: modelData.cls
                            onPicked: SharePickerService.choose(`window:${modelData.handle}`)
                        }
                    }
                }
            }
        }
    }

    // Snapshot + caption; the whole tile is the button
    component PreviewTile: Rectangle {
        id: tile

        property int tileWidth: 200
        property real aspect: 10 / 16
        property var source: null
        property string icon: ""
        property string label: ""
        property string sublabel: ""

        signal picked()

        implicitWidth: tileWidth
        implicitHeight: tileColumn.implicitHeight + 16
        radius: Theme.radius.md
        color: tileArea.containsMouse ? Theme.mainAccentSubtle : "transparent"
        border.width: 1
        border.color: tileArea.containsMouse ? Theme.mainAccent : Theme.alpha(Theme.foreground, 0.15)

        ColumnLayout {
            id: tileColumn
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 8
            spacing: 6

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.round(width * tile.aspect)
                radius: Theme.radius.sm
                color: Theme.alpha(Theme.foreground, 0.06)
                clip: true

                // implicit size = source scaled into the box, aspect kept
                ScreencopyView {
                    id: preview
                    anchors.centerIn: parent
                    width: implicitWidth
                    height: implicitHeight
                    captureSource: tile.source
                    live: false
                    constraintSize: Qt.size(parent.width, parent.height)
                }

                // No snapshot (yet): glyph placeholder
                StyledText {
                    anchors.centerIn: parent
                    visible: !preview.hasContent
                    text: tile.icon
                    color: Theme.dimForeground
                    font.pixelSize: Theme.fontSize.icon
                }
            }

            StyledText {
                Layout.fillWidth: true
                text: tile.label
                elide: Text.ElideRight
                color: tileArea.containsMouse ? Theme.mainAccent : Theme.foreground
                font.pixelSize: Theme.fontSize.md
            }

            // Always laid out (empty text keeps its line) → equal tile heights
            StyledText {
                Layout.fillWidth: true
                text: tile.sublabel !== tile.label ? tile.sublabel : ""
                elide: Text.ElideRight
                color: Theme.dimForeground
                font.pixelSize: Theme.fontSize.sm
            }
        }

        // MouseArea, not TapHandler: sits above the card's click absorber
        MouseArea {
            id: tileArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: tile.picked()
        }
    }
}
