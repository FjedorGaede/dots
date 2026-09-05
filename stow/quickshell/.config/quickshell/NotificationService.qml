pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications

Singleton {
    id: root

    // While swaync is running it owns the D-Bus name and we receive nothing;
    // Quickshell watches it and registers automatically once it stops.
    property bool doNotDisturb: false

    // Notification objects currently shown as toasts (newest last)
    property var toasts: []

    readonly property int trackedCount: server.trackedNotifications.values.length

    // History, newest first (for display)
    readonly property var history: {
        const list = server.trackedNotifications.values;
        return list.slice().reverse();
    }

    // Default expiry if the client sends none (0 / -1 per spec)
    readonly property int defaultExpire: 5000

    function pushToast(notification) {
        // Cap concurrent toasts — the oldest one leaves the screen but
        // STAYS in history (hideToast, not dismissToast!)
        if (root.toasts.length >= 5) {
            root.hideToast(root.toasts[0]);
        }
        root.toasts = root.toasts.concat([notification]);
    }

    // Toast expired — hide it, but keep the notification in history
    function hideToast(notification) {
        // Guards against delegates outliving their notification object
        // (e.g. after a hot reload — the wrapper may exist but its D-Bus
        // object is already destroyed)
        let alive = false;
        try { alive = notification && typeof notification.dismiss === "function"; } catch (e) {}
        if (!alive) {
            root.toasts = [];
            return;
        }

        const i = root.toasts.indexOf(notification);
        if (i === -1) return;

        const copy = root.toasts.slice();
        copy.splice(i, 1);
        root.toasts = copy;

        // Transient notifications are not kept in history (per spec)
        if (notification.transient) {
            try { notification.dismiss(); } catch (e) {}
        }
    }

    function dismissToast(notification) {
        if (!root.toasts.includes(notification)) return;

        const copy = root.toasts.slice();
        copy.splice(copy.indexOf(notification), 1);
        root.toasts = copy;
        notification.dismiss();
    }

    function clearAll() {
        const list = server.trackedNotifications.values.slice();
        for (let i = 0; i < list.length; i++) {
            list[i].dismiss();
        }
        root.toasts = [];
    }

    NotificationServer {
        id: server

        keepOnReload: false
        persistenceSupported: true
        bodySupported: true
        actionsSupported: true

        onNotification: (notification) => {
            // Keep in history; toasts are rendered by NotificationToasts
            notification.tracked = true;

            if (!root.doNotDisturb) {
                root.pushToast(notification);
            }
        }
    }
}
