import QtQuick
import QtQuick.Layouts

import qs.config

// Bar indicator: ink-sized icon + optional label + tap/right-tap + hover
// cursor + tooltip. Popups/panels are declared as children at the use site
// (they are windows, not Items, so they don't take part in the RowLayout).
//
// The icon box is exactly as wide as the glyph's visible ink (InkGlyph), not
// its advance width — nerd glyphs from different sets have very different
// advances/bearings. With ink-sized boxes the RowLayout spacing is the real
// visual gap between icons, so the status pill looks evenly spaced
// (docs/GOTCHAS.md).
//
// Input handling is exactly what every indicator used before: passive
// TapHandlers + a HoverHandler on the RowLayout (no MouseArea).
RowLayout {
    id: root

    property alias icon: glyph.text
    property int iconSize: Theme.bar.iconSize
    property color iconColor: Theme.foreground
    // Vertical optical correction in px (negative = up), see InkGlyph
    property alias iconShiftY: glyph.opticalShiftY
    // Text right of the icon (Battery percentage); "" → no label
    property string label: ""

    // "" → no tooltip is ever shown (Sunshine)
    property string tooltipText: ""
    // While true, hover changes don't touch the tooltip (Vpn: its popup
    // is open). Imperative on purpose — same semantics as before: a tooltip
    // that is already showing stays until the next hover change.
    property bool tooltipBlocked: false

    // false → no left-click handling and no pointer cursor (Battery)
    property bool clickable: true
    property bool rightClickable: false

    signal clicked()
    signal rightClicked()

    // The tooltip is its own window: an indicator hidden while hovered
    // (Setup after its last step is done) would otherwise leave it behind
    onVisibleChanged: if (!visible) tip.visible = false

    spacing: 4

    // Layout height stays at the 14px base line height so every bar pill
    // (incl. StayAwake) has the same height (docs/GOTCHAS.md)
    FontMetrics {
        id: baseMetrics
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize.lg
    }

    Item {
        Layout.preferredWidth: Math.ceil(glyph.ink.width)
        Layout.preferredHeight: Math.ceil(baseMetrics.height)

        InkGlyph {
            id: glyph
            color: root.iconColor
            font.family: Theme.fontFamily
            font.pixelSize: root.iconSize
        }
    }

    StyledText {
        visible: root.label !== ""
        text: root.label
        color: root.iconColor
        font.pixelSize: Theme.fontSize.base
        Layout.preferredHeight: Math.ceil(baseMetrics.height)
        verticalAlignment: Text.AlignVCenter
    }

    TapHandler {
        enabled: root.clickable
        onTapped: root.clicked()
    }

    TapHandler {
        enabled: root.rightClickable
        acceptedButtons: Qt.RightButton
        onTapped: root.rightClicked()
    }

    HoverHandler {
        // undefined → cursorShape reset (not set at all), like Power.qml (Battery) had
        cursorShape: root.clickable ? Qt.PointingHandCursor : undefined
        onHoveredChanged: {
            if (root.tooltipText === "" || root.tooltipBlocked) return;
            tip.visible = hovered;
        }
    }

    Tooltip {
        id: tip
        anchorItem: root
        tooltipText: root.tooltipText
    }
}
