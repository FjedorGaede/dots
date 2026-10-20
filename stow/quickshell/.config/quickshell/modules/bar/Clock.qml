import QtQuick
import QtQuick.Layouts
import Quickshell

import '../../lib/dates.js' as Dates
import '../../lib/icons.js' as Icons
import qs.components
import qs.config
import qs.modules.panels
import qs.services

RowLayout {
    id: clockItem

    StyledText {
        id: clockText
        property bool showDate: false
        // CalendarService.now = the shell's one minute clock (nothing shows seconds)
        text: Qt.formatDateTime(CalendarService.now, showDate ? "dddd - hh:mm - dd.MM.yyyy" : "hh:mm")
        font.pixelSize: Theme.fontSize.lg

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            onClicked: (mouse) => {
                if (mouse.button === Qt.RightButton) {
                    PanelService.toggle("calendar", calendarPopup.screenName);
                } else {
                    clockText.showDate = !clockText.showDate;
                }
            }
        }
    }

    // Upcoming event (CalendarService.leadMinutes before start until shortly
    // after): "● Standup in 8m", then just "● Standup" once it runs; the dot
    // is the calendar color. Clashing events → "+N" after it. Left click joins
    // the meeting / opens the event; right click or "+N" → menu listing every
    // announced event (join / open / hide each)
    RowLayout {
        id: announcement
        readonly property var evs: CalendarService.announcements
        readonly property var ev: CalendarService.announcement
        visible: ev !== null
        Layout.leftMargin: 4
        spacing: 5

        function openMenu() {
            announcementMenu.evs = announcement.evs;  // pinned: the menu acts on what was clicked
            announcementMenu.visible = !announcementMenu.visible;
        }

        Rectangle {
            implicitWidth: 6
            implicitHeight: 6
            radius: 3
            color: announcement.ev ? CalendarService.colorOf(announcement.ev.cal) : "transparent"
        }

        StyledText {
            id: announcementText
            Layout.maximumWidth: 260
            elide: Text.ElideRight
            text: {
                const ev = announcement.ev;
                if (!ev) return "";
                const left = ev.start - CalendarService.now.getTime();
                return left > 0 ? ev.title + " in " + Dates.formatDuration(left) : ev.title;
            }
            color: Theme.mainAccent
            font.pixelSize: Theme.fontSize.md

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: Qt.PointingHandCursor
                onClicked: (mouse) => {
                    const ev = announcement.ev;
                    if (!ev) return;
                    if (mouse.button === Qt.RightButton) announcement.openMenu();
                    else if (ev.join !== "") CalendarService.join(ev);
                    else CalendarService.open(ev);
                }
            }
        }

        // "+N": more events running / starting at the same time
        Rectangle {
            visible: announcement.evs.length > 1
            implicitWidth: moreText.implicitWidth + 10
            implicitHeight: moreText.implicitHeight + 2
            radius: Theme.radius.sm
            color: moreHover.hovered ? Theme.hoverOverlay : Theme.alpha(Theme.mainAccent, 0.15)

            StyledText {
                id: moreText
                anchors.centerIn: parent
                text: "+" + (announcement.evs.length - 1)
                color: Theme.mainAccent
                font { pixelSize: Theme.fontSize.sm; bold: true }
            }

            HoverHandler { id: moreHover; cursorShape: Qt.PointingHandCursor }
            TapHandler {
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onTapped: announcement.openMenu()
            }
        }
    }

    // Menu of the announcement: one section per announced event
    PopupPanel {
        id: announcementMenu
        property var evs: []
        anchorItem: announcement
        minWidth: 240

        // Several events: stay open on the rest (the bar moves on to the next)
        function hide(ev) {
            CalendarService.dismiss(ev);
            evs = evs.filter(e => e.id !== ev.id);
            if (evs.length === 0) visible = false;
        }

        Repeater {
            model: announcementMenu.evs

            ColumnLayout {
                id: section
                required property var modelData
                required property int index
                readonly property var ev: modelData
                Layout.fillWidth: true
                spacing: 2

                Divider {
                    visible: section.index > 0
                    Layout.bottomMargin: 3
                }

                // Calendar dot · title · time (only with more than one event)
                RowLayout {
                    visible: announcementMenu.evs.length > 1
                    Layout.fillWidth: true
                    Layout.leftMargin: 8
                    Layout.rightMargin: 8
                    spacing: 6

                    Rectangle {
                        implicitWidth: 6
                        implicitHeight: 6
                        radius: 3
                        color: CalendarService.colorOf(section.ev.cal)
                    }

                    StyledText {
                        Layout.fillWidth: true
                        Layout.maximumWidth: 220
                        elide: Text.ElideRight
                        text: section.ev.title
                        font { pixelSize: Theme.fontSize.sm; bold: true }
                    }

                    StyledText {
                        text: Qt.formatTime(new Date(section.ev.start), "hh:mm")
                            + "–" + Qt.formatTime(new Date(section.ev.end), "hh:mm")
                        color: Theme.dimForeground
                        font.pixelSize: Theme.fontSize.sm
                    }
                }

                GhostButton {
                    visible: !!section.ev.join
                    Layout.fillWidth: true
                    leftAligned: true
                    icon: Icons.calendar.video
                    text: CalendarService.joinLabel(section.ev)
                    onClicked: { CalendarService.join(section.ev); announcementMenu.visible = false; }
                }

                GhostButton {
                    Layout.fillWidth: true
                    leftAligned: true
                    icon: Icons.calendar.external
                    text: "Open in Google Calendar"
                    onClicked: { CalendarService.open(section.ev); announcementMenu.visible = false; }
                }

                GhostButton {
                    Layout.fillWidth: true
                    leftAligned: true
                    icon: Icons.calendar.hide
                    text: "Hide from the bar"
                    onClicked: announcementMenu.hide(section.ev)
                }
            }
        }
    }

    // Month calendar + agenda — right-click the clock
    CalendarPopup {
        id: calendarPopup
        anchorItem: clockItem
        today: CalendarService.now
    }
}
