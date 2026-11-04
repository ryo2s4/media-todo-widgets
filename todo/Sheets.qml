import QtQuick

// Sheets.qml: the extra views (insights, calendar, tags, templates, archive,
// plan, command palette) and the focus mode overlay.
Item {
    id: sh
    property var st
    property var th
    property var host
    anchors.fill: parent
    z: 110

    function a(c, v) { return Qt.rgba(c.r, c.g, c.b, v); }
    function pad(n) { return (n < 10 ? "0" : "") + n; }
    function dayKeyOf(y, m, d) { return y + "-" + pad(m + 1) + "-" + pad(d); }
    function heat(n) {
        if (n <= 0)
            return a(th.dim, 0.10);
        if (n <= 1)
            return a(th.accent, 0.30);
        if (n <= 3)
            return a(th.accent, 0.55);
        if (n <= 5)
            return a(th.accent, 0.78);
        return th.accent;
    }
    function maxDone(days) {
        var m = 1;
        for (var i = 0; i < days.length; i++)
            m = Math.max(m, days[i].done);
        return m;
    }
    function barH(days, i) {
        var m = maxDone(days);
        return 4 + Math.round((days[i].done / m) * 30);
    }
    function dayNum(key) { return Number(key.substring(8)); }
    function fmtMins(m) { return Math.floor(m / 60) + "h " + (m % 60) + "m"; }
    function monthName() {
        return ["January", "February", "March", "April", "May", "June", "July",
                "August", "September", "October", "November", "December"][host.calMonth];
    }
    function calFirst() { return new Date(host.calYear, host.calMonth, 1).getDay(); }
    function calCount() { return new Date(host.calYear, host.calMonth + 1, 0).getDate(); }
    function calKey(day) { return dayKeyOf(host.calYear, host.calMonth, day); }
    function countOn(key) {
        var t = st.tasksOnDay(key);
        return t.length;
    }
    function isToday(y, m, d) {
        var n = new Date();
        return n.getFullYear() === y && n.getMonth() === m && n.getDate() === d;
    }

    // ───────── menu ─────────
    // Views live in the top NavBar; the ... menu keeps only utilities.
    property var menuItems: [
        { k: "select", t: "Select tasks" },
        { k: "review", t: "Weekly review" },
        { k: "export", t: "Export markdown" },
        { k: "settings", t: "Settings" }
    ]

    // Everything the command palette can jump to.
    property var paletteActions: [
        { k: "board", t: "Back to board" },
        { k: "stats", t: "Insights" },
        { k: "calendar", t: "Calendar" },
        { k: "tags", t: "Tags / projects" },
        { k: "templates", t: "Templates" },
        { k: "archive", t: "Archive" },
        { k: "plan", t: "Plan today" },
        { k: "focus", t: "Focus mode" },
        { k: "select", t: "Select tasks" },
        { k: "review", t: "Weekly review" },
        { k: "export", t: "Export markdown" },
        { k: "settings", t: "Settings" }
    ]

    function runMenu(k) {
        host.menuOpen = false;
        if (k === "board") {
            host.closeSheets();
            host.settingsOpen = false;
            host.focusMode = false;
        } else if (k === "stats")
            host.statsOpen = true;
        else if (k === "calendar")
            host.calOpen = true;
        else if (k === "tags")
            host.tagsOpen = true;
        else if (k === "templates")
            host.templatesOpen = true;
        else if (k === "archive")
            host.archiveOpen = true;
        else if (k === "plan")
            host.planOpen = true;
        else if (k === "palette")
            host.openPalette();
        else if (k === "focus")
            host.focusMode = !host.focusMode;
        else if (k === "select") {
            host.selectMode = !host.selectMode;
            if (!host.selectMode)
                host.clearSelection();
        } else if (k === "review")
            st.forceReview();
        else if (k === "export")
            st.exportMarkdown();
        else if (k === "settings")
            host.settingsOpen = true;
    }

    Sheet {
        visible: host.menuOpen
        theme: th
        heading: "More"
        cardWidth: 230
        onClosed: host.menuOpen = false
        Repeater {
            model: sh.menuItems
            delegate: Text {
                required property var modelData
                width: parent.width
                height: 24
                verticalAlignment: Text.AlignVCenter
                text: modelData.t
                color: menuHover.hovered ? th.accent : th.bright
                font.family: th.font
                font.pixelSize: 12
                HoverHandler { id: menuHover }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: sh.runMenu(parent.modelData.k)
                }
            }
        }
    }

    // ───────── insights ─────────
    readonly property var heatDays: { var r = st.stateRev + st.tasks.length + st.nowTick; return st.daysBack(70); }
    readonly property var barDays: { var r = st.stateRev + st.nowTick; return st.daysBack(14); }
    readonly property var weekDays: { var r = st.stateRev + st.nowTick; return st.daysBack(7); }
    readonly property var tagList: { var r = st.stateRev + st.tasks.length; return st.tagStats().slice(0, 7); }

    Sheet {
        visible: host.statsOpen
        theme: th
        heading: "Insights"
        cardWidth: 300
        cardHeight: 440
        onClosed: host.statsOpen = false

        Text {
            text: "This week: " + sh.st.statTotal(sh.weekDays).done + " done \u00B7 " + sh.fmtMins(sh.st.statTotal(sh.weekDays).mins) + " focus"
            color: th.bright
            font.family: th.font
            font.pixelSize: 11
        }

        Text {
            text: "Activity, last 10 weeks"
            color: th.dim
            font.family: th.font
            font.pixelSize: 10
        }

        Column {
            spacing: 2
            Repeater {
                model: 7
                delegate: Row {
                    required property int index
                    spacing: 2
                    Repeater {
                        model: 10
                        delegate: Rectangle {
                            required property int index
                            width: 14
                            height: 14
                            radius: 2
                            color: sh.heat(sh.heatDays[parent.index * 7 + index].done)
                        }
                    }
                }
            }
        }

        Text {
            text: "Last 14 days"
            color: th.dim
            font.family: th.font
            font.pixelSize: 10
        }

        Row {
            spacing: 3
            Repeater {
                model: 14
                delegate: Column {
                    required property int index
                    spacing: 2
                    Rectangle {
                        width: 13
                        height: sh.barH(sh.barDays, index)
                        radius: 2
                        color: sh.barDays[index].done > 0 ? sh.a(th.accent, 0.8) : sh.a(th.dim, 0.15)
                    }
                    Text {
                        width: 13
                        horizontalAlignment: Text.AlignHCenter
                        text: String(sh.dayNum(sh.barDays[index].key))
                        color: th.dim
                        font.family: th.font
                        font.pixelSize: 7
                    }
                }
            }
        }

        Text {
            text: "Projects"
            color: th.dim
            font.family: th.font
            font.pixelSize: 10
            visible: sh.tagList.length > 0
        }

        Repeater {
            model: sh.tagList
            delegate: Item {
                required property var modelData
                width: parent.width
                height: 20
                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "#" + modelData.tag
                    color: th.bright
                    font.family: th.font
                    font.pixelSize: 10
                }
                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.open + " open \u00B7 " + (modelData.open + modelData.done) + " total"
                    color: th.dim
                    font.family: th.font
                    font.pixelSize: 9
                }
            }
        }
    }

    // ───────── calendar ─────────
    Sheet {
        visible: host.calOpen
        theme: th
        heading: "Calendar"
        cardWidth: 300
        cardHeight: 372
        onClosed: host.calOpen = false

        Row {
            width: parent.width
            spacing: 8
            Text {
                text: "\u2039"
                color: th.dim
                font.family: th.font
                font.pixelSize: 16
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        host.calMonth -= 1;
                        if (host.calMonth < 0) {
                            host.calMonth = 11;
                            host.calYear -= 1;
                        }
                    }
                }
            }
            Text {
                width: parent.width - 76
                horizontalAlignment: Text.AlignHCenter
                text: sh.monthName() + " " + host.calYear
                color: th.bright
                font.family: th.font
                font.pixelSize: 12
                font.bold: true
            }
            Text {
                text: "\u203A"
                color: th.dim
                font.family: th.font
                font.pixelSize: 16
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        host.calMonth += 1;
                        if (host.calMonth > 11) {
                            host.calMonth = 0;
                            host.calYear += 1;
                        }
                    }
                }
            }
        }

        Row {
            width: parent.width
            Repeater {
                model: ["S", "M", "T", "W", "T", "F", "S"]
                delegate: Text {
                    required property string modelData
                    width: parent.width / 7
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData
                    color: th.dim
                    font.family: th.font
                    font.pixelSize: 9
                }
            }
        }

        Grid {
            id: calGrid
            width: parent.width
            columns: 7
            spacing: 1
            Repeater {
                model: 42
                delegate: Item {
                    required property int index
                    readonly property int dayNum: index - sh.calFirst() + 1
                    readonly property bool valid: dayNum >= 1 && dayNum <= sh.calCount()
                    readonly property string key: sh.calKey(dayNum)
                    width: calGrid.width / 7
                    height: 28
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 1
                        radius: 3
                        color: parent.valid && parent.key === st.dateFilter ? sh.a(th.accent, 0.3) : "transparent"
                        border.width: parent.valid && sh.isToday(host.calYear, host.calMonth, parent.dayNum) ? 1 : 0
                        border.color: th.accent
                    }
                    Text {
                        anchors.centerIn: parent
                        text: parent.valid ? parent.dayNum : ""
                        color: parent.valid ? (sh.isToday(host.calYear, host.calMonth, parent.dayNum) ? th.accent : th.bright) : "transparent"
                        font.family: th.font
                        font.pixelSize: 10
                    }
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 3
                        visible: parent.valid && sh.countOn(parent.key) > 0
                        width: 3
                        height: 3
                        radius: 1.5
                        color: th.accent
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (!parent.valid)
                                return;
                            st.dateFilter = (st.dateFilter === parent.key) ? "" : parent.key;
                            host.calOpen = false;
                        }
                    }
                }
            }
        }

        Text {
            visible: st.dateFilter !== ""
            text: "Showing " + st.dateFilter + "  \u00B7  clear"
            color: th.accent
            font.family: th.font
            font.pixelSize: 10
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: st.dateFilter = ""
            }
        }
    }

    // ───────── tags ─────────
    Sheet {
        visible: host.tagsOpen
        theme: th
        heading: "Tags / projects"
        cardWidth: 280
        cardHeight: 340
        onClosed: host.tagsOpen = false

        Text {
            visible: sh.tagList.length === 0
            text: "No tags yet. Add #tag to a task."
            color: th.dim
            font.family: th.font
            font.pixelSize: 11
        }
        Repeater {
            model: sh.tagList
            delegate: Item {
                required property var modelData
                width: parent.width
                height: 30
                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "#" + modelData.tag
                    color: th.bright
                    font.family: th.font
                    font.pixelSize: 11
                }
                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.open + "/" + (modelData.open + modelData.done)
                    color: th.dim
                    font.family: th.font
                    font.pixelSize: 10
                }
                Rectangle {
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    width: parent.width * (modelData.done / Math.max(1, modelData.open + modelData.done))
                    height: 2
                    radius: 1
                    color: th.accent
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        st.tagFilter = modelData.tag;
                        host.tagsOpen = false;
                    }
                }
            }
        }
    }

    // ───────── templates ─────────
    Sheet {
        visible: host.templatesOpen
        theme: th
        heading: "Templates"
        cardWidth: 300
        cardHeight: 320
        onClosed: host.templatesOpen = false

        Text {
            visible: st.templates.length === 0
            text: "No templates. Open a task and press \"Save as template\"."
            color: th.dim
            font.family: th.font
            font.pixelSize: 11
            wrapMode: Text.Wrap
            width: parent.width
        }
        Repeater {
            model: st.templates
            delegate: Item {
                required property var modelData
                required property int index
                width: parent.width
                height: 30
                Text {
                    anchors.left: parent.left
                    anchors.right: delTpl.left
                    anchors.leftMargin: 0
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.text + (modelData.tags.length > 0 ? "  #" + modelData.tags.join(" #") : "")
                    elide: Text.ElideRight
                    color: th.bright
                    font.family: th.font
                    font.pixelSize: 11
                }
                Text {
                    id: delTpl
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "\u2715"
                    color: th.dim
                    font.family: th.font
                    font.pixelSize: 10
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -5
                        cursorShape: Qt.PointingHandCursor
                        onClicked: st.removeTemplate(parent.parent.index)
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    anchors.rightMargin: 24
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        st.addFromTemplate(parent.index, host.newQuad);
                        host.templatesOpen = false;
                    }
                }
            }
        }
    }

    // ───────── archive ─────────
    Sheet {
        visible: host.archiveOpen
        theme: th
        heading: "Archive"
        cardWidth: 310
        cardHeight: 380
        onClosed: host.archiveOpen = false

        Text {
            visible: st.archive.length === 0
            text: "Nothing archived yet. Done tasks move here after 7 days."
            color: th.dim
            font.family: th.font
            font.pixelSize: 11
            width: parent.width
            wrapMode: Text.Wrap
        }
        ListView {
            width: parent.width
            height: 286
            clip: true
            spacing: 2
            model: st.archive
            delegate: Item {
                required property int index
                readonly property int realIndex: sh.st.archive.length - 1 - index
                readonly property var task: sh.st.archive[realIndex]
                width: parent.width
                height: 34
                Text {
                    anchors.left: parent.left
                    anchors.right: rowBtns.left
                    anchors.rightMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    text: parent.task ? parent.task.text : ""
                    elide: Text.ElideRight
                    color: th.dim
                    font.family: th.font
                    font.pixelSize: 11
                }
                Row {
                    id: rowBtns
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8
                    Text {
                        text: "Restore"
                        color: th.accent
                        font.family: th.font
                        font.pixelSize: 9
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -4
                            cursorShape: Qt.PointingHandCursor
                            onClicked: sh.st.restoreArchive(parent.parent.parent.realIndex)
                        }
                    }
                    Text {
                        text: "\u2715"
                        color: th.dim
                        font.family: th.font
                        font.pixelSize: 9
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -4
                            cursorShape: Qt.PointingHandCursor
                            onClicked: sh.st.deleteArchive(parent.parent.parent.realIndex)
                        }
                    }
                }
            }
        }
        Text {
            visible: st.archive.length > 0
            text: "Clear archive"
            color: th.dim
            font.family: th.font
            font.pixelSize: 10
            MouseArea {
                anchors.fill: parent
                anchors.margins: -4
                cursorShape: Qt.PointingHandCursor
                onClicked: st.clearArchive()
            }
        }
    }

    // ───────── plan today ─────────
    property var planList: {
        var r = st.stateRev + st.tasks.length;
        return st.planCandidates().slice(0, 12);
    }
    Sheet {
        visible: host.planOpen
        theme: th
        heading: "Plan today"
        cardWidth: 300
        cardHeight: 380
        onClosed: host.planOpen = false

        Text {
            text: "Pick from End of week and No specific time."
            color: th.dim
            font.family: th.font
            font.pixelSize: 10
        }
        ListView {
            width: parent.width
            height: 280
            clip: true
            spacing: 2
            model: sh.planList
            delegate: Item {
                required property var modelData
                width: parent.width
                height: 28
                Text {
                    anchors.left: parent.left
                    anchors.right: addPlan.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.text
                    elide: Text.ElideRight
                    color: th.bright
                    font.family: th.font
                    font.pixelSize: 11
                }
                Text {
                    id: addPlan
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "\u2192 Today"
                    color: th.accent
                    font.family: th.font
                    font.pixelSize: 9
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -4
                        cursorShape: Qt.PointingHandCursor
                        onClicked: sh.st.promoteToToday(parent.parent.modelData.ord)
                    }
                }
            }
        }
        Row {
            spacing: 16
            Text {
                text: "Done planning"
                color: th.accent
                font.family: th.font
                font.pixelSize: 11
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        st.markPlanSeen();
                        host.planOpen = false;
                    }
                }
            }
        }
    }

    // ───────── command palette ─────────
    function paletteResults() {
        var q = String(host.paletteText).toLowerCase();
        var out = [];
        var arr = st.tasks;
        for (var i = 0; i < arr.length && out.length < 8; i++) {
            var t = arr[i];
            if (t.done)
                continue;
            if (q !== "" && (t.text + " " + t.tags.join(" ")).toLowerCase().indexOf(q) < 0)
                continue;
            out.push({ kind: "task", label: t.text, sub: st.quadNames[t.quad], ord: t.ord, key: "" });
        }
        var acts = sh.paletteActions;
        for (var j = 0; j < acts.length; j++) {
            if (q !== "" && acts[j].t.toLowerCase().indexOf(q) < 0)
                continue;
            out.push({ kind: "action", label: acts[j].t, sub: "action", ord: -1, key: acts[j].k });
        }
        return out;
    }

    Sheet {
        id: paletteSheet
        visible: host.paletteOpen
        theme: th
        heading: "Command palette"
        cardWidth: 320
        cardHeight: 400
        onClosed: host.paletteOpen = false
        onVisibleChanged: if (visible) Qt.callLater(palIn.forceActiveFocus)

        Rectangle {
            width: parent.width
            height: 30
            radius: 4
            color: sh.a(th.dim, 0.08)
            border.width: 1
            border.color: palIn.activeFocus ? th.accent : sh.a(th.dim, 0.2)
            TextInput {
                id: palIn
                anchors.fill: parent
                anchors.margins: 7
                verticalAlignment: TextInput.AlignVCenter
                clip: true
                color: th.bright
                selectByMouse: true
                font.family: th.font
                font.pixelSize: 12
                onTextChanged: host.paletteText = text
                onAccepted: {
                    var res = sh.paletteResults();
                    if (res.length === 0)
                        return;
                    if (res[0].kind === "task") {
                        host.selId = res[0].ord;
                        host.revealSel();
                        host.paletteOpen = false;
                    } else {
                        host.paletteOpen = false;
                        sh.runMenu(res[0].key);
                    }
                }
                Keys.onEscapePressed: host.paletteOpen = false
            }
        }

        ListView {
            id: palList
            width: parent.width
            height: 268
            clip: true
            spacing: 1
            model: {
                var r = host.paletteText + host.paletteTick + st.stateRev + st.tasks.length;
                return sh.paletteResults();
            }
            delegate: Item {
                required property var modelData
                width: parent.width
                height: 28
                Rectangle {
                    anchors.fill: parent
                    radius: 3
                    color: palHover.hovered ? sh.a(th.accent, 0.16) : "transparent"
                }
                HoverHandler { id: palHover }
                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 6
                    anchors.right: parent.right
                    anchors.rightMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.label + (modelData.kind === "action" ? "" : "   \u00B7 " + modelData.sub)
                    elide: Text.ElideRight
                    color: modelData.kind === "action" ? th.dim : th.bright
                    font.family: th.font
                    font.pixelSize: 11
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (parent.modelData.kind === "task") {
                            host.selId = parent.modelData.ord;
                            host.revealSel();
                            host.paletteOpen = false;
                        } else {
                            host.paletteOpen = false;
                            sh.runMenu(parent.modelData.key);
                        }
                    }
                }
            }
        }

        Text {
            text: "Type to filter \u00B7 Enter opens the first task"
            color: sh.a(th.dim, 0.8)
            font.family: th.font
            font.pixelSize: 9
        }
    }

    // ───────── focus mode ─────────
    Rectangle {
        visible: host.focusMode
        anchors.fill: parent
        z: 95
        color: th.cardBot

        Column {
            anchors.centerIn: parent
            spacing: 10
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: st.modes[st.modeIndex].name
                color: th.dim
                font.family: th.font
                font.pixelSize: 12
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: st.fmt(st.remaining)
                color: th.bright
                font.family: th.font
                font.pixelSize: 54
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                width: sh.width - 60
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                text: st.activeTaskText !== "" ? st.activeTaskText : "No task selected"
                color: th.accent
                font.family: th.font
                font.pixelSize: 13
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 18
                Text {
                    text: st.running ? "Pause" : "Start"
                    color: th.accent
                    font.family: th.font
                    font.pixelSize: 13
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -5
                        cursorShape: Qt.PointingHandCursor
                        onClicked: st.toggleRun()
                    }
                }
                Text {
                    text: "Reset"
                    color: th.dim
                    font.family: th.font
                    font.pixelSize: 13
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -5
                        cursorShape: Qt.PointingHandCursor
                        onClicked: st.resetTimer()
                    }
                }
                Text {
                    text: "Next"
                    color: th.dim
                    font.family: th.font
                    font.pixelSize: 13
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -5
                        cursorShape: Qt.PointingHandCursor
                        onClicked: st.nextMode()
                    }
                }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Exit focus  Esc"
                color: sh.a(th.dim, 0.8)
                font.family: th.font
                font.pixelSize: 10
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    cursorShape: Qt.PointingHandCursor
                    onClicked: host.focusMode = false
                }
            }
        }
    }
}
