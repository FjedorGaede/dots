import QtQuick
import QtQuick.Layouts

import qs.components
import qs.config
import qs.services

// Insta360 Link webcam: live preview, AI mode, gimbal + presets, image settings. Every
// change goes straight to the camera (no apply button). Open state lives in
// PanelService ("insta360").
ModalOverlay {
    id: menu
    visible: PanelService.isOpen("insta360")

    onVisibleChanged: if (visible) {
        Insta360Service.checkInstalled();
        Insta360Service.refresh();
    }

    onCloseRequested: PanelService.close("insta360")

    padding: 18
    spacing: 12

    readonly property bool ready: Insta360Service.installed && Insta360Service.present
    readonly property int contentWidth: 380

    PanelHeader {
        Layout.fillWidth: true
        title: "WEBCAM"

        StyledText {
            visible: menu.ready
            text: Insta360Service.name
            color: Theme.dimForeground
            font.pixelSize: Theme.fontSize.md
        }
    }

    Divider {}

    // ── Not installed: one-click install ──
    ColumnLayout {
        visible: !Insta360Service.installed
        Layout.preferredWidth: menu.contentWidth
        spacing: 12

        StyledText {
            Layout.fillWidth: true
            text: "The webcam controls aren't installed yet."
            font.pixelSize: Theme.fontSize.lg
            wrapMode: Text.WordWrap
        }

        GhostButton {
            Layout.fillWidth: true
            implicitHeight: 36
            exclusiveGrab: true
            icon: Insta360Service.installing ? "" : "\uF019"
            text: Insta360Service.installing ? "Installing… (see terminal)" : "Install"
            iconSize: Theme.fontSize.sm
            textSize: Theme.fontSize.lg
            bold: true
            idleColor: Theme.mainAccentSubtle
            hoverColor: Theme.alpha(Theme.mainAccent, 0.3)
            contentColor: Theme.mainAccent
            onClicked: Insta360Service.install()
        }
    }

    StyledText {
        visible: Insta360Service.installed && !Insta360Service.present
        Layout.preferredWidth: menu.contentWidth
        text: "No Insta360 camera connected."
        color: Theme.dimForeground
        font.pixelSize: Theme.fontSize.lg
    }

    // Live preview — streaming is also what wakes the gimbal (parked
    // otherwise). Only while the menu is open: closing releases the camera
    Rectangle {
        visible: menu.ready
        Layout.preferredWidth: menu.contentWidth
        Layout.preferredHeight: Math.round(menu.contentWidth * 9 / 16)
        radius: Theme.radius.md
        color: Theme.black
        clip: true

        Loader {
            id: preview
            anchors.fill: parent
            active: menu.visible && menu.ready
            source: "Preview.qml"
        }

        // No picture: package missing, or another app holds the camera
        // (then it streams anyway, so the controls still work)
        StyledText {
            anchors.centerIn: parent
            width: parent.width - 40
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            visible: preview.status === Loader.Error || (preview.item?.failed ?? false)
            text: preview.status === Loader.Error ? "Preview needs qt6-multimedia"
                : "No preview — the camera is in use by another app"
            color: Theme.dimForeground
            font.pixelSize: Theme.fontSize.md
        }
    }

    StyledText {
        visible: menu.ready && Insta360Service.error !== ""
        Layout.preferredWidth: menu.contentWidth
        text: Insta360Service.error
        color: Theme.error
        wrapMode: Text.WordWrap
        font.pixelSize: Theme.fontSize.md
    }

    // ── Mode ──
    SectionHeader { visible: menu.ready; text: "MODE" }

    RowLayout {
        visible: menu.ready
        Layout.preferredWidth: menu.contentWidth
        spacing: 4

        Repeater {
            model: Insta360Service.modes
            delegate: Chip {
                required property var modelData
                Layout.fillWidth: true
                label: modelData.label
                selected: Insta360Service.mode === modelData.key
                onPicked: Insta360Service.setMode(modelData.key)
            }
        }
    }

    // ── Gimbal ──
    SectionHeader { visible: menu.ready; text: "GIMBAL" }

    RowLayout {
        visible: menu.ready
        Layout.preferredWidth: menu.contentWidth
        spacing: 16

        GridLayout {
            columns: 3
            rowSpacing: 4
            columnSpacing: 4

            Item { implicitWidth: 34; implicitHeight: 34 }
            PadButton { icon: "\uF077"; onPressedStep: Insta360Service.nudge(0, 2) }
            Item { implicitWidth: 34; implicitHeight: 34 }
            PadButton { icon: "\uF053"; onPressedStep: Insta360Service.nudge(-2, 0) }
            PadButton { icon: "\uF05B"; repeat: false; onPressedStep: Insta360Service.center() }
            PadButton { icon: "\uF054"; onPressedStep: Insta360Service.nudge(2, 0) }
            Item { implicitWidth: 34; implicitHeight: 34 }
            PadButton { icon: "\uF078"; onPressedStep: Insta360Service.nudge(0, -2) }
            Item { implicitWidth: 34; implicitHeight: 34 }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 10

            ValueRow {
                label: "Zoom"
                labelWidth: 44
                control: "zoom_absolute"
                format: v => (v / 100).toFixed(1) + "×"
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 4

                Repeater {
                    model: 3
                    delegate: Chip {
                        required property int index
                        readonly property bool saved: !!Insta360Service.presets?.[index]
                        Layout.fillWidth: true
                        label: saved ? "Preset " + (index + 1) : "+ Save " + (index + 1)
                        dim: !saved
                        onPicked: saved ? Insta360Service.goPreset(index) : Insta360Service.savePreset(index)
                        onAltPicked: Insta360Service.savePreset(index)
                    }
                }
            }

            StyledText {
                text: "Right-click a preset to overwrite it"
                color: Theme.dimForeground
                font.pixelSize: Theme.fontSize.sm
            }
        }
    }

    // ── Image ──
    SectionHeader { visible: menu.ready; text: "IMAGE" }

    ColumnLayout {
        visible: menu.ready
        Layout.preferredWidth: menu.contentWidth
        spacing: 8

        ValueRow { label: "Brightness"; control: "brightness" }
        ValueRow { label: "Contrast";   control: "contrast" }
        ValueRow { label: "Saturation"; control: "saturation" }
        ValueRow { label: "Sharpness";  control: "sharpness" }

        SwitchRow { label: "Autofocus"; control: "focus_automatic_continuous" }
        ValueRow {
            visible: Insta360Service.value("focus_automatic_continuous") === 0
            label: "Focus"
            control: "focus_absolute"
        }

        SwitchRow { label: "Auto white balance"; control: "white_balance_automatic" }
        ValueRow {
            visible: Insta360Service.value("white_balance_automatic") === 0
            label: "Temperature"
            control: "white_balance_temperature"
            format: v => v + " K"
        }

        SwitchRow {
            label: "Hand gestures"
            on: !Insta360Service.gesturesOff
            onToggled: Insta360Service.setGesturesOff(!Insta360Service.gesturesOff)
        }
        StyledText {
            visible: !Insta360Service.gesturesOff && !Insta360Service.gestures
            Layout.fillWidth: true
            text: "Gestures are still off in the camera — unplug it once to turn them back on."
            color: Theme.error
            wrapMode: Text.WordWrap
            font.pixelSize: Theme.fontSize.sm
        }

        SwitchRow {
            label: "Mic noise cancellation"
            on: Insta360Service.noise
            onToggled: Insta360Service.setNoise(!Insta360Service.noise)
        }

        GhostButton {
            Layout.fillWidth: true
            implicitHeight: 30
            exclusiveGrab: true
            text: "Reset image"
            textSize: Theme.fontSize.md
            idleColor: Theme.hoverOverlay
            hoverColor: Theme.alpha(Theme.foreground, 0.15)
            onClicked: Insta360Service.resetImage()
        }
    }

    // One selectable pill (mode, preset). Right-click → altPicked
    component Chip: Rectangle {
        id: c
        property string label
        property bool selected
        property bool dim
        signal picked()
        signal altPicked()

        implicitHeight: 30
        implicitWidth: chipText.implicitWidth + 16
        radius: Theme.radius.md
        color: c.selected ? Theme.mainAccentSubtle
             : chipArea.containsMouse ? Theme.hoverOverlay : Theme.alpha(Theme.foreground, 0.04)

        StyledText {
            id: chipText
            anchors.centerIn: parent
            text: c.label
            color: c.selected ? Theme.mainAccent : c.dim ? Theme.dimForeground : Theme.foreground
            font.pixelSize: Theme.fontSize.md
        }

        MouseArea {
            id: chipArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            onClicked: mouse => mouse.button === Qt.RightButton ? c.altPicked() : c.picked()
        }
    }

    // Gimbal arrow: one step on press, repeats while held
    component PadButton: Rectangle {
        id: pb
        property string icon
        property bool repeat: true
        signal pressedStep()

        implicitWidth: 34
        implicitHeight: 34
        radius: Theme.radius.md
        color: padArea.pressed ? Theme.mainAccentSubtle
             : padArea.containsMouse ? Theme.hoverOverlay : Theme.alpha(Theme.foreground, 0.06)

        InkGlyph {
            text: pb.icon
            color: padArea.pressed ? Theme.mainAccent : Theme.foreground
            font.pixelSize: Theme.fontSize.lg
        }

        Timer {
            interval: 180
            repeat: true
            running: pb.repeat && padArea.pressed
            onTriggered: pb.pressedStep()
        }

        MouseArea {
            id: padArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onPressed: pb.pressedStep()
        }
    }

    // Label + slider + value for one v4l2 control
    component ValueRow: RowLayout {
        id: vr
        property string label
        property string control
        property var format: v => String(v)
        property int labelWidth: 90
        readonly property var c: Insta360Service.ctrl(vr.control)

        Layout.fillWidth: true
        spacing: 10

        StyledText {
            Layout.preferredWidth: vr.labelWidth
            text: vr.label
            font.pixelSize: Theme.fontSize.md
        }

        Item {
            id: track
            Layout.fillWidth: true
            implicitHeight: 20
            readonly property real frac: vr.c && vr.c.max > vr.c.min
                ? (vr.c.value - vr.c.min) / (vr.c.max - vr.c.min) : 0

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: 5
                radius: 2.5
                color: Theme.overlay

                Rectangle {
                    width: parent.width * track.frac
                    height: parent.height
                    radius: parent.radius
                    color: Theme.mainAccent
                }
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                x: Math.max(0, Math.min(track.width - width, track.width * track.frac - width / 2))
                width: 13
                height: 13
                radius: 6.5
                border.width: 2
                border.color: Theme.background
                color: Theme.foreground
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                function apply(x) {
                    if (!vr.c) return;
                    const f = Math.max(0, Math.min(1, x / width));
                    Insta360Service.set(vr.control, vr.c.min + f * (vr.c.max - vr.c.min));
                }
                onPressed: mouse => apply(mouse.x)
                onPositionChanged: mouse => { if (pressed) apply(mouse.x); }
                onWheel: wheel => {
                    if (!vr.c) return;
                    const step = Math.max(vr.c.step, (vr.c.max - vr.c.min) / 20);
                    Insta360Service.set(vr.control, vr.c.value + (wheel.angleDelta.y > 0 ? step : -step));
                }
            }
        }

        StyledText {
            Layout.preferredWidth: 52
            horizontalAlignment: Text.AlignRight
            text: vr.c ? vr.format(vr.c.value) : "–"
            color: Theme.dimForeground
            font.pixelSize: Theme.fontSize.md
        }
    }

    // Label + switch pill. With `control` set it drives a v4l2 bool control
    component SwitchRow: Item {
        id: sr
        property string label
        property string control: ""
        property bool on: sr.control !== "" && Insta360Service.value(sr.control) !== 0
        signal toggled()

        Layout.fillWidth: true
        implicitHeight: 28

        StyledText {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: sr.label
            font.pixelSize: Theme.fontSize.md
        }

        Rectangle {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: 36
            implicitHeight: 20
            radius: 10
            color: sr.on ? Theme.mainAccent : Theme.alpha(Theme.foreground, 0.25)
            Behavior on color { ColorAnimation { duration: Theme.anim.fast } }
            Rectangle {
                width: 14; height: 14; radius: 7
                anchors.verticalCenter: parent.verticalCenter
                x: sr.on ? parent.width - width - 3 : 3
                color: Theme.background
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (sr.control !== "") Insta360Service.set(sr.control, sr.on ? 0 : 1);
                sr.toggled();
            }
        }
    }
}
