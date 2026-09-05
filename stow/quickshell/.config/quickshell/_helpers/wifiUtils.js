function getIntervalIndex(value, maximum, numberOfIntevals) {
    return Math.floor(value * (numberOfIntevals - 1) / maximum);
}

const DISCONNECTED_ICON = "󰤮";

// Connected networks first, then strongest signal first.
function byConnectionThenSignal(a, b) {
    if (!!a?.connected !== !!b?.connected) return a?.connected ? -1 : 1;
    return (b?.signalStrength ?? 0) - (a?.signalStrength ?? 0);
}

function getWifiIconForSignalStrength(signalStrength, selectSecureIcons) {
    const wifiIcons = ["󰤯", "󰤟", "󰤢", "󰤥", "󰤨"];
    const secureWifiIcons = ["󰤬", "󰤡", "󰤤", "󰤧", "󰤪"];

    const index = getIntervalIndex(signalStrength, 100, wifiIcons.length);

    if (!!selectSecureIcons) {
        return secureWifiIcons[index];
    }

    return wifiIcons[index];
}
