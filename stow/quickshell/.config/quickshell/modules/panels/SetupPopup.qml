import QtQuick
import QtQuick.Layouts

import qs.components
import qs.config
import qs.services

// All dots setup steps — opened from the setup indicator, grouped into
// open / ignored / done. Run opens the step in a terminal (SetupService).
PopupPanel {
    id: setupPopup
    minWidth: 400
    margin: 12

    PanelHeader {
        title: "Setup"
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
                    setupPopup.visible = false;
                }
                onToggleIgnore: modelData.state === "ignored"
                    ? SetupService.unignore(modelData.name)
                    : SetupService.ignore(modelData.name)
            }
        }
    }

    Section { title: "OPEN"; kind: "open" }
    Section { title: "IGNORED"; kind: "ignored" }
    Section { title: "DONE"; kind: "done" }
}
