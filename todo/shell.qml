import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

// ~/.config/quickshell/todo/shell.qml
//   run:     qs -c todo
//   toggle:  qs -c todo ipc call todo toggle      (also: open, hide, review)
// Keys (click the panel once first): arrows navigate, Space done, E edit, Enter expand,
// Delete remove, Shift+arrows move the task, N new task, Ctrl+F search, Ctrl+Z undo,
// Ctrl+1..4 pick the box for new tasks, Esc closes / cancels.
ShellRoot {
    PanelWindow {
        id: root

        // ───────── window ─────────
        readonly property int panelW: 500
        readonly property real panelAlpha: 0.9
        // true = the panel takes the keyboard as soon as it opens (blocks other apps while open)
        property bool grabKeyboard: false
        property bool open: false

        anchors { top: true; bottom: true; right: true }
        implicitWidth: panelW + th.gap * 2
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        visible: open || panel.x < implicitWidth - 1
        mask: Region { item: panel }

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "todo-panel"
        WlrLayershell.keyboardFocus: open ? (grabKeyboard ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand) : WlrKeyboardFocus.None

        onOpenChanged: if (open) Qt.callLater(root.focusKb)

        function focusMonitor() {
            var m = Hyprland.focusedMonitor;
            if (!m)
                return;
            for (var i = 0; i < Quickshell.screens.length; i++) {
                if (Quickshell.screens[i].name === m.name) {
                    root.screen = Quickshell.screens[i];
                    break;
                }
            }
        }
        function openPanel() {
            if (!open)
                focusMonitor();
            open = true;
        }

        IpcHandler {
            target: "todo"
            function toggle(): void { if (root.open) root.open = false; else root.openPanel(); }
            function show(): void { root.openPanel(); }
            function open(): void { root.openPanel(); }
            function hide(): void { root.open = false; }
            function review(): void { store.forceReview(); root.openPanel(); }
            function stats(): void { root.closeSheets(); root.statsOpen = true; root.openPanel(); }
            function archive(): void { root.closeSheets(); root.archiveOpen = true; root.openPanel(); }
            function calendar(): void { root.closeSheets(); root.calOpen = true; root.openPanel(); }
            function tags(): void { root.closeSheets(); root.tagsOpen = true; root.openPanel(); }
            function templates(): void { root.closeSheets(); root.templatesOpen = true; root.openPanel(); }
            function plan(): void { root.closeSheets(); root.planOpen = true; root.openPanel(); }
            function palette(): void { root.closeSheets(); root.openPalette(); root.openPanel(); }
            function focus(): void { root.focusMode = !root.focusMode; root.openPanel(); }
            function select(): void { root.selectMode = !root.selectMode; if (!root.selectMode) root.clearSelection(); root.openPanel(); }
            function menu(): void { root.menuOpen = !root.menuOpen; root.openPanel(); }
            function sheets(): void { root.closeSheets(); root.settingsOpen = false; }
            function settings(): void { root.closeSheets(); root.settingsOpen = true; root.openPanel(); }
            function importNow(): void { store.importFromPath(store.importPath); }
        }

        Store { id: store }

        Connections {
            target: store
            function onAccentCustomChanged() { root.applyColors(colorsFile.text()); }
        }

        // ───────── theme: Ryoku palette + metrics, with fallbacks ─────────
        QtObject {
            id: th
            property color accent: "#e8553a"
            property color baseAccent: "#e8553a"
            property color bright: "#ece7e2"
            property color dim: "#8f8882"
            property color cardBot: "#171211"
            property int radius: 10
            property int gap: 12
            readonly property string font: "JetBrainsMono Nerd Font"
        }

        function a(c, v) { return Qt.rgba(c.r, c.g, c.b, v); }

        // a different accent-derived colour per box (Urgent keeps the strong accent)
        function boxColor(i) {
            if (i === 3)
                return th.accent;
            var h0 = th.accent.hslHue < 0 ? 0 : th.accent.hslHue;
            var offs = [0.58, 0.33, 0.83];
            var h = (h0 + offs[i]) % 1;
            var s = Math.max(0.35, th.accent.hslSaturation * 0.75);
            var l = Math.min(0.68, Math.max(0.5, th.accent.hslLightness));
            return Qt.hsla(h, s, l, 1);
        }

        function applyColors(raw) {
            var map = {};
            function walk(o) {
                for (var k in o) {
                    var v = o[k];
                    if (typeof v === "string")
                        map[k.toLowerCase()] = v;
                    else if (v && typeof v === "object")
                        walk(v);
                }
            }
            try {
                walk(JSON.parse(raw));
            } catch (e) {
                console.log("todo: colors.json unreadable:", e);
                return;
            }
            function pick(names, fallback) {
                for (var i = 0; i < names.length; i++) {
                    var v = map[names[i]];
                    if (v === undefined)
                        continue;
                    if (/^[0-9a-f]{6}([0-9a-f]{2})?$/i.test(v))
                        v = "#" + v;
                    if (/^#[0-9a-f]{6}([0-9a-f]{2})?$/i.test(v))
                        return v;
                }
                return fallback;
            }
            th.accent = pick(["accent", "primary", "vermilion", "verm", "primary_color"], th.accent);
            th.bright = pick(["on_surface", "foreground", "fg", "text", "bright", "on_background"], th.bright);
            th.dim = pick(["on_surface_variant", "dim", "muted", "outline", "subtext", "comment"], th.dim);
            th.cardBot = pick(["surface_container", "surface", "background", "bg", "card_bot", "cardbot", "base"], th.cardBot);
            th.baseAccent = th.accent;
            if (store && store.accentCustom !== "")
                th.accent = store.accentCustom;
        }

        // corner radius and edge gap from Ryoku's own settings, when they can be found
        function applyMetrics(raw) {
            var map = {};
            function walk(o) {
                for (var k in o) {
                    var v = o[k];
                    if (typeof v === "number")
                        map[k.toLowerCase()] = v;
                    else if (v && typeof v === "object")
                        walk(v);
                }
            }
            try {
                walk(JSON.parse(raw));
            } catch (e) {
                return;
            }
            function num(names, lo, hi) {
                for (var i = 0; i < names.length; i++) {
                    var v = map[names[i]];
                    if (v !== undefined && v >= lo && v <= hi)
                        return v;
                }
                return -1;
            }
            var r = num(["radius", "corner_radius", "rounding", "border_radius"], 0, 30);
            if (r >= 0)
                th.radius = r;
            var g = num(["gaps_out", "gap", "gaps", "outer_gap"], 0, 40);
            if (g >= 0)
                th.gap = g;
        }

        FileView {
            id: colorsFile
            path: Quickshell.env("HOME") + "/.cache/ryoku/colors.json"
            watchChanges: true
            onFileChanged: colorsFile.reload()
            onLoaded: root.applyColors(colorsFile.text())
        }
        FileView {
            id: themeFile
            path: Quickshell.env("HOME") + "/.config/ryoku/theme.json"
            onLoaded: root.applyMetrics(themeFile.text())
        }
        FileView {
            id: desktopFile
            path: Quickshell.env("HOME") + "/.config/ryoku/desktop.json"
            onLoaded: root.applyMetrics(desktopFile.text())
        }

        // ───────── interaction state ─────────
        property int newQuad: 0
        property int selId: -1
        property int editId: -1
        property int expandedId: -1
        property bool searchOpen: false
        property bool settingsOpen: false
        property bool menuOpen: false
        property bool statsOpen: false
        property bool archiveOpen: false
        property bool calOpen: false
        property bool tagsOpen: false
        property bool paletteOpen: false
        property bool templatesOpen: false
        property bool planOpen: false
        property bool focusMode: false
        property bool selectMode: false
        property var selection: []
        property int calYear: new Date().getFullYear()
        property int calMonth: new Date().getMonth()
        property string paletteText: ""
        property int paletteTick: 0
        property int dragId: -1
        property string dragText: ""
        property int hoverQuad: -1
        property point dragPos: Qt.point(0, 0)

        function focusKb() { kb.forceActiveFocus(); }

        function openPalette() {
            paletteText = "";
            paletteTick += 1;
            paletteOpen = true;
        }
        function toggleSelect(id) {
            var s = selection.slice();
            var at = s.indexOf(id);
            if (at >= 0)
                s.splice(at, 1);
            else
                s.push(id);
            selection = s;
        }
        function clearSelection() { selection = []; }
        function isPicked(id) { return selection.indexOf(id) >= 0; }
        function selectAllVisible() {
            var s = [];
            for (var q = 0; q < 4; q++) {
                var it = store.visibleIn(q);
                for (var i = 0; i < it.length; i++)
                    if (!it[i].done)
                        s.push(it[i].ord);
            }
            selection = s;
            if (s.length > 0)
                selectMode = true;
        }
        function closeSheets() {
            menuOpen = false;
            statsOpen = false;
            archiveOpen = false;
            calOpen = false;
            tagsOpen = false;
            paletteOpen = false;
            templatesOpen = false;
            planOpen = false;
        }
        function anySheet() {
            return menuOpen || statsOpen || archiveOpen || calOpen || tagsOpen ||
                   paletteOpen || templatesOpen || planOpen;
        }

        function addFromInput() {
            if (store.addFromText(input.text, newQuad))
                input.text = "";
        }

        function openSearch() {
            searchOpen = true;
            Qt.callLater(searchInput.forceActiveFocus);
        }
        function closeSearch() {
            searchOpen = false;
            searchInput.text = "";
            store.filter = "";
            store.tagFilter = "";
            store.dateFilter = "";
            focusKb();
        }

        function escapeKey() {
            if (store.gifSource.toString() !== "")
                store.dismissGif();
            else if (focusMode)
                focusMode = false;
            else if (anySheet())
                closeSheets();
            else if (store.reviewVisible)
                store.reviewVisible = false;
            else if (settingsOpen)
                settingsOpen = false;
            else if (searchOpen || store.tagFilter !== "" || store.dateFilter !== "")
                closeSearch();
            else if (expandedId >= 0)
                expandedId = -1;
            else
                open = false;
        }

        // ── keyboard navigation ──
        function navList() {
            var out = [];
            for (var q = 0; q < 4; q++) {
                var it = store.visibleIn(q);
                for (var i = 0; i < it.length; i++)
                    out.push(it[i].ord);
            }
            return out;
        }
        function revealSel() {
            var t = store.byId[selId];
            if (!t)
                return;
            var box = quadRepeater.itemAt(t.quad);
            if (!box)
                return;
            var arr = store.visibleIn(t.quad);
            for (var i = 0; i < arr.length; i++) {
                if (arr[i].ord === selId) {
                    box.lv.positionViewAtIndex(i, ListView.Contain);
                    break;
                }
            }
        }
        function moveSel(delta) {
            var l = navList();
            if (l.length === 0)
                return;
            var i = l.indexOf(selId);
            if (i < 0)
                i = delta > 0 ? 0 : l.length - 1;
            else
                i = Math.max(0, Math.min(l.length - 1, i + delta));
            selId = l[i];
            revealSel();
        }
        function sideQuad(q, dir) {
            if (dir < 0)
                return (q % 2 === 1) ? q - 1 : q;
            return (q % 2 === 0) ? q + 1 : q;
        }
        function sideSel(dir) {
            var t = store.byId[selId];
            if (!t) {
                moveSel(1);
                return;
            }
            var cur = store.visibleIn(t.quad);
            var idx = 0;
            for (var i = 0; i < cur.length; i++)
                if (cur[i].ord === selId)
                    idx = i;
            var q2 = sideQuad(t.quad, dir);
            if (q2 === t.quad)
                return;
            var tgt = store.visibleIn(q2);
            if (tgt.length === 0)
                return;
            selId = tgt[Math.min(idx, tgt.length - 1)].ord;
            revealSel();
        }
        function moveSelToBox(dir) {
            var t = store.byId[selId];
            if (!t)
                return;
            var q2 = sideQuad(t.quad, dir);
            if (q2 === t.quad)
                return;
            store.moveTask(selId, q2, -1, -1);
            Qt.callLater(root.revealSel);
        }
        function shiftVert(dir) {
            var t = store.byId[selId];
            if (!t)
                return;
            var items = store.visibleIn(t.quad);
            var i = -1;
            for (var k = 0; k < items.length; k++)
                if (items[k].ord === selId)
                    i = k;
            if (i < 0)
                return;
            var j = i + dir;
            if (j < 0 || j >= items.length)
                return;
            var others = items.filter(function (x) { return x.ord !== selId; });
            var prev = j > 0 ? others[j - 1].ord : -1;
            var next = j < others.length ? others[j].ord : -1;
            store.moveTask(selId, t.quad, prev, next);
            Qt.callLater(root.revealSel);
        }
        function deleteSel() {
            if (selId < 0)
                return;
            var l = navList();
            var i = l.indexOf(selId);
            var nxt = (i >= 0 && i + 1 < l.length) ? l[i + 1] : (i > 0 ? l[i - 1] : -1);
            store.removeTask(selId);
            selId = nxt;
        }

        // ── drag and drop (drop position decides the order too) ──
        function quadAt(sx, sy) {
            for (var i = 0; i < 4; i++) {
                var q = quadRepeater.itemAt(i);
                if (!q)
                    continue;
                var p = q.mapFromItem(null, sx, sy);
                if (p.x >= 0 && p.y >= 0 && p.x <= q.width && p.y <= q.height)
                    return i;
            }
            return -1;
        }
        function beginDrag(id, text, pos) {
            dragId = id;
            dragText = text;
            updateDrag(pos);
        }
        function updateDrag(pos) {
            dragPos = Qt.point(pos.x, pos.y);
            var p = panel.mapFromItem(null, pos.x, pos.y);
            ghost.x = p.x - ghost.width / 2;
            ghost.y = p.y - ghost.height / 2;
            hoverQuad = quadAt(pos.x, pos.y);
        }
        function endDrag() {
            var id = dragId;
            var q = hoverQuad;
            var pos = dragPos;
            dragId = -1;
            hoverQuad = -1;
            if (id < 0 || q < 0)
                return;
            var box = quadRepeater.itemAt(q);
            if (!box)
                return;
            var lv = box.lv;
            var mdl = box.mdl;
            var p = lv.mapFromItem(null, pos.x, pos.y);
            var ords = [];
            for (var i = 0; i < mdl.count; i++)
                ords.push(mdl.get(i).ord);
            var cy = p.y + lv.contentY;
            var hit = lv.indexAt(Math.max(1, Math.min(p.x, lv.width - 1)), cy);
            var idx;
            if (hit < 0) {
                idx = (p.y < 0) ? 0 : ords.length;
            } else {
                var it = lv.itemAtIndex(hit);
                idx = hit;
                if (it && cy > it.y + it.height / 2)
                    idx = hit + 1;
            }
            var from = ords.indexOf(id);
            if (from >= 0 && from < idx)
                idx -= 1;
            if (from >= 0)
                ords.splice(from, 1);
            var prev = idx > 0 ? ords[idx - 1] : -1;
            var next = idx < ords.length ? ords[idx] : -1;
            store.moveTask(id, q, prev, next);
        }

        function fmtMins(m) {
            return Math.floor(m / 60) + "h " + (m % 60) + "m";
        }

        // ───────── the panel ─────────
        Rectangle {
            id: panel
            width: root.panelW
            y: th.gap
            height: parent.height - th.gap * 2
            x: root.open ? th.gap : root.implicitWidth
            Behavior on x { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

            radius: th.radius + 2
            color: "transparent"
            gradient: Gradient {
                GradientStop { position: 0.0; color: root.a(th.accent, 0.14) }
                GradientStop { position: 0.075; color: root.a(th.cardBot, root.panelAlpha) }
                GradientStop { position: 1.0; color: root.a(th.cardBot, root.panelAlpha) }
            }
            border.width: 1
            border.color: root.a(th.dim, 0.28)

            // hairline accent along the top edge
            Rectangle {
                width: parent.width - 80
                height: 1
                anchors.top: parent.top
                anchors.topMargin: 1
                anchors.horizontalCenter: parent.horizontalCenter
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 0.5; color: root.a(th.accent, 0.85) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }

            Item {
                id: kb
                anchors.fill: parent
                focus: true

                Keys.onPressed: function (event) {
                    var ctrl = (event.modifiers & Qt.ControlModifier) !== 0;
                    var shift = (event.modifiers & Qt.ShiftModifier) !== 0;
                    var k = event.key;
                    var typing = !kb.activeFocus;
                    if (k === Qt.Key_Escape) {
                        if (typing)
                            kb.forceActiveFocus();
                        else
                            root.escapeKey();
                        event.accepted = true;
                        return;
                    }
                    if (ctrl && k === Qt.Key_F) {
                        root.openSearch();
                        event.accepted = true;
                        return;
                    }
                    if (ctrl && k === Qt.Key_K) {
                        root.openPalette();
                        event.accepted = true;
                        return;
                    }
                    if (ctrl && k === Qt.Key_A) {
                        root.selectAllVisible();
                        event.accepted = true;
                        return;
                    }
                    if (ctrl && k === Qt.Key_Z) {
                        store.undo();
                        event.accepted = true;
                        return;
                    }
                    if (ctrl && k >= Qt.Key_1 && k <= Qt.Key_4) {
                        root.newQuad = k - Qt.Key_1;
                        event.accepted = true;
                        return;
                    }
                    if (typing || ctrl)
                        return;
                    if (k === Qt.Key_N) {
                        input.forceActiveFocus();
                    } else if (k === Qt.Key_Up) {
                        if (shift) root.shiftVert(-1); else root.moveSel(-1);
                    } else if (k === Qt.Key_Down) {
                        if (shift) root.shiftVert(1); else root.moveSel(1);
                    } else if (k === Qt.Key_Left) {
                        if (shift) root.moveSelToBox(-1); else root.sideSel(-1);
                    } else if (k === Qt.Key_Right) {
                        if (shift) root.moveSelToBox(1); else root.sideSel(1);
                    } else if (k === Qt.Key_Space) {
                        if (root.selId >= 0) store.toggleDone(root.selId);
                    } else if (k === Qt.Key_E) {
                        if (root.selId >= 0) root.editId = root.selId;
                    } else if (k === Qt.Key_Delete) {
                        root.deleteSel();
                    } else if (k === Qt.Key_Return || k === Qt.Key_Enter) {
                        if (root.selId >= 0) root.expandedId = (root.expandedId === root.selId) ? -1 : root.selId;
                    } else {
                        return;
                    }
                    event.accepted = true;
                }

                Item {
                    id: content
                    anchors.fill: parent
                    anchors.margins: 16

                    // ── top: header, search, timer, add ──
                    Column {
                        id: topCol
                        width: parent.width
                        spacing: 12

                        // header
                        Item {
                            width: parent.width
                            height: 32
                            Rectangle {
                                id: logo
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                width: 24
                                height: 24
                                radius: 7
                                gradient: Gradient {
                                    GradientStop { position: 0.0; color: root.a(th.accent, 0.95) }
                                    GradientStop { position: 1.0; color: root.a(th.accent, 0.45) }
                                }
                                border.width: 1
                                border.color: root.a(th.accent, 0.6)
                                Text {
                                    anchors.centerIn: parent
                                    text: "\u2713"
                                    color: th.cardBot
                                    font.family: th.font
                                    font.pixelSize: 12
                                    font.bold: true
                                }
                            }
                            Column {
                                anchors.left: logo.right
                                anchors.leftMargin: 9
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 0
                                Text {
                                    id: title
                                    text: "Todo"
                                    color: th.bright
                                    font.family: th.font
                                    font.pixelSize: 15
                                    font.bold: true
                                    font.letterSpacing: 0.5
                                }
                                Text {
                                    text: {
                                        var r = store.nowTick;
                                        return Qt.formatDate(new Date(), "ddd, MMM d");
                                    }
                                    color: root.a(th.dim, 0.85)
                                    font.family: th.font
                                    font.pixelSize: 8
                                }
                            }
                            Row {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 8
                                StatChip {
                                    anchors.verticalCenter: parent.verticalCenter
                                    glyph: "\u2713"
                                    label: store.doneToday + "/" + store.goal
                                    tone: store.doneToday >= store.goal ? th.accent : th.dim
                                    textColor: store.doneToday >= store.goal ? th.accent : th.bright
                                    family: th.font
                                }
                                StatChip {
                                    anchors.verticalCenter: parent.verticalCenter
                                    glyph: "\u25F7"
                                    label: store.focusToday + "m"
                                    tone: th.dim
                                    textColor: th.dim
                                    family: th.font
                                }
                                StatChip {
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: store.streakShown > 0
                                    glyph: "\u25C6"
                                    label: store.streakShown + "d"
                                    tone: th.accent
                                    textColor: th.accent
                                    family: th.font
                                }
                                IconBtn {
                                    anchors.verticalCenter: parent.verticalCenter
                                    size: 15
                                    glyph: "\u22EF"
                                    on: root.menuOpen
                                    idle: th.dim
                                    hot: th.accent
                                    family: th.font
                                    onClicked: root.menuOpen = !root.menuOpen
                                }
                                IconBtn {
                                    anchors.verticalCenter: parent.verticalCenter
                                    size: 13
                                    glyph: "\u2699"
                                    on: root.settingsOpen
                                    idle: th.dim
                                    hot: th.accent
                                    family: th.font
                                    onClicked: root.settingsOpen = !root.settingsOpen
                                }
                                IconBtn {
                                    anchors.verticalCenter: parent.verticalCenter
                                    size: 12
                                    glyph: "\u2715"
                                    idle: th.dim
                                    hot: th.accent
                                    family: th.font
                                    onClicked: root.open = false
                                }
                            }
                        }

                        NavBar {
                            width: parent.width
                            host: root
                            th: th
                            st: store
                        }

                        // search + tag filter
                        Rectangle {
                            visible: root.searchOpen || store.tagFilter !== "" || store.dateFilter !== ""
                            width: parent.width
                            height: 30
                            radius: th.radius
                            color: root.a(th.dim, 0.07)
                            border.width: 1
                            border.color: searchInput.activeFocus ? root.a(th.accent, 0.6) : root.a(th.dim, 0.14)

                            Row {
                                id: chipsRow
                                anchors.right: parent.right
                                anchors.rightMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 8
                                Text {
                                    id: tagChip
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: store.tagFilter !== ""
                                    text: "#" + store.tagFilter + "  \u2715"
                                    color: th.accent
                                    font.family: th.font
                                    font.pixelSize: 11
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: store.tagFilter = ""
                                    }
                                }
                                Text {
                                    id: dateChip
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: store.dateFilter !== ""
                                    text: "\u25F7 " + store.dateFilter + "  \u2715"
                                    color: th.accent
                                    font.family: th.font
                                    font.pixelSize: 11
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: store.dateFilter = ""
                                    }
                                }
                            }
                            TextInput {
                                id: searchInput
                                anchors.left: parent.left
                                anchors.leftMargin: 12
                                anchors.right: chipsRow.left
                                anchors.rightMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                clip: true
                                color: th.bright
                                selectByMouse: true
                                font.family: th.font
                                font.pixelSize: 12
                                onTextChanged: store.filter = text
                            }
                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                visible: searchInput.text === ""
                                text: "Search (Ctrl+F)"
                                color: root.a(th.dim, 0.8)
                                font.family: th.font
                                font.pixelSize: 12
                            }
                        }

                        // timer
                        Column {
                            width: parent.width
                            spacing: 8

                            Row {
                                spacing: 14
                                Repeater {
                                    model: store.modes
                                    delegate: Item {
                                        id: tab
                                        required property int index
                                        required property var modelData
                                        readonly property bool on: store.modeIndex === index
                                        width: tabLabel.implicitWidth
                                        height: 20
                                        Text {
                                            id: tabLabel
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: tab.modelData.name + " " + tab.modelData.mins
                                            color: tab.on ? th.bright : th.dim
                                            font.family: th.font
                                            font.pixelSize: 12
                                        }
                                        Rectangle {
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            anchors.bottom: parent.bottom
                                            height: 1
                                            color: th.accent
                                            visible: tab.on
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: store.setMode(tab.index)
                                        }
                                    }
                                }
                            }

                            Text {
                                visible: store.activeTaskText !== ""
                                width: parent.width
                                elide: Text.ElideRight
                                text: "\u25B6 " + store.activeTaskText
                                color: th.accent
                                font.family: th.font
                                font.pixelSize: 11
                            }

                            Item {
                                width: parent.width
                                height: 40

                                Rectangle {
                                    id: pulse
                                    visible: store.running
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 6
                                    height: 6
                                    radius: 3
                                    color: th.accent
                                    SequentialAnimation on opacity {
                                        running: store.running
                                        loops: Animation.Infinite
                                        NumberAnimation { to: 0.25; duration: 700; easing.type: Easing.InOutSine }
                                        NumberAnimation { to: 1.0; duration: 700; easing.type: Easing.InOutSine }
                                    }
                                }

                                Text {
                                    anchors.left: pulse.visible ? pulse.right : parent.left
                                    anchors.leftMargin: pulse.visible ? 9 : 0
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: store.fmt(store.remaining)
                                    color: th.bright
                                    font.family: th.font
                                    font.pixelSize: 30
                                    font.letterSpacing: 0.5
                                }

                                Row {
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        rightPadding: 10
                                        text: store.sessions > 0 ? (store.sessions + " sessions") : ""
                                        color: th.dim
                                        font.family: th.font
                                        font.pixelSize: 11
                                    }
                                    IconBtn {
                                        size: 17
                                        glyph: store.running ? "\u275A\u275A" : "\u25B6"
                                        on: store.running
                                        idle: th.dim
                                        hot: th.accent
                                        family: th.font
                                        onClicked: store.toggleRun()
                                    }
                                    IconBtn {
                                        glyph: "\u21BA"
                                        idle: th.dim
                                        hot: th.accent
                                        family: th.font
                                        onClicked: store.resetTimer()
                                    }
                                    IconBtn {
                                        glyph: "\u23ED"
                                        idle: th.dim
                                        hot: th.accent
                                        family: th.font
                                        onClicked: store.nextMode()
                                    }
                                }
                            }

                            Rectangle {
                                width: parent.width
                                height: 3
                                radius: 1.5
                                color: root.a(th.dim, 0.18)
                                Rectangle {
                                    height: parent.height
                                    radius: parent.radius
                                    width: parent.width * (1 - store.remaining / store.total)
                                    gradient: Gradient {
                                        orientation: Gradient.Horizontal
                                        GradientStop { position: 0.0; color: root.a(th.accent, 0.45) }
                                        GradientStop { position: 0.7; color: th.accent }
                                        GradientStop { position: 1.0; color: root.a(th.bright, 0.9) }
                                    }
                                }
                            }
                        }

                        // add task
                        Rectangle {
                            width: parent.width
                            height: 36
                            radius: th.radius
                            color: "transparent"
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: root.a(th.accent, 0.07) }
                                GradientStop { position: 0.35; color: root.a(th.dim, 0.04) }
                                GradientStop { position: 1.0; color: root.a(th.dim, 0.04) }
                            }
                            border.width: 1
                            border.color: input.activeFocus ? root.a(th.accent, 0.6) : root.a(th.dim, 0.14)

                            Text {
                                id: quadPick
                                anchors.left: parent.left
                                anchors.leftMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                text: store.quadNames[root.newQuad] + " \u25BE"
                                color: root.newQuad === 3 ? th.accent : th.dim
                                font.family: th.font
                                font.pixelSize: 12
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.newQuad = (root.newQuad + 1) % 4
                                }
                            }

                            IconBtn {
                                id: addBtn
                                anchors.right: parent.right
                                anchors.rightMargin: 4
                                anchors.verticalCenter: parent.verticalCenter
                                size: 18
                                glyph: "+"
                                idle: th.dim
                                hot: th.accent
                                family: th.font
                                onClicked: root.addFromInput()
                            }

                            Item {
                                anchors.left: quadPick.right
                                anchors.leftMargin: 12
                                anchors.right: addBtn.left
                                anchors.rightMargin: 4
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom

                                TextInput {
                                    id: input
                                    anchors.fill: parent
                                    verticalAlignment: TextInput.AlignVCenter
                                    clip: true
                                    color: th.bright
                                    selectByMouse: true
                                    font.family: th.font
                                    font.pixelSize: 13
                                    onAccepted: root.addFromInput()
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: input.text === ""
                                    text: "Add a task  (!  #w  @fri  *daily  #tag)"
                                    color: root.a(th.dim, 0.8)
                                    font.family: th.font
                                    font.pixelSize: 12
                                }
                            }
                        }
                    }

                    // ── bulk bar (appears when tasks are selected) ──
                    Rectangle {
                        id: bulkBar
                        visible: root.selection.length > 0
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: footer.top
                        anchors.bottomMargin: 6
                        height: 26
                        radius: th.radius
                        color: root.a(th.accent, 0.12)
                        border.width: 1
                        border.color: root.a(th.accent, 0.45)

                        Row {
                            anchors.centerIn: parent
                            spacing: 10
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.selection.length + " selected"
                                color: th.bright
                                font.family: th.font
                                font.pixelSize: 10
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Done"
                                color: th.accent
                                font.family: th.font
                                font.pixelSize: 10
                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -4
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        store.bulkDone(root.selection);
                                        root.clearSelection();
                                    }
                                }
                            }
                            Repeater {
                                model: ["T", "W", "S", "U"]
                                delegate: Text {
                                    required property int index
                                    required property string modelData
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "\u2192" + modelData
                                    color: th.dim
                                    font.family: th.font
                                    font.pixelSize: 10
                                    MouseArea {
                                        anchors.fill: parent
                                        anchors.margins: -4
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            store.bulkMove(root.selection, index);
                                            root.clearSelection();
                                        }
                                    }
                                }
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Del"
                                color: th.dim
                                font.family: th.font
                                font.pixelSize: 10
                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -4
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        store.bulkRemove(root.selection);
                                        root.clearSelection();
                                    }
                                }
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "\u2715"
                                color: th.dim
                                font.family: th.font
                                font.pixelSize: 10
                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -4
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.clearSelection()
                                }
                            }
                        }
                    }

                    // ── footer ──
                    Item {
                        id: footer
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: 18

                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            height: 1
                            color: root.a(th.dim, 0.12)
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: "drag to move \u00B7 dbl-click to edit \u00B7 Enter to expand"
                            color: root.a(th.dim, 0.8)
                            font.family: th.font
                            font.pixelSize: 10
                        }
                        Row {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 14
                            Text {
                                text: "Export"
                                color: exportArea.containsMouse ? th.accent : th.dim
                                font.family: th.font
                                font.pixelSize: 11
                                MouseArea {
                                    id: exportArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: store.exportMarkdown()
                                }
                            }
                            Text {
                                visible: store.doneCount > 0
                                text: "Clear done"
                                color: clearArea.containsMouse ? th.accent : th.dim
                                font.family: th.font
                                font.pixelSize: 11
                                MouseArea {
                                    id: clearArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: store.clearDone()
                                }
                            }
                        }
                    }

                    // ── the four boxes (fill the space between) ──
                    Grid {
                        id: grid
                        anchors.top: topCol.bottom
                        anchors.topMargin: 12
                        anchors.bottom: footer.top
                        anchors.bottomMargin: 10
                        anchors.left: parent.left
                        anchors.right: parent.right
                        columns: 2
                        spacing: 8

                        Repeater {
                            id: quadRepeater
                            model: 4

                            delegate: Rectangle {
                                id: quadBox
                                required property int index
                                property alias lv: qlist
                                property alias mdl: lm
                                readonly property bool urgent: index === 3
                                readonly property bool hot: root.hoverQuad === index
                                readonly property bool overWip: index === 3 && store.wipLimit > 0 && lm.count > store.wipLimit

                                width: (grid.width - grid.spacing) / 2
                                height: (grid.height - grid.spacing) / 2
                                radius: th.radius
                                color: "transparent"
                                gradient: Gradient {
                                    GradientStop { position: 0.0; color: root.a(root.boxColor(index), hot ? 0.17 : 0.11) }
                                    GradientStop { position: 0.24; color: root.a(root.boxColor(index), 0.035) }
                                    GradientStop { position: 1.0; color: "transparent" }
                                }
                                border.width: 1
                                border.color: hot ? th.accent : root.a(urgent ? th.accent : th.dim, urgent ? 0.4 : 0.14)

                                Rectangle {
                                    anchors.top: parent.top
                                    anchors.left: parent.left
                                    anchors.leftMargin: 12
                                    anchors.right: parent.right
                                    anchors.rightMargin: 12
                                    height: 2
                                    radius: 1
                                    color: root.a(root.boxColor(index), hot ? 0.9 : 0.45)
                                }

                                // The model holds only task ids; rows read their data from the store.
                                // Diff-syncing it is what makes add / remove / move animate.
                                ListModel { id: lm }

                                function sync() {
                                    var items = store.visibleIn(index);
                                    var want = {};
                                    for (var i = 0; i < items.length; i++)
                                        want[items[i].ord] = true;
                                    for (var j = lm.count - 1; j >= 0; j--)
                                        if (!want[lm.get(j).ord])
                                            lm.remove(j);
                                    for (var k = 0; k < items.length; k++) {
                                        var id = items[k].ord;
                                        var at = -1;
                                        for (var m = k; m < lm.count; m++) {
                                            if (lm.get(m).ord === id) {
                                                at = m;
                                                break;
                                            }
                                        }
                                        if (at < 0)
                                            lm.insert(k, { ord: id });
                                        else if (at !== k)
                                            lm.move(at, k, 1);
                                    }
                                }

                                Component.onCompleted: sync()
                                Connections {
                                    target: store
                                    function onTasksChanged() { quadBox.sync(); }
                                    function onFilterChanged() { quadBox.sync(); }
                                    function onTagFilterChanged() { quadBox.sync(); }
                                    function onDateFilterChanged() { quadBox.sync(); }
                                }

                                Item {
                                    id: qhead
                                    x: 12
                                    y: 6
                                    width: parent.width - 20
                                    height: 24

                                    Rectangle {
                                        id: dot
                                        anchors.left: parent.left
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 7
                                        height: 7
                                        radius: 3.5
                                        color: root.boxColor(quadBox.index)
                                    }
                                    Text {
                                        id: qname
                                        anchors.left: dot.right
                                        anchors.leftMargin: 7
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: store.quadNames[quadBox.index]
                                        color: quadBox.urgent ? th.accent : th.bright
                                        font.family: th.font
                                        font.pixelSize: 12
                                        font.bold: true
                                    }
                                    Rectangle {
                                        anchors.left: qname.right
                                        anchors.leftMargin: 6
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: lm.count > 0
                                        width: countLabel.implicitWidth + 8
                                        height: 14
                                        radius: 4
                                        color: quadBox.overWip ? root.a(th.accent, 0.18) : root.a(th.dim, 0.10)
                                        Text {
                                            id: countLabel
                                            anchors.centerIn: parent
                                            text: (quadBox.index === 3 && store.wipLimit > 0) ? lm.count + "/" + store.wipLimit : lm.count
                                            color: quadBox.overWip ? th.accent : th.dim
                                            font.family: th.font
                                            font.pixelSize: 8
                                        }
                                    }
                                    IconBtn {
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        size: 15
                                        glyph: "+"
                                        idle: th.dim
                                        hot: th.accent
                                        family: th.font
                                        onClicked: {
                                            root.newQuad = quadBox.index;
                                            input.forceActiveFocus();
                                        }
                                    }
                                }

                                Text {
                                    anchors.centerIn: parent
                                    visible: lm.count === 0 && root.dragId >= 0
                                    text: "drop here"
                                    color: root.a(th.dim, 0.8)
                                    font.family: th.font
                                    font.pixelSize: 11
                                }

                                ListView {
                                    id: qlist
                                    x: 6
                                    y: qhead.y + qhead.height + 2
                                    width: parent.width - 12
                                    height: parent.height - y - 6
                                    clip: true
                                    interactive: false
                                    spacing: 2
                                    model: lm

                                    WheelHandler {
                                        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                                        onWheel: function (event) {
                                            var maxY = Math.max(0, qlist.contentHeight - qlist.height);
                                            qlist.contentY = Math.max(0, Math.min(maxY, qlist.contentY - event.angleDelta.y / 2));
                                        }
                                    }

                                    add: Transition {
                                        ParallelAnimation {
                                            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 180 }
                                            NumberAnimation { property: "x"; from: -14; to: 0; duration: 180; easing.type: Easing.OutCubic }
                                        }
                                    }
                                    remove: Transition {
                                        ParallelAnimation {
                                            NumberAnimation { property: "opacity"; to: 0; duration: 140 }
                                            NumberAnimation { property: "x"; to: 24; duration: 140 }
                                        }
                                    }
                                    displaced: Transition {
                                        NumberAnimation { properties: "y"; duration: 160; easing.type: Easing.OutCubic }
                                    }
                                    move: Transition {
                                        NumberAnimation { properties: "y"; duration: 160; easing.type: Easing.OutCubic }
                                    }

                                    delegate: TaskRow {
                                        st: store
                                        theme: th
                                        host: root
                                        quad: quadBox.index
                                        width: qlist.width
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ───────── overlays ─────────
            Rectangle {
                id: ghost
                z: 100
                visible: root.dragId >= 0
                width: 200
                height: 28
                radius: th.radius
                color: th.cardBot
                border.width: 1
                border.color: th.accent
                Text {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    verticalAlignment: Text.AlignVCenter
                    text: root.dragText
                    elide: Text.ElideRight
                    color: th.bright
                    font.family: th.font
                    font.pixelSize: 12
                }
            }

            Rectangle {
                id: snack
                z: 130
                visible: store.undoVisible
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 46
                width: snackRow.implicitWidth + 28
                height: 34
                radius: th.radius
                color: th.cardBot
                border.width: 1
                border.color: root.a(th.accent, 0.5)
                Row {
                    id: snackRow
                    anchors.centerIn: parent
                    spacing: 16
                    Text {
                        text: store.undoLabel
                        color: th.bright
                        font.family: th.font
                        font.pixelSize: 12
                    }
                    Text {
                        text: "Undo"
                        color: th.accent
                        font.family: th.font
                        font.pixelSize: 12
                        font.bold: true
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: store.undo()
                        }
                    }
                }
            }

            Rectangle {
                id: settingsCard
                z: 120
                visible: root.settingsOpen
                anchors.top: parent.top
                anchors.topMargin: 48
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                height: setCol.implicitHeight + 28
                radius: th.radius
                color: th.cardBot
                border.width: 1
                border.color: root.a(th.accent, 0.5)

                Column {
                    id: setCol
                    x: 14
                    y: 14
                    width: parent.width - 28
                    spacing: 12

                    Text {
                        text: "Settings"
                        color: th.bright
                        font.family: th.font
                        font.pixelSize: 13
                        font.bold: true
                    }

                    Item {
                        width: parent.width
                        height: 26
                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Daily goal (tasks)"
                            color: th.bright
                            font.family: th.font
                            font.pixelSize: 12
                        }
                        Row {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            IconBtn {
                                size: 15
                                glyph: "\u2212"
                                idle: th.dim
                                hot: th.accent
                                family: th.font
                                onClicked: {
                                    store.goal = Math.max(1, store.goal - 1);
                                    store.saveState();
                                }
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 28
                                horizontalAlignment: Text.AlignHCenter
                                text: store.goal
                                color: th.accent
                                font.family: th.font
                                font.pixelSize: 13
                            }
                            IconBtn {
                                size: 15
                                glyph: "+"
                                idle: th.dim
                                hot: th.accent
                                family: th.font
                                onClicked: {
                                    store.goal = store.goal + 1;
                                    store.saveState();
                                }
                            }
                        }
                    }

                    Item {
                        width: parent.width
                        height: 22
                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Start the next phase automatically"
                            color: th.bright
                            font.family: th.font
                            font.pixelSize: 12
                        }
                        Toggle {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            on: store.autoStart
                            accent: th.accent
                            dim: th.dim
                            onToggled: {
                                store.autoStart = !store.autoStart;
                                store.saveState();
                            }
                        }
                    }

                    Item {
                        width: parent.width
                        height: 22
                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Sounds"
                            color: th.bright
                            font.family: th.font
                            font.pixelSize: 12
                        }
                        Toggle {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            on: !store.muted
                            accent: th.accent
                            dim: th.dim
                            onToggled: {
                                store.muted = !store.muted;
                                store.saveState();
                            }
                        }
                    }

                    Item {
                        width: parent.width
                        height: 26
                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Accent"
                            color: th.bright
                            font.family: th.font
                            font.pixelSize: 12
                        }
                        Row {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 6
                            Repeater {
                                model: ["", "#e8553a", "#f0a35e", "#8fbf6a", "#5aa9e6", "#a98ae0", "#e57fa8"]
                                delegate: Rectangle {
                                    required property int index
                                    required property string modelData
                                    width: 16
                                    height: 16
                                    radius: 8
                                    color: modelData === "" ? th.cardBot : modelData
                                    border.width: (store.accentCustom === modelData) ? 2 : 1
                                    border.color: index === 0 ? th.dim : th.bright
                                    Text {
                                        visible: index === 0
                                        anchors.centerIn: parent
                                        text: "A"
                                        color: th.bright
                                        font.family: th.font
                                        font.pixelSize: 8
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            store.accentCustom = modelData;
                                            store.saveState();
                                            root.applyColors(colorsFile.text());
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Item {
                        width: parent.width
                        height: 26
                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Urgent WIP limit (0 = off)"
                            color: th.bright
                            font.family: th.font
                            font.pixelSize: 12
                        }
                        Row {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            IconBtn {
                                size: 15
                                glyph: "\u2212"
                                idle: th.dim
                                hot: th.accent
                                family: th.font
                                onClicked: {
                                    store.wipLimit = Math.max(0, store.wipLimit - 1);
                                    store.saveState();
                                }
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 28
                                horizontalAlignment: Text.AlignHCenter
                                text: store.wipLimit === 0 ? "off" : store.wipLimit
                                color: th.accent
                                font.family: th.font
                                font.pixelSize: 12
                            }
                            IconBtn {
                                size: 15
                                glyph: "+"
                                idle: th.dim
                                hot: th.accent
                                family: th.font
                                onClicked: {
                                    store.wipLimit = Math.min(9, store.wipLimit + 1);
                                    store.saveState();
                                }
                            }
                        }
                    }

                    Item {
                        width: parent.width
                        height: 22
                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Celebrate every task"
                            color: th.bright
                            font.family: th.font
                            font.pixelSize: 12
                        }
                        Toggle {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            on: store.celebrateEach
                            accent: th.accent
                            dim: th.dim
                            onToggled: {
                                store.celebrateEach = !store.celebrateEach;
                                store.saveState();
                            }
                        }
                    }

                    Item {
                        width: parent.width
                        height: 22
                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Sound when a task is done"
                            color: th.bright
                            font.family: th.font
                            font.pixelSize: 12
                        }
                        Toggle {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            on: store.soundOnDone
                            accent: th.accent
                            dim: th.dim
                            onToggled: {
                                store.soundOnDone = !store.soundOnDone;
                                store.saveState();
                            }
                        }
                    }

                    Item {
                        width: parent.width
                        height: 22
                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Sound when the timer ends"
                            color: th.bright
                            font.family: th.font
                            font.pixelSize: 12
                        }
                        Toggle {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            on: store.soundOnTimer
                            accent: th.accent
                            dim: th.dim
                            onToggled: {
                                store.soundOnTimer = !store.soundOnTimer;
                                store.saveState();
                            }
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: 4
                        Text {
                            text: "Markdown export path"
                            color: th.dim
                            font.family: th.font
                            font.pixelSize: 11
                        }
                        Rectangle {
                            width: parent.width
                            height: 26
                            radius: 4
                            color: root.a(th.dim, 0.08)
                            border.width: 1
                            border.color: pathInput.activeFocus ? th.accent : root.a(th.dim, 0.2)
                            TextInput {
                                id: pathInput
                                anchors.fill: parent
                                anchors.margins: 7
                                verticalAlignment: TextInput.AlignVCenter
                                clip: true
                                color: th.bright
                                selectByMouse: true
                                font.family: th.font
                                font.pixelSize: 11
                                text: store.exportPath
                                onEditingFinished: {
                                    if (text.trim() !== "") {
                                        store.exportPath = text.trim();
                                        store.saveState();
                                    }
                                }
                            }
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: 4
                        Text {
                            text: "Import path (markdown or todo.txt)"
                            color: th.dim
                            font.family: th.font
                            font.pixelSize: 11
                        }
                        Rectangle {
                            width: parent.width
                            height: 26
                            radius: 4
                            color: root.a(th.dim, 0.08)
                            border.width: 1
                            border.color: importInput.activeFocus ? th.accent : root.a(th.dim, 0.2)
                            TextInput {
                                id: importInput
                                anchors.fill: parent
                                anchors.margins: 7
                                verticalAlignment: TextInput.AlignVCenter
                                clip: true
                                color: th.bright
                                selectByMouse: true
                                font.family: th.font
                                font.pixelSize: 11
                                text: store.importPath
                                onEditingFinished: {
                                    if (text.trim() !== "") {
                                        store.importPath = text.trim();
                                        store.saveState();
                                    }
                                }
                            }
                        }
                        Text {
                            text: "Import now"
                            color: impNow.containsMouse ? th.accent : th.dim
                            font.family: th.font
                            font.pixelSize: 12
                            MouseArea {
                                id: impNow
                                anchors.fill: parent
                                anchors.margins: -4
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: store.importFromPath(store.importPath)
                            }
                        }
                    }

                    Row {
                        spacing: 18
                        Text {
                            text: "Export now"
                            color: exNow.containsMouse ? th.accent : th.dim
                            font.family: th.font
                            font.pixelSize: 12
                            MouseArea {
                                id: exNow
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: store.exportMarkdown()
                            }
                        }
                        Text {
                            text: "Weekly review"
                            color: revNow.containsMouse ? th.accent : th.dim
                            font.family: th.font
                            font.pixelSize: 12
                            MouseArea {
                                id: revNow
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.settingsOpen = false;
                                    store.forceReview();
                                }
                            }
                        }
                        Text {
                            text: "Close"
                            color: closeSet.containsMouse ? th.accent : th.dim
                            font.family: th.font
                            font.pixelSize: 12
                            MouseArea {
                                id: closeSet
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.settingsOpen = false
                            }
                        }
                    }
                }
            }

            Rectangle {
                id: reviewCard
                z: 140
                visible: store.reviewVisible
                anchors.centerIn: parent
                width: 300
                height: revCol.implicitHeight + 28
                radius: th.radius
                color: th.cardBot
                border.width: 1
                border.color: root.a(th.accent, 0.5)

                Column {
                    id: revCol
                    x: 14
                    y: 14
                    width: parent.width - 28
                    spacing: 8
                    Text {
                        text: "Weekly review"
                        color: th.bright
                        font.family: th.font
                        font.pixelSize: 14
                        font.bold: true
                    }
                    Text {
                        text: "Done this week: " + store.reviewData.done
                        color: th.bright
                        font.family: th.font
                        font.pixelSize: 12
                    }
                    Text {
                        text: "Focus time: " + root.fmtMins(store.reviewData.mins)
                        color: th.bright
                        font.family: th.font
                        font.pixelSize: 12
                    }
                    Text {
                        text: "Streak: " + store.reviewData.streak + " days"
                        color: th.accent
                        font.family: th.font
                        font.pixelSize: 12
                    }
                    Text {
                        visible: store.reviewData.archived > 0
                        text: store.reviewData.archived + " old done tasks archived"
                        color: th.dim
                        font.family: th.font
                        font.pixelSize: 11
                    }
                    Text {
                        text: "Close"
                        color: th.accent
                        font.family: th.font
                        font.pixelSize: 12
                        font.bold: true
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: store.reviewVisible = false
                        }
                    }
                }
            }

            Rectangle {
                id: gifCard
                z: 150
                visible: store.gifSource.toString() !== ""
                anchors.centerIn: parent
                width: 240
                height: 240
                radius: th.radius
                color: th.cardBot
                border.width: 1
                border.color: root.a(th.accent, 0.5)

                AnimatedImage {
                    anchors.fill: parent
                    anchors.margins: 6
                    source: store.gifSource
                    playing: gifCard.visible
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: store.dismissGif()
                }
            }

            Sheets {
                st: store
                th: th
                host: root
            }
        }
    }
}
