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
    // after): "Standup in 8m", then just "Standup" once it runs. Left click
    // joins the meeting / opens the event; right click → menu (join / open / hide)
    StyledText {
        id: announcement
        readonly property var ev: CalendarService.announcement
        visible: ev !== null
        Layout.leftMargin: 4
        Layout.maximumWidth: 260
        elide: Text.ElideRight
        text: {
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
                if (mouse.button === Qt.RightButton) {
                    announcementMenu.ev = ev;  // pinned: the menu acts on what was clicked
                    announcementMenu.visible = !announcementMenu.visible;
                } else if (ev.join !== "") {
                    CalendarService.join(ev);
                } else {
                    CalendarService.open(ev);
                }
            }
        }
    }

    // Right-click menu of the announcement
    PopupPanel {
        id: announcementMenu
        property var ev: null
        anchorItem: announcement
        minWidth: 200

        GhostButton {
            visible: !!announcementMenu.ev?.join
            Layout.fillWidth: true
            icon: Icons.calendar.video
            text: "Join meeting"
            onClicked: { CalendarService.join(announcementMenu.ev); announcementMenu.visible = false; }
        }

        GhostButton {
            Layout.fillWidth: true
            icon: Icons.calendar.external
            text: "Open in Google Calendar"
            onClicked: { CalendarService.open(announcementMenu.ev); announcementMenu.visible = false; }
        }

        GhostButton {
            Layout.fillWidth: true
            icon: Icons.calendar.hide
            text: "Hide from the bar"
            onClicked: { CalendarService.dismiss(announcementMenu.ev); announcementMenu.visible = false; }
        }
    }

    // Month calendar + agenda — right-click the clock
    CalendarPopup {
        id: calendarPopup
        anchorItem: clockItem
        today: CalendarService.now
    }
}
