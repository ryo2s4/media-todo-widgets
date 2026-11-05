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
// The calendar only reads tasks.json; new and completed tasks go through the
// todo panel's IPC so both widgets agree on the file.
ShellRoot {
    PanelWindow {
        id: root

        // the Ryoku top bar owns the first 38 px; start below it so the square
        // card drops out from under the bar at the top-right.
        readonly property int topInset: 38
        readonly property int designSize: 560
        readonly property int size: {
            var cap = 900;
            if (root.screen && root.screen.height > 0) {
                cap = Math.min(cap, root.screen.height - topInset - 24);
                cap = Math.min(cap, root.screen.width - 24);
            }
            return Math.min(cap, Math.max(520, cfg.panelWidth));
        }
        readonly property real zoom: size / designSize
        property bool open: false
        property bool settingsOpen: false
        property int calYear: new Date().getFullYear()
        property int calMonth: new Date().getMonth()
        property string selectedKey: store.todayKey()
        property date now: new Date()

        anchors { top: true; bottom: true; right: true }
        implicitWidth: size + th.gap * 2
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        visible: open || panel.y > -panel.height + 1
        mask: Region { item: panel }

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "calendar-panel"
        WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

        onOpenChanged: {
            if (open)
                Qt.callLater(focusScope.forceActiveFocus);
            else
                settingsOpen = false;
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
            open = true;
        }
        function goToday() {
            var d = new Date();
            calYear = d.getFullYear();
            calMonth = d.getMonth();
            selectedKey = store.todayKey();
        }
        function keyForDay(day) {
            var d = new Date(calYear, calMonth, day);
            var p = function (n) { return (n < 10 ? "0" : "") + n; };
            return d.getFullYear() + "-" + p(d.getMonth() + 1) + "-" + p(d.getDate());
        }
        function setMonth(y, m) {
            if (m < 0) { m = 11; y -= 1; }
            if (m > 11) { m = 0; y += 1; }
            calYear = y;
            calMonth = m;
            var now = new Date();
            selectedKey = (y === now.getFullYear() && m === now.getMonth()) ? store.todayKey() : keyForDay(1);
        }

        IpcHandler {
            target: "calendar"
            function toggle(): void { if (root.open) root.open = false; else root.openPanel(); }
            function show(): void { root.openPanel(); }
            function open(): void { root.openPanel(); }
            function hide(): void { root.open = false; }
            function closeSettings(): void { root.settingsOpen = false; }
            function today(): void { root.goToday(); root.openPanel(); }
            function settings(): void { root.settingsOpen = true; root.openPanel(); }
            function select(key: string): string {
                var p = String(key).split("-");
                if (p.length !== 3)
                    return "bad date";
                root.calYear = Number(p[0]);
                root.calMonth = Number(p[1]) - 1;
                root.selectedKey = key;
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
        Store { id: store }
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
            property color bright: "#dfe3e7"
            property color dim: "#8b9297"
            property color cardBot: "#0f1417"
            property int radius: 12
            property int gap: 12
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
            th.bright = pick(["on_surface", "foreground", "fg", "text", "bright", "on_background"], th.bright);
            th.dim = pick(["on_surface_variant", "dim", "muted", "outline", "subtext", "comment"], th.dim);
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

        function gifUrl() {
            var p = String(cfg.gif).trim();
            if (p === "")
                return "";
            if (p.indexOf("file://") === 0 || p.indexOf("http://") === 0 || p.indexOf("https://") === 0)
                return p;
            if (p.indexOf("~/") === 0)
                p = cfg.home + p.substring(1);
            return "file://" + p;
        }

        // ───────── todo bridge ─────────
        Process {
            id: addProc
            property string pendingTitle: ""
            onExited: function (code) {
                if (code !== 0 && pendingTitle !== "" && addIn.text === "")
                    addIn.text = pendingTitle;
                pendingTitle = "";
                if (addIn.text === "")
                    addIn.forceActiveFocus();
            }
        }
        Process {
            id: toggleProc
        }
        Process {
            id: todoProc
            command: ["qs", "-c", "todo", "ipc", "call", "todo", "open"]
        }

        function addTask() {
            var title = addIn.text.trim();
            if (title === "")
                return;
            if (addProc.running)
                return;
            var p = String(root.selectedKey).split("-");
            var hh = 23;
            var mm = 59;
            var t = timeIn.text.trim();
            if (t !== "") {
                var m = /^(\d{1,2}):(\d{2})$/.exec(t);
                if (m === null) {
                    timeIn.focus = true;
                    return;
                }
                hh = Number(m[1]);
                mm = Number(m[2]);
                if (hh > 23 || mm > 59) {
                    timeIn.focus = true;
                    return;
                }
            }
            var when = new Date(Number(p[0]), Number(p[1]) - 1, Number(p[2]), hh, mm, 0, 0).getTime();
            addProc.pendingTitle = title;
            addProc.command = ["qs", "-c", "todo", "ipc", "call", "todo", "addTask", title, String(when)];
            addProc.running = true;
            addIn.text = "";
        }

        function toggleTask(id) {
            if (toggleProc.running)
                return;
            toggleProc.command = ["qs", "-c", "todo", "ipc", "call", "todo", "toggleTask", String(id)];
            toggleProc.running = true;
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
                width: root.size
                height: root.size
                x: th.gap
                y: root.open ? th.gap : -height - th.gap
                opacity: root.open ? 1 : 0
                Behavior on y { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
                Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                radius: th.radius + 2
                color: "transparent"
                gradient: Gradient {
                    GradientStop { position: 0.0; color: root.a(th.accent, 0.30) }
                    GradientStop { position: 0.05; color: root.a(th.cardBot, cfg.panelOpacity) }
                    GradientStop { position: 1.0; color: root.a(th.cardBot, cfg.panelOpacity) }
                }
                border.width: 1
                border.color: root.a(th.dim, 0.28)

                Rectangle {
                    width: parent.width - 90
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
                            else
                                root.open = false;
                            e.accepted = true;
                        } else if (e.key === Qt.Key_Left && !addIn.activeFocus && !timeIn.activeFocus) {
                            root.setMonth(root.calYear, root.calMonth - 1);
                            e.accepted = true;
                        } else if (e.key === Qt.Key_Right && !addIn.activeFocus && !timeIn.activeFocus) {
                            root.setMonth(root.calYear, root.calMonth + 1);
                            e.accepted = true;
                        } else if (e.key === Qt.Key_T && !addIn.activeFocus && !timeIn.activeFocus && !root.settingsOpen) {
                            root.goToday();
                            e.accepted = true;
                        }
                    }

                    Item {
                        id: content
                        anchors.fill: parent
                        anchors.margins: 18

                        // ── clock, date, stats ──
                        Item {
                            id: header
                            width: parent.width
                            height: 48

                            Row {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 10

                                Rectangle {
                                    width: 44
                                    height: 44
                                    radius: 10
                                    gradient: Gradient {
                                        GradientStop { position: 0.0; color: root.a(th.accent, 0.96) }
                                        GradientStop { position: 1.0; color: root.a(th.accent, 0.42) }
                                    }
                                    border.width: 1
                                    border.color: root.a(th.accent, 0.6)
                                    Column {
                                        anchors.centerIn: parent
                                        spacing: -1
                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: Qt.formatDate(root.now, "d")
                                            color: th.cardBot
                                            font.family: th.font
                                            font.pixelSize: 18
                                            font.bold: true
                                        }
                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: Qt.formatDate(root.now, "MMM").toUpperCase()
                                            color: root.a(th.cardBot, 0.75)
                                            font.family: th.font
                                            font.pixelSize: 6
                                            font.letterSpacing: 0.5
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
                                            text: Qt.formatTime(root.now, "HH:mm")
                                            color: th.bright
                                            font.family: th.font
                                            font.pixelSize: 34
                                            font.bold: true
                                        }
                                        Text {
                                            anchors.bottom: clockMain.bottom
                                            anchors.bottomMargin: 5
                                            text: Qt.formatTime(root.now, "ss")
                                            color: th.accent
                                            font.family: th.font
                                            font.pixelSize: 11
                                        }
                                    }
                                    Text {
                                        text: Qt.formatDate(root.now, "dddd, d MMMM") + "  \u00B7  week " + Qt.formatDate(root.now, "ww")
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
                                    label: store.countToday() + " today"
                                    tone: store.countToday() > 0 ? th.accent : th.dim
                                    textColor: store.countToday() > 0 ? th.bright : th.dim
                                    family: th.font
                                }
                                StatChip {
                                    glyph: "\u25F7"
                                    label: store.countMonth(root.calYear, root.calMonth) + " month"
                                    tone: store.countMonth(root.calYear, root.calMonth) > 0 ? th.accent : th.dim
                                    textColor: store.countMonth(root.calYear, root.calMonth) > 0 ? th.bright : th.dim
                                    family: th.font
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
                                    onClicked: root.settingsOpen = !root.settingsOpen
                                }
                                IconBtn {
                                    box: 24
                                    size: 12
                                    glyph: "\u2715"
                                    idle: th.dim
                                    hot: th.accent
                                    family: th.font
                                    onClicked: root.open = false
                                }
                            }
                        }

                        // ── lunar month line ──
                        MoonLine {
                            id: moonLine
                            y: header.height + 8
                            width: parent.width
                            height: 48
                            accent: th.accent
                            bright: th.bright
                            dim: th.dim
                            cardBg: th.cardBot
                            font: th.font
                        }

                        // ── weather under the lunar line ──
                        WeatherStrip {
                            id: weather
                            y: moonLine.y + moonLine.height + 8
                            width: parent.width
                            height: 36
                            wx: wx
                            accent: th.accent
                            bright: th.bright
                            dim: th.dim
                            font: th.font
                            onClicked: root.settingsOpen = true
                        }

                        // ── month + selected-day tasks ──
                        Item {
                            id: body
                            y: weather.y + weather.height + 12
                            width: parent.width
                            height: parent.height - y

                            readonly property real leftW: Math.round(width * 0.55)
                            readonly property real rightW: width - leftW - 12
                            readonly property real gifSize: Math.max(56, Math.min(96, height - 260))

                            Row {
                                anchors.fill: parent
                                spacing: 12

                                Item {
                                    width: body.leftW
                                    height: parent.height

                                    Rectangle {
                                        id: monthCard
                                        width: parent.width
                                        height: 250
                                        radius: th.radius
                                        color: root.a(th.dim, 0.035)
                                        border.width: 1
                                        border.color: root.a(th.dim, 0.12)

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
                                                color: th.bright
                                                font.family: th.font
                                                font.pixelSize: 12
                                                font.bold: true
                                            }
                                            Text {
                                                anchors.left: monthLabel.right
                                                anchors.leftMargin: 4
                                                anchors.baseline: monthLabel.baseline
                                                text: root.calYear
                                                color: root.a(th.dim, 0.8)
                                                font.family: th.font
                                                font.pixelSize: 8
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
                                                    onClicked: root.setMonth(root.calYear, root.calMonth - 1)
                                                }
                                                IconBtn {
                                                    box: 18
                                                    size: 12
                                                    glyph: "\u203A"
                                                    idle: th.dim
                                                    hot: th.accent
                                                    family: th.font
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
                                                model: ["S", "M", "T", "W", "T", "F", "S"]
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
                                            height: 209
                                            store: store
                                            selectedKey: root.selectedKey
                                            year: root.calYear
                                            month: root.calMonth
                                            accent: th.accent
                                            bright: th.bright
                                            dim: th.dim
                                            cardBg: th.cardBot
                                            font: th.font
                                            cellHeight: 34
                                            onDayClicked: function (key) { root.selectedKey = key }
                                        }
                                    }

                                    Item {
                                        y: monthCard.height + 10
                                        width: parent.width
                                        height: body.gifSize

                                        Rectangle {
                                            id: gifCard
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            width: body.gifSize
                                            height: body.gifSize
                                            radius: th.radius
                                            color: root.a(th.dim, 0.035)
                                            border.width: 1
                                            border.color: root.a(th.dim, 0.12)
                                            clip: true

                                            Item {
                                                id: gifFrame
                                                anchors.fill: parent
                                                anchors.margins: 1
                                                visible: false
                                                AnimatedImage {
                                                    anchors.fill: parent
                                                    source: root.gifUrl()
                                                    fillMode: Image.PreserveAspectCrop
                                                    asynchronous: true
                                                    smooth: true
                                                    playing: root.open
                                                    cache: false
                                                    sourceSize.width: gifFrame.width * 2
                                                    sourceSize.height: gifFrame.height * 2
                                                }
                                            }

                                            Item {
                                                id: gifMask
                                                anchors.fill: parent
                                                anchors.margins: 1
                                                layer.enabled: true
                                                visible: false
                                                Rectangle {
                                                    anchors.fill: parent
                                                    radius: 8
                                                    color: "black"
                                                }
                                            }

                                            MultiEffect {
                                                anchors.fill: parent
                                                anchors.margins: 1
                                                source: gifFrame
                                                maskEnabled: true
                                                maskSource: gifMask
                                                visible: cfg.gif !== ""
                                                opacity: 0.95
                                            }

                                            Rectangle {
                                                anchors.fill: parent
                                                visible: cfg.gif === ""
                                                radius: th.radius
                                                color: root.a(th.dim, 0.04)
                                                border.width: 1
                                                border.color: root.a(th.dim, 0.14)

                                                Column {
                                                    anchors.centerIn: parent
                                                    spacing: 3
                                                    Text {
                                                        anchors.horizontalCenter: parent.horizontalCenter
                                                        text: "\u2727"
                                                        color: root.a(th.accent, 0.55)
                                                        font.family: th.font
                                                        font.pixelSize: 20
                                                    }
                                                    Text {
                                                        anchors.horizontalCenter: parent.horizontalCenter
                                                        text: "gif"
                                                        color: root.a(th.dim, 0.7)
                                                        font.family: th.font
                                                        font.pixelSize: 8
                                                    }
                                                    Text {
                                                        anchors.horizontalCenter: parent.horizontalCenter
                                                        text: "click to set"
                                                        color: root.a(th.dim, 0.45)
                                                        font.family: th.font
                                                        font.pixelSize: 7
                                                    }
                                                }
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.settingsOpen = true
                                            }
                                        }
                                    }
                                }

                                Rectangle {
                                    id: taskCard
                                    width: body.rightW
                                    height: parent.height
                                    radius: th.radius
                                    color: root.a(th.dim, 0.035)
                                    border.width: 1
                                    border.color: root.a(th.dim, 0.12)

                                    readonly property int taskCount: store.countOn(root.selectedKey)

                                    Item {
                                        id: taskHead
                                        x: 10
                                        y: 8
                                        width: parent.width - 20
                                        height: 28

                                        Column {
                                            anchors.left: parent.left
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: 0
                                            Text {
                                                text: store.dayTitle(root.selectedKey)
                                                color: root.selectedKey === store.todayKey() ? th.accent : th.bright
                                                font.family: th.font
                                                font.pixelSize: 13
                                                font.bold: true
                                            }
                                            Text {
                                                text: taskCard.taskCount + (taskCard.taskCount === 1 ? " task" : " tasks")
                                                color: root.a(th.dim, 0.8)
                                                font.family: th.font
                                                font.pixelSize: 8
                                            }
                                        }

                                        Text {
                                            anchors.right: parent.right
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

                                    Rectangle {
                                        x: 10
                                        y: 40
                                        width: parent.width - 20
                                        height: 1
                                        color: root.a(th.dim, 0.12)
                                    }

                                    Flickable {
                                        id: taskFlick
                                        x: 10
                                        y: 46
                                        width: parent.width - 20
                                        height: parent.height - 46 - 60
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

                                            Repeater {
                                                model: store.tasksOn(root.selectedKey)
                                                delegate: Item {
                                                    id: taskRow
                                                    required property var modelData
                                                    readonly property var task: modelData
                                                    readonly property bool overdue: !task.done && task.due < Date.now()

                                                    width: taskCol.width
                                                    height: 34

                                                    Rectangle {
                                                        anchors.fill: parent
                                                        anchors.margins: 1
                                                        radius: 5
                                                        color: rowHover.hovered ? root.a(th.dim, 0.06) : "transparent"
                                                    }

                                                    Rectangle {
                                                        x: 2
                                                        y: 10
                                                        width: 14
                                                        height: 14
                                                        radius: 7
                                                        color: taskRow.task.done ? root.a(th.accent, 0.85) : "transparent"
                                                        border.width: 1
                                                        border.color: taskRow.task.done ? th.accent
                                                            : taskRow.overdue ? th.accent : root.a(th.dim, 0.55)
                                                        Text {
                                                            anchors.centerIn: parent
                                                            visible: taskRow.task.done
                                                            text: "\u2713"
                                                            color: th.cardBot
                                                            font.family: th.font
                                                            font.pixelSize: 8
                                                            font.bold: true
                                                        }
                                                        MouseArea {
                                                            anchors.fill: parent
                                                            anchors.margins: -5
                                                            cursorShape: Qt.PointingHandCursor
                                                            onClicked: root.toggleTask(taskRow.task.ord)
                                                        }
                                                    }

                                                    Text {
                                                        x: 24
                                                        y: 3
                                                        width: parent.width - 28
                                                        text: taskRow.task.text
                                                        color: taskRow.task.done ? root.a(th.dim, 0.5) : th.bright
                                                        elide: Text.ElideRight
                                                        font.family: th.font
                                                        font.pixelSize: 10
                                                        font.strikeout: taskRow.task.done
                                                    }
                                                    Text {
                                                        x: 24
                                                        y: 19
                                                        width: parent.width - 28
                                                        text: store.isDateOnly(taskRow.task.due) ? "all day" : store.timeLabel(taskRow.task.due)
                                                        color: taskRow.task.done ? root.a(th.dim, 0.4)
                                                            : taskRow.overdue ? th.accent : root.a(th.dim, 0.8)
                                                        elide: Text.ElideRight
                                                        font.family: th.font
                                                        font.pixelSize: 8
                                                    }

                                                    HoverHandler { id: rowHover }

                                                    MouseArea {
                                                        x: 24
                                                        y: 0
                                                        width: parent.width - 24
                                                        height: parent.height
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: root.openTodo()
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    Rectangle {
                                        id: addBox
                                        x: 10
                                        y: parent.height - 54
                                        width: parent.width - 20
                                        height: 34
                                        radius: 7
                                        color: root.a(th.dim, 0.06)
                                        border.width: 1
                                        border.color: (addIn.activeFocus || timeIn.activeFocus)
                                            ? th.accent : root.a(th.dim, 0.18)

                                        Text {
                                            x: 9
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: "+"
                                            color: th.accent
                                            font.family: th.font
                                            font.pixelSize: 13
                                            font.bold: true
                                        }
                                        TextInput {
                                            id: addIn
                                            x: 24
                                            width: parent.width - 24 - 42 - 8
                                            anchors.verticalCenter: parent.verticalCenter
                                            color: th.bright
                                            selectionColor: root.a(th.accent, 0.45)
                                            selectedTextColor: th.bright
                                            font.family: th.font
                                            font.pixelSize: 9
                                            clip: true
                                            onAccepted: root.addTask()
                                        }
                                        Text {
                                            x: 24
                                            width: addIn.width
                                            anchors.verticalCenter: parent.verticalCenter
                                            visible: addIn.text === ""
                                            text: "add a task\u2026"
                                            color: root.a(th.dim, 0.55)
                                            elide: Text.ElideRight
                                            font.family: th.font
                                            font.pixelSize: 9
                                        }
                                        Rectangle {
                                            x: timeIn.x - 5
                                            width: 1
                                            height: 16
                                            anchors.verticalCenter: parent.verticalCenter
                                            color: root.a(th.dim, 0.18)
                                        }
                                        TextInput {
                                            id: timeIn
                                            width: 34
                                            anchors.right: parent.right
                                            anchors.rightMargin: 8
                                            anchors.verticalCenter: parent.verticalCenter
                                            horizontalAlignment: TextInput.AlignHCenter
                                            color: th.bright
                                            selectionColor: root.a(th.accent, 0.45)
                                            selectedTextColor: th.bright
                                            font.family: th.font
                                            font.pixelSize: 8
                                            clip: true
                                            onAccepted: root.addTask()
                                        }
                                        Text {
                                            width: timeIn.width
                                            anchors.right: parent.right
                                            anchors.rightMargin: 8
                                            anchors.verticalCenter: parent.verticalCenter
                                            horizontalAlignment: Text.AlignHCenter
                                            visible: timeIn.text === ""
                                            text: "18:00"
                                            color: root.a(th.dim, 0.55)
                                            font.family: th.font
                                            font.pixelSize: 8
                                        }
                                    }

                                    Text {
                                        x: 10
                                        y: parent.height - 16
                                        text: "time empty = all day"
                                        color: root.a(th.dim, 0.5)
                                        font.family: th.font
                                        font.pixelSize: 7
                                    }
                                }
                            }
                        }
                    }
                }
            // ── settings card ──
            Rectangle {
                id: settingsCard
                anchors.fill: parent
                visible: root.settingsOpen
                z: 100
                color: root.a(th.cardBot, 1.0)
                radius: panel.radius / root.zoom

                Rectangle {
                    anchors.fill: parent
                    color: root.a(th.cardBot, 1.0)
                    radius: parent.radius
                    z: -1
                }

                // keep clicks and scrolling on the card while it is open
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.AllButtons
                    onWheel: function (wheel) { wheel.accepted = true }
                }

                Column {
                    x: 24
                    y: 22
                    width: parent.width - 48
                    spacing: 15
                    z: 1

                    Item {
                        width: parent.width
                        height: 24
                        Text {
                            text: "Settings"
                            color: th.bright
                            font.family: th.font
                            font.pixelSize: 15
                            font.bold: true
                        }
                        Text {
                            anchors.right: parent.right
                            text: "close \u00D7"
                            color: setCloseHover.hovered ? th.accent : th.dim
                            font.family: th.font
                            font.pixelSize: 10
                            HoverHandler { id: setCloseHover }
                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -5
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    cfg.set("gif", gifIn.text.trim());
                                    cfg.set("city", cityIn.text.trim());
                                    root.settingsOpen = false;
                                }
                            }
                        }
                    }

                    Text {
                        text: "GIF"
                        color: root.a(th.dim, 0.9)
                        font.family: th.font
                        font.pixelSize: 9
                    }
                    Rectangle {
                        width: parent.width
                        height: 32
                        radius: 5
                        color: root.a(th.dim, 0.06)
                        border.width: 1
                        border.color: root.a(th.dim, 0.18)
                        TextInput {
                            id: gifIn
                            anchors.fill: parent
                            anchors.margins: 8
                            verticalAlignment: TextInput.AlignVCenter
                            color: th.bright
                            selectionColor: root.a(th.accent, 0.45)
                            selectedTextColor: th.bright
                            font.family: th.font
                            font.pixelSize: 10
                            clip: true
                            onEditingFinished: cfg.set("gif", text.trim())
                        }
                        Text {
                            x: 9
                            width: parent.width - 18
                            anchors.verticalCenter: parent.verticalCenter
                            visible: gifIn.text === ""
                            text: "~/Pictures/your.gif"
                            color: root.a(th.dim, 0.55)
                            elide: Text.ElideRight
                            font.family: th.font
                            font.pixelSize: 10
                        }
                    }

                    Text {
                        text: "WEATHER CITY"
                        color: root.a(th.dim, 0.9)
                        font.family: th.font
                        font.pixelSize: 9
                    }
                    Rectangle {
                        width: parent.width
                        height: 32
                        radius: 5
                        color: root.a(th.dim, 0.06)
                        border.width: 1
                        border.color: root.a(th.dim, 0.18)
                        TextInput {
                            id: cityIn
                            anchors.fill: parent
                            anchors.margins: 8
                            verticalAlignment: TextInput.AlignVCenter
                            color: th.bright
                            selectionColor: root.a(th.accent, 0.45)
                            selectedTextColor: th.bright
                            font.family: th.font
                            font.pixelSize: 10
                            clip: true
                            onEditingFinished: cfg.set("city", text.trim())
                        }
                        Text {
                            x: 9
                            width: parent.width - 18
                            anchors.verticalCenter: parent.verticalCenter
                            visible: cityIn.text === ""
                            text: "empty = guess from the network"
                            color: root.a(th.dim, 0.55)
                            elide: Text.ElideRight
                            font.family: th.font
                            font.pixelSize: 10
                        }
                    }

                    Row {
                        spacing: 8
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "UNITS"
                            color: root.a(th.dim, 0.9)
                            font.family: th.font
                            font.pixelSize: 9
                        }
                        Rectangle {
                            width: 36
                            height: 22
                            radius: 4
                            color: cfg.units === "c" ? root.a(th.accent, 0.18) : root.a(th.dim, 0.06)
                            border.width: 1
                            border.color: cfg.units === "c" ? th.accent : root.a(th.dim, 0.2)
                            Text {
                                anchors.centerIn: parent
                                text: "\u00B0C"
                                color: cfg.units === "c" ? th.accent : th.dim
                                font.family: th.font
                                font.pixelSize: 9
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: cfg.set("units", "c")
                            }
                        }
                        Rectangle {
                            width: 36
                            height: 22
                            radius: 4
                            color: cfg.units === "f" ? root.a(th.accent, 0.18) : root.a(th.dim, 0.06)
                            border.width: 1
                            border.color: cfg.units === "f" ? th.accent : root.a(th.dim, 0.2)
                            Text {
                                anchors.centerIn: parent
                                text: "\u00B0F"
                                color: cfg.units === "f" ? th.accent : th.dim
                                font.family: th.font
                                font.pixelSize: 9
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: cfg.set("units", "f")
                            }
                        }
                    }

                    Text {
                        width: parent.width
                        text: "The calendar reads your todo list live. New tasks and checkmarks are sent to the todo panel, so both stay in sync."
                        color: root.a(th.dim, 0.6)
                        font.family: th.font
                        font.pixelSize: 9
                        wrapMode: Text.WordWrap
                        lineHeight: 1.25
                    }

                    Text {
                        text: "reload weather"
                        color: reloadHover.hovered ? th.accent : root.a(th.dim, 0.8)
                        font.family: th.font
                        font.pixelSize: 9
                        HoverHandler { id: reloadHover }
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -4
                            cursorShape: Qt.PointingHandCursor
                            onClicked: wx.refresh(true)
                        }
                    }
                }

                onVisibleChanged: {
                    if (visible) {
                        gifIn.text = cfg.gif;
                        cityIn.text = cfg.city;
                    }
                }
            }
            }
            }
        }
    }
}
