import QtQuick
import QtQuick.Layouts

import qs.components
import qs.config
import qs.services

// "Usage" card in the Home menu: Anthropic limit windows + OpenRouter credits.
// Data: services/AiUsageService.qml.
Rectangle {
    id: card

    readonly property var a: AiUsageService.anthropic
    readonly property var o: AiUsageService.openrouter

    // Only providers with credentials in Pi's auth.json are reported
    readonly property bool hasA: a.ok !== undefined
    readonly property bool hasO: o.ok !== undefined

    readonly property var unknown: AiUsageService.unknown

    visible: hasA || hasO || unknown.length > 0
    Layout.fillWidth: true
    implicitHeight: col.implicitHeight + 24
    radius: Theme.radius.lg
    color: Theme.alpha(Theme.foreground, 0.04)

    function levelColor(p) {
        return p >= 90 ? Theme.error : p >= 70 ? Theme.warning : Theme.mainAccent
    }

    // "2h 05m" / "3d 4h"; a reset in the past means the window has not
    // restarted yet — say so instead of a negative time
    function resetText(iso) {
        if (!iso) return ""
        const s = (new Date(iso).getTime() - Date.now()) / 1000
        if (s <= 0) return "reset pending"
        const m = Math.floor(s / 60)
        if (m >= 1440) return "resets in " + Math.floor(m / 1440) + "d " + Math.floor(m % 1440 / 60) + "h"
        return "resets in " + Math.floor(m / 60) + "h " + String(m % 60).padStart(2, "0") + "m"
    }

    function money(v, cur) {
        return (cur === "EUR" ? "€" : "$") + v.toFixed(2)
    }

    // One limit window: label, bar, percent, reset text
    component Window: ColumnLayout {
        id: w
        property string label
        property var win
        visible: !!win && win.percent !== null
        Layout.fillWidth: true
        spacing: 4

        RowLayout {
            Layout.fillWidth: true
            StyledText { text: w.label; font.pixelSize: Theme.fontSize.md }
            StyledText {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignRight
                text: w.win ? card.resetText(w.win.resetsAt) : ""
                color: Theme.dimForeground
                font.pixelSize: Theme.fontSize.sm
            }
            StyledText {
                text: w.win ? Math.round(w.win.percent) + "%" : ""
                color: w.win ? card.levelColor(w.win.percent) : Theme.foreground
                font.pixelSize: Theme.fontSize.md
            }
        }
        ProgressBar {
            Layout.fillWidth: true
            height: 6
            backgroundColor: Theme.alpha(Theme.foreground, 0.12)
            fillColor: w.win ? card.levelColor(w.win.percent) : Theme.mainAccent
            percent: w.win ? Math.round(w.win.percent) : 0
        }
    }

    component Title: RowLayout {
        property string text
        property string note
        Layout.fillWidth: true
        StyledText {
            text: parent.text
            font.pixelSize: Theme.fontSize.lg
            font.bold: true
        }
        StyledText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignRight
            text: parent.note
            color: Theme.dimForeground
            font.pixelSize: Theme.fontSize.sm
        }
    }

    ColumnLayout {
        id: col
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        // ── Anthropic ──
        Title {
            visible: card.hasA
            text: "Anthropic"
            note: card.a.ok === false ? card.a.error
                : AiUsageService.loading ? "updating…" : ""
        }
        Window { label: "Session (5h)"; win: card.a.ok ? card.a.session : null }
        Window { label: "Week";         win: card.a.ok ? card.a.weekly : null }
        Window { label: "Week · Sonnet"; win: card.a.ok ? card.a.sonnet : null }
        Window { label: "Week · Opus";   win: card.a.ok ? card.a.opus : null }
        StyledText {
            visible: card.a.ok === true && !!card.a.extra
            text: card.a.extra
                ? "Extra usage  " + card.money(card.a.extra.used, card.a.extra.currency)
                  + " / " + card.money(card.a.extra.limit, card.a.extra.currency)
                : ""
            color: Theme.dimForeground
            font.pixelSize: Theme.fontSize.sm
        }

        Divider { visible: card.hasA && card.hasO; Layout.fillWidth: true }

        // ── OpenRouter ──
        Title {
            visible: card.hasO
            text: "OpenRouter"
            note: card.o.ok === false ? card.o.error
                : card.o.ok ? card.money(card.o.remaining, "USD") + " left" : ""
        }
        Window {
            label: "Credits used"
            visible: card.o.ok === true
            win: card.o.ok ? { percent: card.o.total > 0 ? card.o.used / card.o.total * 100 : 0,
                               resetsAt: null } : null
        }
        StyledText {
            visible: card.o.ok === true
            text: card.o.ok
                ? "Today " + card.money(card.o.daily, "USD")
                  + "  ·  Week " + card.money(card.o.weekly, "USD")
                  + "  ·  Month " + card.money(card.o.monthly, "USD")
                : ""
            color: Theme.dimForeground
            font.pixelSize: Theme.fontSize.sm
        }

        // ── Providers in auth.json that we cannot read usage for ──
        Rectangle {
            visible: card.unknown.length > 0
            Layout.fillWidth: true
            implicitHeight: warn.implicitHeight + 16
            radius: Theme.radius.md
            color: Theme.alpha(Theme.warning, 0.18)
            border.width: 1
            border.color: Theme.alpha(Theme.warning, 0.6)

            StyledText {
                id: warn
                anchors.fill: parent
                anchors.margins: 8
                wrapMode: Text.WordWrap
                color: Theme.warning
                font.pixelSize: Theme.fontSize.sm
                text: "Unknown provider" + (card.unknown.length > 1 ? "s" : "") + ": "
                    + card.unknown.join(", ")
                    + " — no usage support yet (scripts/ai-usage.py)"
            }
        }
    }
}
