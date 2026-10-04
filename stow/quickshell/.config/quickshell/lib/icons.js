.pragma library
// Nerd Font glyphs in ONE place. Glyphs are private-use codepoints — the
// Text rendering them needs `font.family: Theme.fontFamily` (docs/GOTCHAS.md).
// `.pragma library` → one shared instance instead of a copy per importer.

// Split [0, max] into n equal buckets and return the bucket index for value.
// Clamped to [0, n-1]: >100 % battery, negative or NaN input used to index
// out of range (→ undefined icon). In-range results are unchanged.
function bucket(value, max, n) {
    const i = Math.floor(value * (n - 1) / max);
    return i > 0 ? Math.min(n - 1, i) : 0;
}

// ── Volume ──
var volume = { loud: "", quiet: "", off: "" };

// Muted and volume 0 are not the same thing, but both show the "off" glyph
function volumeIcon(pct, muted) {
    if (muted || pct === 0) return volume.off;
    return pct < 70 ? volume.quiet : volume.loud;
}

var mic = { on: "󰍬", muted: "󰍭" };
var brightness = "";

// ── Network ──
var wifi       = ["󰤯", "󰤟", "󰤢", "󰤥", "󰤨"];
var wifiSecure = ["󰤬", "󰤡", "󰤤", "󰤧", "󰤪"];
var wifiOff        = "󰤮";   // disconnected
var wifiRestricted = "󰤩";   // captive portal / limited connectivity
var ethernet           = "󰈀";
var ethernetRestricted = "󰈂";

// signal: 0–100
function wifiIcon(signal, secure) {
    const set = secure ? wifiSecure : wifi;
    return set[bucket(signal, 100, set.length)];
}

// ── Battery ──
var batteryCharging    = ["󰢜", "󰂆", "󰂇", "󰂈", "󰢝", "󰂉", "󰢞", "󰂊", "󰂋", "󰂅"];
var batteryDischarging = ["󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"];
var batteryFull = "";

function batteryIcon(pct, charging) {
    const set = charging ? batteryCharging : batteryDischarging;
    return set[bucket(pct, 100, set.length)];
}

// Arrows (battery tooltip; the bar appends arrowDown to the discharging icon)
var arrowUp   = "";
var arrowDown = "";

// ── Bluetooth ──
var bluetooth = { off: "󰂲", on: "󰂯", connected: "󰂱", battery: "󰂄" };

// ── Notifications ──
var bell = { empty: "󰂚", unread: "󱅫" };
var trash = "󰆴";

// ── VPN / misc ──
var vpn = { on: "󰌆", off: "󰌊" };
var forget = "󰌸";

// ── Calendar ──
var calendar = { refresh: "󰑐", external: "󰏌", video: "󰕧", warning: "󰀦", settings: "󰒓", today: "󰃶", back: "󰁍", check: "󰄬", hide: "󰂛" };

// ── Setup (dots setup steps) ──
var setup = { indicator: "󰖷", open: "󰗖", done: "󰄬", ignored: "󰈉", ignore: "󰈉", unignore: "󰈈" };
