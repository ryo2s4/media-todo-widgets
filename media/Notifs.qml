import QtQuick
import Quickshell
import Quickshell.Io

// Notification history for the panel. It does not replace your notification
// daemon: it listens in on the session bus (notif-monitor.py) and keeps a list.
// Only notifications that arrive while this config is running are captured.
Scope {
    id: nf

    readonly property string base: Quickshell.env("HOME") + "/.config/quickshell/media"
    readonly property int maxItems: 40

    // newest first: { id, app, summary, body, t }
    property var items: []
    property int nextId: 1
    property int tick: 0

    function add(raw) {
        var d;
        try {
            d = JSON.parse(raw);
        } catch (e) {
            return;
        }
        if (!d.summary && !d.body)
            return;
        var arr = items.slice();
        if (d.rid && d.rid !== 0) {
            // an app updating its own notification: replace that app's latest one
            for (var i = 0; i < arr.length; i++) {
                if (arr[i].app === d.app) {
                    arr.splice(i, 1);
                    break;
                }
            }
        } else if (arr.length > 0 && arr[0].app === d.app && arr[0].summary === d.summary
                   && arr[0].body === d.body && (d.t - arr[0].t) < 1500) {
            return;
        }
        arr.unshift({ id: nextId, app: d.app, summary: d.summary, body: d.body, t: d.t });
        nextId += 1;
        if (arr.length > maxItems)
            arr.length = maxItems;
        items = arr;
        _save();
    }

    function dismiss(id) {
        items = items.filter(function (x) { return x.id !== id; });
        _save();
    }

    function clear() {
        items = [];
        _save();
    }

    function ago(t, dep) {
        var s = Math.max(0, Math.floor((Date.now() - t) / 1000));
        if (s < 60)
            return "now";
        if (s < 3600)
            return Math.floor(s / 60) + "m";
        if (s < 86400)
            return Math.floor(s / 3600) + "h";
        return Math.floor(s / 86400) + "d";
    }

    function _save() { file.setText(JSON.stringify(items)); }

    FileView {
        id: file
        path: nf.base + "/notifs.json"
        onLoaded: {
            try {
                var arr = JSON.parse(file.text());
                var m = 0;
                for (var i = 0; i < arr.length; i++)
                    m = Math.max(m, arr[i].id + 1);
                nf.nextId = Math.max(1, m);
                nf.items = arr;
            } catch (e) {
                console.log("media: could not read notifs.json:", e);
            }
        }
    }

    Process {
        id: mon
        command: ["python3", nf.base + "/notif-monitor.py"]
        running: true
        stdout: SplitParser {
            onRead: function (data) { nf.add(data); }
        }
        onRunningChanged: if (!running) restart.start()
    }
    Timer {
        id: restart
        interval: 3000
        onTriggered: mon.running = true
    }

    // refresh the "5m" labels
    Timer {
        interval: 30000
        repeat: true
        running: true
        onTriggered: nf.tick += 1
    }
}
