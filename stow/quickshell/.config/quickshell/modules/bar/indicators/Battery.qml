import QtQuick

import '../../../lib/icons.js' as Icons
import qs.components
import qs.config
import qs.services

BarButton {
    id: power
    // No tap, no pointer cursor — tooltip only
    clickable: false

    // State lives in BatteryService
    readonly property bool isCharging: BatteryService.charging
    readonly property bool discharging: BatteryService.discharging
    readonly property bool fullyCharged: BatteryService.fullyCharged
    readonly property int percentage: BatteryService.percentage
    readonly property bool batteryCritical: BatteryService.critical
    readonly property int changeRate: BatteryService.changeRate

    // Battery glyph bucketed over 0–100 % (see lib/icons.js)
    function icon() {
        if (isCharging) {
            return Icons.batteryIcon(percentage, true);
        }

        if (fullyCharged) {
            return Icons.batteryFull;
        }

        // Discharging, PendingCharge (charge threshold reached),
        // PendingDischarge, Empty, Unknown: level glyph — never undefined
        return Icons.batteryIcon(percentage, false);
    }

    // Shown right of the icon slot. No discharge arrow: charging already
    // has its own (bolt) glyph set, and the tooltip shows the direction
    function label() {
        if (fullyCharged) {
            return "";
        }

        return percentage + "%";
    }

    function powerTooltipText() {
        const arrowIcon = isCharging ? Icons.arrowUp : Icons.arrowDown;
        return arrowIcon + " " + power.changeRate + "W - " + power.percentage + "%";
    }

    icon: power.icon()
    label: power.label()
    iconColor: power.batteryCritical ? Theme.error : Theme.foreground
    tooltipText: power.powerTooltipText()
}
