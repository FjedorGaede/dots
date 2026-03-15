function getIntervalIndex(value, maximum, numberOfIntevals) {
    return Math.floor(value * numberOfIntevals / maximum);
}

const DISCONNECTED_ICON = "󰖪";

function getWifiIconForSignalStrength(signalStrength, selectSecureIcons) {
    const wifiIcons = ["󰤯", "󰤟", "󰤢", "󰤥", "󰤨"];
    const secureWifiIcons = ["󰤬", "󰤡", "󰤤", "󰤧", "󰤪"];

    const index = getIntervalIndex(signalStrength, 100, wifiIcons.length);


    if (!!selectSecureIcons) {
        return secureWifiIcons[index];
    }

    return wifiIcons[index];
}

