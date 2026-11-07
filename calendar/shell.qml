import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

// ~/.config/quickshell/calendar/shell.qml
//   run:    qs -c calendar
//   toggle: qs -c calendar ipc call calendar toggle
// A month of todo due-dates, then the moon, clock and weather, then a gif.
// The calendar is a viewer: it reads tasks.json and shows the selected day's
// list. Adding, completing and rescheduling stay in the todo panel.
ShellRoot {
    PanelWindow {
        id: root

        // the Ryoku top bar owns the first 38 px; start below it so the square
        // card drops out from under the bar at the top-right.
        readonly property int topInset: 38
        readonly property int designSize: 560
        // Kept as a plain property and refreshed from a function: binding the
        // square straight to root.screen makes the panel's own geometry and
        // screen selection chase each other on startup.
        property int panelSize: 640
        readonly property real zoom: panelSize / designSize
        function applyPanelSize() {
            var cap = 900;
            if (root.screen && root.screen.height > 0 && root.screen.width > 0) {
                cap = Math.min(cap, root.screen.height - topInset - 24);
                cap = Math.min(cap, root.screen.width - 24);
            }
            panelSize = Math.min(cap, Math.max(520, cfg.panelWidth));
        }

        // The sheet is laid out on one 560 px canvas. These metrics let the
        // same design breathe at 520 px and use the extra room at 900 px.
        property string layoutMode: "comfortable"
        readonly property bool compact: layoutMode === "compact"
        readonly property bool roomy: layoutMode === "roomy"
        readonly property int contentMargin: compact ? 14 : roomy ? 20 : 18
        readonly property int headerH: compact ? 44 : roomy ? 52 : 48
        readonly property int dateBox: compact ? 40 : roomy ? 46 : 44
        readonly property int clockSize: compact ? 30 : roomy ? 36 : 34
        readonly property int moonH: compact ? 44 : roomy ? 50 : 48
        readonly property int weatherH: compact ? 32 : roomy ? 38 : 36
        readonly property int rowGap: compact ? 7 : roomy ? 10 : 8
        readonly property int bodyGap: compact ? 8 : roomy ? 14 : 12
        readonly property int monthH: compact ? 232 : roomy ? 258 : 250
        readonly property int cardGap: compact ? 8 : 10
        readonly property int cellH: Math.floor((monthH - 46) / 6)
        readonly property int taskHeadH: compact ? 26 : roomy ? 30 : 28
        readonly property int titleSize: compact ? 12 : roomy ? 14 : 13
        readonly property int subSize: compact ? 7 : 8
        readonly property int animFast: cfg.reducedMotion ? 0 : 140
        readonly property int animBase: cfg.reducedMotion ? 0 : 280
        readonly property int animSlow: cfg.reducedMotion ? 0 : 420
        readonly property real borderAlpha: cfg.highContrast ? 0.38 : 0.12
        readonly property int hairline: cfg.highContrast ? 2 : 1

        property bool open: false
        property bool settingsOpen: false
        property bool monthPickerOpen: false
        property bool searchOpen: false
        property string detailMode: ""
        property int calYear: new Date().getFullYear()
        property int calMonth: new Date().getMonth()
        property string selectedKey: store.todayKey()
        property date now: new Date()

        anchors { top: true; bottom: true; right: true }
        implicitWidth: panelSize + th.gap * 2
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        visible: open || panel.y > -panel.height + 1
        mask: Region { item: panel }

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "calendar-panel"
        WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

        onOpenChanged: {
            if (open) {
                Qt.callLater(focusScope.forceActiveFocus);
            } else {
                settingsOpen = false;
                monthPickerOpen = false;
                searchOpen = false;
                detailMode = "";
            }
        }
        onSettingsOpenChanged: {
            if (settingsOpen) {
                monthPickerOpen = false;
                searchOpen = false;
                detailMode = "";
            }
        }
        onMonthPickerOpenChanged: if (monthPickerOpen) {
            settingsOpen = false;
            searchOpen = false;
            detailMode = "";
        }
        onSearchOpenChanged: if (searchOpen) {
            settingsOpen = false;
            monthPickerOpen = false;
            detailMode = "";
            Qt.callLater(searchPanel.focusField);
        }
        onDetailModeChanged: if (detailMode !== "") {
            settingsOpen = false;
            monthPickerOpen = false;
            searchOpen = false;
        }

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
            applyPanelSize();
            open = true;
        }
        function goToday() {
            var d = new Date();
            calYear = d.getFullYear();
            calMonth = d.getMonth();
            selectedKey = store.todayKey();
            monthPickerOpen = false;
        }
        function selectTask(task) {
            if (!task || !(task.due > 0))
                return;
            var d = new Date(task.due);
            calYear = d.getFullYear();
            calMonth = d.getMonth();
            selectedKey = store.dayKey(task.due);
            monthPickerOpen = false;
            searchOpen = false;
        }
        function selectDayOffset(days) {
            var p = String(selectedKey).split("-");
            if (p.length !== 3) {
                goToday();
                return;
            }
            var d = new Date(Number(p[0]), Number(p[1]) - 1, Number(p[2]));
            d.setDate(d.getDate() + days);
            calYear = d.getFullYear();
            calMonth = d.getMonth();
            selectedKey = keyForDay(d.getDate());
            monthPickerOpen = false;
        }
        function openSearch() {
            openPanel();
            searchOpen = true;
        }
        function closeSearch() {
            searchOpen = false;
            Qt.callLater(focusScope.forceActiveFocus);
        }
        function openDetail(mode) {
            openPanel();
            detailMode = mode;
        }
        function selectOldestOverdue() {
            if (store.overdueTasks.length > 0)
                selectTask(store.overdueTasks[0]);
        }
        function toggleMonthPicker() {
            if (!monthPickerOpen)
                settingsOpen = false;
            monthPickerOpen = !monthPickerOpen;
        }
        function keyForDay(day) {
            var d = new Date(calYear, calMonth, day);
            var p = function (n) { return (n < 10 ? "0" : "") + n; };
            return d.getFullYear() + "-" + p(d.getMonth() + 1) + "-" + p(d.getDate());
        }
        function clockMainText() {
            var h = root.now.getHours();
            var m = root.now.getMinutes();
            if (!cfg.clock24h) {
                h = h % 12;
                if (h === 0)
                    h = 12;
                return h + ":" + (m < 10 ? "0" : "") + m;
            }
            return (h < 10 ? "0" : "") + h + ":" + (m < 10 ? "0" : "") + m;
        }
        function isoWeek(d) {
            // ISO-8601 week number. Qt's "ww" format is not a week number.
            var date = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()));
            var day = date.getUTCDay() || 7;
            date.setUTCDate(date.getUTCDate() + 4 - day);
            var yearStart = new Date(Date.UTC(date.getUTCFullYear(), 0, 1));
            return Math.ceil((((date - yearStart) / 86400000) + 1) / 7);
        }
        function setMonth(y, m) {
            if (m < 0) { m = 11; y -= 1; }
            if (m > 11) { m = 0; y += 1; }
            calYear = y;
            calMonth = m;
            monthPickerOpen = false;
            var now = new Date();
            selectedKey = (y === now.getFullYear() && m === now.getMonth()) ? store.todayKey() : keyForDay(1);
        }

        // Three sizes, with a little hysteresis so a monitor or manual resize
        // near a threshold does not flip the layout back and forth.
        function nextLayout(px, current) {
            var h = 10;
            if (current === "compact")
                return px >= 660 + h ? (px >= 780 + h ? "roomy" : "comfortable") : "compact";
            if (current === "roomy")
                return px < 780 - h ? (px < 660 - h ? "compact" : "comfortable") : "roomy";
            return px < 660 - h ? "compact" : (px >= 780 + h ? "roomy" : "comfortable");
        }
        function updateLayout() {
            if (!cfg.autoLayout) {
                layoutMode = "comfortable";
                return;
            }
            var next = nextLayout(panelSize, layoutMode);
            if (next !== layoutMode)
                layoutMode = next;
        }
        onPanelSizeChanged: updateLayout()
        onScreenChanged: applyPanelSize()
        Component.onCompleted: {
            applyPanelSize();
            updateLayout();
        }

        IpcHandler {
            target: "calendar"
            function toggle(): void { if (root.open) root.open = false; else root.openPanel(); }
            function show(): void { root.openPanel(); }
            function open(): void { root.openPanel(); }
            function hide(): void { root.open = false; }
            function closeSettings(): void { root.settingsOpen = false; }
            function today(): void { root.goToday(); root.openPanel(); }
            function months(): void { root.monthPickerOpen = true; root.openPanel(); }
            function search(): void { root.openSearch(); }
            function overdue(): string {
                if (store.overdueTasks.length === 0)
                    return "none";
                root.selectOldestOverdue();
                root.openPanel();
                return root.selectedKey;
            }
            function settings(): void {
                root.settingsOpen = true;
                root.monthPickerOpen = false;
                root.openPanel();
            }
            function select(key: string): string {
                var p = String(key).split("-");
                if (p.length !== 3)
                    return "bad date";
                root.calYear = Number(p[0]);
                root.calMonth = Number(p[1]) - 1;
                root.selectedKey = key;
                root.monthPickerOpen = false;
                root.openPanel();
                return "ok";
            }
        }

        Timer {
            interval: 1000
            repeat: true
            running: true
            onTriggered: root.now = new Date()
        }
        Settings { id: cfg }
        Connections {
            target: cfg
            function onAutoLayoutChanged() { root.updateLayout(); }
            function onPanelWidthChanged() { root.applyPanelSize(); }
        }
        Store {
            id: store
            nowMs: root.now.getTime()
        }
        Weather {
            id: wx
            active: true
            enabled: true
            city: cfg.city
            units: cfg.units
        }

        // ───────── theme: Ryoku palette + metrics, with fallbacks ─────────
        QtObject {
            id: th
            property color accent: "#90cef4"
            property color brightBase: "#dfe3e7"
            property color dimBase: "#8b9297"
            property color warnBase: "#e8a15a"
            property color cardBot: "#0f1417"
            property int radius: 12
            property int gap: 12
            readonly property color bright: cfg.highContrast ? "#ffffff" : brightBase
            readonly property color dim: cfg.highContrast ? Qt.lighter(dimBase, 1.45) : dimBase
            readonly property color warn: cfg.highContrast ? Qt.lighter(warnBase, 1.25) : warnBase
            readonly property string font: "JetBrainsMono Nerd Font"
        }

        function a(c, v) { return Qt.rgba(c.r, c.g, c.b, v); }

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
                console.log("calendar: colors.json unreadable:", e);
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
            th.brightBase = pick(["on_surface", "foreground", "fg", "text", "bright", "on_background"], th.brightBase);
            th.dimBase = pick(["on_surface_variant", "dim", "muted", "outline", "subtext", "comment"], th.dimBase);
            th.warnBase = pick(["error", "warning", "warn", "critical", "amber"], th.warnBase);
            th.cardBot = pick(["surface_container", "surface", "background", "bg", "card_bot", "cardbot", "base"], th.cardBot);
            if (cfg.accentValid)
                th.accent = cfg.accentOverride;
        }

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
            var g = num(["gap", "gaps_out", "gaps", "outer_gap"], 0, 40);
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
            path: Quickshell.env("HOME") + "/.config/ryoku/desktop.json"
            onLoaded: root.applyMetrics(themeFile.text())
        }

        function localUrl(raw) {
            var p = String(raw).trim();
            if (p === "")
                return "";
            if (p.indexOf("file://") === 0 || p.indexOf("http://") === 0 || p.indexOf("https://") === 0)
                return p;
            if (p.indexOf("~/") === 0)
                p = cfg.home + p.substring(1);
            return "file://" + p;
        }
        function gifUrl() { return localUrl(cfg.gif); }

        // ───────── todo bridge ─────────
        // The calendar is a viewer. It only opens the todo panel; it never
        // adds, completes or reschedules a task itself.
        Process {
            id: todoProc
            command: ["qs", "-c", "todo", "ipc", "call", "todo", "open"]
        }

        function openTodo() {
            todoProc.running = false;
            todoProc.running = true;
        }

        // ───────── panel ─────────
        Item {
            id: stage
            anchors.fill: parent
            anchors.topMargin: root.topInset
            clip: true

            Rectangle {
                id: panel
                width: root.panelSize
                height: root.panelSize
                x: th.gap
                y: root.open ? th.gap : -height - th.gap
                opacity: root.open ? 1 : 0
                Behavior on y { NumberAnimation { duration: root.animBase; easing.type: Easing.OutCubic } }
                Behavior on opacity { NumberAnimation { duration: root.animFast; easing.type: Easing.OutCubic } }

                radius: th.radius + 3
                color: "transparent"
                clip: true
                gradient: Gradient {
                    GradientStop { position: 0.0; color: root.a(th.cardBot, cfg.panelOpacity) }
                    GradientStop { position: 0.10; color: root.a(th.cardBot, cfg.panelOpacity) }
                    GradientStop { position: 0.72; color: root.a(th.cardBot, cfg.panelOpacity) }
                    GradientStop { position: 1.0; color: root.a(th.cardBot, cfg.panelOpacity) }
                }

                // The accent wash lives above the opaque card so the header
                // still gets its tint without letting the wallpaper through.
                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    height: parent.height * 0.24
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: root.a(th.accent, 0.12 + cfg.aura * 0.10) }
                        GradientStop { position: 0.62; color: root.a(th.accent, 0.025) }
                        GradientStop { position: 1.0; color: "transparent" }
                    }
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: parent.height * 0.28
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 1.0; color: root.a(th.accent, 0.030 + cfg.aura * 0.020) }
                    }
                }
                border.width: root.hairline
                border.color: root.a(th.dim, cfg.highContrast ? 0.58 : 0.24 + cfg.aura * 0.08)

                // A pair of very soft light sweeps give the flat card some
                // depth without images or much overdraw.
                Rectangle {
                    x: parent.width * 0.54
                    y: -parent.height * 0.18
                    width: parent.width * 0.62
                    height: parent.height * 0.82
                    rotation: 16
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 0.48; color: root.a(th.accent, 0.030 + cfg.aura * 0.025) }
                        GradientStop { position: 1.0; color: "transparent" }
                    }
                }

                Rectangle {
                    x: -parent.width * 0.18
                    y: parent.height * 0.55
                    width: parent.width * 0.70
                    height: parent.height * 0.60
                    rotation: -18
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 0.5; color: root.a(th.bright, 0.018) }
                        GradientStop { position: 1.0; color: "transparent" }
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 1
                    radius: Math.max(1, parent.radius - 1)
                    color: "transparent"
                    border.width: 1
                    border.color: root.a(th.bright, cfg.highContrast ? 0.10 : 0.035)
                }

                Rectangle {
                    width: parent.width - 70
                    height: root.hairline + 1
                    anchors.top: parent.top
                    anchors.topMargin: 1
                    anchors.horizontalCenter: parent.horizontalCenter
                    radius: height / 2
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 0.5; color: root.a(th.accent, 0.55 + cfg.aura * 0.40) }
                        GradientStop { position: 1.0; color: "transparent" }
                    }
                }

                Item {
                    id: design
                    width: root.designSize
                    height: root.designSize
                    scale: root.zoom
                    transformOrigin: Item.TopLeft

                Item {
                    id: focusScope
                    anchors.fill: parent
                    focus: root.open

                    Keys.onPressed: function (e) {
                        if (e.key === Qt.Key_Escape) {
                            if (root.settingsOpen)
                                root.settingsOpen = false;
                            else if (root.monthPickerOpen)
                                root.monthPickerOpen = false;
                            else if (root.searchOpen)
                                root.closeSearch();
                            else if (root.detailMode !== "")
                                root.detailMode = "";
                            else
                                root.open = false;
                            e.accepted = true;
                        } else if (e.key === Qt.Key_Slash && !root.settingsOpen && !root.monthPickerOpen) {
                            root.openSearch();
                            e.accepted = true;
                        } else if (e.key === Qt.Key_M && !root.settingsOpen) {
                            root.toggleMonthPicker();
                            e.accepted = true;
                        } else if ((e.modifiers & Qt.ShiftModifier) && e.key === Qt.Key_Left && !root.settingsOpen) {
                            root.selectDayOffset(-1);
                            e.accepted = true;
                        } else if ((e.modifiers & Qt.ShiftModifier) && e.key === Qt.Key_Right && !root.settingsOpen) {
                            root.selectDayOffset(1);
                            e.accepted = true;
                        } else if ((e.modifiers & Qt.ShiftModifier) && e.key === Qt.Key_Up && !root.settingsOpen) {
                            root.selectDayOffset(-7);
                            e.accepted = true;
                        } else if ((e.modifiers & Qt.ShiftModifier) && e.key === Qt.Key_Down && !root.settingsOpen) {
                            root.selectDayOffset(7);
                            e.accepted = true;
                        } else if (e.key === Qt.Key_Left && !root.settingsOpen) {
                            root.setMonth(root.calYear, root.calMonth - 1);
                            e.accepted = true;
                        } else if (e.key === Qt.Key_Right && !root.settingsOpen) {
                            root.setMonth(root.calYear, root.calMonth + 1);
                            e.accepted = true;
                        } else if (e.key === Qt.Key_T && !root.settingsOpen) {
                            root.goToday();
                            e.accepted = true;
                        }
                    }

                    Item {
                        id: content
                        anchors.fill: parent
                        anchors.margins: root.contentMargin

                        // ── clock, date, stats ──
                        Item {
                            id: header
                            width: parent.width
                            height: root.headerH

                            Row {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 10

                                Rectangle {
                                    width: root.dateBox
                                    height: root.dateBox
                                    radius: Math.round(root.dateBox * 0.25)
                                    gradient: Gradient {
                                        GradientStop { position: 0.0; color: root.a(th.accent, 1.0) }
                                        GradientStop { position: 0.55; color: root.a(th.accent, 0.82) }
                                        GradientStop { position: 1.0; color: root.a(th.accent, 0.34) }
                                    }
                                    border.width: 1
                                    border.color: root.a(th.bright, 0.18 + cfg.aura * 0.16)
                                    Rectangle {
                                        anchors.fill: parent
                                        anchors.margins: 1
                                        radius: Math.max(1, parent.radius - 1)
                                        color: "transparent"
                                        border.width: 1
                                        border.color: root.a(th.bright, 0.10)
                                    }
                                    Column {
                                        anchors.centerIn: parent
                                        spacing: -1
                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: Qt.formatDate(root.now, "d")
                                            color: th.cardBot
                                            font.family: th.font
                                            font.pixelSize: 19
                                            font.bold: true
                                        }
                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: Qt.formatDate(root.now, "MMM").toUpperCase()
                                            color: root.a(th.cardBot, 0.78)
                                            font.family: th.font
                                            font.pixelSize: 6
                                            font.letterSpacing: 0.8
                                        }
                                    }
                                }

                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 0
                                    Row {
                                        spacing: 4
                                        Text {
                                            id: clockMain
                                            text: root.clockMainText()
                                            color: th.bright
                                            font.family: th.font
                                            font.pixelSize: root.clockSize
                                            font.bold: true
                                        }
                                        Text {
                                            anchors.bottom: clockMain.bottom
                                            anchors.bottomMargin: 5
                                            visible: cfg.showSeconds
                                            text: Qt.formatTime(root.now, "ss")
                                            color: th.accent
                                            font.family: th.font
                                            font.pixelSize: 11
                                        }
                                        Text {
                                            anchors.bottom: clockMain.bottom
                                            anchors.bottomMargin: 6
                                            visible: !cfg.clock24h
                                            text: Qt.formatTime(root.now, "AP")
                                            color: root.a(th.dim, 0.9)
                                            font.family: th.font
                                            font.pixelSize: 8
                                        }
                                    }
                                    Text {
                                        text: Qt.formatDate(root.now, "dddd, d MMMM") + "  \u00B7  week " + root.isoWeek(root.now)
                                        color: root.a(th.dim, 0.9)
                                        font.family: th.font
                                        font.pixelSize: 8
                                    }
                                }
                            }

                            Row {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 5

                                StatChip {
                                    glyph: "\u2713"
                                    label: store.todayOpen + " today"
                                    tone: store.todayOpen > 0 ? th.accent : th.dim
                                    textColor: store.todayOpen > 0 ? th.bright : th.dim
                                    family: th.font
                                    interactive: true
                                    onClicked: root.goToday()
                                }
                                StatChip {
                                    glyph: "!"
                                    label: store.overdueCount + " overdue"
                                    tone: store.overdueCount > 0 ? th.warn : th.dim
                                    textColor: store.overdueCount > 0 ? th.bright : th.dim
                                    family: th.font
                                    interactive: store.overdueCount > 0
                                    onClicked: root.selectOldestOverdue()
                                }
                                StatChip {
                                    glyph: "\u25F7"
                                    visible: !root.compact
                                    label: store.countMonth(root.calYear, root.calMonth) + " month"
                                    tone: store.countMonth(root.calYear, root.calMonth) > 0 ? th.accent : th.dim
                                    textColor: store.countMonth(root.calYear, root.calMonth) > 0 ? th.bright : th.dim
                                    family: th.font
                                    interactive: true
                                    onClicked: root.toggleMonthPicker()
                                }
                                Item { width: 2; height: 1 }
                                IconBtn {
                                    box: 24
                                    size: 13
                                    glyph: "\u2699"
                                    on: root.settingsOpen
                                    idle: th.dim
                                    hot: th.accent
                                    family: th.font
                                    duration: root.animFast
                                    onClicked: root.settingsOpen = !root.settingsOpen
                                }
                                IconBtn {
                                    box: 24
                                    size: 12
                                    glyph: "\u2715"
                                    idle: th.dim
                                    hot: th.accent
                                    family: th.font
                                    duration: root.animFast
                                    onClicked: root.open = false
                                }
                            }
                        }

                        // ── lunar month line ──
                        MoonLine {
                            id: moonLine
                            visible: cfg.showMoonLine
                            y: header.height + (visible ? root.rowGap : 0)
                            width: parent.width
                            height: visible ? root.moonH : 0
                            accent: th.accent
                            bright: th.bright
                            dim: th.dim
                            cardBg: th.cardBot
                            font: th.font
                            onClicked: root.openDetail("moon")
                        }

                        // ── weather under the lunar line ──
                        WeatherStrip {
                            id: weather
                            visible: cfg.showWeatherStrip
                            y: moonLine.visible
                                ? moonLine.y + moonLine.height + (visible ? root.rowGap : 0)
                                : header.height + (visible ? root.rowGap : 0)
                            width: parent.width
                            height: visible ? root.weatherH : 0
                            wx: wx
                            accent: th.accent
                            bright: th.bright
                            dim: th.dim
                            warn: th.warn
                            cardBg: th.cardBot
                            font: th.font
                            onClicked: root.openDetail("weather")
                        }

                        // ── month + selected-day tasks ──
                        Item {
                            id: body
                            y: (weather.visible ? weather.y + weather.height
                                : moonLine.visible ? moonLine.y + moonLine.height
                                : header.height) + root.bodyGap
                            width: parent.width
                            height: parent.height - y

                            readonly property real leftW: Math.round(width * (root.compact ? 0.56 : 0.55))
                            readonly property real rightW: width - leftW - root.cardGap
                            readonly property real panelH: cfg.showGif
                                ? Math.max(180, Math.min(root.monthH, height - 64))
                                : height
                            readonly property real gifH: Math.max(0, height - panelH - root.cardGap)
                            readonly property real gifSize: Math.max(48, Math.min(rightW, gifH, Math.round(root.monthH * 0.62)))

                            Row {
                                anchors.fill: parent
                                spacing: root.compact ? 8 : 12

                                Item {
                                    width: body.leftW
                                    height: parent.height

                                    Rectangle {
                                        id: monthCard
                                        width: parent.width
                                        height: parent.height
                                        radius: th.radius
                                        color: "transparent"
                                        gradient: Gradient {
                                            GradientStop { position: 0.0; color: root.a(th.bright, cfg.highContrast ? 0.09 : 0.050) }
                                            GradientStop { position: 0.22; color: root.a(th.cardBot, 0.28) }
                                            GradientStop { position: 1.0; color: root.a(th.cardBot, 0.46) }
                                        }
                                        border.width: root.hairline
                                        border.color: root.a(th.dim, root.borderAlpha)

                                        Rectangle {
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            anchors.top: parent.top
                                            anchors.margins: 1
                                            height: 1
                                            gradient: Gradient {
                                                orientation: Gradient.Horizontal
                                                GradientStop { position: 0.0; color: "transparent" }
                                                GradientStop { position: 0.5; color: root.a(th.accent, 0.20 + cfg.aura * 0.18) }
                                                GradientStop { position: 1.0; color: "transparent" }
                                            }
                                        }

                                        Item {
                                            id: monthHead
                                            x: 8
                                            y: 6
                                            width: parent.width - 16
                                            height: 20

                                            Text {
                                                id: monthLabel
                                                anchors.left: parent.left
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: store.monthNames[root.calMonth]
                                                color: monthMa.containsMouse ? th.accent : th.bright
                                                font.family: th.font
                                                font.pixelSize: 12
                                                font.bold: true
                                            }
                                            Text {
                                                id: yearLabel
                                                anchors.left: monthLabel.right
                                                anchors.leftMargin: 4
                                                anchors.baseline: monthLabel.baseline
                                                text: root.calYear
                                                color: monthMa.containsMouse ? th.accent : root.a(th.dim, 0.8)
                                                font.family: th.font
                                                font.pixelSize: 8
                                            }
                                            Text {
                                                anchors.left: yearLabel.right
                                                anchors.leftMargin: 4
                                                anchors.verticalCenter: monthLabel.verticalCenter
                                                text: "\u25BE"
                                                color: monthMa.containsMouse ? th.accent : root.a(th.dim, 0.55)
                                                font.family: th.font
                                                font.pixelSize: 7
                                            }
                                            MouseArea {
                                                id: monthMa
                                                x: 0
                                                y: 0
                                                width: Math.min(parent.width - 88, 150)
                                                height: 20
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.toggleMonthPicker()
                                            }

                                            Row {
                                                anchors.right: parent.right
                                                anchors.verticalCenter: parent.verticalCenter
                                                spacing: 2

                                                Rectangle {
                                                    width: 32
                                                    height: 16
                                                    radius: 4
                                                    color: todayMa.containsMouse ? root.a(th.accent, 0.14) : root.a(th.dim, 0.05)
                                                    border.width: 1
                                                    border.color: todayMa.containsMouse ? th.accent : root.a(th.dim, 0.18)
                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: "today"
                                                        color: todayMa.containsMouse ? th.accent : root.a(th.dim, 0.9)
                                                        font.family: th.font
                                                        font.pixelSize: 7
                                                    }
                                                    MouseArea {
                                                        id: todayMa
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: root.goToday()
                                                    }
                                                }
                                                IconBtn {
                                                    box: 18
                                                    size: 12
                                                    glyph: "\u2039"
                                                    idle: th.dim
                                                    hot: th.accent
                                                    family: th.font
                                                    duration: root.animFast
                                                    onClicked: root.setMonth(root.calYear, root.calMonth - 1)
                                                }
                                                IconBtn {
                                                    box: 18
                                                    size: 12
                                                    glyph: "\u203A"
                                                    idle: th.dim
                                                    hot: th.accent
                                                    family: th.font
                                                    duration: root.animFast
                                                    onClicked: root.setMonth(root.calYear, root.calMonth + 1)
                                                }
                                            }
                                        }

                                        Row {
                                            x: 8
                                            y: 27
                                            width: parent.width - 16
                                            height: 9

                                            Repeater {
                                                model: cfg.weekStartsMonday
                                                    ? ["M", "T", "W", "T", "F", "S", "S"]
                                                    : ["S", "M", "T", "W", "T", "F", "S"]
                                                delegate: Item {
                                                    required property string modelData
                                                    width: parent.width / 7
                                                    height: 9
                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: modelData
                                                        color: root.a(th.dim, 0.72)
                                                        font.family: th.font
                                                        font.pixelSize: 7
                                                    }
                                                }
                                            }
                                        }

                                        CalendarGrid {
                                            x: 8
                                            y: 37
                                            width: parent.width - 16
                                            height: parent.height - 41
                                            store: store
                                            selectedKey: root.selectedKey
                                            year: root.calYear
                                            month: root.calMonth
                                            accent: th.accent
                                            bright: th.bright
                                            dim: th.dim
                                            cardBg: th.cardBot
                                            warn: th.warn
                                            nowMs: root.now.getTime()
                                            font: th.font
                                            cellHeight: Math.max(root.cellH, Math.floor((parent.height - 46) / 6))
                                            weekStartsMonday: cfg.weekStartsMonday
                                            aura: cfg.aura
                                            highContrast: cfg.highContrast
                                            onDayClicked: function (key) {
                                                root.selectedKey = key;
                                                root.monthPickerOpen = false;
                                            }
                                        }

                                        MonthPicker {
                                            anchors.fill: parent
                                            visible: root.monthPickerOpen
                                            year: root.calYear
                                            month: root.calMonth
                                            todayYear: root.now.getFullYear()
                                            todayMonth: root.now.getMonth()
                                            store: store
                                            accent: th.accent
                                            warn: th.warn
                                            bright: th.bright
                                            dim: th.dim
                                            cardBg: th.cardBot
                                            font: th.font
                                            motionFast: root.animFast
                                            onPicked: function (y, m) { root.setMonth(y, m); }
                                            onTodayClicked: root.goToday()
                                            onClosed: root.monthPickerOpen = false
                                        }
                                    }

                                }

                                Item {
                                    width: body.rightW
                                    height: parent.height

                                    Rectangle {
                                        id: taskCard
                                        z: root.searchOpen ? 2 : 1
                                        width: parent.width
                                        height: body.panelH
                                        radius: th.radius
                                        color: "transparent"
                                        gradient: Gradient {
                                            GradientStop { position: 0.0; color: root.a(th.bright, cfg.highContrast ? 0.09 : 0.050) }
                                            GradientStop { position: 0.22; color: root.a(th.cardBot, 0.28) }
                                            GradientStop { position: 1.0; color: root.a(th.cardBot, 0.46) }
                                        }
                                        border.width: root.hairline
                                        border.color: root.a(th.dim, root.borderAlpha)

                                        Rectangle {
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            anchors.top: parent.top
                                            anchors.margins: 1
                                            height: 1
                                            gradient: Gradient {
                                                orientation: Gradient.Horizontal
                                                GradientStop { position: 0.0; color: "transparent" }
                                                GradientStop { position: 0.5; color: root.a(th.accent, 0.20 + cfg.aura * 0.18) }
                                                GradientStop { position: 1.0; color: "transparent" }
                                            }
                                        }

                                        readonly property var stats: store.statsOn(root.selectedKey)
                                    readonly property int taskCount: stats.total

                                    Item {
                                        id: taskHead
                                        x: 10
                                        y: 8
                                        width: parent.width - 20
                                        height: root.taskHeadH

                                        Column {
                                            anchors.left: parent.left
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: 0
                                            Text {
                                                text: store.dayTitle(root.selectedKey)
                                                color: root.selectedKey === store.todayKey() ? th.accent : th.bright
                                                font.family: th.font
                                                font.pixelSize: root.titleSize
                                                font.bold: true
                                            }
                                            Text {
                                                text: taskCard.stats.total === 0 ? "nothing due"
                                                    : taskCard.stats.done + " of " + taskCard.stats.total + " done"
                                                        + (taskCard.stats.overdue > 0 ? "  \u00B7  " + taskCard.stats.overdue + " overdue" : "")
                                                color: taskCard.stats.overdue > 0 ? th.warn
                                                    : taskCard.stats.allDone ? th.accent : root.a(th.dim, 0.8)
                                                font.family: th.font
                                                font.pixelSize: root.subSize
                                            }
                                        }

                                        Row {
                                            anchors.right: parent.right
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: 9

                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: "\u2315"
                                                color: searchHover.hovered ? th.accent : root.a(th.dim, 0.8)
                                                font.family: th.font
                                                font.pixelSize: 12
                                                HoverHandler { id: searchHover }
                                                MouseArea {
                                                    anchors.fill: parent
                                                    anchors.margins: -5
                                                    cursorShape: Qt.PointingHandCursor
                                                    Accessible.name: "Search tasks"
                                                    onClicked: root.openSearch()
                                                }
                                            }
                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: "open todo \u2197"
                                                color: openHover.hovered ? th.accent : root.a(th.dim, 0.8)
                                                font.family: th.font
                                                font.pixelSize: 8
                                                HoverHandler { id: openHover }
                                                MouseArea {
                                                    anchors.fill: parent
                                                    anchors.margins: -4
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: root.openTodo()
                                                }
                                            }
                                        }
                                    }

                                    Rectangle {
                                        id: taskProgress
                                        x: 10
                                        y: taskHead.height + 11
                                        width: parent.width - 20
                                        height: 3
                                        radius: 2
                                        color: root.a(th.dim, cfg.highContrast ? 0.34 : 0.16)

                                        Rectangle {
                                            width: parent.width * taskCard.stats.ratio
                                            height: parent.height
                                            radius: 2
                                            gradient: Gradient {
                                                orientation: Gradient.Horizontal
                                                GradientStop {
                                                    position: 0.0
                                                    color: taskCard.stats.overdue > 0 ? root.a(th.warn, 0.72) : root.a(th.accent, 0.62)
                                                }
                                                GradientStop {
                                                    position: 1.0
                                                    color: taskCard.stats.overdue > 0 ? th.warn : th.accent
                                                }
                                            }
                                        }
                                    }

                                    Rectangle {
                                        id: nextRow
                                        x: 10
                                        y: taskProgress.y + 7
                                        width: parent.width - 20
                                        height: 20
                                        radius: 5
                                        visible: cfg.showTaskNext && store.nextUp !== null
                                        gradient: Gradient {
                                            orientation: Gradient.Horizontal
                                            GradientStop { position: 0.0; color: root.a(th.accent, 0.10) }
                                            GradientStop { position: 1.0; color: root.a(th.accent, 0.035) }
                                        }
                                        border.width: 1
                                        border.color: root.a(th.accent, 0.20 + cfg.aura * 0.10)

                                        Text {
                                            x: 6
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: "NEXT"
                                            color: th.accent
                                            font.family: th.font
                                            font.pixelSize: 6
                                            font.bold: true
                                            font.letterSpacing: 0.5
                                        }
                                        Text {
                                            x: 33
                                            width: 68
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: store.nextUp ? store.whenLabel(store.nextUp.due) : ""
                                            color: root.a(th.dim, 0.9)
                                            elide: Text.ElideRight
                                            font.family: th.font
                                            font.pixelSize: 7
                                        }
                                        Text {
                                            x: 103
                                            width: parent.width - 103 - 15
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: store.nextUp ? store.nextUp.text : ""
                                            color: th.bright
                                            elide: Text.ElideRight
                                            font.family: th.font
                                            font.pixelSize: 8
                                        }
                                        Text {
                                            anchors.right: parent.right
                                            anchors.rightMargin: 6
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: "\u2197"
                                            color: root.a(th.accent, 0.7)
                                            font.family: th.font
                                            font.pixelSize: 8
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: if (store.nextUp) root.selectTask(store.nextUp)
                                        }
                                    }

                                    SearchPanel {
                                        id: searchPanel
                                        x: 0
                                        y: 0
                                        width: parent.width
                                        height: body.height
                                        z: 80
                                        active: root.searchOpen
                                        store: store
                                        nowMs: root.now.getTime()
                                        accent: th.accent
                                        warn: th.warn
                                        bright: th.bright
                                        dim: th.dim
                                        cardBg: th.cardBot
                                        font: th.font
                                        cornerRadius: th.radius
                                        highContrast: cfg.highContrast
                                        onClosed: root.closeSearch()
                                        onTaskActivated: function (task) {
                                            root.searchOpen = false;
                                            if (task && task.due > 0)
                                                root.selectTask(task);
                                            else
                                                root.openTodo();
                                            Qt.callLater(focusScope.forceActiveFocus);
                                        }
                                    }

                                    Flickable {
                                        id: taskFlick
                                        x: 10
                                        y: nextRow.visible ? nextRow.y + nextRow.height + 6 : taskProgress.y + 8
                                        width: parent.width - 20
                                        height: parent.height - y - 12
                                        contentWidth: width
                                        contentHeight: taskCol.height
                                        boundsBehavior: Flickable.StopAtBounds
                                        clip: true

                                        Column {
                                            id: taskCol
                                            width: taskFlick.width
                                            spacing: 2

                                            Item {
                                                visible: taskCard.taskCount === 0
                                                width: taskCol.width
                                                height: 150
                                                Column {
                                                    anchors.centerIn: parent
                                                    spacing: 4
                                                    Text {
                                                        anchors.horizontalCenter: parent.horizontalCenter
                                                        text: "\u263E"
                                                        color: root.a(th.accent, 0.55)
                                                        font.family: th.font
                                                        font.pixelSize: 22
                                                    }
                                                    Text {
                                                        anchors.horizontalCenter: parent.horizontalCenter
                                                        text: "nothing due"
                                                        color: root.a(th.dim, 0.75)
                                                        font.family: th.font
                                                        font.pixelSize: 9
                                                    }
                                                    Text {
                                                        anchors.horizontalCenter: parent.horizontalCenter
                                                        text: "a good day."
                                                        color: root.a(th.dim, 0.45)
                                                        font.family: th.font
                                                        font.pixelSize: 7
                                                    }
                                                }
                                            }

                                            TaskSection {
                                                tasks: store.overdueOn(root.selectedKey)
                                                store: store
                                                nowMs: root.now.getTime()
                                                accent: th.accent
                                                warn: th.warn
                                                bright: th.bright
                                                dim: th.dim
                                                cardBg: th.cardBot
                                                tone: th.warn
                                                title: "OVERDUE"
                                                font: th.font
                                                onOpenRequested: root.openTodo()
                                            }

                                            TaskSection {
                                                tasks: store.openOn(root.selectedKey)
                                                store: store
                                                nowMs: root.now.getTime()
                                                accent: th.accent
                                                warn: th.warn
                                                bright: th.bright
                                                dim: th.dim
                                                cardBg: th.cardBot
                                                tone: th.accent
                                                title: "OPEN"
                                                font: th.font
                                                onOpenRequested: root.openTodo()
                                            }

                                            TaskSection {
                                                tasks: store.doneOn(root.selectedKey)
                                                store: store
                                                nowMs: root.now.getTime()
                                                accent: th.accent
                                                warn: th.warn
                                                bright: th.bright
                                                dim: th.dim
                                                cardBg: th.cardBot
                                                tone: th.dim
                                                title: "DONE"
                                                font: th.font
                                                onOpenRequested: root.openTodo()
                                            }
                                        }
                                    }

                                    }

                                    GifTile {
                                        id: gifTile
                                        visible: cfg.showGif && body.gifH > 1
                                        x: Math.round((parent.width - width) / 2)
                                        y: taskCard.height + root.cardGap
                                        width: body.gifSize
                                        height: body.gifSize
                                        source: root.gifUrl()
                                        fit: cfg.gifFit
                                        open: root.open
                                        reducedMotion: cfg.reducedMotion
                                        aura: cfg.aura
                                        accent: th.accent
                                        bright: th.bright
                                        dim: th.dim
                                        cardBg: th.cardBot
                                        font: th.font
                                        radius: th.radius
                                        highContrast: cfg.highContrast
                                        onClicked: root.settingsOpen = true
                                    }
                                }
                            }
                        }
                    }
                }
            // ── moon and weather detail cards ──
            DetailOverlay {
                id: detailOverlay
                anchors.fill: parent
                mode: root.detailMode
                wx: wx
                accent: th.accent
                warn: th.warn
                bright: th.bright
                dim: th.dim
                cardBg: th.cardBot
                font: th.font
                highContrast: cfg.highContrast
                onClosed: root.detailMode = ""
            }

            // ── settings sheet ──
            SettingsSheet {
                id: settingsSheet
                anchors.fill: parent
                open: root.settingsOpen
                cfg: cfg
                weather: wx
                accent: th.accent
                bright: th.bright
                dim: th.dim
                cardBg: th.cardBot
                font: th.font
                radius: Math.max(10, panel.radius / root.zoom)
                highContrast: cfg.highContrast
                motionFast: root.animFast
                onClosed: root.settingsOpen = false
            }
            }
            }
        }
    }
}
