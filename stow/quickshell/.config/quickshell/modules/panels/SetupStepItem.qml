import QtQuick
import QtQuick.Layouts

import '../../lib/icons.js' as Icons
import qs.components
import qs.config

// One dots setup step in the SetupPopup: state glyph, name over status text,
// and explicit buttons (Run / Ignore / Unignore) instead of a hover-only
// action — the whole row also runs the step. Done rows are informative only.
Rectangle {
    id: root

    required property var step   // { name, state, text } from SetupService

    readonly property bool done: step.state === "done"
    readonly property bool ignored: step.state === "ignored"

    signal run()
    signal toggleIgnore()

    Layout.fillWidth: true
    implicitHeight: 52
    radius: Theme.radius.md
    color: hover.hovered && !root.done ? Theme.hoverOverlay : "transparent"

    Behavior on color {
        ColorAnimation { duration: Theme.anim.fast }
    }

    HoverHandler {
        id: hover
        cursorShape: root.done ? undefined : Qt.PointingHandCursor
    }

    TapHandler {
        enabled: !root.done
        onTapped: root.run()
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 8
        spacing: 12

        StyledText {
            text: root.done ? Icons.setup.done : root.ignored ? Icons.setup.ignored : Icons.setup.open
            color: root.done ? Theme.success : root.ignored ? Theme.dimForeground : Theme.warning
            font.pixelSize: Theme.fontSize.xl
            Layout.preferredWidth: 18
            horizontalAlignment: Text.AlignHCenter
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            StyledText {
                text: root.step.name
                color: root.done || root.ignored ? Theme.fadedForeground : Theme.foreground
                font.pixelSize: Theme.fontSize.base
                font.bold: !root.done && !root.ignored
                Layout.fillWidth: true
                elide: Text.ElideRight
            }

            StyledText {
                text: root.step.text + (root.ignored ? " · ignored" : "")
                color: Theme.dimForeground
                font.pixelSize: Theme.fontSize.sm
                Layout.fillWidth: true
                elide: Text.ElideRight
            }
        }

        // exclusiveGrab: else the click also reaches the row's TapHandler and
        // runs the step a second time (docs/GOTCHAS.md "MouseArea vs TapHandler")
        GhostButton {
            visible: !root.done
            exclusiveGrab: true
            icon: root.ignored ? Icons.setup.unignore : Icons.setup.ignore
            text: root.ignored ? "Unignore" : "Ignore"
            onClicked: root.toggleIgnore()
        }

        GhostButton {
            visible: !root.done
            exclusiveGrab: true
            text: "Run"
            bold: true
            idleColor: Theme.alpha(Theme.warning, 0.15)
            contentColor: Theme.warning
            onClicked: root.run()
        }
    }
}
