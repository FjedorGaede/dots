import QtQuick
import QtQuick.Layouts

import qs.components
import qs.config
import qs.services
import qs.modules.panels

// All dots setup steps — centered menu, opened from the setup indicator or
// the home menu (panel "setup"), grouped into open / optional / ignored /
// done. Run opens the step in a terminal (SetupService).
ModalOverlay {
    id: setupMenu
    visible: PanelService.isOpen("setup")
    onVisibleChanged: if (visible) SetupService.refresh()
    onCloseRequested: PanelService.close("setup")

    cardWidth: 460
    padding: 18
    spacing: 4

    PanelHeader {
        title: "SETUP"
        Layout.fillWidth: true
        Layout.bottomMargin: 4

        StyledText {
            text: SetupService.openSteps.length + " open"
            color: SetupService.openSteps.length > 0 ? Theme.warning : Theme.dimForeground
            font.pixelSize: Theme.fontSize.sm
        }
    }

    component Section: ColumnLayout {
        id: section

        required property string title
        required property string kind

        readonly property var items: SetupService.steps.filter(s => s.state === section.kind)

        visible: section.items.length > 0
        Layout.fillWidth: true
        spacing: 2

        StyledText {
            text: section.title
            color: Theme.dimForeground
            font.pixelSize: Theme.fontSize.xs
            font.bold: true
            font.letterSpacing: 1
            Layout.leftMargin: 12
            Layout.topMargin: 6
            Layout.bottomMargin: 2
        }

        Repeater {
            model: section.items

            SetupStepItem {
                required property var modelData
                step: modelData
                onRun: {
                    SetupService.run(modelData.name);
                    PanelService.close("setup");
                }
                onToggleIgnore: modelData.state === "ignored"
                    ? SetupService.unignore(modelData.name)
                    : SetupService.ignore(modelData.name)
            }
        }
    }

    // first `dots setup --status` after a shell (re)load takes a few seconds
    StyledText {
        visible: SetupService.steps.length === 0
        text: SetupService.loading ? "Loading…" : "No setup steps"
        color: Theme.dimForeground
        font.pixelSize: Theme.fontSize.sm
        Layout.leftMargin: 12
        Layout.topMargin: 6
    }

    Section { title: "OPEN"; kind: "open" }
    Section { title: "OPTIONAL"; kind: "optional" }
    Section { title: "IGNORED"; kind: "ignored" }
    Section { title: "DONE"; kind: "done" }
}
