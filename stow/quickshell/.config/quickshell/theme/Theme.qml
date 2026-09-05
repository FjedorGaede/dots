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
    property color accentSubtle:     Qt.rgba(accent.r, accent.g, accent.b, 0.15)
    property color mainAccentSubtle: Qt.rgba(mainAccent.r, mainAccent.g, mainAccent.b, 0.15)
    property color hoverOverlay:     Qt.rgba(1, 1, 1, 0.07)
    property color backdrop:         Qt.rgba(background.r, background.g, background.b, 0.7)
    property color dimForeground:    Qt.rgba(foreground.r, foreground.g, foreground.b, 0.5)
    property color fadedForeground:  Qt.rgba(foreground.r, foreground.g, foreground.b, 0.8)

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

    // ── File watching ──

    FileView {
        id: walView
        // NB: StandardPaths.homeLocation is undefined in QML — use $HOME directly
        path: Quickshell.env("HOME") + "/.cache/wal/colors.json"
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

    function writeLockConf() {
        const body = "$qs_accent = " + root.toRgba(root.mainAccent) + "\n"
                   + "$qs_highlight = " + root.toRgba(root.highlight) + "\n";
        // body contains no single quotes → shell-safe
        Quickshell.execDetached(["sh", "-c",
            "mkdir -p ~/.cache/quickshell-theme && printf '%s' '" + body
            + "' > ~/.cache/quickshell-theme/hyprlock.conf"]);
    }

    onMainAccentChanged: root.writeLockConf()
    onHighlightChanged:  root.writeLockConf()
    Component.onCompleted: root.writeLockConf()
}
