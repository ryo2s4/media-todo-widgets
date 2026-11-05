import QtQuick
import Quickshell
import Quickshell.Io

// Store.qml: a read-only window onto the todo board's tasks.json.
// The calendar never writes the file; adding and completing tasks goes through
// `qs -c todo ipc call ...`, so the todo panel stays the single writer.
Scope {
    id: st

    readonly property string home: Quickshell.env("HOME")
    readonly property string todoDir: home + "/.config/quickshell/todo"
    readonly property string tasksPath: todoDir + "/tasks.json"

    property var tasks: []
    property bool loaded: false
    property int rev: 0

    readonly property var dayNames: ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    readonly property var monthNames: ["January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December"]

    function pad(n) { return (n < 10 ? "0" : "") + n; }
    function dayKey(ms) {
        var d = new Date(ms);
        return d.getFullYear() + "-" + pad(d.getMonth() + 1) + "-" + pad(d.getDate());
    }
    function isDateOnly(ms) {
        var d = new Date(ms);
        return d.getHours() === 23 && d.getMinutes() === 59;
    }
    function startOfDay(ms) {
        var d = new Date(ms);
        d.setHours(0, 0, 0, 0);
        return d.getTime();
    }
    function timeLabel(ms) {
        if (!ms || isDateOnly(ms))
            return "";
        var d = new Date(ms);
        return pad(d.getHours()) + ":" + pad(d.getMinutes());
    }
    function dayTitle(key) {
        var p = String(key).split("-");
        var d = new Date(Number(p[0]), Number(p[1]) - 1, Number(p[2]));
        return st.dayNames[d.getDay()] + " " + d.getDate() + " " + st.monthNames[d.getMonth()].substring(0, 3);
    }
    function todayKey() { return dayKey(Date.now()); }

    function _order(a, b) {
        if (a.done !== b.done)
            return a.done ? 1 : -1;
        var aa = st.isDateOnly(a.due);
        var bb = st.isDateOnly(b.due);
        if (aa !== bb)
            return aa ? -1 : 1;
        return a.due - b.due;
    }

    // day key -> tasks due that day. Rebuilt whenever tasks.json changes.
    readonly property var byDay: {
        var map = {};
        for (var i = 0; i < tasks.length; i++) {
            var t = tasks[i];
            if (!(t.due > 0))
                continue;
            var k = dayKey(t.due);
            if (!map[k])
                map[k] = [];
            map[k].push(t);
        }
        for (var key in map)
            map[key].sort(_order);
        return map;
    }

    function tasksOn(key) { return byDay[key] || []; }
    function countOn(key) { var a = byDay[key]; return a ? a.length : 0; }
    function countMonth(year, month) {
        var n = 0;
        for (var i = 0; i < tasks.length; i++) {
            var d = new Date(tasks[i].due);
            if (tasks[i].due > 0 && d.getFullYear() === year && d.getMonth() === month)
                n++;
        }
        return n;
    }
    function countOverdue() {
        var n = 0;
        var now = Date.now();
        for (var i = 0; i < tasks.length; i++)
            if (tasks[i].due > 0 && !tasks[i].done && tasks[i].due < now)
                n++;
        return n;
    }
    function countToday() {
        var n = 0;
        var k = todayKey();
        for (var i = 0; i < tasks.length; i++)
            if (tasks[i].due > 0 && !tasks[i].done && dayKey(tasks[i].due) === k)
                n++;
        return n;
    }

    function _load(raw) {
        try {
            var arr = JSON.parse(raw);
            if (!Array.isArray(arr))
                return;
            var out = [];
            for (var i = 0; i < arr.length; i++) {
                var t = arr[i];
                out.push({
                    text: String(t.text || ""),
                    quad: Number(t.quad) || 0,
                    done: !!t.done,
                    ord: Number(t.ord) || -1,
                    due: Number(t.due) || 0,
                    repeat: String(t.repeat || ""),
                    tags: Array.isArray(t.tags) ? t.tags.map(String) : []
                });
            }
            tasks = out;
            loaded = true;
            rev += 1;
        } catch (e) {
            console.log("calendar: could not read tasks.json:", e);
        }
    }

    FileView {
        id: tasksFile
        path: st.tasksPath
        watchChanges: true
        onFileChanged: tasksFile.reload()
        onLoaded: st._load(tasksFile.text())
        onLoadFailed: st.loaded = false
    }
}
