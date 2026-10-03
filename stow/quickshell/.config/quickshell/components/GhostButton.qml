import QtQuick
import QtQuick.Layouts

import qs.config

// Transparent → hover-highlighted button: optional glyph + optional label,
// centered. Used by CloseButton, the calendar arrows, the bell's "Clear",
// wifi "Back", the LAN rescan button and notification action buttons.
//
// Input: HoverHandler (cursor + `hovered`) + a passive TapHandler — what all
// of these used before. Set `exclusiveGrab: true` for buttons that sit above a
// MouseArea click absorber (ModalOverlay cards): a passive TapHandler would be
// canceled by the absorber's exclusive grab, so those use a MouseArea
// (docs/GOTCHAS.md "MouseArea vs TapHandler").
Rectangle {
    id: root

    property string icon: ""
    property string text: ""
    property int iconSize: Theme.fontSize.md
    property int textSize: Theme.fontSize.sm
    property bool bold: false
    // implicitWidth = content + 2 × hPadding (fixed-size buttons override implicitWidth)
    property int hPadding: 8

    property color idleColor: "transparent"
    property color hoverColor: Theme.hoverOverlay
    // Glyph/label color: dim, full foreground on hover (override for a fixed color)
    property color contentColor: hovered ? Theme.foreground : Theme.dimForeground

    property bool exclusiveGrab: false

    // true: glyph + label in a RowLayout — content-sized buttons (the layout
    // ceil()s the text width, which is part of their implicitWidth).
    // false: the single glyph/label is centered directly — fixed-size buttons
    // (a RowLayout would shift a fractional-width text by up to 1 px).
    property bool rowContent: true

    readonly property bool hovered: hover.hovered

    signal clicked()

    implicitWidth: content.implicitWidth + hPadding * 2
    implicitHeight: 26
    radius: Theme.radius.sm
    color: hovered ? hoverColor : idleColor

    HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }

    TapHandler {
        enabled: !root.exclusiveGrab
        onTapped: root.clicked()
    }

    Loader {
        anchors.fill: parent
        active: root.exclusiveGrab
        // cursorShape: this MouseArea sits above the HoverHandler and would
        // otherwise reset the pointer to an arrow
        sourceComponent: MouseArea {
            cursorShape: Qt.PointingHandCursor
            onClicked: root.clicked()
        }
    }

    StyledText {
        visible: !root.rowContent
        anchors.centerIn: parent
        text: root.icon !== "" ? root.icon : root.text
        color: root.contentColor
        font { pixelSize: root.icon !== "" ? root.iconSize : root.textSize; bold: root.bold }
    }

    RowLayout {
        id: content
        visible: root.rowContent
        anchors.centerIn: parent
        spacing: 4

        StyledText {
            visible: root.icon !== ""
            text: root.icon
            color: root.contentColor
            font { pixelSize: root.iconSize; bold: root.bold }
        }

        StyledText {
            visible: root.text !== ""
            text: root.text
            color: root.contentColor
            font { pixelSize: root.textSize; bold: root.bold }
        }
    }
}
