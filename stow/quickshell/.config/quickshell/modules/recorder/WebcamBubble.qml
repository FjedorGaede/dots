import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts

import qs.components
import qs.config
import qs.services

// Loom-style webcam bubble for the screen recorder (RecorderService): a round
// live camera picture with a panel below it. Shown from "ready" (preview
// after the target is picked) until the recording stops. Recording is KMS
// capture, so the bubble is simply part of the video (docs/GOTCHAS.md).
//
//   ready      — setup card: camera, microphone, desktop audio, Start recording
//   recording  — pill: time, pause/resume, stop
//   drag the bubble = move it (kept inside the recorded target), scroll = resize
//
// While recording the pill fades out unless hovered (it is in the video
// too); paused keeps it up. Full-screen transparent layer, input only
// on the bubble + controls (mask), never takes keyboard focus.
PanelWindow {
    id: root

    readonly property int gap: 10
    readonly property int inset: 24      // distance kept from the target's edge
    readonly property bool ready: RecorderService.phase === "ready"
    readonly property bool paused: RecorderService.phase === "paused"

    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "quickshell-webcam"
    color: "transparent"

    // Input on the bubble + the visible panel only
    mask: Region {
        x: box.x; y: box.y; width: box.width; height: box.height
        Region {
            x: box.x + root.panel.x; y: box.y + root.panel.y
            width: root.panel.width; height: root.panel.height
        }
    }

    // Recorded target in window coordinates, minus the inset (when it fits)
    readonly property rect area: {
        const t = RecorderService.target, s = root.screen;
        if (!t || !s) return Qt.rect(0, 0, root.width, root.height);
        const x = Math.max(0, t.x - s.x), y = Math.max(0, t.y - s.y);
        const w = Math.min(root.width, t.x - s.x + t.w) - x;
        const h = Math.min(root.height, t.y - s.y + t.h) - y;
        const i = Math.min(root.inset, Math.max(0, (Math.min(w, h) - 200) / 4));
        return Qt.rect(x + i, y + i, w - 2 * i, h - 2 * i);
    }

    // Diameter: the saved size, shrunk to fit small regions. Independent of
    // the panel → the bubble keeps its size when the card gives way to the pill
    readonly property int size: Math.max(60, Math.min(RecorderService.bubbleSize,
        area.width, area.height))

    // What sits next to the bubble: setup card while "ready", else the pill
    readonly property Item panel: ready ? setupCard : controls

    // Panel below the bubble if the (taller) setup card fits on screen there,
    // else above — so the bubble can sit in any corner. Decided with the
    // card's height in both phases: the pill doesn't flip sides on start.
    readonly property bool panelBelow:
        box.y + box.height + gap + setupCard.height <= root.height - 8

    // Panel x in box coordinates: centered on the bubble, kept on screen
    function panelX(w) {
        return Math.max(8 - box.x, Math.min(root.width - 8 - w - box.x, (box.width - w) / 2));
    }

    // Position as a fraction of the free space; local while dragging,
    // saved to the service on release
    property real fx: RecorderService.bubbleFx
    property real fy: RecorderService.bubbleFy

    Item {
        id: box
        // The bubble only; the panels hang outside it (above or below)
        width: root.size
        height: root.size
        x: Math.round(root.area.x + root.fx * Math.max(0, root.area.width - width))
        y: Math.round(root.area.y + root.fy * Math.max(0, root.area.height - height))

        HoverHandler { id: hover }

        // ── Bubble ──
        Item {
            id: bubble
            width: root.size
            height: root.size

            Behavior on width { NumberAnimation { duration: Theme.anim.fast } }
            Behavior on height { NumberAnimation { duration: Theme.anim.fast } }

            // Placeholder under the feed: visible while the camera starts, or
            // instead of it (no camera / qt6-multimedia missing)
            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: Theme.background

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 4
                    visible: !(feed.item && feed.item.ok)

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: "󰗟"
                        color: Theme.dimForeground
                        font.pixelSize: Theme.fontSize.osd
                    }
                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        // Camera off ("No camera" in the setup card): the empty
                        // bubble stays as a handle to move the card around
                        text: !RecorderService.webcam ? "Camera off"
                            : feed.status === Loader.Error ? "qt6-multimedia missing" : "No camera"
                        color: Theme.dimForeground
                        font.pixelSize: Theme.fontSize.sm
                    }
                }
            }

            Loader {
                id: feed
                anchors.fill: parent
                active: RecorderService.webcam   // off → camera released
                source: "WebcamFeed.qml"
                layer.enabled: true
                layer.effect: MultiEffect {
                    maskEnabled: true
                    maskSource: circleMask
                    maskThresholdMin: 0.5
                    maskSpreadAtMin: 1.0
                }
            }

            Item {
                id: circleMask
                anchors.fill: parent
                layer.enabled: true
                layer.smooth: true
                visible: false

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: "black"
                    antialiasing: true
                }
            }

            // Edge against same-colored backgrounds
            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: "transparent"
                border.width: 2
                border.color: Theme.alpha(Theme.foreground, dragArea.pressed ? 0.5 : 0.2)
            }

            MouseArea {
                id: dragArea
                anchors.fill: parent
                cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor

                property point start
                property point origin

                onPressed: mouse => {
                    start = mapToItem(null, mouse.x, mouse.y);
                    origin = Qt.point(box.x, box.y);
                }
                onPositionChanged: mouse => {
                    const p = mapToItem(null, mouse.x, mouse.y);
                    const freeX = root.area.width - box.width, freeY = root.area.height - box.height;
                    if (freeX > 0)
                        root.fx = Math.max(0, Math.min(1, (origin.x + p.x - start.x - root.area.x) / freeX));
                    if (freeY > 0)
                        root.fy = Math.max(0, Math.min(1, (origin.y + p.y - start.y - root.area.y) / freeY));
                }
                onReleased: {
                    RecorderService.bubbleFx = root.fx;
                    RecorderService.bubbleFy = root.fy;
                }
                onWheel: wheel => {
                    const step = wheel.angleDelta.y > 0 ? 20 : -20;
                    RecorderService.bubbleSize = Math.max(140, Math.min(480, root.size + step));
                }
            }
        }

        // ── Setup card ("ready") ──
        Rectangle {
            id: setupCard
            x: root.panelX(width)
            y: root.panelBelow ? box.height + root.gap : -root.gap - height
            visible: root.ready
            width: 260
            height: setupColumn.implicitHeight + 16
            radius: Theme.radius.lg
            color: Theme.background
            border.width: 1
            border.color: Theme.subdued

            ColumnLayout {
                id: setupColumn
                anchors.fill: parent
                anchors.margins: 8
                spacing: 2

                // Heading + cancel (back to idle)
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    StyledText {
                        Layout.leftMargin: 8
                        Layout.fillWidth: true
                        text: "Camera"
                        color: Theme.dimForeground
                        font.pixelSize: Theme.fontSize.sm
                    }

                    CloseButton {
                        size: 24
                        glyphSize: 11
                        exclusiveGrab: true
                        onClicked: RecorderService.stop()
                    }
                }

                Repeater {
                    model: RecorderService.cameras
                    delegate: SetupOption {
                        Layout.fillWidth: true
                        required property string modelData
                        glyph: "\uF03D"
                        label: RecorderService.cameraLabel(modelData)
                        checked: RecorderService.webcam && RecorderService.activeCamera === modelData
                        onClicked: {
                            RecorderService.camera = modelData;
                            RecorderService.webcam = true;
                        }
                    }
                }

                SetupOption {
                    Layout.fillWidth: true
                    glyph: "\u{F0568}"
                    label: "No camera"
                    checked: !RecorderService.webcam
                    onClicked: RecorderService.webcam = false
                }

                StyledText {
                    Layout.leftMargin: 8
                    Layout.topMargin: 8
                    text: "Audio"
                    color: Theme.dimForeground
                    font.pixelSize: Theme.fontSize.sm
                }

                SetupOption {
                    Layout.fillWidth: true
                    glyph: "\uF130"
                    label: "Microphone"
                    checked: RecorderService.mic
                    onClicked: RecorderService.mic = !RecorderService.mic
                }

                SetupOption {
                    Layout.fillWidth: true
                    glyph: "\uF028"
                    label: "Desktop audio"
                    checked: RecorderService.desktopAudio
                    onClicked: RecorderService.desktopAudio = !RecorderService.desktopAudio
                }

                GhostButton {
                    Layout.fillWidth: true
                    Layout.topMargin: 8
                    implicitHeight: 34
                    exclusiveGrab: true
                    icon: "\uF111"
                    text: "Start recording"
                    iconSize: Theme.fontSize.sm
                    textSize: Theme.fontSize.lg
                    bold: true
                    idleColor: Theme.alpha(Theme.red, 0.15)
                    hoverColor: Theme.alpha(Theme.red, 0.3)
                    contentColor: Theme.red
                    onClicked: RecorderService.begin()
                }
            }
        }

        // ── Recording pill ──
        Rectangle {
            id: controls
            x: root.panelX(width)
            y: root.panelBelow ? box.height + root.gap : -root.gap - height
            visible: !root.ready
            width: controlRow.implicitWidth + 12
            height: 32
            radius: height / 2
            color: Theme.background
            border.width: 1
            border.color: Theme.subdued

            opacity: root.paused || hover.hovered || pillHover.hovered || dragArea.pressed ? 1 : 0
            HoverHandler { id: pillHover }
            Behavior on opacity { NumberAnimation { duration: Theme.anim.slow } }

            RowLayout {
                id: controlRow
                anchors.centerIn: parent
                spacing: 2

                // dot/pause glyph + time
                RowLayout {
                    spacing: 6
                    Layout.leftMargin: 8
                    Layout.rightMargin: 4

                    Rectangle {
                        visible: !root.paused
                        width: 8
                        height: 8
                        radius: 4
                        color: Theme.red
                    }
                    StyledText {
                        text: RecorderService.formatElapsed(RecorderService.elapsed)
                        color: root.paused ? Theme.yellow : Theme.foreground
                        font.pixelSize: Theme.fontSize.base
                        font.features: { "tnum": 1 }
                    }
                }

                Control {
                    glyph: root.paused ? "\uF04B" : "\uF04C"
                    onClicked: RecorderService.togglePause()
                }

                Control {
                    glyph: "\uF04D"
                    glyphColor: Theme.red
                    onClicked: RecorderService.stop()
                }

            }
        }
    }

    // Pill-shaped glyph (+ optional label) button
    component Control: Rectangle {
        id: control
        property string glyph: ""
        property string label: ""
        property color glyphColor: Theme.foreground
        signal clicked()

        implicitWidth: label === "" ? 28 : row.implicitWidth + 20
        implicitHeight: 24
        radius: height / 2
        color: area.containsMouse ? Theme.hoverOverlay : "transparent"

        RowLayout {
            id: row
            anchors.centerIn: parent
            spacing: 6

            StyledText {
                text: control.glyph
                color: control.glyphColor
                font.pixelSize: Theme.fontSize.sm
            }
            StyledText {
                visible: control.label !== ""
                text: control.label
                font.pixelSize: Theme.fontSize.base
                font.bold: true
            }
        }

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: control.clicked()
        }
    }
}
