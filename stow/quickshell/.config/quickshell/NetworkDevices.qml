import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import './theme'

// Network device list — centered overlay card like the home menu.
// Fuzzy-searchable list of every device seen on the local network
// (ping sweep + ARP + DNS/mDNS names, see NetworkDevicesService).
// Click a device to open its IP in the browser.
//
// Visibility lives in ShellState.networkPanelOpen so the home menu
// can open this window (cross-file ids don't see each other).
PanelWindow {
    id: root

    visible: ShellState.networkPanelOpen

    onVisibleChanged: {
        if (visible) {
            searchField.text = "";
            searchField.forceActiveFocus();
            NetworkDevicesService.scan();
        }
    }

    // Keybinds: qs ipc call network toggle
    IpcHandler {
        target: "network"

        function toggle(): void { ShellState.networkPanelOpen = !ShellState.networkPanelOpen }
        function open(): void { ShellState.networkPanelOpen = true }
        function close(): void { ShellState.networkPanelOpen = false }
    }

    // Auto-refresh while the panel is open
    Timer {
        interval: 30000
        running: root.visible
        repeat: true
        onTriggered: NetworkDevicesService.scan()
    }

    function displayName(d) {
        let n = (d.name || "").replace(/\.fritz\.box$/i, "").replace(/\.local$/i, "");
        if (n === "_gateway") n = "";
        return n;
    }

    function ipKey(ip) {
        return ip.split(".").map(x => parseInt(x, 10));
    }

    // Subsequence fuzzy match; returns score or -1 for no match
    function fuzzyScore(query, text) {
        query = query.toLowerCase();
        text = text.toLowerCase();
        if (query === "") return 1;
        let score = 0, ti = 0, streak = 0;
        for (let qi = 0; qi < query.length; qi++) {
            const idx = text.indexOf(query[qi], ti);
            if (idx === -1) return -1;
            if (idx === ti) {
                streak++;
                score += 2 + streak;          // consecutive chars
            } else {
                streak = 0;
                if (idx === 0 || /[^a-z0-9]/.test(text[idx - 1]))
                    score += 4;               // word start
                else
                    score += 1;
            }
            ti = idx + 1;
        }
        return score - text.length * 0.01;
    }

    readonly property var filtered: {
        const q = searchField.text.trim();
        const out = [];
        for (const d of NetworkDevicesService.devices) {
            const hay = (d.name || "") + " " + d.ip + " " + d.mac;
            const s = root.fuzzyScore(q, hay);
            if (s >= 0) out.push({ d: d, s: s });
        }
        out.sort((a, b) =>
            (b.d.online - a.d.online)
            || (b.s - a.s)
            || (root.ipKey(a.d.ip) < root.ipKey(b.d.ip) ? -1 : 1));
        return out.map(o => o.d);
    }

    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true

    focusable: true
    color: Theme.backdrop

    HyprlandFocusGrab {
        windows: [root]
        active: root.visible
        onCleared: ShellState.networkPanelOpen = false
    }

    // Backdrop click-to-close (MouseArea, not TapHandler — same reason
    // as PowerMenu: a click on a row would also hit a passive handler)
    MouseArea {
        anchors.fill: parent
        onClicked: ShellState.networkPanelOpen = false
    }

    Rectangle {
        id: card
        property int padding: 18

        width: 660
        height: column.implicitHeight + card.padding * 2
        anchors.centerIn: parent
        color: Theme.background
        radius: 14
        border.color: Theme.foreground
        border.width: 1

        focus: true
        Keys.onEscapePressed: ShellState.networkPanelOpen = false

        // Absorb clicks on the card so they don't reach the backdrop closer
        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        ColumnLayout {
            id: column
            anchors.centerIn: parent
            width: parent.width - card.padding * 2
            spacing: 12

            // ── Header ──
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Text {
                    text: "\uF1EB"
                    color: Theme.mainAccent
                    font { family: Theme.fontFamily; pixelSize: 16 }
                }

                Text {
                    text: "Network devices"
                    color: Theme.foreground
                    font { family: Theme.fontFamily; pixelSize: 14; bold: true }
                }

                Text {
                    readonly property int onlineCount:
                        NetworkDevicesService.devices.filter(d => d.online).length
                    text: NetworkDevicesService.scanning
                          ? "scanning…"
                          : onlineCount + " online / " + NetworkDevicesService.devices.length
                    color: Theme.dimForeground
                    font { family: Theme.fontFamily; pixelSize: 11 }
                }

                Item { Layout.fillWidth: true }

                // Rescan
                Rectangle {
                    implicitWidth: 28
                    implicitHeight: 28
                    radius: 6
                    color: rescanHover.hovered ? Theme.hoverOverlay : "transparent"

                    HoverHandler {
                        id: rescanHover
                        cursorShape: Qt.PointingHandCursor
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: NetworkDevicesService.scan()
                    }
                    Text {
                        anchors.centerIn: parent
                        text: "\uF021"           // refresh
                        visible: !NetworkDevicesService.scanning
                        color: Theme.dimForeground
                        font { family: Theme.fontFamily; pixelSize: 13 }
                    }
                }
            }

            // ── Search ──
            Rectangle {
                id: searchBg
                Layout.fillWidth: true
                implicitHeight: 36
                radius: 8
                color: searchField.activeFocus ? Theme.hoverOverlay : Theme.mainAccentSubtle

                TextField {
                    id: searchField
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    background: null
                    placeholderText: "Search devices… (name, ip, mac)"
                    placeholderTextColor: Theme.dimForeground
                    color: Theme.foreground
                    font { family: Theme.fontFamily; pixelSize: 13 }
                    selectByMouse: true

                    Keys.onEscapePressed: ShellState.networkPanelOpen = false
                    Keys.onReturnPressed: {
                        // Enter opens the top match
                        if (root.filtered.length > 0)
                            Quickshell.execDetached(["xdg-open", "http://" + root.filtered[0].ip]);
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
                    radius: 8
                    color: rowHover.hovered ? Theme.hoverOverlay : "transparent"

                    Behavior on color { ColorAnimation { duration: 100 } }

                    HoverHandler {
                        id: rowHover
                        cursorShape: Qt.PointingHandCursor
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: Quickshell.execDetached(["xdg-open", "http://" + dev.modelData.ip])
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

                            Text {
                                Layout.fillWidth: true
                                text: root.displayName(dev.modelData) || "Unknown device"
                                color: Theme.foreground
                                font { family: Theme.fontFamily; pixelSize: 13 }
                                elide: Text.ElideRight
                            }

                            Text {
                                Layout.fillWidth: true
                                text: dev.modelData.ip + (dev.modelData.mac ? "  ·  " + dev.modelData.mac : "")
                                color: Theme.dimForeground
                                font { family: Theme.fontFamily; pixelSize: 11 }
                                elide: Text.ElideRight
                            }
                        }

                        Text {
                            text: dev.modelData.online ? "online" : "seen"
                            color: dev.modelData.online ? Theme.green : Theme.dimForeground
                            font { family: Theme.fontFamily; pixelSize: 11 }
                        }
                    }
                }
            }

            // Empty state (only when there ARE devices but no matches)
            Text {
                visible: root.filtered.length === 0 && NetworkDevicesService.devices.length > 0
                text: "no devices match '" + searchField.text + "'"
                color: Theme.dimForeground
                font { family: Theme.fontFamily; pixelSize: 12 }
                Layout.alignment: Qt.AlignHCenter
            }

            // ── Footer ──
            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: NetworkDevicesService.devices.length === 0 && NetworkDevicesService.scanning
                          ? "first scan takes a few seconds…"
                          : "click a device to open it in your browser · Esc to close"
                    color: Theme.dimForeground
                    font { family: Theme.fontFamily; pixelSize: 11 }
                }

                Item { Layout.fillWidth: true }

                // scanning spinner
                Text {
                    visible: NetworkDevicesService.scanning
                    color: Theme.dimForeground
                    font { family: Theme.fontFamily; pixelSize: 11 }

                    property var frames: ["●○○", "○●○", "○○●", "○●○"]
                    property int frame: 0
                    text: frames[frame]

                    Timer {
                        running: parent.visible
                        interval: 400
                        repeat: true
                        onTriggered: parent.frame = (parent.frame + 1) % parent.frames.length
                    }
                }
            }
        }
    }
}
