pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.UPower

// UPower display device state in ONE place.
Singleton {
    id: root

    readonly property var device: UPower.displayDevice

    readonly property bool charging: device.state == UPowerDeviceState.Charging
    readonly property bool discharging: device.state == UPowerDeviceState.Discharging
    readonly property bool fullyCharged: device.state == UPowerDeviceState.FullyCharged

    // int on purpose: truncates the 0–100 real, as the battery indicator (Power.qml) always did
    readonly property int percentage: device.percentage * 100
    readonly property int criticalLevel: 15
    // Only while on battery — a low but charging battery is not an alarm
    readonly property bool critical: percentage <= criticalLevel && !charging && !fullyCharged
    readonly property int changeRate: Math.ceil(device.changeRate)
}
