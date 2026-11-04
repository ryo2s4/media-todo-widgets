import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io

// Store.qml: no UI. Everything the panel shows comes from here.
// Files (all under ~/.config/quickshell/todo/):
//   tasks.json   the tasks (schema in README.md)
//   state.json   goal, streak, stats, archive, timer state, settings
//   status.json  small snapshot for the bar plugin
Scope {
    id: store

    // ───────── config (edit freely) ─────────
    readonly property string home: Quickshell.env("HOME")
    readonly property string base: home + "/.config/quickshell/todo"
    readonly property string gifDir: "file://" + home + "/Pictures/pc/Todo-gifs"
    // GIFs for reaching the daily goal: put them in <gifDir>/goal (falls back to the main folder)
    readonly property int longBreakEvery: 4
    readonly property string soundDone: "/usr/share/sounds/freedesktop/stereo/complete.oga"
    readonly property string soundEnd: "/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga"
    readonly property var modes: [
        { name: "Pomodoro", mins: 25, focus: true },
        { name: "Break", mins: 5, focus: false },
        { name: "Deep focus", mins: 50, focus: true },
        { name: "Long break", mins: 15, focus: false }
    ]
    readonly property var quadNames: ["Today", "End of week", "No specific time", "Urgent"]
    readonly property var dayNames: ["sun", "mon", "tue", "wed", "thu", "fri", "sat"]

    // ───────── tasks ─────────
    // task: { text, quad, done, ord (id), pos (order), due (ms, 0 = none), repeat,
    //         note, subs:[{t,d}], tags:[], pomos, doneAt, created, stage, reminded }
    // quad: 0 Today, 1 End of week, 2 No specific time, 3 Urgent
    property var tasks: []
    property var byId: ({})
    property int pending: 0
    property int doneCount: 0
    property int urgentPending: 0
    property int nextOrd: 1
    property bool tasksLoaded: false
    property bool stateLoaded: false

    property string filter: ""
    property string tagFilter: ""

    // ───────── timer ─────────
    property int modeIndex: 0
    property int remaining: 25 * 60
    property bool running: false
    property double endAt: 0
    property int sessions: 0
    property int activeTaskId: -1
    readonly property int total: modes[modeIndex].mins * 60
    readonly property string activeTaskText: {
        var t = byId[activeTaskId];
        return t ? t.text : "";
    }

    // ───────── stats & settings ─────────
    property int goal: 5
    property int streak: 0
    property string lastGoalDay: ""
    property string goalHitDay: ""
    property var doneLog: ({})
    property var focusLog: ({})
    property var archive: []
    property string lastReview: ""
    property bool muted: false
    property bool autoStart: false
    property string exportPath: home + "/Documents/todo-export.md"
    property string importPath: home + "/Documents/todo-import.md"
    property int wipLimit: 0
    property bool celebrateEach: false
    property bool soundOnDone: true
    property bool soundOnTimer: true
    property var templates: []
    property string lastPlanDay: ""
    property string dateFilter: ""
    property string accentCustom: ""
    property int stateRev: 0
    property int nowTick: 0

    // write status once on startup so the bar widget has data immediately
    Component.onCompleted: statusSoon.restart()

    readonly property int doneToday: {
        var dep = stateRev + nowTick;
        return doneLog[dayKey(Date.now())] || 0;
    }
    readonly property int focusToday: {
        var dep = stateRev + nowTick;
        return focusLog[dayKey(Date.now())] || 0;
    }
    readonly property int streakShown: {
        var dep = stateRev + nowTick;
        var now = Date.now();
        return (lastGoalDay === dayKey(now) || lastGoalDay === dayKey(now - 86400000)) ? streak : 0;
    }

    // undo / review / gif state
    property bool undoVisible: false
    property string undoLabel: ""
    property string _undoSnap: ""
    property bool reviewVisible: false
    property var reviewData: ({ done: 0, mins: 0, streak: 0, archived: 0 })
    property url gifSource: ""
    property string lastGifUrl: ""

    // ───────── date helpers ─────────
    function pad(n) { return (n < 10 ? "0" : "") + n; }
    function dayKey(ms) {
        var d = new Date(ms);
        return d.getFullYear() + "-" + pad(d.getMonth() + 1) + "-" + pad(d.getDate());
    }
    function startOfDay(ms) {
        var d = new Date(ms);
        d.setHours(0, 0, 0, 0);
        return d.getTime();
    }
    function isDateOnly(ms) {
        var d = new Date(ms);
        return d.getHours() === 23 && d.getMinutes() === 59;
    }
    function _shiftNow(n, unit) {
        var ms = n * (unit === "m" ? 60000 : (unit === "h" ? 3600000 : 86400000));
        return new Date(Date.now() + ms);
    }

    // "today 17:30", "tomorrow", "fri", "2026-11-05 09:00", "17:30"  ->  ms, 0 = none, -1 = invalid
    function parseDue(str) {
        str = String(str).trim().toLowerCase();
        if (str === "")
            return 0;
        var parts = str.split(/\s+/);
        var now = new Date();
        var date = null;
        var hh = -1;
        var mm = 0;
        for (var i = 0; i < parts.length; i++) {
            var p = parts[i];
            var m = null;
            if (p === "today") {
                date = new Date(now);
            } else if (p === "tomorrow" || p === "tmr") {
                date = new Date(now);
                date.setDate(date.getDate() + 1);
            } else if (p === "tonight") {
                date = new Date(now);
                hh = 21;
                mm = 0;
            } else if (p === "noon") {
                date = new Date(now);
                hh = 12;
                mm = 0;
            } else if (p === "eod" || p === "midnight") {
                date = new Date(now);
                hh = 23;
                mm = 59;
            } else if ((m = /^in(\d+)([mhd])$/.exec(p)) !== null) {
                var base = _shiftNow(Number(m[1]), m[2]);
                date = base;
                hh = base.getHours();
                mm = base.getMinutes();
            } else if (p === "in" && i + 1 < parts.length && (m = /^(\d+)([mhd])$/.exec(parts[i + 1])) !== null) {
                i += 1;
                var base2 = _shiftNow(Number(m[1]), m[2]);
                date = base2;
                hh = base2.getHours();
                mm = base2.getMinutes();
            } else if (p === "next" && i + 1 < parts.length) {
                var dm = /^(sun|mon|tue|wed|thu|fri|sat)[a-z]*$/.exec(parts[i + 1]);
                if (dm === null)
                    return -1;
                i += 1;
                var nt = dayNames.indexOf(dm[1]);
                date = new Date(now);
                var nd = (nt - date.getDay() + 7) % 7;
                if (nd === 0)
                    nd = 7;
                date.setDate(date.getDate() + nd + 7);
            } else if ((m = /^(\d{4})-(\d{1,2})-(\d{1,2})$/.exec(p)) !== null) {
                date = new Date(Number(m[1]), Number(m[2]) - 1, Number(m[3]));
            } else if ((m = /^(\d{1,2}):(\d{2})$/.exec(p)) !== null) {
                hh = Number(m[1]);
                mm = Number(m[2]);
                if (hh > 23 || mm > 59)
                    return -1;
            } else if ((m = /^(sun|mon|tue|wed|thu|fri|sat)[a-z]*$/.exec(p)) !== null) {
                var target = dayNames.indexOf(m[1]);
                date = new Date(now);
                var delta = (target - date.getDay() + 7) % 7;
                if (delta === 0)
                    delta = 7;
                date.setDate(date.getDate() + delta);
            } else {
                return -1;
            }
        }
        if (date === null && hh < 0)
            return -1;
        var timeOnly = (date === null);
        if (timeOnly)
            date = new Date(now);
        if (hh >= 0)
            date.setHours(hh, mm, 0, 0);
        else
            date.setHours(23, 59, 0, 0);
        if (timeOnly && date.getTime() <= now.getTime())
            date.setDate(date.getDate() + 1);
        return date.getTime();
    }

    function dueEdit(ms) {
        if (!ms)
            return "";
        var d = new Date(ms);
        var s = d.getFullYear() + "-" + pad(d.getMonth() + 1) + "-" + pad(d.getDate());
        if (!isDateOnly(ms))
            s += " " + pad(d.getHours()) + ":" + pad(d.getMinutes());
        return s;
    }

    function fmtDue(ms) {
        if (!ms)
            return "";
        var d = new Date(ms);
        var diff = Math.round((startOfDay(ms) - startOfDay(Date.now())) / 86400000);
        var label;
        if (diff === 0)
            label = "Today";
        else if (diff === 1)
            label = "Tomorrow";
        else if (diff === -1)
            label = "Yesterday";
        else
            label = d.getDate() + "/" + (d.getMonth() + 1);
        if (!isDateOnly(ms))
            label += " " + pad(d.getHours()) + ":" + pad(d.getMinutes());
        return label;
    }

    function quadForDue(ms) {
        var now = Date.now();
        if (ms < now)
            return 3;
        var days = Math.round((startOfDay(ms) - startOfDay(now)) / 86400000);
        if (days <= 0)
            return 0;
        if (days <= 7)
            return 1;
        return 2;
    }

    // ───────── quick-add parsing ─────────
    // "!" prefix = Urgent; #t #w #s = Today / End of week / No specific time;
    // #tag = tag; @tomorrow @17:30 @2026-11-05 = due; *daily *weekly *weekdays *mon,wed = repeat
    function parseRepeat(s) {
        s = s.toLowerCase();
        if (s === "daily")
            return "daily";
        if (s === "weekly")
            return "weekly";
        if (s === "weekdays")
            return "days:1,2,3,4,5";
        var names = s.split(",");
        var days = [];
        for (var i = 0; i < names.length; i++) {
            var idx = dayNames.indexOf(names[i].substring(0, 3));
            if (idx < 0)
                return "";
            if (days.indexOf(idx) < 0)
                days.push(idx);
        }
        days.sort(function (a, b) { return a - b; });
        return days.length > 0 ? "days:" + days.join(",") : "";
    }

    function parseQuick(raw, defQuad) {
        var words = String(raw).trim().split(/\s+/);
        var quad = defQuad;
        var explicit = false;
        var out = [];
        var tags = [];
        var dueParts = [];
        var repeat = "";
        if (words.length > 0 && words[0].charAt(0) === "!") {
            quad = 3;
            explicit = true;
            var rest = words[0].replace(/^!+/, "");
            if (rest === "")
                words.shift();
            else
                words[0] = rest;
        }
        var needInNum = false;
        var needNextDay = false;
        for (var i = 0; i < words.length; i++) {
            var w = words[i];
            var lw = w.toLowerCase();
            if (needInNum && /^\d+[mhd]$/.test(lw)) {
                dueParts.push(lw);
                needInNum = false;
                continue;
            }
            if (needNextDay && /^(sun|mon|tue|wed|thu|fri|sat)/.test(lw)) {
                dueParts.push(lw);
                needNextDay = false;
                continue;
            }
            if (lw === "#t") { quad = 0; explicit = true; }
            else if (lw === "#w") { quad = 1; explicit = true; }
            else if (lw === "#s") { quad = 2; explicit = true; }
            else if (w.charAt(0) === "#" && w.length > 1) {
                var tg = lw.substring(1);
                if (tags.indexOf(tg) < 0)
                    tags.push(tg);
            }
            else if (w.charAt(0) === "@" && w.length > 1) {
                dueParts.push(w.substring(1));
                if (w.substring(1).toLowerCase() === "in")
                    needInNum = true;
                else if (w.substring(1).toLowerCase() === "next")
                    needNextDay = true;
            }
            else if (w.charAt(0) === "*" && w.length > 1) repeat = parseRepeat(w.substring(1));
            else out.push(w);
        }
        var due = 0;
        if (dueParts.length > 0) {
            due = parseDue(dueParts.join(" "));
            if (due < 0) {
                due = 0;
                for (var k = 0; k < dueParts.length; k++)
                    out.push("@" + dueParts[k]);
            }
        }
        var text = out.join(" ").trim();
        if (text === "")
            return null;
        if (!explicit && due > 0)
            quad = quadForDue(due);
        return { text: text, quad: quad, due: due, repeat: repeat, tags: tags };
    }

    // ───────── task plumbing ─────────
    function _norm(t) {
        var subs = [];
        if (t.subs)
            for (var i = 0; i < t.subs.length; i++)
                subs.push({ t: String(t.subs[i].t), d: !!t.subs[i].d });
        var tags = [];
        if (t.tags)
            for (var j = 0; j < t.tags.length; j++)
                tags.push(String(t.tags[j]));
        var ord = Number(t.ord);
        var quad = (t.quad !== undefined) ? Number(t.quad) : (Number(t.prio) === 0 ? 3 : (Number(t.prio) === 1 ? 0 : 2));
        return {
            text: String(t.text),
            quad: quad,
            done: !!t.done,
            ord: ord,
            pos: (t.pos !== undefined) ? Number(t.pos) : ord,
            due: Number(t.due) || 0,
            repeat: t.repeat ? String(t.repeat) : "",
            note: t.note ? String(t.note) : "",
            subs: subs,
            tags: tags,
            pomos: Number(t.pomos) || 0,
            doneAt: Number(t.doneAt) || 0,
            created: Number(t.created) || 0,
            stage: Number(t.stage) || 0,
            reminded: !!t.reminded,
            snooze: Number(t.snooze) || 0,
            focusMs: Number(t.focusMs) || 0
        };
    }

    function _clone() {
        var out = [];
        for (var i = 0; i < tasks.length; i++)
            out.push(_norm(tasks[i]));
        return out;
    }

    function _find(arr, id) {
        for (var i = 0; i < arr.length; i++)
            if (arr[i].ord === id)
                return i;
        return -1;
    }

    function _maxPos(arr) {
        var m = 0;
        for (var i = 0; i < arr.length; i++)
            m = Math.max(m, arr[i].pos);
        return m;
    }

    function _apply(arr, persist) {
        arr.sort(function (a, b) {
            if (a.done !== b.done)
                return a.done ? 1 : -1;
            return a.pos - b.pos;
        });
        var d = 0;
        var u = 0;
        var map = {};
        for (var i = 0; i < arr.length; i++) {
            map[arr[i].ord] = arr[i];
            if (arr[i].done)
                d++;
            else if (arr[i].quad === 3)
                u++;
        }
        doneCount = d;
        pending = arr.length - d;
        urgentPending = u;
        byId = map;
        tasks = arr;
        if (persist)
            tasksFile.setText(JSON.stringify(arr, null, 1));
        statusSoon.restart();
    }

    function _mutate(fn) {
        var arr = _clone();
        fn(arr);
        _apply(arr, true);
    }

    function matches(t) {
        if (tagFilter !== "" && t.tags.indexOf(tagFilter) < 0)
            return false;
        if (dateFilter !== "" && (!t.due || dayKey(t.due) !== dateFilter))
            return false;
        if (filter !== "") {
            var f = filter.toLowerCase();
            var hay = (t.text + " " + t.note + " " + t.tags.join(" ")).toLowerCase();
            for (var i = 0; i < t.subs.length; i++)
                hay += " " + t.subs[i].t.toLowerCase();
            if (hay.indexOf(f) < 0)
                return false;
        }
        return true;
    }

    // visible tasks of one box, in display order (done last)
    function visibleIn(q) {
        var out = [];
        for (var i = 0; i < tasks.length; i++)
            if (tasks[i].quad === q && matches(tasks[i]))
                out.push(tasks[i]);
        return out;
    }

    function addFromText(raw, defQuad) {
        var p = parseQuick(raw, defQuad);
        if (p === null)
            return false;
        var arr = _clone();
        var id = nextOrd;
        nextOrd += 1;
        arr.push({
            text: p.text, quad: p.quad, done: false, ord: id, pos: _maxPos(arr) + 1,
            due: p.due, repeat: p.repeat, note: "", subs: [], tags: p.tags, pomos: 0,
            doneAt: 0, created: Date.now(), stage: 0, reminded: false, snooze: 0, focusMs: 0
        });
        _apply(arr, true);
        return true;
    }

    function _step(d, rep) {
        if (rep === "daily") {
            d.setDate(d.getDate() + 1);
        } else if (rep === "weekly") {
            d.setDate(d.getDate() + 7);
        } else if (rep.indexOf("days:") === 0) {
            var days = rep.substring(5).split(",").map(Number);
            for (var g = 0; g < 8; g++) {
                d.setDate(d.getDate() + 1);
                if (days.indexOf(d.getDay()) >= 0)
                    break;
            }
        } else {
            d.setDate(d.getDate() + 1);
        }
    }

    function _nextInstance(t, arr) {
        var d = (t.due > 0) ? new Date(t.due) : new Date();
        if (!(t.due > 0))
            d.setHours(23, 59, 0, 0);
        var now = Date.now();
        _step(d, t.repeat);
        for (var g = 0; g < 400 && d.getTime() <= now; g++)
            _step(d, t.repeat);
        var due = d.getTime();
        var subs = [];
        for (var i = 0; i < t.subs.length; i++)
            subs.push({ t: t.subs[i].t, d: false });
        var id = nextOrd;
        nextOrd += 1;
        return {
            text: t.text, quad: (t.quad === 3) ? 3 : quadForDue(due), done: false, ord: id,
            pos: _maxPos(arr) + 1, due: due, repeat: t.repeat, note: t.note, subs: subs,
            tags: t.tags.slice(), pomos: 0, doneAt: 0, created: Date.now(), stage: 0, reminded: false,
            snooze: 0, focusMs: 0
        };
    }

    function toggleDone(id) {
        var arr = _clone();
        var i = _find(arr, id);
        if (i < 0)
            return;
        var t = arr[i];
        var now = Date.now();
        var today = dayKey(now);
        t.done = !t.done;
        if (t.done) {
            t.doneAt = now;
            doneLog[today] = (doneLog[today] || 0) + 1;
            if (t.repeat !== "")
                arr.push(_nextInstance(t, arr));
            _apply(arr, true);
            stateRev += 1;
            _sound("done");
            var hit = (doneLog[today] >= goal && goalHitDay !== today);
            if (hit)
                _goalReached(today);
            if (hit)
                celebrate(true);
            else if (celebrateEach)
                celebrate(false);
        } else {
            if (t.doneAt && dayKey(t.doneAt) === today)
                doneLog[today] = Math.max(0, (doneLog[today] || 0) - 1);
            t.doneAt = 0;
            _apply(arr, true);
            stateRev += 1;
        }
        _saveState();
    }

    function _goalReached(today) {
        var y = dayKey(Date.now() - 86400000);
        streak = (lastGoalDay === y) ? streak + 1 : 1;
        lastGoalDay = today;
        goalHitDay = today;
        stateRev += 1;
    }

    // Place a task in `quad`, between the tasks `prevId` and `nextId` (-1 = none).
    function moveTask(id, quad, prevId, nextId) {
        _mutate(function (arr) {
            var i = _find(arr, id);
            if (i < 0)
                return;
            var p = byId[prevId];
            var n = byId[nextId];
            var pos;
            if (p && n)
                pos = (p.pos + n.pos) / 2;
            else if (p)
                pos = p.pos + 1;
            else if (n)
                pos = n.pos - 1;
            else
                pos = _maxPos(arr) + 1;
            arr[i].quad = quad;
            arr[i].pos = pos;
        });
    }

    function setText(id, text) {
        text = String(text).trim();
        if (text === "")
            return;
        _mutate(function (arr) {
            var i = _find(arr, id);
            if (i >= 0)
                arr[i].text = text;
        });
    }

    function setNote(id, note) {
        _mutate(function (arr) {
            var i = _find(arr, id);
            if (i >= 0)
                arr[i].note = String(note);
        });
    }

    function setDue(id, str) {
        var v = parseDue(str);
        if (v < 0)
            return false;
        _mutate(function (arr) {
            var i = _find(arr, id);
            if (i >= 0) {
                arr[i].due = v;
                arr[i].stage = 0;
                arr[i].reminded = false;
                arr[i].snooze = 0;
            }
        });
        return true;
    }

    function cycleRepeat(id) {
        _mutate(function (arr) {
            var i = _find(arr, id);
            if (i < 0)
                return;
            var r = arr[i].repeat;
            var order = ["", "daily", "weekly", "days:1,2,3,4,5"];
            var cur = (r.indexOf("days:") === 0) ? 3 : order.indexOf(r);
            arr[i].repeat = order[(cur + 1) % 4];
        });
    }

    function toggleDay(id, day) {
        _mutate(function (arr) {
            var i = _find(arr, id);
            if (i < 0)
                return;
            var r = arr[i].repeat;
            var days = [];
            if (r.indexOf("days:") === 0)
                days = r.substring(5).split(",").filter(function (x) { return x !== ""; }).map(Number);
            var at = days.indexOf(day);
            if (at >= 0)
                days.splice(at, 1);
            else
                days.push(day);
            days.sort(function (a, b) { return a - b; });
            arr[i].repeat = days.length > 0 ? "days:" + days.join(",") : "";
        });
    }

    // ───────── snooze ─────────
    function snoozeTask(id, mins) {
        _mutate(function (arr) {
            var i = _find(arr, id);
            if (i >= 0) {
                arr[i].snooze = Date.now() + mins * 60000;
                arr[i].reminded = false;
                arr[i].stage = 0;
            }
        });
    }
    function snoozeUntil(id, when) {
        _mutate(function (arr) {
            var i = _find(arr, id);
            if (i >= 0) {
                arr[i].snooze = when;
                arr[i].reminded = false;
                arr[i].stage = 0;
            }
        });
    }
    function snoozeTonight(id) {
        var d = new Date();
        d.setHours(21, 0, 0, 0);
        if (d.getTime() <= Date.now())
            d.setDate(d.getDate() + 1);
        snoozeUntil(id, d.getTime());
    }
    function snoozeTomorrow(id) {
        var d = new Date();
        d.setDate(d.getDate() + 1);
        d.setHours(9, 0, 0, 0);
        snoozeUntil(id, d.getTime());
    }
    function clearSnooze(id) {
        _mutate(function (arr) {
            var i = _find(arr, id);
            if (i >= 0) {
                arr[i].snooze = 0;
                arr[i].reminded = false;
            }
        });
    }

    // ───────── templates ─────────
    function saveTemplateFromTask(id) {
        var t = byId[id];
        if (!t)
            return false;
        var subs = [];
        for (var i = 0; i < t.subs.length; i++)
            subs.push({ t: t.subs[i].t, d: false });
        var list = templates.slice();
        list.push({ text: t.text, quad: t.quad, repeat: t.repeat, tags: t.tags.slice(), subs: subs, note: t.note });
        templates = list;
        _saveState();
        _notify("Template saved", t.text);
        return true;
    }
    function addFromTemplate(index, defQuad) {
        var tpl = templates[index];
        if (!tpl)
            return false;
        var arr = _clone();
        var id = nextOrd;
        nextOrd += 1;
        var subs = [];
        for (var i = 0; i < tpl.subs.length; i++)
            subs.push({ t: tpl.subs[i].t, d: false });
        arr.push({
            text: tpl.text, quad: (defQuad !== undefined && defQuad >= 0) ? defQuad : tpl.quad,
            done: false, ord: id, pos: _maxPos(arr) + 1, due: 0, repeat: tpl.repeat,
            note: tpl.note, subs: subs, tags: tpl.tags.slice(), pomos: 0, doneAt: 0,
            created: Date.now(), stage: 0, reminded: false, snooze: 0, focusMs: 0
        });
        _apply(arr, true);
        return true;
    }
    function removeTemplate(index) {
        var list = templates.slice();
        list.splice(index, 1);
        templates = list;
        _saveState();
    }

    // ───────── bulk actions ─────────
    function bulkDone(ids) {
        if (ids.length === 0)
            return;
        _snapshot("Completed " + ids.length);
        var now = Date.now();
        var today = dayKey(now);
        var arr = _clone();
        var n = 0;
        for (var k = 0; k < ids.length; k++) {
            var i = _find(arr, ids[k]);
            if (i < 0 || arr[i].done)
                continue;
            var t = arr[i];
            t.done = true;
            t.doneAt = now;
            doneLog[today] = (doneLog[today] || 0) + 1;
            if (t.repeat !== "")
                arr.push(_nextInstance(t, arr));
            n += 1;
        }
        if (n === 0)
            return;
        _apply(arr, true);
        stateRev += 1;
        _sound("done");
        var hit = (doneLog[today] >= goal && goalHitDay !== today);
        if (hit) {
            _goalReached(today);
            celebrate(true);
        } else if (celebrateEach) {
            celebrate(false);
        }
        _saveState();
    }
    function bulkRemove(ids) {
        if (ids.length === 0)
            return;
        _snapshot("Deleted " + ids.length);
        for (var k = 0; k < ids.length; k++)
            if (activeTaskId === ids[k])
                activeTaskId = -1;
        _mutate(function (arr) {
            for (var i = arr.length - 1; i >= 0; i--)
                if (ids.indexOf(arr[i].ord) >= 0)
                    arr.splice(i, 1);
        });
    }
    function bulkMove(ids, quad) {
        if (ids.length === 0)
            return;
        _mutate(function (arr) {
            for (var k = 0; k < ids.length; k++) {
                var i = _find(arr, ids[k]);
                if (i >= 0) {
                    arr[i].quad = quad;
                    arr[i].pos = _maxPos(arr) + 1;
                }
            }
        });
    }

    // ───────── archive ─────────
    function restoreArchive(index) {
        var a = archive.slice();
        if (index < 0 || index >= a.length)
            return;
        var t = _norm(a[index]);
        a.splice(index, 1);
        archive = a;
        var arr = _clone();
        t.ord = nextOrd;
        nextOrd += 1;
        t.pos = _maxPos(arr) + 1;
        t.done = false;
        t.doneAt = 0;
        arr.push(t);
        _apply(arr, true);
        stateRev += 1;
        _saveState();
    }
    function deleteArchive(index) {
        var a = archive.slice();
        if (index < 0 || index >= a.length)
            return;
        a.splice(index, 1);
        archive = a;
        stateRev += 1;
        _saveState();
    }
    function clearArchive() {
        archive = [];
        stateRev += 1;
        _saveState();
    }

    // ───────── stats ─────────
    function daysBack(n) {
        var out = [];
        var now = Date.now();
        for (var i = n - 1; i >= 0; i--) {
            var ms = now - i * 86400000;
            var k = dayKey(ms);
            out.push({ key: k, done: doneLog[k] || 0, mins: focusLog[k] || 0, dow: new Date(ms).getDay() });
        }
        return out;
    }
    function statTotal(days) {
        var d = 0;
        var m = 0;
        for (var i = 0; i < days.length; i++) {
            d += days[i].done;
            m += days[i].mins;
        }
        return { done: d, mins: m };
    }
    function tagStats() {
        var map = {};
        function bump(tag, key) {
            if (!map[tag])
                map[tag] = { tag: tag, open: 0, done: 0 };
            map[tag][key] += 1;
        }
        for (var i = 0; i < tasks.length; i++) {
            var t = tasks[i];
            for (var j = 0; j < t.tags.length; j++)
                bump(t.tags[j], t.done ? "done" : "open");
        }
        var out = [];
        for (var k in map)
            out.push(map[k]);
        out.sort(function (a, b) { return (b.open + b.done) - (a.open + a.done); });
        return out;
    }
    function tasksOnDay(key) {
        var out = [];
        for (var i = 0; i < tasks.length; i++)
            if (!tasks[i].done && tasks[i].due > 0 && dayKey(tasks[i].due) === key)
                out.push(tasks[i]);
        return out;
    }
    function focusText(ms) {
        var m = Math.round(ms / 60000);
        if (m < 60)
            return m + "m";
        return Math.floor(m / 60) + "h " + (m % 60) + "m";
    }

    // ───────── plan today ─────────
    function planCandidates() {
        var out = [];
        for (var i = 0; i < tasks.length; i++) {
            var t = tasks[i];
            if (!t.done && (t.quad === 1 || t.quad === 2))
                out.push(t);
        }
        return out;
    }
    function promoteToToday(id) {
        _mutate(function (arr) {
            var i = _find(arr, id);
            if (i >= 0) {
                arr[i].quad = 0;
                arr[i].pos = -1;
            }
        });
        lastPlanDay = dayKey(Date.now());
        _saveState();
    }
    function markPlanSeen() {
        lastPlanDay = dayKey(Date.now());
        _saveState();
    }

    // ───────── import ─────────
    function importText(raw) {
        var lines = String(raw).split("\n");
        var arr = _clone();
        var n = 0;
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i];
            var m = /^\s*[-*]\s*\[( |x|X)\]\s+(.+)$/.exec(line);
            var text = null;
            var done = false;
            if (m !== null) {
                text = m[2];
                done = m[1].toLowerCase() === "x";
            } else if ((m = /^\s*\(([A-D])\)\s+(.+)$/.exec(line)) !== null) {
                text = m[2];
                if (m[1] === "A")
                    text = "!" + text;
                text = text.replace(/\bdue:(\d{4}-\d{2}-\d{2})/gi, "@$1");
                text = text.replace(/(^|\s)\+(\w+)/g, "$1#$2");
            } else if (/^\s*x\s+/i.test(line)) {
                text = line.replace(/^\s*x\s+/i, "");
                text = text.replace(/\bdue:(\d{4}-\d{2}-\d{2})/gi, "@$1");
                text = text.replace(/(^|\s)\+(\w+)/g, "$1#$2");
                done = true;
            } else if (/^\s*#/.test(line) || /^\s*$/.test(line) || /^\s*_/.test(line)) {
                continue;
            }
            if (text === null)
                continue;
            var p = parseQuick(text, 2);
            if (p === null)
                continue;
            var id = nextOrd;
            nextOrd += 1;
            arr.push({
                text: p.text, quad: p.quad, done: done, ord: id, pos: _maxPos(arr) + 1,
                due: p.due, repeat: p.repeat, note: "", subs: [], tags: p.tags, pomos: 0,
                doneAt: done ? Date.now() : 0, created: Date.now(), stage: 0, reminded: false,
                snooze: 0, focusMs: 0
            });
            n += 1;
        }
        if (n > 0)
            _apply(arr, true);
        return n;
    }
    Process {
        id: importProc
        stdout: StdioCollector {
            onStreamFinished: {
                var n = store.importText(text);
                store._notify("Todo import", n + " task" + (n === 1 ? "" : "s") + " added");
            }
        }
    }
    function importFromPath(path) {
        if (!path || path === "")
            return;
        importProc.command = ["sh", "-c", 'cat "$1" 2>/dev/null', "sh", path];
        importProc.running = true;
    }

    // ───────── auto backup ─────────
    Process { id: backupProc }
    function backupNow() {
        var script = 'mkdir -p "$1/backups"; ' +
            'cp "$1/tasks.json" "$1/backups/tasks-$(date +%Y%m%d-%H%M%S).json" 2>/dev/null; ' +
            'cp "$1/state.json" "$1/backups/state-$(date +%Y%m%d-%H%M%S).json" 2>/dev/null; ' +
            'ls -1t "$1/backups"/tasks-*.json 2>/dev/null | tail -n +16 | xargs -r rm -f; ' +
            'ls -1t "$1/backups"/state-*.json 2>/dev/null | tail -n +16 | xargs -r rm -f';
        backupProc.command = ["sh", "-c", script, "sh", base];
        backupProc.running = true;
    }

    function addSub(id, text) {
        text = String(text).trim();
        if (text === "")
            return;
        _mutate(function (arr) {
            var i = _find(arr, id);
            if (i >= 0)
                arr[i].subs.push({ t: text, d: false });
        });
    }

    function toggleSub(id, idx) {
        _mutate(function (arr) {
            var i = _find(arr, id);
            if (i >= 0 && idx < arr[i].subs.length)
                arr[i].subs[idx].d = !arr[i].subs[idx].d;
        });
    }

    function removeSub(id, idx) {
        _mutate(function (arr) {
            var i = _find(arr, id);
            if (i >= 0 && idx < arr[i].subs.length)
                arr[i].subs.splice(idx, 1);
        });
    }

    function _snapshot(label) {
        _undoSnap = JSON.stringify(tasks);
        undoLabel = label;
        undoVisible = true;
        undoTimer.restart();
    }

    function removeTask(id) {
        _snapshot("Task deleted");
        if (activeTaskId === id)
            activeTaskId = -1;
        _mutate(function (arr) {
            var i = _find(arr, id);
            if (i >= 0)
                arr.splice(i, 1);
        });
    }

    function clearDone() {
        if (doneCount === 0)
            return;
        _snapshot("Cleared " + doneCount + " done");
        _mutate(function (arr) {
            for (var i = arr.length - 1; i >= 0; i--)
                if (arr[i].done)
                    arr.splice(i, 1);
        });
    }

    function undo() {
        if (_undoSnap === "")
            return;
        try {
            var src = JSON.parse(_undoSnap);
            var arr = [];
            for (var i = 0; i < src.length; i++)
                arr.push(_norm(src[i]));
            _apply(arr, true);
        } catch (e) {
            console.log("todo: undo failed:", e);
        }
        _undoSnap = "";
        undoVisible = false;
        undoTimer.stop();
    }

    Timer {
        id: undoTimer
        interval: 6000
        onTriggered: {
            store.undoVisible = false;
            store._undoSnap = "";
        }
    }

    // ───────── loading ─────────
    function _loadTasks(raw) {
        try {
            var src = JSON.parse(raw);
            var arr = [];
            var m = 0;
            for (var i = 0; i < src.length; i++) {
                var t = _norm(src[i]);
                arr.push(t);
                m = Math.max(m, t.ord + 1);
            }
            nextOrd = Math.max(1, m);
            _apply(arr, false);
        } catch (e) {
            console.log("todo: could not read tasks.json:", e);
        }
        tasksLoaded = true;
        _minuteTick();
    }

    function _loadState(raw) {
        try {
            var s = JSON.parse(raw);
            goal = s.goal > 0 ? s.goal : 5;
            streak = s.streak || 0;
            lastGoalDay = s.lastGoalDay || "";
            goalHitDay = s.goalHitDay || "";
            doneLog = s.doneLog || {};
            focusLog = s.focusLog || {};
            archive = s.archive || [];
            lastReview = s.lastReview || "";
            muted = !!s.muted;
            autoStart = !!s.autoStart;
            if (s.exportPath)
                exportPath = s.exportPath;
            if (s.importPath)
                importPath = s.importPath;
            wipLimit = s.wipLimit || 0;
            celebrateEach = !!s.celebrateEach;
            soundOnDone = (s.soundOnDone !== undefined) ? !!s.soundOnDone : true;
            soundOnTimer = (s.soundOnTimer !== undefined) ? !!s.soundOnTimer : true;
            templates = s.templates || [];
            lastPlanDay = s.lastPlanDay || "";
            accentCustom = s.accentCustom || "";
            var t = s.timer;
            if (t) {
                sessions = t.sessions || 0;
                modeIndex = (t.modeIndex >= 0 && t.modeIndex < modes.length) ? t.modeIndex : 0;
                activeTaskId = (t.activeTaskId !== undefined) ? t.activeTaskId : -1;
                remaining = t.remaining > 0 ? t.remaining : modes[modeIndex].mins * 60;
                if (t.running && t.endAt) {
                    endAt = t.endAt;
                    if (endAt > Date.now()) {
                        running = true;
                        _tickRemaining();
                    } else {
                        remaining = 0;
                        _finish(true);
                    }
                }
            }
        } catch (e) {
            console.log("todo: could not read state.json:", e);
        }
        stateLoaded = true;
        stateRev += 1;
        _minuteTick();
        backupNow();
    }

    function _stateObj() {
        return {
            goal: goal, streak: streak, lastGoalDay: lastGoalDay, goalHitDay: goalHitDay,
            doneLog: doneLog, focusLog: focusLog, archive: archive, lastReview: lastReview,
            muted: muted, autoStart: autoStart, exportPath: exportPath,
            importPath: importPath, wipLimit: wipLimit, celebrateEach: celebrateEach,
            soundOnDone: soundOnDone, soundOnTimer: soundOnTimer, templates: templates,
            lastPlanDay: lastPlanDay, accentCustom: accentCustom,
            timer: {
                modeIndex: modeIndex, remaining: remaining, running: running, endAt: endAt,
                sessions: sessions, activeTaskId: activeTaskId
            }
        };
    }

    function saveState() { _saveState(); }
    function _saveState() { stateSave.restart(); }

    Timer {
        id: stateSave
        interval: 400
        onTriggered: stateFile.setText(JSON.stringify(store._stateObj(), null, 1))
    }

    FileView {
        id: tasksFile
        path: store.base + "/tasks.json"
        onLoaded: store._loadTasks(tasksFile.text())
        onLoadFailed: store.tasksLoaded = true
    }
    FileView {
        id: stateFile
        path: store.base + "/state.json"
        onLoaded: store._loadState(stateFile.text())
        onLoadFailed: store.stateLoaded = true
    }
    FileView {
        id: statusFile
        path: store.base + "/status.json"
    }
    FileView {
        id: exportFile
        path: store.exportPath
    }

    // ───────── status file for the bar plugin ─────────
    Timer {
        id: statusSoon
        interval: 300
        onTriggered: store._writeStatus()
    }
    onRunningChanged: statusSoon.restart()
    onModeIndexChanged: statusSoon.restart()
    onActiveTaskIdChanged: statusSoon.restart()
    onGoalChanged: statusSoon.restart()

    function _writeStatus() {
        statusFile.setText(JSON.stringify({
            urgent: urgentPending, pending: pending, running: running, endAt: endAt,
            remaining: remaining, mode: modes[modeIndex].name, task: activeTaskText,
            doneToday: doneToday, goal: goal, streak: streakShown, updated: Date.now()
        }));
    }

    // ───────── timer ─────────
    function fmt(sec) {
        var m = Math.floor(sec / 60);
        var s = sec % 60;
        return pad(m) + ":" + pad(s);
    }

    function _tickRemaining() {
        remaining = Math.max(0, Math.round((endAt - Date.now()) / 1000));
    }

    function setMode(i) {
        modeIndex = i;
        running = false;
        remaining = modes[i].mins * 60;
        _saveState();
    }

    function toggleRun() {
        if (running) {
            _tickRemaining();
            running = false;
        } else {
            if (remaining <= 0)
                remaining = modes[modeIndex].mins * 60;
            endAt = Date.now() + remaining * 1000;
            running = true;
        }
        _saveState();
    }

    function resetTimer() { setMode(modeIndex); }
    function nextMode() { setMode(modes[modeIndex].focus ? 1 : 0); }

    function startTask(id) {
        if (!byId[id])
            return;
        activeTaskId = id;
        if (!modes[modeIndex].focus) {
            modeIndex = 0;
            remaining = modes[0].mins * 60;
            running = false;
        }
        if (!running) {
            endAt = Date.now() + remaining * 1000;
            running = true;
        }
        _saveState();
    }

    function _finish(silent) {
        running = false;
        var m = modes[modeIndex];
        var next;
        if (m.focus) {
            sessions += 1;
            var day = dayKey(Date.now());
            focusLog[day] = (focusLog[day] || 0) + m.mins;
            if (activeTaskId >= 0 && byId[activeTaskId]) {
                var aid = activeTaskId;
                var gained = m.mins * 60000;
                _mutate(function (arr) {
                    var i = _find(arr, aid);
                    if (i >= 0) {
                        arr[i].pomos += 1;
                        arr[i].focusMs = (arr[i].focusMs || 0) + gained;
                    }
                });
            }
            next = (sessions % longBreakEvery === 0) ? 3 : 1;
            if (!silent) {
                _notify(m.name + " done", "Take a break. Sessions: " + sessions);
                _sound("end");
                celebrate(false);
            }
        } else {
            next = 0;
            if (!silent) {
                _notify(m.name + " over", "Back to work.");
                _sound("end");
            }
        }
        modeIndex = next;
        remaining = modes[next].mins * 60;
        stateRev += 1;
        _saveState();
        if (autoStart && !silent) {
            endAt = Date.now() + remaining * 1000;
            running = true;
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: store.running
        onTriggered: {
            store._tickRemaining();
            if (store.remaining <= 0)
                store._finish(false);
        }
    }

    // ───────── every minute: auto-move, reminders, weekly review ─────────
    Timer {
        interval: 60000
        repeat: true
        running: true
        onTriggered: store._minuteTick()
    }

    function _minuteTick() {
        if (!tasksLoaded)
            return;
        var now = Date.now();
        nowTick += 1;
        var arr = _clone();
        var changed = false;
        for (var i = 0; i < arr.length; i++) {
            var t = arr[i];
            if (t.done || !t.due)
                continue;
            if (t.snooze) {
                if (t.snooze > now)
                    continue;
                t.snooze = 0;
                t.reminded = false;
                t.stage = 0;
                changed = true;
            }
            if (t.due < now) {
                if (t.stage < 2) {
                    t.quad = 3;
                    t.stage = 2;
                    changed = true;
                }
            } else if (t.stage < 1 && startOfDay(t.due) <= startOfDay(now) && t.quad !== 0 && t.quad !== 3) {
                t.quad = 0;
                t.stage = 1;
                changed = true;
            }
            if (!t.reminded && t.due > now && (t.due - now) <= 15 * 60000 && !isDateOnly(t.due)) {
                var mins = Math.max(1, Math.round((t.due - now) / 60000));
                _notify("Due in " + mins + " min", t.text);
                t.reminded = true;
                changed = true;
            }
        }
        if (changed)
            _apply(arr, true);
        _checkReview(false);
    }

    function forceReview() { _checkReview(true); }

    function _checkReview(force) {
        if (!tasksLoaded || !stateLoaded)
            return;
        var now = Date.now();
        var today = dayKey(now);
        var sunday = (new Date(now).getDay() === 0);
        if (!force && !(sunday && lastReview !== today))
            return;
        var cutoff = now - 7 * 86400000;
        var keep = [];
        var moved = 0;
        var cur = _clone();
        for (var i = 0; i < cur.length; i++) {
            if (cur[i].done && cur[i].doneAt && cur[i].doneAt < cutoff) {
                archive.push(cur[i]);
                moved += 1;
            } else {
                keep.push(cur[i]);
            }
        }
        var done = 0;
        var mins = 0;
        for (var d = 0; d < 7; d++) {
            var k = dayKey(now - d * 86400000);
            done += doneLog[k] || 0;
            mins += focusLog[k] || 0;
        }
        reviewData = { done: done, mins: mins, streak: streakShown, archived: moved };
        reviewVisible = true;
        lastReview = today;
        _apply(keep, true);
        stateRev += 1;
        _saveState();
    }

    // ───────── gifs ─────────
    FolderListModel {
        id: gifs
        folder: store.gifDir
        nameFilters: ["*.gif", "*.GIF", "*.webp", "*.WEBP"]
        showDirs: false
    }
    FolderListModel {
        id: goalGifs
        folder: store.gifDir + "/goal"
        nameFilters: ["*.gif", "*.GIF", "*.webp", "*.WEBP"]
        showDirs: false
    }
    Timer {
        id: gifTimer
        interval: 4500
        onTriggered: store.gifSource = ""
    }

    function celebrate(special) {
        var m = (special && goalGifs.count > 0) ? goalGifs : gifs;
        if (m.count <= 0)
            return;
        var i = Math.floor(Math.random() * m.count);
        var src = m.get(i, "fileUrl").toString();
        if (m.count > 1 && src === lastGifUrl) {
            i = (i + 1) % m.count;
            src = m.get(i, "fileUrl").toString();
        }
        lastGifUrl = src;
        gifSource = src;
        gifTimer.restart();
    }

    function dismissGif() {
        gifTimer.stop();
        gifSource = "";
    }

    // ───────── notifications, sounds, do-not-disturb ─────────
    Process { id: notifier }
    function _notify(title, body) {
        notifier.command = ["notify-send", "-a", "Todo", title, body];
        notifier.running = true;
    }

    Process { id: sndDone }
    Process { id: sndEnd }
    function _sound(kind) {
        if (muted)
            return;
        if (kind === "done" && !soundOnDone)
            return;
        if (kind === "end" && !soundOnTimer)
            return;
        var p = (kind === "done") ? sndDone : sndEnd;
        var f = (kind === "done") ? soundDone : soundEnd;
        if (p.running)
            return;
        p.command = ["sh", "-c",
            'f="$1"; [ -f "$f" ] || exit 0; if command -v pw-play >/dev/null 2>&1; then pw-play "$f"; elif command -v paplay >/dev/null 2>&1; then paplay "$f"; elif command -v mpv >/dev/null 2>&1; then mpv --no-video --really-quiet "$f"; fi',
            "sh", f];
        p.running = true;
    }

    // Deep focus turns Do Not Disturb on for the session (swaync, mako or dunst) and restores it after.
    readonly property bool wantDnd: running && modeIndex === 2
    onWantDndChanged: _dnd(wantDnd)

    property bool _dndWanted: false
    property bool _dndEnabled: false
    property bool _dndPrev: false
    property string _dndDaemon: "none"
    readonly property string dndProbeScript: 'if command -v swaync-client >/dev/null 2>&1; then echo "swaync:$(swaync-client -D 2>/dev/null)"; elif command -v makoctl >/dev/null 2>&1; then echo "mako:$(makoctl mode 2>/dev/null | tr "\\n" ",")"; elif command -v dunstctl >/dev/null 2>&1; then echo "dunst:$(dunstctl is-paused 2>/dev/null)"; else echo "none:"; fi'

    Process {
        id: dndProbe
        stdout: StdioCollector {
            onStreamFinished: store._dndProbed(text)
        }
    }
    Process { id: dndRun }

    function _dnd(on) {
        if (on) {
            _dndWanted = true;
            dndProbe.command = ["sh", "-c", dndProbeScript];
            dndProbe.running = true;
        } else {
            _dndWanted = false;
            if (_dndEnabled) {
                _dndEnabled = false;
                if (!_dndPrev)
                    _dndRunCmd(false);
            }
        }
    }

    function _dndProbed(out) {
        if (!_dndWanted)
            return;
        var parts = String(out).trim().split(":");
        _dndDaemon = parts[0];
        var v = parts.slice(1).join(":");
        if (_dndDaemon === "none") {
            console.log("todo: no supported notification daemon found for Do Not Disturb");
            return;
        }
        _dndPrev = (_dndDaemon === "mako") ? (v.indexOf("do-not-disturb") >= 0) : (v.trim() === "true");
        _dndEnabled = true;
        if (!_dndPrev)
            _dndRunCmd(true);
    }

    function _dndRunCmd(on) {
        var c;
        if (_dndDaemon === "swaync")
            c = ["swaync-client", on ? "-dn" : "-df"];
        else if (_dndDaemon === "mako")
            c = ["makoctl", "mode", on ? "-a" : "-r", "do-not-disturb"];
        else if (_dndDaemon === "dunst")
            c = ["dunstctl", "set-paused", on ? "true" : "false"];
        else
            return;
        dndRun.command = c;
        dndRun.running = true;
    }

    // ───────── markdown export ─────────
    function exportMarkdown() {
        var L = ["# Todo", "", "_Exported " + dayKey(Date.now()) + "_", ""];
        for (var q = 0; q < 4; q++) {
            L.push("## " + quadNames[q]);
            L.push("");
            var any = false;
            for (var i = 0; i < tasks.length; i++) {
                var t = tasks[i];
                if (t.quad !== q)
                    continue;
                any = true;
                var line = "- [" + (t.done ? "x" : " ") + "] " + t.text;
                for (var g = 0; g < t.tags.length; g++)
                    line += " #" + t.tags[g];
                if (t.due > 0)
                    line += " (due " + dueEdit(t.due) + ")";
                if (t.repeat !== "")
                    line += " (repeats " + t.repeat + ")";
                L.push(line);
                for (var s = 0; s < t.subs.length; s++)
                    L.push("  - [" + (t.subs[s].d ? "x" : " ") + "] " + t.subs[s].t);
                if (t.note !== "") {
                    var nl = t.note.split("\n");
                    for (var n = 0; n < nl.length; n++)
                        L.push("  > " + nl[n]);
                }
            }
            if (!any)
                L.push("_empty_");
            L.push("");
        }
        exportFile.setText(L.join("\n"));
        _notify("Todo exported", exportPath);
    }
}
