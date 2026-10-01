pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

import qs.config

Singleton {
    id: root

    // While swaync is running it owns the D-Bus name and we receive nothing;
    // Quickshell watches it and registers automatically once it stops.

    // Do-not-disturb, file-backed (Paths.notificationsState) so it survives
    // reloads/restarts. Change it via setDoNotDisturb().
    readonly property bool doNotDisturb: stateAdapter.doNotDisturb

    function setDoNotDisturb(value) {
        stateAdapter.doNotDisturb = value;
        stateView.writeAdapter();
    }

    FileView {
        id: stateView
        path: Paths.notificationsState
        // A missing file is the normal first-run state (and the preview never
        // writes it) → default false, no "File does not exist" warning.
        // Quickshell 0.3.1 exposes printErrors only as __printErrors.
        __printErrors: false

        JsonAdapter {
            id: stateAdapter
            property bool doNotDisturb: false
        }
    }

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

    // Notification objects can outlive their D-Bus object (e.g. after a hot
    // reload — the wrapper may exist but its D-Bus object is already destroyed)
    function _alive(notification) {
        try { return !!notification && typeof notification.dismiss === "function"; } catch (e) { return false; }
    }

    // Remove one toast (and any dead ones); history is untouched.
    // Returns whether `notification` was shown as a toast.
    function _removeToast(notification) {
        const wasShown = root.toasts.includes(notification);
        const kept = root.toasts.filter(t => t !== notification && root._alive(t));
        if (kept.length !== root.toasts.length) root.toasts = kept;
        return wasShown;
    }

    // Toast expired — hide it, but keep the notification in history
    function hideToast(notification) {
        if (!root._removeToast(notification) || !root._alive(notification)) return;

        // Transient notifications are not kept in history (per spec)
        if (notification.transient) {
            try { notification.dismiss(); } catch (e) {}
        }
    }

    function dismissToast(notification) {
        if (!root._removeToast(notification) || !root._alive(notification)) return;
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
            // Keep in history; toasts are rendered by notifications/Toasts.qml
            notification.tracked = true;
            // Closed for any reason (app retracted it, expired, dismissed
            // elsewhere) → its toast goes too
            notification.closed.connect(() => root._removeToast(notification));

            if (!root.doNotDisturb) {
                root.pushToast(notification);
            }
        }
    }
}
