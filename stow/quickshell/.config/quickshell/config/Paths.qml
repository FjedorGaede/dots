pragma Singleton
import QtQuick
import Quickshell

// Filesystem locations used by the shell, in ONE place.
Singleton {
    id: root

    // NB: StandardPaths.homeLocation is undefined in QML — use $HOME directly
    readonly property string home: Quickshell.env("HOME")
    readonly property string cache: root.home + "/.cache"

    // pywal scheme (Theme.qml watches it)
    readonly property string walColors: root.cache + "/wal/colors.json"

    // Stay-awake state (persists across reloads; read by StayAwakeService)
    readonly property string stayAwakeFlag: root.cache + "/quickshell/stay-awake.json"

    // Notification state (do-not-disturb), NotificationService
    readonly property string notificationsState: root.cache + "/quickshell/notifications.json"

    // Calendar events JSON written by scripts/gcal-sync.py (CalendarService)
    readonly property string calendarEvents: root.cache + "/quickshell/calendar-events.json"
    // Bar announcements hidden via right-click ({ "<event id>": <event end ms> })
    readonly property string calendarDismissed: root.cache + "/quickshell/calendar-dismissed.json"
    // Calendar settings: which calendars are shown ({ "<google id>": bool })
    readonly property string calendarVisibility: root.home + "/.local/share/quickshell/calendar-visibility.json"

    // Accent export for hyprlock (hyprlock.conf sources this exact path — keep it)
    readonly property string themeCache: root.cache + "/quickshell-theme"
    readonly property string hyprlockConf: root.themeCache + "/hyprlock.conf"
}
