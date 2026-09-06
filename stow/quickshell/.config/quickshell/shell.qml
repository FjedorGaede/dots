//@ pragma UseQApplication
import Quickshell
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import './theme'

PanelWindow {
    id: root
    anchors.top: true
    anchors.right: true
    anchors.left: true
    implicitHeight: 30
    color: "transparent"

    property int borderMargin: 4

    Control {
        anchors.fill: parent
        background: null

        BarElement {
            anchors.left: parent.left
            anchors.leftMargin: root.borderMargin
            HyprlandWorkspaces {}
        }

        BarElement {
            id: clockElement
            anchors.centerIn: parent
            Clock {}
        }

        // Media readout, right of the clock (hidden when nothing plays)
        BarElement {
            anchors.left: clockElement.right
            anchors.leftMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            visible: mediaPlayer.activePlayer !== null
            MediaPlayer { id: mediaPlayer }
        }

        RowLayout {
            anchors.right: parent.right
            anchors.rightMargin: root.borderMargin
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            BarElement {
                id: statusBarElement
                // Layout.fillHeight removed: it stretched right-side pills to the tallest
                // sibling, making them flush with the window below (left pills keep
                // natural height + centered, which leaves the bottom gap)

                Layout.preferredWidth: statusBar.implicitWidth > 0 ? -1 : 0
                clip: true
                StatusBar {
                    id: statusBar
                }
            }

            BarElement {
                // Layout.fillHeight removed: it stretched right-side pills to the tallest
                // sibling, making them flush with the window below (left pills keep
                // natural height + centered, which leaves the bottom gap)

                SystemTray {}
            }

            // Coffee cup — only visible while "stay awake" is on (suspend
            // inhibited); click turns it off again. Own pill (same look as
            // BarElement) so the padding is identical on both sides.
            Rectangle {
                id: stayAwakePill
                // Layout.fillHeight removed: it stretched right-side pills to the tallest
                // sibling, making them flush with the window below (left pills keep
                // natural height + centered, which leaves the bottom gap)

                visible: StayAwakeService.enabled
                color: Theme.background
                radius: 6
                // Ink is 1.2em wide (≈15.6px at size 13); pill = ink + 16
                implicitWidth: 32
                implicitHeight: stayIcon.implicitHeight + 16

                // The mug-saucer glyph's ink hangs right of its 0.6em advance
                // cell (ink starts at cell origin), so place the box so the
                // ink — not the cell — sits centered: 8 + 15.6/2 = ~12 from
                // pill left → horizontalCenterOffset ≈ -4
                Text {
                    id: stayIcon
                    anchors.centerIn: parent
                    text: "\uF0F4"
                    color: Theme.mainAccent
                    font { family: Theme.fontFamily; pixelSize: 13 }
                }

                TapHandler { onTapped: StayAwakeService.toggle() }

                HoverHandler {
                    cursorShape: Qt.PointingHandCursor
                    onHoveredChanged: stayTooltip.visible = hovered
                }

                Tooltip {
                    id: stayTooltip
                    anchorItem: stayAwakePill
                    tooltipText: "Stay awake — suspend inhibited (click to disable)"
                }
            }

            BarElement {
                // Layout.fillHeight removed: it stretched right-side pills to the tallest
                // sibling, making them flush with the window below (left pills keep
                // natural height + centered, which leaves the bottom gap)

                SystemStats {}
            }
        }
    }

    OSD {}

    NotificationToasts {}
}
