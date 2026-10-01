.pragma library
// Date math for the calendar popup (Qt 6 has no calendar widget).

function firstOfMonth(d) {
    return new Date(d.getFullYear(), d.getMonth(), 1);
}

// First day of the month `delta` months away from `d`'s month
function addMonths(d, delta) {
    return new Date(d.getFullYear(), d.getMonth() + delta, 1);
}

function daysInMonth(d) {
    return new Date(d.getFullYear(), d.getMonth() + 1, 0).getDate();
}

// Weekday with Monday = 0 … Sunday = 6
function mondayIndex(d) {
    return (d.getDay() + 6) % 7;
}

function sameDay(a, b) {
    return a.getFullYear() === b.getFullYear()
        && a.getMonth() === b.getMonth()
        && a.getDate() === b.getDate();
}

function addDays(d, n) {
    return new Date(d.getFullYear(), d.getMonth(), d.getDate() + n);
}

function startOfDay(d) {
    return new Date(d.getFullYear(), d.getMonth(), d.getDate());
}

// Local "YYYY-MM-DD" — key of CalendarService.byDay
function dayKey(d) {
    const m = d.getMonth() + 1, day = d.getDate();
    return d.getFullYear() + "-" + (m < 10 ? "0" : "") + m + "-" + (day < 10 ? "0" : "") + day;
}

// ISO 8601 week number (weeks start Monday, week 1 contains the first Thursday)
function isoWeek(d) {
    const t = new Date(d.getFullYear(), d.getMonth(), d.getDate() + 3 - mondayIndex(d));
    const jan4 = new Date(t.getFullYear(), 0, 4);
    return 1 + Math.round(((t - jan4) / 86400000 - 3 + mondayIndex(jan4)) / 7);
}

// 8 min → "8m", 80 min → "1h 20m", 2 days → "2d"
function formatDuration(ms) {
    const min = Math.max(0, Math.round(ms / 60000));
    if (min < 60) return min + "m";
    if (min < 24 * 60) {
        const h = Math.floor(min / 60), m = min % 60;
        return m > 0 ? h + "h " + m + "m" : h + "h";
    }
    return Math.round(min / (24 * 60)) + "d";
}
