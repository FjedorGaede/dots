import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import QtQuick
import QtQuick.Layouts

import './_helpers/getIntervalIndex.js' as Util
import './theme'

RowLayout {
    id: power
    spacing: 2

    property int criticalBatteryLevel: 15
    property bool isCharging: UPower.displayDevice.state == UPowerDeviceState.Charging
    property bool discharging: UPower.displayDevice.state == UPowerDeviceState.Discharging
    property bool fullyCharged: UPower.displayDevice.state == UPowerDeviceState.FullyCharged
    property int percentage: UPower.displayDevice.percentage * 100;
    property bool batteryCritical: percentage <= criticalBatteryLevel
    property int changeRate: Math.ceil(UPower.displayDevice.changeRate)

    property color defaultColor: Theme.foreground
    property color criticalColor: Theme.error

    function getChargingIcon() {
        // I want to divide the interval from 0 to 100 into number of icons chunks and automatically select the corresponding icon

		const chargingIcons = [ "󰢜", "󰂆", "󰂇", "󰂈", "󰢝", "󰂉", "󰢞", "󰂊", "󰂋", "󰂅"];
        return chargingIcons[Util.getIntervalIndex(percentage, 100, chargingIcons.length)]
    }

    function getDischargingIcon() {
        const dischargingIcons = ["󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"];
        return dischargingIcons[Util.getIntervalIndex(percentage, 100, dischargingIcons.length)]
    }

    function icon() {
        if (isCharging) {
            return getChargingIcon();
        }

        if (discharging) {
            const icon = getDischargingIcon();
            return icon + "";
        }

        if (fullyCharged) {
            return "";
        }
    }

    function percentageString() {
        if (fullyCharged) {
            return ""
        }

        return percentage + "%";
    }

    function getColor() {
        if (batteryCritical) {
            return criticalColor;
        }

        return defaultColor;
    }

    function powerTooltipText() {
        const arrowIcon = isCharging ? "" : "";
        return arrowIcon + " " + power.changeRate + "W - " + power.percentage + "%";
    }

    Text {
        text: parent.icon()
        color: parent.getColor()

        font { family: Theme.fontFamily; pixelSize: 14 }
    }

    Text {
        text: parent.percentageString()
        color: parent.getColor()
        font.pixelSize: 13
    }

    Process {
        id: bluemanManagerProc
        command: ["GTK_THEME=Adwaita-dark blueman-manager"]
        running: false
    }

    HoverHandler {
        cursorShape: Qt.PointingHandCursor
        onHoveredChanged: tooltip.visible = hovered
    }

    Tooltip {
        id: tooltip
        anchorItem: power
        tooltipText: power.powerTooltipText()
    }
}
