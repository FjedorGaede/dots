pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

import '../lib/dates.js' as Dates
import qs.config

// Google Calendar of every logged-in Google account (`dots calendar login`).
// scripts/gcal-sync.py fetches the events via the Calendar API into
// ~/.cache/quickshell/calendar-events.json; this service runs it every
// `syncMinutes` and watches the JSON. All calendars are synced; which ones
// are shown is the calendar settings (setVisible → Paths.calendarVisibility,
// default = checked in Google's sidebar).
//
// Event: { id, cal, title, location, allDay, start, end (epoch ms; all-day end
// is the exclusive local midnight), url (Google edit link), join (meet url) }
Singleton {
    id: root

    readonly property int syncMinutes: 5
    // Bar announcement: from this many minutes before an event starts until
    // it ends (or is hidden via right-click)
    readonly property int leadMinutes: 15
    // Join button: from this many minutes before start until the end
    readonly property int joinMinutes: 15

    property bool configured: true
    property bool hasClient: true  // OAuth client JSON installed (`dots calendar client`)
    property var expired: []       // accounts whose login expired → "Log in again"
    property var calendarList: []  // every calendar: { id, gid, account, name, color, selected }
    property var calendars: ({})   // id → calendar (with resolved color)
    property var events: []        // of visible calendars, sorted by start
    property var timedEvents: []   // `events` without all-day ones (announcement)
    property real maxTimedDuration: 0  // longest timed event → announcement search bound
    property var byDay: ({})       // Dates.dayKey → [event], all-day first
    property var visibility: ({})  // gid → bool, overrides the Google default
    property var dismissed: ({})   // event id → end ms: announcements hidden from the bar
    property var errors: []
    property real updated: 0
    // Synced window (gcal-sync.py PAST_DAYS / FUTURE_DAYS); outside it there
    // is no data, which is not the same as "no events"
    property real rangeStart: 0
    property real rangeEnd: 0
    readonly property bool syncing: syncProc.running

    // The shell's one minute clock: bar clock, popup, countdowns, announcement
    readonly property date now: clock.date

    // Bar announcement (timed events, minus the ones hidden via right-click):
    // the next event starting within leadMinutes wins — a long running event
    // must not hide an upcoming meeting — else the running event that started
    // last (the most specific one).
    readonly property var announcement: {
        const t = root.now.getTime();
        const evs = root.timedEvents;
        // Binary search (sorted by start): first event that can still be
        // running, i.e. start > t - longest duration
        let lo = 0, hi = evs.length;
        while (lo < hi) {
            const mid = (lo + hi) >> 1;
            if (evs[mid].start > t - root.maxTimedDuration) hi = mid; else lo = mid + 1;
        }
        let running = null;
        for (let i = lo; i < evs.length && evs[i].start - t <= root.leadMinutes * 60000; i++) {
            const ev = evs[i];
            if (t >= ev.end || ev.id in root.dismissed) continue;
            if (ev.start > t) return ev;  // upcoming — first one is the soonest
            running = ev;                 // running — later starts overwrite
        }
        return running;
    }

    function inRange(d) {
        const t = d.getTime();
        return root.rangeEnd === 0 || (t >= root.rangeStart && t < root.rangeEnd);
    }

    readonly property var palette: [Theme.blue, Theme.green, Theme.magenta,
                                    Theme.yellow, Theme.cyan, Theme.red]

    function colorOf(calId) {
        return root.calendars[calId]?.color ?? Theme.mainAccent;
    }

    function isVisible(cal) {
        return root.visibility[cal.gid] ?? cal.selected ?? true;
    }

    function setVisible(cal, value) {
        const next = Object.assign({}, root.visibility);
        next[cal.gid] = value;
        root.visibility = next;
        visibilityView.setText(JSON.stringify(next, null, 2));
        root.rebuild();
    }

    // Hide one event (this occurrence) from the bar; entries expire with the event
    function dismiss(ev) {
        const t = Date.now();
        const next = {};
        for (const id in root.dismissed)
            if (root.dismissed[id] > t) next[id] = root.dismissed[id];
        next[ev.id] = ev.end;
        root.dismissed = next;
        dismissedView.setText(JSON.stringify(next));
    }

    function eventsOn(d) {
        return root.byDay[Dates.dayKey(d)] ?? [];
    }

    function isPast(ev)    { return ev.end <= root.now.getTime() }
    function isCurrent(ev) { const t = root.now.getTime(); return ev.start <= t && t < ev.end }
    function canJoin(ev) {
        const t = root.now.getTime();
        return ev.join !== "" && t >= ev.start - root.joinMinutes * 60000 && t < ev.end;
    }

    function refresh() {
        if (!syncProc.running) syncProc.running = true;
    }

    // Refresh unless synced within the last minute (popup open)
    function refreshIfStale() {
        if (Date.now() - root.updated > 60000) root.refresh();
    }

    // Account login in a terminal (the browser opens from there); the login
    // ends with a sync → the popup updates by itself. No client yet → set it
    // up first (newest Desktop client JSON in ~/Downloads).
    function connect(email) {
        const login = "dots calendar login" + (email ? " '" + email.replace(/'/g, "") + "'" : "");
        Apps.runInTerminal(root.hasClient ? login : "dots calendar client && " + login);
    }

    function open(ev) { Apps.openUrl(ev.url) }
    function join(ev) { Apps.openUrl(ev.join) }
    function openDay(d) {
        Apps.openUrl("https://calendar.google.com/calendar/r/day/"
                     + d.getFullYear() + "/" + (d.getMonth() + 1) + "/" + d.getDate());
    }

    property var allEvents: []

    function load() {
        const raw = view.text();
        if (!raw) return;
        let data = null;
        try { data = JSON.parse(raw); } catch (e) { return; } // half-written → keep current
        if (!data || !Array.isArray(data.events)) return;

        root.calendarList = (data.calendars ?? []).map((c, i) => Object.assign({}, c, {
            color: c.color || root.palette[i % root.palette.length]
        }));
        root.allEvents = data.events;
        root.errors = data.errors ?? [];
        root.configured = data.configured !== false;
        root.hasClient = data.hasClient !== false;
        root.expired = data.expired ?? [];
        root.updated = data.updated ?? 0;
        root.rangeStart = data.rangeStart ?? 0;
        root.rangeEnd = data.rangeEnd ?? 0;
        root.rebuild();
    }

    function loadVisibility() {
        let next = null;
        try { next = JSON.parse(visibilityView.text() || "{}"); }
        catch (e) { return; }
        // Our own setVisible() write comes back here — already applied
        if (JSON.stringify(next) === JSON.stringify(root.visibility)) return;
        root.visibility = next;
        root.rebuild();
    }

    // Visible calendars' events → events + byDay
    function rebuild() {
        const cals = {};
        for (const c of root.calendarList) cals[c.id] = c;
        const events = root.allEvents.filter(ev => cals[ev.cal] && root.isVisible(cals[ev.cal]));

        const days = {};
        for (const ev of events) {
            // Every local day the event touches (end exclusive), capped
            let d = Dates.startOfDay(new Date(ev.start));
            const last = new Date(Math.max(ev.start, ev.end - 1));
            for (let i = 0; i < 62 && d <= last; i++, d = Dates.addDays(d, 1)) {
                const key = Dates.dayKey(d);
                (days[key] = days[key] ?? []).push(ev);
            }
        }
        for (const key in days)
            days[key].sort((a, b) => (b.allDay - a.allDay) || (a.start - b.start));

        root.calendars = cals;
        root.events = events;
        root.timedEvents = events.filter(ev => !ev.allDay);
        root.maxTimedDuration = root.timedEvents.reduce((m, ev) => Math.max(m, ev.end - ev.start), 0);
        root.byDay = days;
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    FileView {
        id: view
        path: Paths.calendarEvents
        watchChanges: true
        onFileChanged: reload()
        onTextChanged: root.load()
    }

    FileView {
        id: visibilityView
        path: Paths.calendarVisibility
        watchChanges: true
        printErrors: false  // missing until the first toggle
        atomicWrites: true
        onFileChanged: reload()
        onTextChanged: root.loadVisibility()
    }

    FileView {
        id: dismissedView
        path: Paths.calendarDismissed
        printErrors: false  // missing until the first hide
        onLoaded: {
            try { root.dismissed = JSON.parse(text() || "{}"); } catch (e) {}
        }
    }

    Process {
        id: syncProc
        command: ["python3", Quickshell.shellPath("scripts/gcal-sync.py")]
        stderr: StdioCollector {
            onStreamFinished: if (text.trim() !== "") console.warn("gcal-sync:", text.trim())
        }
    }

    Timer {
        running: true
        repeat: true
        triggeredOnStart: true
        interval: root.syncMinutes * 60 * 1000
        onTriggered: root.refresh()
    }
}
