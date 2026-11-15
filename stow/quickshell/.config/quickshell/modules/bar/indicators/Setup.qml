import QtQuick

import '../../../lib/icons.js' as Icons
import qs.components
import qs.config
import qs.services

// Open dots setup steps (github, calendar, ...) — hidden when every step is
// done, ignored or optional (SetupService). Click opens the centered SetupMenu.
BarButton {
    id: setup

    readonly property int open: SetupService.openSteps.length

    visible: setup.open > 0

    icon: Icons.setup.indicator
    iconColor: Theme.warning
    tooltipText: setup.open === 1 ? "1 setup step open" : setup.open + " setup steps open"
    onClicked: PanelService.open("setup")
}
