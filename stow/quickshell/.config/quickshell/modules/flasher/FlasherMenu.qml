import QtQuick
import QtQuick.Layouts

import qs.components
import qs.config
import qs.services

// USB flasher: pick an image + a USB stick → Flash (click twice to confirm)
// → progress → done. Open state lives in PanelService ("flasher").
ModalOverlay {
    id: menu
    visible: PanelService.isOpen("flasher")

    // Armed = the Flash button asks "Erase …?" — second click writes
    property bool armed: false

    onVisibleChanged: if (visible) {
        menu.armed = false;
        FlasherService.checkInstalled();
        FlasherService.refresh();
    }

    // Closing while flashing is fine: the write keeps running, a toast says when it's done
    onCloseRequested: PanelService.close("flasher")

    padding: 18
    spacing: 14

    readonly property bool picking: FlasherService.installed
        && (FlasherService.phase === "idle")

    PanelHeader {
        Layout.fillWidth: true
        title: "FLASH USB STICK"
    }

    Divider {}

    // ── Not installed: one-click install ──
    ColumnLayout {
        visible: !FlasherService.installed
        Layout.preferredWidth: 360
        spacing: 12

        StyledText {
            Layout.fillWidth: true
            text: "The USB flasher isn't installed yet."
            font.pixelSize: Theme.fontSize.lg
            wrapMode: Text.WordWrap
        }

        GhostButton {
            Layout.fillWidth: true
            implicitHeight: 36
            exclusiveGrab: true
            icon: FlasherService.installing ? "" : "\uF019"
            text: FlasherService.installing ? "Installing… (see terminal)" : "Install"
            iconSize: Theme.fontSize.sm
            textSize: Theme.fontSize.lg
            bold: true
            idleColor: Theme.mainAccentSubtle
            hoverColor: Theme.alpha(Theme.mainAccent, 0.3)
            contentColor: Theme.mainAccent
            onClicked: FlasherService.install()
        }
    }

    // ── Pick: image ──
    SectionHeader { visible: menu.picking; text: "IMAGE" }

    StyledText {
        visible: menu.picking && FlasherService.images.length === 0
        Layout.preferredWidth: 360
        text: "No .iso / .img in ~/Downloads or ~"
        color: Theme.dimForeground
        font.pixelSize: Theme.fontSize.md
    }

    ColumnLayout {
        visible: menu.picking
        Layout.preferredWidth: 360
        spacing: 2

        Repeater {
            model: FlasherService.images.slice(0, 6)
            delegate: Choice {
                required property var modelData
                icon: "\uF1C6"
                label: modelData.name
                detail: FlasherService.formatSize(modelData.size)
                selected: FlasherService.image === modelData.path
                onPicked: { FlasherService.image = modelData.path; menu.armed = false; }
            }
        }
    }

    // ── Pick: stick ──
    SectionHeader { visible: menu.picking; text: "USB STICK" }

    StyledText {
        visible: menu.picking && FlasherService.drives.length === 0
        Layout.preferredWidth: 360
        text: "Plug in a USB stick…"
        color: Theme.dimForeground
        font.pixelSize: Theme.fontSize.md
    }

    ColumnLayout {
        visible: menu.picking
        Layout.preferredWidth: 360
        spacing: 2

        Repeater {
            model: FlasherService.drives
            delegate: Choice {
                required property var modelData
                icon: "\uF287"
                label: modelData.label + "  " + modelData.path
                detail: FlasherService.formatSize(modelData.size)
                selected: FlasherService.drive === modelData.path
                onPicked: { FlasherService.drive = modelData.path; menu.armed = false; }
            }
        }
    }

    StyledText {
        visible: menu.picking && !!FlasherService.imageInfo && !!FlasherService.driveInfo && !FlasherService.fits
        text: "The image is larger than the stick."
        color: Theme.warning
        font.pixelSize: Theme.fontSize.md
    }

    GhostButton {
        visible: menu.picking
        Layout.fillWidth: true
        implicitHeight: 36
        exclusiveGrab: true
        enabled: FlasherService.canFlash
        opacity: enabled ? 1 : 0.4
        icon: menu.armed ? "\uF071" : "\uF0E7"
        text: menu.armed
            ? "Erase " + (FlasherService.driveInfo?.label ?? "") + " (" + FlasherService.formatSize(FlasherService.driveInfo?.size ?? 0) + ")?"
            : "Flash"
        iconSize: Theme.fontSize.sm
        textSize: Theme.fontSize.lg
        bold: true
        idleColor: Theme.alpha(menu.armed ? Theme.red : Theme.mainAccent, 0.15)
        hoverColor: Theme.alpha(menu.armed ? Theme.red : Theme.mainAccent, 0.3)
        contentColor: menu.armed ? Theme.red : Theme.mainAccent
        onClicked: {
            if (!menu.armed) { menu.armed = true; return; }
            menu.armed = false;
            FlasherService.flash();
        }
    }

    // ── Flashing / done / error ──
    ColumnLayout {
        visible: FlasherService.installed && FlasherService.phase !== "idle"
        Layout.preferredWidth: 360
        spacing: 10

        StyledText {
            Layout.fillWidth: true
            text: (FlasherService.imageInfo?.name ?? "") + "  →  " + (FlasherService.driveInfo?.label ?? FlasherService.drive)
            elide: Text.ElideMiddle
            font.pixelSize: Theme.fontSize.lg
        }

        ProgressBar {
            Layout.fillWidth: true
            height: 8
            percent: Math.round(FlasherService.progress * 100)
            backgroundColor: Theme.alpha(Theme.foreground, 0.12)
            fillColor: FlasherService.phase === "error" ? Theme.error
                     : FlasherService.phase === "done" ? Theme.green : Theme.mainAccent
        }

        StyledText {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            font.pixelSize: Theme.fontSize.md
            color: FlasherService.phase === "error" ? Theme.error
                 : FlasherService.phase === "done" ? Theme.green : Theme.dimForeground
            text: FlasherService.phase === "flashing"
                    ? Math.round(FlasherService.progress * 100) + " %  ·  "
                      + FlasherService.formatSize(FlasherService.written)
                      + (FlasherService.speed ? "  ·  " + FlasherService.speed : "")
                : FlasherService.phase === "done" ? "Done — safe to remove the stick."
                : FlasherService.error
        }

        GhostButton {
            visible: !FlasherService.busy
            Layout.fillWidth: true
            implicitHeight: 34
            exclusiveGrab: true
            text: "Flash another"
            textSize: Theme.fontSize.md
            idleColor: Theme.hoverOverlay
            hoverColor: Theme.alpha(Theme.foreground, 0.15)
            onClicked: { FlasherService.reset(); FlasherService.refresh(); }
        }
    }

    // One selectable row (image / stick)
    component Choice: Rectangle {
        id: c
        property string icon
        property string label
        property string detail
        property bool selected
        signal picked()

        Layout.fillWidth: true
        implicitHeight: 34
        radius: Theme.radius.md
        color: c.selected ? Theme.mainAccentSubtle
             : area.containsMouse ? Theme.hoverOverlay : "transparent"

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
                text: c.icon
                color: c.selected ? Theme.mainAccent : Theme.dimForeground
                font.pixelSize: Theme.fontSize.lg
            }

            StyledText {
                Layout.fillWidth: true
                text: c.label
                elide: Text.ElideMiddle
                font.pixelSize: Theme.fontSize.lg
            }

            StyledText {
                text: c.detail
                color: c.selected ? Theme.mainAccent : Theme.dimForeground
                font.pixelSize: Theme.fontSize.md
            }
        }

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: c.picked()
        }
    }
}
