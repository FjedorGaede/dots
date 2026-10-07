import QtQuick
import QtQuick.Layouts

import '../../lib/dates.js' as Dates
import '../../lib/icons.js' as Icons
import qs.components
import qs.config
import qs.services

// Month calendar + day agenda — right-click the clock (`qs ipc call calendar
// toggle`). Custom-built: Qt has no calendar widget in Qt6 (Qt Labs Calendar
// was dropped), so this is a plain Grid with Date math. Weeks start Monday,
// ISO week numbers on the left, today is highlighted with the accent,
// adjacent-month days are shown dimmed, colored dots = calendars with events.
// Events come from CalendarService (Google accounts); clicking one opens it
// in Google Calendar for editing, right-clicking one opens a menu (join in
// Teams / Google Meet, open, hide from the bar), double-clicking a day opens
// that day.
// ⚙ swaps the agenda for the calendar settings (show/hide per calendar) —
// a view inside this popup, not a second popup: a nested grabFocus popup
// would steal the focus grab and close this one.
PopupPanel {
    id: calendarPopup
    minWidth: 280

    // Current date, bound to the bar clock's SystemClock → the today
    // highlight moves at midnight
    property date today: new Date()
    property date viewMonth: Dates.firstOfMonth(new Date())  // reset on open
    property date selected: new Date()                        // agenda day, reset on open
    property bool showSettings: false                         // ⚙ view, reset on open

    // Right-click menu: the event it acts on (null = closed) + where it opens
    property var menuEvent: null
    property point menuPos: Qt.point(0, 0)

    function showMenu(ev, item, pos) {
        menuPos = item.mapToItem(menuLayer, pos.x, pos.y);
        menuEvent = ev;
    }

    // Calendar settings: calendars grouped by account, in sync order
    readonly property var accountGroups: {
        const groups = [];
        for (const cal of CalendarService.calendarList) {
            let g = groups.find(x => x.account === cal.account);
            if (!g) groups.push(g = { account: cal.account ?? "", cals: [] });
            g.cals.push(cal);
        }
        return groups;
    }

    readonly property int cellWidth: 36
    readonly property int weekColumnWidth: 26
    readonly property int agendaWidth: 290

    // Some locales have no standalone month names → fallback to format
    function monthName(d) {
        // QML Locale month functions are 0-based (unlike C++ QLocale): 8 = September
        const name = Qt.locale().standaloneMonthName(d.getMonth());
        return name && name.length > 0 ? name : Qt.formatDate(d, "MMMM");
    }

    function select(d) {
        selected = d;
        if (d.getMonth() !== viewMonth.getMonth() || d.getFullYear() !== viewMonth.getFullYear())
            viewMonth = Dates.firstOfMonth(d);
    }

    function dayTitle(d) {
        if (Dates.sameDay(d, today)) return "Today";
        if (Dates.sameDay(d, Dates.addDays(today, 1))) return "Tomorrow";
        if (Dates.sameDay(d, Dates.addDays(today, -1))) return "Yesterday";
        return Qt.formatDate(d, "dddd, d MMMM");
    }

    function openEvent(ev) { CalendarService.open(ev); calendarPopup.visible = false; }
    // Teams links open in the Teams web app, everything else in the browser
    function joinEvent(ev) { CalendarService.join(ev); calendarPopup.visible = false; }
    function openDay(d)    { CalendarService.openDay(d); calendarPopup.visible = false; }
    function connect(email) { CalendarService.connect(email); calendarPopup.visible = false; }

    readonly property var allDay: CalendarService.eventsOn(selected).filter(ev => ev.allDay)

    // Timed events of the selected day, with a "now" line when it's today —
    // only in a gap between events: while one is running, that event IS now
    // (highlighted + progress bar), a line below it would look misplaced
    readonly property var agenda: {
        const evs = CalendarService.eventsOn(selected).filter(ev => !ev.allDay);
        const t = CalendarService.now.getTime();
        if (!Dates.sameDay(selected, today) || evs.length === 0
                || evs.some(ev => ev.start <= t && t < ev.end))
            return evs.map(ev => ({ ev: ev }));
        const items = [];
        let marked = false;
        for (const ev of evs) {
            if (!marked && ev.start > t) { items.push({ now: true }); marked = true; }
            items.push({ ev: ev });
        }
        if (!marked) items.push({ now: true });
        return items;
    }

    // Agenda auto-scroll to "now": the running event, or the now line in a
    // gap. Follows it (layout changes, next event starting) until the user
    // scrolls by hand; reset on open and on picking another day.
    property Item nowItem: null
    property bool userScrolled: false
    property real autoScrollY: 0

    function claimNow(item, isNow) {
        if (isNow) nowItem = item;
        else if (nowItem === item) nowItem = null;
    }

    function scrollToNow() {
        if (!userScrolled) Qt.callLater(doScrollToNow);
    }

    function doScrollToNow() {
        if (userScrolled || !visible) return;
        if (nowItem) agendaScroll.scrollTo(nowItem, 8);
        else agendaScroll.contentY = 0;
        autoScrollY = agendaScroll.contentY;
    }

    function resetScroll() {
        userScrolled = false;
        scrollToNow();
    }

    onNowItemChanged: scrollToNow()
    onSelectedChanged: { menuEvent = null; resetScroll(); }
    onShowSettingsChanged: menuEvent = null

    // Open state in PanelService (`qs ipc call calendar …`), synced both ways
    open: PanelService.isOpenOn("calendar", screenName)
    onVisibleChanged: {
        PanelService.setOpen("calendar", visible, screenName);
        menuEvent = null;
        if (visible) {
            viewMonth = Dates.firstOfMonth(today);
            selected = today;
            showSettings = false;
            CalendarService.refreshIfStale();
            resetScroll();
        }
    }

    // Plain Item, not a layout: the event menu floats above the content
    Item {
        id: menuLayer
        implicitWidth: mainRow.implicitWidth
        implicitHeight: mainRow.implicitHeight

        RowLayout {
            id: mainRow
            spacing: 10

            // ════════ Month ════════
            ColumnLayout {
                id: monthColumn
                Layout.alignment: Qt.AlignTop
                spacing: 8

                // One month per wheel notch (120 units); touchpads send many small
                // deltas per swipe → accumulate. Horizontal scrolling (y = 0) is ignored.
                WheelHandler {
                    property real acc: 0
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: (event) => {
                        const dy = event.angleDelta.y;
                        if (dy === 0) return;
                        if ((dy > 0) !== (acc > 0)) acc = 0;  // direction change
                        acc += dy;
                        while (Math.abs(acc) >= 120) {
                            const step = acc > 0 ? -1 : 1;
                            calendarPopup.viewMonth = Dates.addMonths(calendarPopup.viewMonth, step);
                            acc += step * 120;
                        }
                    }
                }

                // ── Header: < Month Year > ──
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    GhostButton {
                        implicitWidth: 24
                        implicitHeight: 24
                        rowContent: false
                        text: "<"
                        textSize: Theme.fontSize.base
                        bold: true
                        onClicked: calendarPopup.viewMonth = Dates.addMonths(calendarPopup.viewMonth, -1)
                    }

                    // Click → back to today
                    StyledText {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: calendarPopup.monthName(calendarPopup.viewMonth)
                              + " " + calendarPopup.viewMonth.getFullYear()
                        color: Theme.mainAccent
                        font { pixelSize: Theme.fontSize.lg; bold: true }

                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: calendarPopup.select(calendarPopup.today) }
                    }

                    GhostButton {
                        implicitWidth: 24
                        implicitHeight: 24
                        rowContent: false
                        text: ">"
                        textSize: Theme.fontSize.base
                        bold: true
                        onClicked: calendarPopup.viewMonth = Dates.addMonths(calendarPopup.viewMonth, +1)
                    }
                }

                // ── Weekday header (Monday-first, locale-aware) ──
                Row {
                    Layout.alignment: Qt.AlignHCenter

                    Item { width: calendarPopup.weekColumnWidth; height: 1 }

                    Repeater {
                        model: 7
                        StyledText {
                            required property int index
                            text: Qt.locale().dayName(index + 1, Locale.ShortFormat).slice(0, 2)
                            color: Theme.dimForeground
                            font.pixelSize: Theme.fontSize.sm
                            horizontalAlignment: Text.AlignHCenter
                            width: calendarPopup.cellWidth
                        }
                    }
                }

                // ── Day grid: 6 weeks × (ISO week number + 7 days) ──
                Grid {
                    id: dayGrid
                    columns: 8
                    Layout.alignment: Qt.AlignHCenter

                    readonly property int daysInMonth: Dates.daysInMonth(calendarPopup.viewMonth)
                    readonly property int firstWeekday: Dates.mondayIndex(calendarPopup.viewMonth)

                    Repeater {
                        model: 48

                        Item {
                            id: cell

                            required property int index

                            readonly property bool isWeek: index % 8 === 0
                            // Week cells take their row's Monday (→ week number)
                            readonly property int dayNumber: Math.floor(index / 8) * 7
                                + Math.max(0, index % 8 - 1) - dayGrid.firstWeekday + 1
                            readonly property bool inMonth:
                                dayNumber >= 1 && dayNumber <= dayGrid.daysInMonth
                            readonly property date cellDate:
                                new Date(calendarPopup.viewMonth.getFullYear(),
                                         calendarPopup.viewMonth.getMonth(), dayNumber)
                            readonly property bool isToday: !isWeek && Dates.sameDay(cellDate, calendarPopup.today)
                            readonly property bool isSelected: !isWeek && Dates.sameDay(cellDate, calendarPopup.selected)
                            // One dot per calendar with events that day (max 3)
                            readonly property var dots: {
                                if (isWeek) return [];
                                const seen = [];
                                for (const ev of CalendarService.eventsOn(cellDate))
                                    if (seen.indexOf(ev.cal) < 0) seen.push(ev.cal);
                                return seen.slice(0, 3);
                            }

                            width: isWeek ? calendarPopup.weekColumnWidth : calendarPopup.cellWidth
                            height: 34

                            StyledText {
                                visible: cell.isWeek
                                anchors.centerIn: parent
                                anchors.verticalCenterOffset: -3
                                text: Dates.isoWeek(cell.cellDate)
                                color: Theme.overlay
                                font.pixelSize: Theme.fontSize.xs
                            }

                            Rectangle {
                                visible: cell.isToday || cell.isSelected || dayHover.hovered
                                anchors.centerIn: parent
                                width: 30
                                height: 30
                                radius: Theme.radius.sm
                                color: cell.isToday ? Theme.mainAccentSubtle
                                     : cell.isSelected ? Theme.alpha(Theme.foreground, 0.1)
                                     : Theme.hoverOverlay
                                border.width: cell.isSelected ? 1 : 0
                                border.color: cell.isToday ? Theme.mainAccent : Theme.dimForeground
                            }

                            StyledText {
                                visible: !cell.isWeek
                                anchors.centerIn: parent
                                anchors.verticalCenterOffset: -3
                                text: cell.cellDate.getDate()
                                color: !cell.inMonth ? Theme.overlay
                                    : cell.isToday ? Theme.mainAccent : Theme.foreground
                                font {
                                    pixelSize: Theme.fontSize.md
                                    bold: cell.isToday
                                }
                            }

                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 6
                                spacing: 3
                                opacity: cell.inMonth ? 1 : 0.4

                                Repeater {
                                    model: cell.dots
                                    Rectangle {
                                        required property string modelData
                                        width: 4
                                        height: 4
                                        radius: 2
                                        color: CalendarService.colorOf(modelData)
                                    }
                                }
                            }

                            HoverHandler {
                                id: dayHover
                                enabled: !cell.isWeek
                                cursorShape: Qt.PointingHandCursor
                            }
                            TapHandler {
                                enabled: !cell.isWeek
                                onTapped: calendarPopup.select(cell.cellDate)
                                onDoubleTapped: calendarPopup.openDay(cell.cellDate)
                            }
                        }
                    }
                }
            }

            VerticalDivider {
                implicitWidth: 1
                dividerColor: Theme.alpha(Theme.foreground, 0.12)
            }

            // ════════ Day agenda ════════
            ColumnLayout {
                Layout.preferredWidth: calendarPopup.agendaWidth
                Layout.minimumHeight: monthColumn.implicitHeight
                Layout.alignment: Qt.AlignTop
                spacing: 6

                // ── Header: day (or "Calendars") · today · settings · refresh · open the day in Google ──
                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 24
                    spacing: 2

                    StyledText {
                        Layout.fillWidth: true
                        text: calendarPopup.showSettings ? "Calendars"
                                                         : calendarPopup.dayTitle(calendarPopup.selected)
                        color: Theme.mainAccent
                        elide: Text.ElideRight
                        font { pixelSize: Theme.fontSize.lg; bold: true }
                    }

                    // Back to today (month + agenda); always shown so the row never shifts
                    GhostButton {
                        implicitWidth: 24
                        implicitHeight: 24
                        rowContent: false
                        icon: Icons.calendar.today
                        iconSize: Theme.fontSize.base
                        onClicked: {
                            calendarPopup.select(calendarPopup.today);
                            calendarPopup.showSettings = false;
                        }
                    }

                    GhostButton {
                        implicitWidth: 24
                        implicitHeight: 24
                        rowContent: false
                        icon: calendarPopup.showSettings ? Icons.calendar.back : Icons.calendar.settings
                        iconSize: Theme.fontSize.base
                        onClicked: calendarPopup.showSettings = !calendarPopup.showSettings
                    }

                    DotsSpinner {
                        visible: CalendarService.syncing
                        font.pixelSize: Theme.fontSize.xs
                    }

                    GhostButton {
                        visible: !CalendarService.syncing
                        implicitWidth: 24
                        implicitHeight: 24
                        rowContent: false
                        icon: Icons.calendar.refresh
                        iconSize: Theme.fontSize.base
                        onClicked: CalendarService.refresh()
                    }

                    GhostButton {
                        visible: !calendarPopup.showSettings
                        implicitWidth: 24
                        implicitHeight: 24
                        rowContent: false
                        icon: Icons.calendar.external
                        iconSize: Theme.fontSize.base
                        onClicked: calendarPopup.openDay(calendarPopup.selected)
                    }
                }

                // ── Calendar settings: checkbox per calendar, grouped by account ──
                ScrollColumn {
                    visible: calendarPopup.showSettings
                    maxHeight: 320
                    spacing: 2

                    Repeater {
                        model: calendarPopup.accountGroups

                        ColumnLayout {
                            id: group
                            required property var modelData
                            required property int index
                            Layout.fillWidth: true
                            Layout.topMargin: index > 0 ? 8 : 0
                            spacing: 2

                            StyledText {
                                Layout.fillWidth: true
                                Layout.leftMargin: 6
                                text: group.modelData.account
                                color: Theme.dimForeground
                                elide: Text.ElideRight
                                font.pixelSize: Theme.fontSize.sm
                            }

                            Repeater {
                                model: group.modelData.cals

                                Rectangle {
                                    id: calRow
                                    required property var modelData
                                    readonly property bool shown: CalendarService.isVisible(modelData)

                                    Layout.fillWidth: true
                                    implicitHeight: 26
                                    radius: Theme.radius.sm
                                    color: calHover.hovered ? Theme.hoverOverlay : "transparent"

                                    HoverHandler { id: calHover; cursorShape: Qt.PointingHandCursor }
                                    TapHandler { onTapped: CalendarService.setVisible(calRow.modelData, !calRow.shown) }

                                    RowLayout {
                                        anchors { fill: parent; leftMargin: 6; rightMargin: 6 }
                                        spacing: 8

                                        // Checkbox in the calendar's color
                                        Rectangle {
                                            implicitWidth: 14
                                            implicitHeight: 14
                                            radius: 3
                                            color: calRow.shown ? calRow.modelData.color : "transparent"
                                            border.width: 1.5
                                            border.color: calRow.modelData.color

                                            StyledText {
                                                visible: calRow.shown
                                                anchors.centerIn: parent
                                                text: Icons.calendar.check
                                                color: Theme.background
                                                font { pixelSize: Theme.fontSize.sm; bold: true }
                                            }
                                        }

                                        StyledText {
                                            Layout.fillWidth: true
                                            text: calRow.modelData.name
                                            color: calRow.shown ? Theme.foreground : Theme.dimForeground
                                            elide: Text.ElideRight
                                            font.pixelSize: Theme.fontSize.md
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                ConnectButton {
                    visible: calendarPopup.showSettings && CalendarService.configured
                    Layout.topMargin: 4
                    text: "+ Add Google account"
                    onClicked: calendarPopup.connect("")
                }

                ScrollColumn {
                    id: agendaScroll
                    visible: !calendarPopup.showSettings
                    maxHeight: 320
                    spacing: 3

                    // Any scroll we didn't do ourselves = the user's → stop following
                    onContentYChanged: if (Math.abs(contentY - calendarPopup.autoScrollY) > 1)
                                           calendarPopup.userScrolled = true

                    // All-day events: filled chips (timed events below: side bar + times)
                    Repeater {
                        model: calendarPopup.allDay
                        AllDayChip {
                            required property var modelData
                            ev: modelData
                        }
                    }

                    Rectangle {
                        visible: calendarPopup.allDay.length > 0 && calendarPopup.agenda.some(i => i.ev)
                        Layout.fillWidth: true
                        Layout.topMargin: 4
                        Layout.bottomMargin: 4
                        implicitHeight: 1
                        color: Theme.alpha(Theme.foreground, 0.12)
                    }

                    Repeater {
                        model: calendarPopup.agenda

                        Item {
                            id: agendaItem
                            required property var modelData
                            Layout.fillWidth: true
                            implicitHeight: modelData.now ? 14 : row.implicitHeight

                            readonly property bool isNow: !!modelData.now
                                || (!!modelData.ev && CalendarService.isCurrent(modelData.ev))
                            onIsNowChanged: calendarPopup.claimNow(agendaItem, isNow)
                            onYChanged: if (isNow) calendarPopup.scrollToNow()
                            Component.onCompleted: if (isNow) calendarPopup.claimNow(agendaItem, true)
                            Component.onDestruction: calendarPopup.claimNow(agendaItem, false)

                            // Now line
                            RowLayout {
                                visible: !!agendaItem.modelData.now
                                anchors.fill: parent
                                spacing: 6

                                StyledText {
                                    text: Qt.formatTime(CalendarService.now, "hh:mm")
                                    color: Theme.mainAccent
                                    font { pixelSize: Theme.fontSize.xs; bold: true }
                                }
                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: 1
                                    color: Theme.mainAccent
                                }
                            }

                            EventRow {
                                id: row
                                visible: !agendaItem.modelData.now
                                width: parent.width
                                ev: agendaItem.modelData.ev ?? null
                            }
                        }
                    }

                    StyledText {
                        readonly property bool synced: CalendarService.inRange(calendarPopup.selected)
                        visible: CalendarService.configured
                                 && calendarPopup.allDay.length === 0
                                 && !calendarPopup.agenda.some(i => i.ev)
                        Layout.fillWidth: true
                        Layout.topMargin: 12
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                        // Outside the synced window there's no data, not "no events"
                        text: synced ? "No events" : "Not synced this far"
                        color: Theme.dimForeground
                        font.pixelSize: Theme.fontSize.md
                    }
                }

                Item { Layout.fillHeight: true }

                // ── Synced-window note / setup hint / sync errors ──
                StyledText {
                    // Viewed month reaches outside the synced window → its empty
                    // days mean "no data", not "no events"
                    readonly property date monthEnd: Dates.addMonths(calendarPopup.viewMonth, 1)
                    visible: !calendarPopup.showSettings && CalendarService.rangeEnd > 0
                             && (calendarPopup.viewMonth.getTime() < CalendarService.rangeStart
                                 || monthEnd.getTime() > CalendarService.rangeEnd)
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    text: "Synced: " + Qt.formatDate(new Date(CalendarService.rangeStart), "d MMM yyyy")
                          + " – " + Qt.formatDate(new Date(CalendarService.rangeEnd - 1), "d MMM yyyy")
                    color: Theme.dimForeground
                    font.pixelSize: Theme.fontSize.sm
                }

                // Not connected → button instead of a command to remember. It runs
                // `dots calendar [client &&] login` in a terminal; the login ends
                // with a sync, so this disappears by itself.
                ColumnLayout {
                    visible: !CalendarService.configured
                    Layout.fillWidth: true
                    spacing: 6

                    StyledText {
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                        text: CalendarService.hasClient
                            ? "No Google account connected."
                            : "No Google account connected. First download the Desktop OAuth "
                              + "client JSON (Cloud console → Google Auth Platform → Clients) "
                              + "into ~/Downloads."
                        color: Theme.dimForeground
                        font.pixelSize: Theme.fontSize.sm
                    }

                    ConnectButton {
                        text: "Connect Google account"
                        onClicked: calendarPopup.connect("")
                    }
                }

                // Expired logins (7-day "Testing" expiry, revoked access)
                Repeater {
                    model: CalendarService.expired

                    ColumnLayout {
                        required property string modelData
                        Layout.fillWidth: true
                        spacing: 4

                        StyledText {
                            Layout.fillWidth: true
                            text: Icons.calendar.warning + " Login expired: " + parent.modelData
                            color: Theme.warning
                            wrapMode: Text.Wrap
                            font.pixelSize: Theme.fontSize.sm
                        }

                        ConnectButton {
                            text: "Log in again"
                            onClicked: calendarPopup.connect(parent.modelData)
                        }
                    }
                }

                StyledText {
                    visible: CalendarService.errors.length > 0
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    maximumLineCount: 3
                    elide: Text.ElideRight
                    text: Icons.calendar.warning + " " + CalendarService.errors.join("\n")
                    color: Theme.error
                    font.pixelSize: Theme.fontSize.sm
                }
            }
        }

        // ── Right-click menu of an event: Join (Teams / Meet / other) · Open · Hide ──
        // Inside this popup, not a PopupPanel of its own: a nested grabFocus
        // popup would steal the focus grab and close this one. Clicking (or
        // scrolling) anywhere else closes it.
        MouseArea {
            visible: calendarPopup.menuEvent !== null
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: calendarPopup.menuEvent = null
            onWheel: calendarPopup.menuEvent = null
        }

        Rectangle {
            id: eventMenu
            visible: calendarPopup.menuEvent !== null
            x: Math.max(0, Math.min(calendarPopup.menuPos.x, menuLayer.width - width))
            y: Math.max(0, Math.min(calendarPopup.menuPos.y, menuLayer.height - height))
            width: Math.max(200, menuColumn.implicitWidth + 10)
            height: menuColumn.implicitHeight + 10
            radius: Theme.radius.sm
            color: Theme.background
            border.width: 1
            border.color: Theme.alpha(Theme.foreground, 0.2)

            ColumnLayout {
                id: menuColumn
                anchors { fill: parent; margins: 5 }
                spacing: 2

                // exclusiveGrab: the buttons sit above the click-away MouseArea
                GhostButton {
                    visible: !!calendarPopup.menuEvent?.join
                    Layout.fillWidth: true
                    exclusiveGrab: true
                    leftAligned: true
                    icon: Icons.calendar.video
                    text: CalendarService.joinLabel(calendarPopup.menuEvent)
                    onClicked: calendarPopup.joinEvent(calendarPopup.menuEvent)
                }

                GhostButton {
                    Layout.fillWidth: true
                    exclusiveGrab: true
                    leftAligned: true
                    icon: Icons.calendar.external
                    text: "Open in Google Calendar"
                    onClicked: calendarPopup.openEvent(calendarPopup.menuEvent)
                }

                GhostButton {
                    visible: !!calendarPopup.menuEvent && !calendarPopup.menuEvent.allDay
                             && !CalendarService.isPast(calendarPopup.menuEvent)
                    Layout.fillWidth: true
                    exclusiveGrab: true
                    leftAligned: true
                    icon: Icons.calendar.hide
                    text: "Hide from the bar"
                    onClicked: {
                        CalendarService.dismiss(calendarPopup.menuEvent);
                        calendarPopup.menuEvent = null;
                    }
                }
            }
        }
    }

    // Accent action button (connect / log in again / add account)
    component ConnectButton: GhostButton {
        Layout.alignment: Qt.AlignLeft
        bold: true
        textSize: Theme.fontSize.sm
        idleColor: Theme.mainAccentSubtle
        contentColor: Theme.mainAccent
    }

    // All-day event: compact chip filled with the calendar color, title only
    // (+ the span for multi-day events)
    component AllDayChip: Rectangle {
        id: chip

        property var ev: null
        readonly property color calColor: ev ? CalendarService.colorOf(ev.cal) : "transparent"
        readonly property string span: {
            if (!ev) return "";
            const s = new Date(ev.start), last = Dates.addDays(new Date(ev.end), -1);
            return Dates.sameDay(s, last) ? ""
                 : Qt.formatDate(s, "d MMM") + " – " + Qt.formatDate(last, "d MMM");
        }

        Layout.fillWidth: true
        implicitHeight: 24
        radius: Theme.radius.sm
        color: Theme.alpha(calColor, chipHover.hovered ? 0.4 : 0.25)
        border.width: 1
        border.color: Theme.alpha(calColor, 0.5)

        HoverHandler { id: chipHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: if (chip.ev) calendarPopup.openEvent(chip.ev) }
        TapHandler {
            acceptedButtons: Qt.RightButton
            onTapped: (point) => { if (chip.ev) calendarPopup.showMenu(chip.ev, chip, point.position) }
        }

        RowLayout {
            anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
            spacing: 6

            StyledText {
                Layout.fillWidth: true
                text: chip.ev?.title ?? ""
                elide: Text.ElideRight
                font { pixelSize: Theme.fontSize.md; bold: true }
            }

            StyledText {
                visible: chip.span !== ""
                text: chip.span
                color: Theme.fadedForeground
                font.pixelSize: Theme.fontSize.xs
            }
        }
    }

    // Timed event: color bar · title / time + countdown / location · Join
    component EventRow: Rectangle {
        id: eventRow

        property var ev: null
        readonly property bool past: ev !== null && CalendarService.isPast(ev)
        readonly property bool current: ev !== null && CalendarService.isCurrent(ev)

        readonly property string timeText: {
            if (!ev) return "";
            const s = new Date(ev.start), e = new Date(ev.end);
            const day = calendarPopup.selected;
            const fmt = d => Dates.sameDay(d, day) ? Qt.formatTime(d, "hh:mm")
                                                  : Qt.formatDateTime(d, "ddd hh:mm");
            const t = CalendarService.now.getTime();
            let text = fmt(s) + " – " + fmt(e);
            if (current) text += " · " + Dates.formatDuration(ev.end - t) + " left";
            else if (ev.start > t && ev.start - t < 24 * 3600000)
                text += " · in " + Dates.formatDuration(ev.start - t);
            return text;
        }

        Layout.fillWidth: true
        implicitHeight: content.implicitHeight + (current ? 20 : 10)  // + progress bar
        radius: Theme.radius.sm
        color: rowHover.hovered ? Theme.hoverOverlay
             : current ? Theme.mainAccentSubtle : "transparent"
        opacity: past && !rowHover.hovered ? 0.45 : 1

        HoverHandler { id: rowHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: if (eventRow.ev) calendarPopup.openEvent(eventRow.ev) }
        TapHandler {
            acceptedButtons: Qt.RightButton
            onTapped: (point) => { if (eventRow.ev) calendarPopup.showMenu(eventRow.ev, eventRow, point.position) }
        }

        // Running event: how far through it we are (replaces the now line)
        Rectangle {
            id: progressTrack
            visible: eventRow.current
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom
                      leftMargin: 8; rightMargin: 8; bottomMargin: 5 }
            height: 3
            radius: 1.5
            color: Theme.alpha(Theme.mainAccent, 0.2)

            Rectangle {
                readonly property real progress: !eventRow.ev ? 0 : Math.min(1, Math.max(0,
                    (CalendarService.now.getTime() - eventRow.ev.start) / (eventRow.ev.end - eventRow.ev.start)))
                width: parent.width * progress
                height: parent.height
                radius: parent.radius
                color: Theme.mainAccent
            }
        }

        RowLayout {
            id: content
            anchors {
                left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter
                leftMargin: 6; rightMargin: 6
                verticalCenterOffset: eventRow.current ? -5 : 0  // room for the progress bar
            }
            spacing: 8

            Rectangle {
                Layout.fillHeight: true
                implicitWidth: 3
                radius: 1.5
                color: eventRow.ev ? CalendarService.colorOf(eventRow.ev.cal) : "transparent"
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                StyledText {
                    Layout.fillWidth: true
                    text: eventRow.ev?.title ?? ""
                    elide: Text.ElideRight
                    font { pixelSize: Theme.fontSize.md; bold: eventRow.current }
                }

                StyledText {
                    Layout.fillWidth: true
                    text: eventRow.timeText
                    color: eventRow.current ? Theme.mainAccent : Theme.dimForeground
                    elide: Text.ElideRight
                    font.pixelSize: Theme.fontSize.sm
                }

                StyledText {
                    // Meeting URLs as location are covered by the Join button
                    visible: text !== "" && !/^https?:/.test(text)
                    Layout.fillWidth: true
                    text: eventRow.ev?.location ?? ""
                    color: Theme.dimForeground
                    elide: Text.ElideRight
                    font.pixelSize: Theme.fontSize.sm
                }
            }

            GhostButton {
                visible: eventRow.ev !== null && CalendarService.canJoin(eventRow.ev)
                icon: Icons.calendar.video
                text: "Join"
                bold: true
                idleColor: Theme.mainAccentSubtle
                contentColor: Theme.mainAccent
                onClicked: calendarPopup.joinEvent(eventRow.ev)
            }
        }
    }
}
