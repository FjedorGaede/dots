import QtQuick

import '../../../lib/icons.js' as Icons
import qs.components
import qs.config
import qs.services

// BenQ connected but its colour range fix is missing (after a reboot) —
// click runs `benq-fix` in a terminal (BenqRangeService)
BarButton {
    visible: BenqRangeService.needed

    icon: Icons.calendar.warning
    iconColor: Theme.warning
    tooltipText: "BenQ colours wrong — click to run benq-fix"
    onClicked: BenqRangeService.fix()
}
