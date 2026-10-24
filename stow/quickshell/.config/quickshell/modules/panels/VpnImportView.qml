import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import '../../lib/icons.js' as Icons
import qs.components
import qs.config
import qs.services

// "Add VPN" view inside the wifi panel: pick a WireGuard .conf (found in
// ~/Downloads and ~), name the profile, import via nmcli.
// No file dialog: none is installed, and a separate window would take the
// focus grab → the panel would close. open() shows it, cancel() hides it.
ColumnLayout {
    id: root

    property bool active: false
    // Name typed by hand → stop replacing it with the file name suggestion
    property bool nameEdited: false

    readonly property string home: Paths.home
    // Chosen config file (absolute path), "" = none
    property string selectedPath: ""
    readonly property bool canImport: selectedPath !== ""
                                      && VpnService.isValidName(nameField.text)
                                      && !VpnService.importing

    visible: active
    spacing: 8

    function open() {
        active = true
        nameEdited = false
        selectedPath = ""
        nameField.text = ""
        VpnService.importError = ""
        VpnService.scanConfigs()
    }

    function cancel() {
        active = false
        VpnService.importError = ""
    }

    function select(path) {
        selectedPath = path
        if (!nameEdited)
            nameField.text = VpnService.suggestName(path)
    }

    function confirmImport() {
        if (canImport)
            VpnService.importConfig(selectedPath, nameField.text)
    }

    Connections {
        target: VpnService
        function onImported() { root.cancel() }
        // Exactly one config around → preselect it
        function onFoundConfigsChanged() {
            if (root.active && root.selectedPath === "" && VpnService.foundConfigs.length === 1)
                root.select(VpnService.foundConfigs[0])
        }
    }

    component Field: TextField {
        id: field
        Layout.fillWidth: true
        color: Theme.foreground
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize.base
        leftPadding: 10
        rightPadding: 10
        placeholderTextColor: Theme.dimForeground

        background: Rectangle {
            radius: Theme.radius.sm
            color: Theme.hoverOverlay
            border.color: field.activeFocus ? Theme.mainAccent : "transparent"
            border.width: 1
        }

        onAccepted: root.confirmImport()
    }

    Divider {}

    StyledText {
        Layout.topMargin: 4
        text: "1. WireGuard config file"
        font.pixelSize: Theme.fontSize.base
        font.bold: true
    }

    StyledText {
        text: VpnService.foundConfigs.length > 0
              ? "Found in ~/Downloads and ~ — click one"
              : "None found — save the .conf file to ~/Downloads first"
        color: Theme.dimForeground
        font.pixelSize: Theme.fontSize.md
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
        // Wrap to the panel width instead of widening it
        Layout.preferredWidth: 1
    }

    Repeater {
        model: VpnService.foundConfigs

        // "wg_config.conf  ·  ~/Downloads"
        ListItem {
            required property string modelData
            readonly property string dir: modelData.slice(0, modelData.lastIndexOf("/"))
            size: ListItem.Small
            icon: Icons.vpn.off
            label: modelData.split("/").pop() + "  ·  "
                   + (dir.startsWith(root.home) ? "~" + dir.slice(root.home.length) : dir)
            status: root.selectedPath === modelData ? ListItem.Active : ListItem.Default
            onTapped: root.select(modelData)
        }
    }

    StyledText {
        Layout.topMargin: 4
        text: "2. Name"
        font.pixelSize: Theme.fontSize.base
        font.bold: true
    }

    StyledText {
        text: "Shown in the VPN list — max 15 characters, no spaces"
        color: Theme.dimForeground
        font.pixelSize: Theme.fontSize.md
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
        // Wrap to the panel width instead of widening it
        Layout.preferredWidth: 1
    }

    Field {
        id: nameField
        placeholderText: "e.g. fritzbox"
        maximumLength: 15
        onTextEdited: root.nameEdited = text !== ""
    }

    StyledText {
        Layout.fillWidth: true
        color: Theme.errorBright
        font.pixelSize: Theme.fontSize.md
        wrapMode: Text.WordWrap
        text: VpnService.importError
        visible: text.length > 0
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        GhostButton {
            implicitWidth: 80
            implicitHeight: 30
            rowContent: false
            border.color: Theme.dimForeground
            border.width: 1
            text: "Back"
            textSize: Theme.fontSize.md
            contentColor: Theme.foreground      // not dimmed
            onClicked: root.cancel()
        }

        Item { Layout.fillWidth: true }

        Rectangle {
            id: importButton
            implicitWidth: 90
            implicitHeight: 30
            radius: Theme.radius.sm
            color: root.canImport && importHover.hovered ? Theme.mainAccent : Theme.hoverOverlay
            opacity: root.canImport ? 1.0 : 0.5

            HoverHandler { id: importHover; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: root.confirmImport() }

            StyledText {
                anchors.centerIn: parent
                text: VpnService.importing ? "Importing…" : "Import"
                font.pixelSize: Theme.fontSize.md
            }
        }
    }
}
