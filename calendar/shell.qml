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

        readonly property int panelW: cfg.panelWidth
        // the Ryoku top bar owns the first 38 px; start below it so the month
        // header is never swallowed by the bar.
        readonly property int topInset: 38
        property bool open: false
        property bool settingsOpen: false
        property int calYear: new Date().getFullYear()
        property int calMonth: new Date().getMonth()
        property string selectedKey: store.todayKey()

        anchors { top: true; bottom: true; right: true }
        implicitWidth: panelW + th.gap * 2
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        visible: open || panel.x < implicitWidth - 1
        mask: Region { item: panel }

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "calendar-panel"
        WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

        onOpenChanged: if (open) Qt.callLater(focusScope.forceActiveFocus)

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
            onExited: if (addIn.text === "") addIn.forceActiveFocus()
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
        Rectangle {
            id: panel
            width: root.panelW
            y: root.topInset + th.gap
            height: parent.height - root.topInset - th.gap * 2
            x: root.open ? th.gap : root.implicitWidth
            Behavior on x { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }

            radius: th.radius + 2
            color: "transparent"
            gradient: Gradient {
                GradientStop { position: 0.0; color: root.a(th.accent, 0.30) }
                GradientStop { position: 0.06; color: root.a(th.cardBot, cfg.panelOpacity) }
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

                Flickable {
                    id: flick
                    anchors.fill: parent
                    contentWidth: width
                    contentHeight: col.height
                    boundsBehavior: Flickable.StopAtBounds
                    clip: true

                    Column {
                        id: col
                        x: 18
                        width: flick.width - 36
                        spacing: 0

                        // ── header ──
                        Item {
                            width: parent.width
                            height: 62

                            Column {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.topMargin: 8
                                spacing: 1

                                Row {
                                    spacing: 7
                                    Text {
                                        text: store.monthNames[root.calMonth]
                                        color: th.bright
                                        font.family: th.font
                                        font.pixelSize: 24
                                        font.bold: true
                                    }
                                    Text {
                                        anchors.bottom: parent.bottom
                                        anchors.bottomMargin: 3
                                        text: root.calYear
                                        color: th.dim
                                        font.family: th.font
                                        font.pixelSize: 12
                                    }
                                }

                                Row {
                                    spacing: 5
                                    Text {
                                        text: store.countToday() + " today"
                                        color: root.a(th.dim, 0.95)
                                        font.family: th.font
                                        font.pixelSize: 9
                                    }
                                    Text {
                                        text: "\u00B7  " + store.countMonth(root.calYear, root.calMonth) + " this month"
                                        color: root.a(th.dim, 0.75)
                                        font.family: th.font
                                        font.pixelSize: 9
                                    }
                                    Text {
                                        visible: store.countOverdue() > 0
                                        text: "\u00B7  " + store.countOverdue() + " overdue"
                                        color: th.accent
                                        font.family: th.font
                                        font.pixelSize: 9
                                    }
                                }
                            }

                            Row {
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.topMargin: 11
                                spacing: 12

                                Text {
                                    text: "today"
                                    color: todayHover.hovered ? th.accent : th.dim
                                    font.family: th.font
                                    font.pixelSize: 9
                                    HoverHandler { id: todayHover }
                                    MouseArea {
                                        anchors.fill: parent
                                        anchors.margins: -4
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.goToday()
                                    }
                                }
                                Text {
                                    text: "\u2039"
                                    color: prevHover.hovered ? th.bright : th.dim
                                    font.family: th.font
                                    font.pixelSize: 18
                                    HoverHandler { id: prevHover }
                                    MouseArea {
                                        anchors.fill: parent
                                        anchors.margins: -5
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.setMonth(root.calYear, root.calMonth - 1)
                                    }
                                }
                                Text {
                                    text: "\u203A"
                                    color: nextHover.hovered ? th.bright : th.dim
                                    font.family: th.font
                                    font.pixelSize: 18
                                    HoverHandler { id: nextHover }
                                    MouseArea {
                                        anchors.fill: parent
                                        anchors.margins: -5
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.setMonth(root.calYear, root.calMonth + 1)
                                    }
                                }
                                Text {
                                    text: "\uF013"
                                    color: gearHover.hovered ? th.accent : th.dim
                                    font.family: th.font
                                    font.pixelSize: 11
                                    HoverHandler { id: gearHover }
                                    MouseArea {
                                        anchors.fill: parent
                                        anchors.margins: -5
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.settingsOpen = true
                                    }
                                }
                                Text {
                                    text: "\u00D7"
                                    color: closeHover.hovered ? th.accent : th.dim
                                    font.family: th.font
                                    font.pixelSize: 13
                                    HoverHandler { id: closeHover }
                                    MouseArea {
                                        anchors.fill: parent
                                        anchors.margins: -5
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.open = false
                                    }
                                }
                            }
                        }

                        // ── weekday letters ──
                        Row {
                            width: parent.width
                            Repeater {
                                model: ["S", "M", "T", "W", "T", "F", "S"]
                                delegate: Text {
                                    required property string modelData
                                    width: parent.width / 7
                                    horizontalAlignment: Text.AlignHCenter
                                    text: modelData
                                    color: root.a(th.dim, 0.8)
                                    font.family: th.font
                                    font.pixelSize: 9
                                }
                            }
                        }

                        Item { width: 1; height: 5 }

                        CalendarGrid {
                            width: col.width
                            store: store
                            selectedKey: root.selectedKey
                            year: root.calYear
                            month: root.calMonth
                            accent: th.accent
                            bright: th.bright
                            dim: th.dim
                            cardBg: th.cardBot
                            font: th.font
                            cellHeight: 62
                            onDayClicked: function (key) { root.selectedKey = key; }
                        }

                        Item { width: 1; height: 12 }

                        Rectangle {
                            width: parent.width
                            height: 1
                            color: root.a(th.dim, 0.16)
                        }

                        // ── selected day ──
                        Item {
                            width: parent.width
                            height: 34

                            Row {
                                anchors.left: parent.left
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 7
                                spacing: 7
                                Text {
                                    text: store.dayTitle(root.selectedKey)
                                    color: th.bright
                                    font.family: th.font
                                    font.pixelSize: 12
                                    font.bold: true
                                }
                                Text {
                                    text: store.countOn(root.selectedKey) > 0 ? store.countOn(root.selectedKey) + " due" : "clear"
                                    color: root.a(th.dim, 0.8)
                                    font.family: th.font
                                    font.pixelSize: 9
                                }
                            }

                            Text {
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 7
                                text: "open todo \u2197"
                                color: openHover.hovered ? th.accent : root.a(th.dim, 0.8)
                                font.family: th.font
                                font.pixelSize: 9
                                HoverHandler { id: openHover }
                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -4
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.openTodo()
                                }
                            }
                        }

                        // empty state
                        Item {
                            width: parent.width
                            height: store.countOn(root.selectedKey) === 0 ? 34 : 0
                            Text {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Nothing due. A good day."
                                color: root.a(th.dim, 0.7)
                                font.family: th.font
                                font.pixelSize: 10
                            }
                        }

                        Repeater {
                            model: store.tasksOn(root.selectedKey)
                            delegate: Item {
                                id: agRow
                                required property var modelData
                                readonly property var task: modelData
                                readonly property bool overdue: !task.done && task.due < Date.now()

                                width: col.width
                                height: 30

                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: 1
                                    radius: 5
                                    color: agHover.hovered ? root.a(th.dim, 0.06) : "transparent"
                                }

                                Rectangle {
                                    x: 2
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 14
                                    height: 14
                                    radius: 7
                                    color: agRow.task.done ? root.a(th.accent, 0.85) : "transparent"
                                    border.width: 1
                                    border.color: agRow.task.done ? th.accent
                                        : agRow.overdue ? th.accent : root.a(th.dim, 0.55)
                                    Text {
                                        anchors.centerIn: parent
                                        visible: agRow.task.done
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
                                        onClicked: root.toggleTask(agRow.task.ord)
                                    }
                                }

                                Text {
                                    x: 26
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 44
                                    text: store.isDateOnly(agRow.task.due) ? "all day" : store.timeLabel(agRow.task.due)
                                    color: agRow.task.done ? root.a(th.dim, 0.55)
                                        : agRow.overdue ? th.accent : root.a(th.dim, 0.9)
                                    font.family: th.font
                                    font.pixelSize: 9
                                }

                                Text {
                                    x: 74
                                    width: parent.width - 80
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: agRow.task.text
                                    color: agRow.task.done ? root.a(th.dim, 0.55) : th.bright
                                    elide: Text.ElideRight
                                    font.family: th.font
                                    font.pixelSize: 10
                                    font.strikeout: agRow.task.done
                                }

                                HoverHandler { id: agHover }

                                MouseArea {
                                    x: 74
                                    y: 0
                                    width: parent.width - 74
                                    height: parent.height
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.openTodo()
                                }
                            }
                        }

                        // ── quick add ──
                        Item { width: 1; height: 8 }

                        Rectangle {
                            width: parent.width
                            height: 34
                            radius: 6
                            color: root.a(th.dim, 0.06)
                            border.width: 1
                            border.color: addIn.activeFocus || timeIn.activeFocus ? root.a(th.accent, 0.55) : root.a(th.dim, 0.16)

                            Text {
                                x: 9
                                anchors.verticalCenter: parent.verticalCenter
                                text: "+"
                                color: th.accent
                                font.family: th.font
                                font.pixelSize: 15
                            }

                            TextInput {
                                id: addIn
                                x: 26
                                width: parent.width - 26 - 58 - 8
                                anchors.verticalCenter: parent.verticalCenter
                                color: th.bright
                                selectionColor: root.a(th.accent, 0.45)
                                selectedTextColor: th.bright
                                font.family: th.font
                                font.pixelSize: 10
                                clip: true
                                onAccepted: root.addTask()
                            }
                            Text {
                                x: 26
                                width: addIn.width
                                anchors.verticalCenter: parent.verticalCenter
                                visible: addIn.text === ""
                                text: "add a task for " + store.dayTitle(root.selectedKey).toLowerCase() + "\u2026"
                                color: root.a(th.dim, 0.65)
                                elide: Text.ElideRight
                                font.family: th.font
                                font.pixelSize: 10
                            }

                            TextInput {
                                id: timeIn
                                width: 48
                                anchors.right: parent.right
                                anchors.rightMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                horizontalAlignment: TextInput.AlignHCenter
                                color: th.bright
                                selectionColor: root.a(th.accent, 0.45)
                                selectedTextColor: th.bright
                                font.family: th.font
                                font.pixelSize: 9
                                clip: true
                                onAccepted: root.addTask()
                            }
                            Text {
                                anchors.right: parent.right
                                anchors.rightMargin: 8
                                width: 48
                                anchors.verticalCenter: parent.verticalCenter
                                horizontalAlignment: Text.AlignHCenter
                                visible: timeIn.text === ""
                                text: "18:00"
                                color: root.a(th.dim, 0.55)
                                font.family: th.font
                                font.pixelSize: 9
                            }

                            Rectangle {
                                anchors.right: timeIn.left
                                anchors.rightMargin: 4
                                width: 1
                                height: 14
                                anchors.verticalCenter: parent.verticalCenter
                                color: root.a(th.dim, 0.18)
                            }
                        }

                        Text {
                            width: parent.width
                            text: "Enter adds it to the todo list with that date and time \u00B7 leave the time empty for all day"
                            color: root.a(th.dim, 0.55)
                            font.family: th.font
                            font.pixelSize: 8
                            wrapMode: Text.WordWrap
                        }

                        Item { width: 1; height: 14 }

                        Rectangle {
                            width: parent.width
                            height: 1
                            color: root.a(th.dim, 0.16)
                        }

                        Item { width: 1; height: 10 }

                        // ── moon / clock / weather ──
                        Tray {
                            width: col.width
                            cfg: cfg
                            wx: wx
                            accent: th.accent
                            bright: th.bright
                            dim: th.dim
                            font: th.font
                        }

                        Item { width: 1; height: 12 }

                        // ── gif ──
                        Item {
                            width: parent.width
                            height: 140

                            Item {
                                id: gifFrame
                                anchors.fill: parent
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
                                layer.enabled: true
                                visible: false
                                Rectangle {
                                    anchors.fill: parent
                                    radius: 10
                                    color: "black"
                                }
                            }

                            MultiEffect {
                                anchors.fill: parent
                                source: gifFrame
                                maskEnabled: true
                                maskSource: gifMask
                                visible: cfg.gif !== ""
                                opacity: 0.94
                            }

                            Rectangle {
                                anchors.fill: parent
                                visible: cfg.gif === ""
                                radius: 10
                                color: root.a(th.dim, 0.05)
                                border.width: 1
                                border.color: root.a(th.dim, 0.14)
                                gradient: Gradient {
                                    GradientStop { position: 0.0; color: root.a(th.accent, 0.06) }
                                    GradientStop { position: 1.0; color: "transparent" }
                                }

                                Column {
                                    anchors.centerIn: parent
                                    spacing: 4
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: "\u2727"
                                        color: root.a(th.accent, 0.55)
                                        font.family: th.font
                                        font.pixelSize: 24
                                    }
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: "gif slot \u00B7 click to set one"
                                        color: root.a(th.dim, 0.65)
                                        font.family: th.font
                                        font.pixelSize: 9
                                    }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.settingsOpen = true
                                }
                            }
                        }

                        Item { width: 1; height: 18 }
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
                radius: parent.radius

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
