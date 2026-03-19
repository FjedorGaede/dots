pragma Singleton
import QtQuick
import QtCore
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property string fontFamily: "JetBrainsMono Nerd Font"

    // Special
    property color background: "#1e1e2e"
    property color foreground: "#cdd6f4"
    property color cursor:     "#cdd6f4"
    property color white:      "#ffffff"
    property color black:      "#000000"

    // Colors
    property color color0:  "#45475a"
    property color color1:  "#f38ba8"
    property color color2:  "#a6e3a1"
    property color color3:  "#f9e2af"
    property color color4:  "#89b4fa"
    property color color5:  "#f5c2e7"
    property color color6:  "#94e2d5"
    property color color7:  "#bac2de"
    property color color8:  "#585b70"
    property color color9:  "#f38ba8"
    property color color10: "#a6e3a1"
    property color color11: "#f9e2af"
    property color color12: "#89b4fa"
    property color color13: "#f5c2e7"
    property color color14: "#94e2d5"
    property color color15: "#a6adc8"

    property color mainAccent: "#f6aede"

    // Translucent helpers
    property color accentSubtle:     Qt.rgba(accent.r, accent.g, accent.b, 0.15)
    property color mainAccentSubtle: Qt.rgba(mainAccent.r, mainAccent.g, mainAccent.b, 0.15)
    property color hoverOverlay:     Qt.rgba(1, 1, 1, 0.07)
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

    property color highlight: color5
    property color subdued:   color8
    property color error:     color1
    property color success:   color2
    property color warning:   color3

    FileView {
        path: StandardPaths.homeLocation + "/.cache/wal/colors.json"
        watchChanges: true
        onTextChanged: {
            const s = JSON.parse(text)
            root.background = s.special.background
            root.foreground = s.special.foreground
            root.cursor     = s.special.cursor
            root.color0     = s.colors.color0
            root.color1     = s.colors.color1
            root.color2     = s.colors.color2
            root.color3     = s.colors.color3
            root.color4     = s.colors.color4
            root.color5     = s.colors.color5
            root.color6     = s.colors.color6
            root.color7     = s.colors.color7
            root.color8     = s.colors.color8
            root.color9     = s.colors.color9
            root.color10    = s.colors.color10
            root.color11    = s.colors.color11
            root.color12    = s.colors.color12
            root.color13    = s.colors.color13
            root.color14    = s.colors.color14
            root.color15    = s.colors.color15
        }
    }
}
