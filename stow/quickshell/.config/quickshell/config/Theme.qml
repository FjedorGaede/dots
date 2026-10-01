pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Theme layering (later layers win):
//   0. static Catppuccin Mocha  — hardcoded fallback below
//   1. pywal scheme             — ~/.cache/wal/colors.json, watched live
//   2. user overrides           — overrides.json next to this file, watched live
//        { "mainAccent": "#f6aede",  // fixed hex → always mine
//          "highlight":  "color13" } // "colorN"  → follow the wal scheme
//
// The resolved accent/highlight are exported to hyprlock through
//   ~/.cache/quickshell-theme/hyprlock.conf  ($qs_accent / $qs_highlight),
// which hyprlock.conf sources.

Singleton {
    id: root

    property string fontFamily: "JetBrainsMono Nerd Font"

    // ── Design tokens (values = the magic numbers used before, unchanged) ──

    readonly property QtObject fontSize: QtObject {
        readonly property int xs: 10
        readonly property int sm: 11
        readonly property int md: 12
        readonly property int base: 13
        readonly property int lg: 14
        readonly property int xl: 16
        readonly property int icon: 20
        readonly property int osd: 24
    }

    readonly property QtObject radius: QtObject {
        readonly property int xs: 2
        readonly property int sm: 6
        readonly property int md: 8
        readonly property int lg: 12
        readonly property int xl: 14
    }

    readonly property QtObject anim: QtObject {
        readonly property int fast: 100
        readonly property int normal: 150
        readonly property int slow: 180
    }

    readonly property QtObject bar: QtObject {
        id: barTokens
        readonly property int height: 30
        readonly property int edgeMargin: 4
        readonly property int pillPadding: 8
        // Status-pill indicators (BarButton): default glyph size and the
        // visible gap between icons (boxes are ink-sized)
        readonly property int iconSize: 14
        readonly property int iconSpacing: 8
        readonly property int toastTop: barTokens.height + 8   // toasts start 8px below the bar
    }

    // Color `c` with alpha `a` (replaces Qt.rgba(c.r, c.g, c.b, a))
    function alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a); }

    // ── Layer 1: raw wal scheme (strings), {} until a scheme is loaded ──
    property var walColors: ({})

    function parseWal() {
        const raw = walView.text();
        if (!raw) return;

        let scheme = null;
        try { scheme = JSON.parse(raw); } catch (e) { return; } // half-written / invalid → keep current
        if (!scheme || !scheme.colors || !scheme.special) return;

        const merged = Object.assign({}, scheme.colors);
        merged.special = scheme.special;
        root.walColors = merged;
    }

    // ── Layer 2 resolution: "" → keep fallback, "colorN" → wal slot, hex → fixed ──
    function resolveOverride(spec, fallback) {
        if (spec === undefined || spec === null || spec === "") return fallback;
        const m = /^color(\d+)$/.exec(String(spec));
        if (m) {
            const walValue = root.walColors["color" + m[1]];
            return walValue !== undefined ? walValue : fallback;
        }
        return spec;
    }

    // ── Layer 0: static Catppuccin Mocha fallbacks (overridden by wal when present) ──

    // Special
    property color background: root.walColors.special?.background ?? "#1e1e2e"
    property color foreground: root.walColors.special?.foreground ?? "#cdd6f4"
    property color cursor:     root.walColors.special?.cursor     ?? "#cdd6f4"
    property color white:      "#ffffff"
    property color black:      "#000000"

    // Colors
    property color color0:  root.walColors.color0  ?? "#45475a"
    property color color1:  root.walColors.color1  ?? "#f38ba8"
    property color color2:  root.walColors.color2  ?? "#a6e3a1"
    property color color3:  root.walColors.color3  ?? "#f9e2af"
    property color color4:  root.walColors.color4  ?? "#89b4fa"
    property color color5:  root.walColors.color5  ?? "#f5c2e7"
    property color color6:  root.walColors.color6  ?? "#94e2d5"
    property color color7:  root.walColors.color7  ?? "#bac2de"
    property color color8:  root.walColors.color8  ?? "#585b70"
    property color color9:  root.walColors.color9  ?? "#f38ba8"
    property color color10: root.walColors.color10 ?? "#a6e3a1"
    property color color11: root.walColors.color11 ?? "#f9e2af"
    property color color12: root.walColors.color12 ?? "#89b4fa"
    property color color13: root.walColors.color13 ?? "#f5c2e7"
    property color color14: root.walColors.color14 ?? "#94e2d5"
    property color color15: root.walColors.color15 ?? "#a6adc8"

    // Custom accent — never comes from wal directly; either a fixed color of
    // yours or a reference into the current scheme (see overrides.json)
    readonly property color mainAccent: resolveOverride(overrides.mainAccent, "#f6aede")
    readonly property color highlight:  resolveOverride(overrides.highlight,  "#f5c2e7")

    // Translucent helpers
    property color accentSubtle:     alpha(accent, 0.15)
    property color mainAccentSubtle: alpha(mainAccent, 0.15)
    property color hoverOverlay:     Qt.rgba(1, 1, 1, 0.07)
    property color backdrop:         alpha(background, 0.7)
    property color dimForeground:    alpha(foreground, 0.5)
    property color fadedForeground:  alpha(foreground, 0.8)

    // Semantic aliases
    property color surface:  color0
    property color red:      color1
    property color green:    color2
    property color yellow:   color3
    property color blue:     color4
    property color magenta:  color5
    property color cyan:     color6
    property color text:     color7
    property color overlay:  color8
    property color accent:   color12
    property color subtext:  color15

    property color subdued:   color8
    property color error:     color1
    property color success:   color2
    property color warning:   color3

    // Formerly hardcoded colors, named (same values → same look)
    readonly property color divider:        "gray"     // Divider / VerticalDivider default
    readonly property color errorBright:    "#ff6b6b"  // wifi password error (not themed)
    readonly property color criticalBorder: color1     // critical notification border
    readonly property color cardBorder:     color0     // notification history card border
    readonly property color actionButton:   color8     // notification action button idle bg

    // ── File watching ──

    FileView {
        id: walView
        path: Paths.walColors
        watchChanges: true
        onTextChanged: root.parseWal()
    }

    FileView {
        id: overridesView
        path: Qt.resolvedUrl("overrides.json")
        watchChanges: true
        onLoaded: root.writeLockConf()

        JsonAdapter {
            id: overrides
            property string mainAccent: ""
            property string highlight:  ""
        }
    }

    // ── Export accent to hyprlock ──

    function toRgba(c) {
        const col = Qt.color(c);
        return "rgba(" + Math.round(col.r * 255) + "," + Math.round(col.g * 255) + ","
                       + Math.round(col.b * 255) + ",1.0)";
    }

    // Debounced: at startup this is requested up to 4× (overrides onLoaded,
    // accent/highlight changes, onCompleted) — spawn `sh` only once.
    Timer {
        id: lockDebounce
        interval: 50
        onTriggered: root._writeLockConf()
    }

    function writeLockConf() { lockDebounce.restart(); }

    function _writeLockConf() {
        const body = "$qs_accent = " + root.toRgba(root.mainAccent) + "\n"
                   + "$qs_highlight = " + root.toRgba(root.highlight) + "\n";
        // body contains no single quotes → shell-safe
        Quickshell.execDetached(["sh", "-c",
            "mkdir -p '" + Paths.themeCache + "' && printf '%s' '" + body
            + "' > '" + Paths.hyprlockConf + "'"]);
    }

    onMainAccentChanged: root.writeLockConf()
    onHighlightChanged:  root.writeLockConf()
    Component.onCompleted: root.writeLockConf()
}
