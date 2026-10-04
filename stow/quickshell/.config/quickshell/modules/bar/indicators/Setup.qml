import QtQuick

import '../../../lib/icons.js' as Icons
import qs.components
import qs.config
import qs.services
import qs.modules.panels

// Open dots setup steps (github, calendar, ...) — hidden when every step is
// done or ignored (SetupService)
BarButton {
    id: setup

    readonly property int open: SetupService.openSteps.length

    visible: setup.open > 0

    icon: Icons.setup.indicator
    iconColor: Theme.warning
    tooltipText: setup.open === 1 ? "1 setup step open" : setup.open + " setup steps open"
    tooltipBlocked: setupPopup.visible
    onClicked: {
        setupPopup.visible = !setupPopup.visible;
        if (setupPopup.visible) SetupService.refresh();
    }

    SetupPopup {
        id: setupPopup
        anchorItem: setup
    }
}
