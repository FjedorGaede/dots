import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import '../../lib/fuzzy.js' as Fuzzy
import qs.components
import qs.config
import qs.services

// Network device list — centered overlay card like the home menu.
// Fuzzy-searchable list of every device seen on the local network
// (ping sweep + ARP + DNS/mDNS names, see LanScannerService).
// Click a device to open its IP in the browser.
//
// Visibility lives in PanelService ("network") so the home menu
// can open this window (cross-file ids don't see each other).
// Also `qs ipc call network toggle / open / close`.
ModalOverlay {
    id: root

    visible: PanelService.isOpen("network")

    onVisibleChanged: {
        if (visible) {
            searchField.text = "";
            searchField.forceActiveFocus();
            LanScannerService.scan();
        }
    }

    // Auto-refresh while the panel is open
    Timer {
        interval: 30000
        running: root.visible
        repeat: true
        onTriggered: LanScannerService.scan()
    }

    function displayName(d) {
        let n = (d.name || "").replace(/\.fritz\.box$/i, "").replace(/\.local$/i, "");
        if (n === "_gateway") n = "";
        return n;
    }

    function ipKey(ip) {
        return ip.split(".").map(x => parseInt(x, 10));
    }

    // Element-wise numeric IPv4 compare (.9 before .10 — arrays compared with
    // `<` are stringified and sorted lexically)
    function compareIp(a, b) {
        const ka = ipKey(a), kb = ipKey(b);
        for (let i = 0; i < Math.max(ka.length, kb.length); i++) {
            const d = (ka[i] || 0) - (kb[i] || 0);
            if (d !== 0) return d;
        }
        return 0;
    }

    // "all" | "shelly" — Tab / Shift+Tab or click the tabs to switch
    property string tab: "all"

    function shellyOf(d) {
        return LanScannerService.shellies[d.ip] || null;
    }

    // Shelly rows: user-given name > DHCP hostname > model
    function rowTitle(d) {
        const s = root.shellyOf(d);
        if (s && s.name) return s.name;
        return root.displayName(d) || (s ? "Shelly " + s.model : "Unknown device");
    }

    function rowSubtitle(d) {
        const s = root.shellyOf(d);
        if (root.tab === "shelly" && s)
            return d.ip + "  ·  " + s.model + "  ·  Gen" + s.gen + (s.fw ? "  ·  " + s.fw : "");
        return d.ip + (d.mac ? "  ·  " + d.mac : "");
    }

    readonly property int shellyCount:
        LanScannerService.devices.filter(d => !!LanScannerService.shellies[d.ip]).length

    readonly property var filtered: {
        const q = searchField.text.trim();
        const out = [];
        for (const d of LanScannerService.devices) {
            const sh = LanScannerService.shellies[d.ip];
            if (root.tab === "shelly" && !sh) continue;
            const hay = (d.name || "") + " " + d.ip + " " + d.mac
                      + (sh ? " shelly " + sh.name + " " + sh.model : "");
            const s = Fuzzy.fuzzyScore(q, hay);
            if (s >= 0) out.push({ d: d, s: s });
        }
        out.sort((a, b) =>
            (b.d.online - a.d.online)
            || (b.s - a.s)
            || root.compareIp(a.d.ip, b.d.ip));
        return out.map(o => o.d);
    }

    // Backdrop click (MouseArea, not TapHandler — a click on a row would
    // also hit a passive handler), focus-grab loss and Escape
    onCloseRequested: PanelService.close("network")

    cardWidth: 660
    padding: 18
    spacing: 12

    // ── Header ──
    RowLayout {
        Layout.fillWidth: true
        spacing: 10

        StyledText {
            text: "\uF1EB"
            color: Theme.mainAccent
            font.pixelSize: Theme.fontSize.xl
        }

        StyledText {
            text: "Network devices"
            font { pixelSize: Theme.fontSize.lg; bold: true }
        }

        StyledText {
            readonly property int onlineCount:
                LanScannerService.devices.filter(d => d.online).length
            text: LanScannerService.scanning
                  ? "scanning…"
                  : onlineCount + " online / " + LanScannerService.devices.length
            color: Theme.dimForeground
            font.pixelSize: Theme.fontSize.sm
        }

        Item { Layout.fillWidth: true }

        // Rescan
        GhostButton {
            implicitWidth: 28
            implicitHeight: 28
            rowContent: false
            // Sits above the card's MouseArea click absorber
            exclusiveGrab: true
            icon: LanScannerService.scanning ? "" : "\uF021"    // refresh
            iconSize: Theme.fontSize.base
            contentColor: Theme.dimForeground   // no hover brightening
            onClicked: LanScannerService.scan()
        }
    }

    // ── Tabs ──
    RowLayout {
        Layout.fillWidth: true
        spacing: 6

        Repeater {
            model: [
                { key: "all",    label: "All",    count: LanScannerService.devices.length },
                { key: "shelly", label: "Shelly", count: root.shellyCount }
            ]

            delegate: Rectangle {
                id: tabBtn
                required property var modelData
                readonly property bool active: root.tab === modelData.key

                implicitWidth: tabLabel.implicitWidth + 24
                implicitHeight: 28
                radius: Theme.radius.md
                color: active ? Theme.mainAccentSubtle
                     : tabHover.hovered ? Theme.hoverOverlay : "transparent"

                Behavior on color { ColorAnimation { duration: Theme.anim.fast } }

                HoverHandler {
                    id: tabHover
                    cursorShape: Qt.PointingHandCursor
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        root.tab = tabBtn.modelData.key;
                        searchField.forceActiveFocus();
                    }
                }

                StyledText {
                    id: tabLabel
                    anchors.centerIn: parent
                    text: tabBtn.modelData.label + "  " + tabBtn.modelData.count
                    color: tabBtn.active ? Theme.mainAccent : Theme.dimForeground
                    font { pixelSize: Theme.fontSize.sm; bold: tabBtn.active }
                }
            }
        }

        Item { Layout.fillWidth: true }

        // Shelly probe runs after the LAN scan
        StyledText {
            visible: LanScannerService.probingShelly
            text: "probing shellys…"
            color: Theme.dimForeground
            font.pixelSize: Theme.fontSize.sm
        }
    }

    // ── Search ──
    Rectangle {
        id: searchBg
        Layout.fillWidth: true
        implicitHeight: 36
        radius: Theme.radius.md
        color: searchField.activeFocus ? Theme.hoverOverlay : Theme.mainAccentSubtle

        TextField {
            id: searchField
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            background: null
            placeholderText: root.tab === "shelly"
                             ? "Search shellys… (name, ip, model)"
                             : "Search devices… (name, ip, mac)"
            placeholderTextColor: Theme.dimForeground
            color: Theme.foreground
            font { family: Theme.fontFamily; pixelSize: Theme.fontSize.base }
            selectByMouse: true

            Keys.onEscapePressed: PanelService.close("network")
            Keys.onTabPressed: root.tab = root.tab === "all" ? "shelly" : "all"
            Keys.onBacktabPressed: root.tab = root.tab === "all" ? "shelly" : "all"
            Keys.onReturnPressed: {
                // Enter opens the top match
                if (root.filtered.length > 0) {
                    Apps.openUrl("http://" + root.filtered[0].ip);
                    PanelService.close("network");
                }
            }
        }
    }

    // ── Device list ──
    ListView {
        id: list
        Layout.fillWidth: true
        implicitHeight: Math.min(contentHeight, 430)
        clip: true
        spacing: 2
        model: root.filtered

        ScrollIndicator.vertical: ScrollIndicator {}

        delegate: Rectangle {
            id: dev

            required property var modelData

            width: list.width
            implicitHeight: 42
            radius: Theme.radius.md
            color: rowHover.hovered ? Theme.hoverOverlay : "transparent"

            Behavior on color { ColorAnimation { duration: Theme.anim.fast } }

            HoverHandler {
                id: rowHover
                cursorShape: Qt.PointingHandCursor
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    Apps.openUrl("http://" + dev.modelData.ip);
                    PanelService.close("network");
                }
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                spacing: 10

                // status dot: green = answered ping, yellow = seen in ARP
                Rectangle {
                    implicitWidth: 8
                    implicitHeight: 8
                    radius: 4
                    color: dev.modelData.online ? Theme.green : Theme.yellow
                }

                ColumnLayout {
                    spacing: 0
                    Layout.fillWidth: true

                    StyledText {
                        Layout.fillWidth: true
                        text: root.rowTitle(dev.modelData)
                        font.pixelSize: Theme.fontSize.base
                        elide: Text.ElideRight
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: root.rowSubtitle(dev.modelData)
                        color: Theme.dimForeground
                        font.pixelSize: Theme.fontSize.sm
                        elide: Text.ElideRight
                    }
                }

                // Shelly badge (All tab only — the Shelly tab shows Gen in the subtitle)
                Rectangle {
                    visible: root.tab === "all" && !!root.shellyOf(dev.modelData)
                    implicitWidth: badge.implicitWidth + 12
                    implicitHeight: 18
                    radius: Theme.radius.sm
                    color: Theme.mainAccentSubtle

                    StyledText {
                        id: badge
                        anchors.centerIn: parent
                        text: "shelly"
                        color: Theme.mainAccent
                        font.pixelSize: Theme.fontSize.sm
                    }
                }

                StyledText {
                    text: dev.modelData.online ? "online" : "seen"
                    color: dev.modelData.online ? Theme.green : Theme.dimForeground
                    font.pixelSize: Theme.fontSize.sm
                }
            }
        }
    }

    // Empty state (only when there ARE devices but no matches)
    StyledText {
        visible: root.filtered.length === 0 && LanScannerService.devices.length > 0
        text: root.tab === "shelly" && root.shellyCount === 0
              ? (LanScannerService.probingShelly ? "looking for shellys…" : "no shellys found")
              : "no devices match '" + searchField.text + "'"
        color: Theme.dimForeground
        font.pixelSize: Theme.fontSize.md
        Layout.alignment: Qt.AlignHCenter
    }

    // ── Footer ──
    RowLayout {
        Layout.fillWidth: true

        StyledText {
            text: LanScannerService.devices.length === 0 && LanScannerService.scanning
                  ? "first scan takes a few seconds…"
                  : "click a device to open it in your browser · Tab switches tabs · Esc to close"
            color: Theme.dimForeground
            font.pixelSize: Theme.fontSize.sm
        }

        Item { Layout.fillWidth: true }

        // scanning spinner
        DotsSpinner {
            visible: LanScannerService.scanning || LanScannerService.probingShelly
            font.pixelSize: Theme.fontSize.sm
        }
    }
}
