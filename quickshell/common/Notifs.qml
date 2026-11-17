pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

// The rice's notification daemon (replaces mako). Every notification stays in the history
// for the centre (clock click) until dismissed there or closed by its app; the newest show
// as toasts (osd/Toasts.qml). Focus mode (dnd) sends them straight to the centre; critical
// ones still pop up. The clock shows how many came in since the centre was last opened.
Singleton {
    id: root

    // history, newest first
    readonly property var list: server.trackedNotifications.values.slice().sort((a, b) => root.timeOf(b) - root.timeOf(a))
    property var toasts: []          // notifications showing as toasts, newest first
    property int unread: 0
    property bool dnd: false
    property var times: ({})         // notification id -> arrival time (ms)

    function timeOf(n) {
        return times[n.id] || 0;
    }

    function isCritical(n) {
        return n.urgency === NotificationUrgency.Critical;
    }

    // A path, URL or icon-theme name for the notification's picture; "" when it has none.
    function iconOf(n) {
        if (n.image)
            return n.image;
        const ic = n.appIcon || "";
        if (ic === "")
            return "";
        if (ic.startsWith("/"))
            return "file://" + ic;
        if (ic.includes("://"))
            return ic;
        return Quickshell.iconPath(ic, true);
    }

    function hideToast(n) {
        toasts = toasts.filter(t => t !== n);
        // transient ones (volume changes and the like) are not kept in the history
        if (n.transient && list.includes(n))
            n.expire();
    }

    function dismiss(n) {
        hideToast(n);
        n.dismiss();
    }

    function clearAll() {
        toasts = [];
        for (const n of server.trackedNotifications.values.slice())
            n.dismiss();
    }

    function invoke(n, action) {
        hideToast(n);
        action.invoke();
    }

    function setDnd(on) {
        dnd = on;
        dndFile.setText(on ? "1\n" : "0\n");
    }

    function toggleDnd() {
        setDnd(!dnd);
    }

    // Opening the centre counts everything as read.
    function markRead() {
        unread = 0;
    }

    Connections {
        target: Popup
        function onSideChanged() {
            if (Popup.side === "nc")
                root.markRead();
        }
    }

    // focus mode survives a shell restart
    FileView {
        id: dndFile
        path: Theme.cacheDir + "/dnd"
        printErrors: false
        onLoaded: root.dnd = text().trim() === "1"
    }

    NotificationServer {
        id: server
        keepOnReload: true
        actionsSupported: true
        imageSupported: true
        bodySupported: true
        bodyMarkupSupported: false
        bodyHyperlinksSupported: false
        persistenceSupported: true

        onNotification: n => {
            n.tracked = true;
            const t = Object.assign({}, root.times);
            t[n.id] = Date.now();
            root.times = t;
            if (Popup.side !== "nc")
                root.unread++;
            const id = n.id;
            n.closed.connect(() => {
                root.toasts = root.toasts.filter(x => x !== n);
                const left = Object.assign({}, root.times);
                delete left[id];
                root.times = left;
            });
            if (!root.dnd || root.isCritical(n))
                root.toasts = [n].concat(root.toasts.filter(x => x !== n));
        }
    }

    IpcHandler {
        target: "notifs"
        function toggleDnd(): void {
            root.toggleDnd();
        }
        function clear(): void {
            root.clearAll();
        }
    }
}
