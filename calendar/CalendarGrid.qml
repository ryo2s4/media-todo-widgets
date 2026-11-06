import QtQuick

// CalendarGrid.qml: a compact month for the square panel.
// Each day carries a task count and a done/overdue tone. Hovering a day opens
// a small read-only detail card with its progress and next few tasks.
Item {
    id: grid

    property var store
    property string selectedKey: ""
    property int year: new Date().getFullYear()
    property int month: new Date().getMonth()
    property double nowMs: Date.now()
    property color accent: "#90cef4"
    property color warn: "#e8a15a"
    property color bright: "#dfe3e7"
    property color dim: "#8b9297"
    property color cardBg: "#0f1417"
    property string font: "JetBrainsMono Nerd Font"
    property real cellHeight: 34
    property bool weekStartsMonday: false
    property real aura: 0.7
    property bool highContrast: false

    signal dayClicked(string key)

    readonly property int firstDay: {
        var d = new Date(year, month, 1).getDay();
        return weekStartsMonday ? (d + 6) % 7 : d;
    }
    readonly property int dayCount: new Date(year, month + 1, 0).getDate()
    readonly property real cellWidth: (width - 6) / 7
    readonly property real tipWidth: Math.min(176, width - 8)

    // Hover is delayed a touch so sweeping across the month doesn't flash a
    // card for every cell.
    property int previewIndex: -1
    property int shownIndex: -1
    readonly property string shownKey: shownIndex >= 0 ? keyFor(shownIndex - firstDay + 1) : ""
    readonly property var shownList: shownKey !== "" ? store.tasksOn(shownKey) : []
    readonly property var shownStats: shownKey !== "" ? store.statsOn(shownKey) : null

    implicitHeight: cellHeight * 6 + 5

    function a(c, v) { return Qt.rgba(c.r, c.g, c.b, v); }
    function keyFor(day) {
        var d = new Date(year, month, day);
        var p = function (n) { return (n < 10 ? "0" : "") + n; };
        return d.getFullYear() + "-" + p(d.getMonth() + 1) + "-" + p(d.getDate());
    }
    function summary(stats) {
        if (!stats)
            return "";
        var bits = [];
        if (stats.done > 0)
            bits.push(stats.done + " done");
        var open = stats.open - stats.overdue;
        if (open > 0)
            bits.push(open + " open");
        if (stats.overdue > 0)
            bits.push(stats.overdue + " overdue");
        return bits.join("  \u00B7  ");
    }

    onYearChanged: { previewIndex = -1; shownIndex = -1; }
    onMonthChanged: { previewIndex = -1; shownIndex = -1; }
    onPreviewIndexChanged: shownIndex = -1

    Timer {
        id: hoverTimer
        interval: 220
        onTriggered: grid.shownIndex = grid.previewIndex
    }

    Grid {
        id: cells
        anchors.fill: parent
        columns: 7
        spacing: 1

        Repeater {
            model: 42
            delegate: Item {
                id: cell
                required property int index

                readonly property int dayNum: index - grid.firstDay + 1
                readonly property bool valid: dayNum >= 1 && dayNum <= grid.dayCount
                readonly property string key: valid ? grid.keyFor(dayNum) : ""
                readonly property bool isToday: valid && key === grid.store.todayKey() && grid.nowMs > 0
                readonly property bool isSelected: valid && key === grid.selectedKey
                readonly property bool isWeekend: grid.weekStartsMonday
                    ? (index % 7) >= 5 : (index % 7) === 0 || (index % 7) === 6
                readonly property var stats: valid ? grid.store.statsOn(key) : null
                readonly property int count: stats ? stats.total : 0
                readonly property bool anyOverdue: stats ? stats.overdue > 0 : false
                readonly property bool allDone: stats ? stats.allDone : false
                property bool hovered: false
                property var list: valid ? grid.store.tasksOn(key) : []

                width: (cells.width - 6) / 7
                height: grid.cellHeight

                Rectangle {
                    visible: cell.isSelected
                    anchors.fill: parent
                    anchors.margins: -1
                    radius: 7
                    color: "transparent"
                    border.width: grid.highContrast ? 2 : 1
                    border.color: grid.a(grid.accent, 0.13 + grid.aura * 0.13)
                }

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 1
                    radius: 6
                    color: cell.isSelected ? grid.a(grid.accent, cell.hovered ? 0.18 : 0.105)
                        : cell.hovered ? grid.a(grid.dim, 0.075) : "transparent"
                    border.width: cell.isSelected ? 1 : 0
                    border.color: cell.anyOverdue ? grid.a(grid.warn, 0.60) : grid.a(grid.accent, 0.48 + grid.aura * 0.14)
                }

                Rectangle {
                    visible: cell.isToday
                    anchors.fill: todayDot
                    anchors.margins: -2
                    radius: width / 2
                    color: "transparent"
                    border.width: 1
                    border.color: grid.a(grid.accent, 0.24 + grid.aura * 0.22)
                }

                Rectangle {
                    id: todayDot
                    visible: cell.isToday
                    x: 2
                    y: 2
                    width: 14
                    height: 14
                    radius: width / 2
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: grid.accent }
                        GradientStop { position: 1.0; color: grid.a(grid.accent, 0.62) }
                    }
                }

                Text {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.leftMargin: cell.isToday ? 2 : 4
                    anchors.topMargin: 2
                    width: cell.isToday ? 14 : Math.max(0, cell.width - 8)
                    height: 14
                    horizontalAlignment: cell.isToday ? Text.AlignHCenter : Text.AlignLeft
                    verticalAlignment: cell.isToday ? Text.AlignVCenter : Text.AlignTop
                    text: cell.valid ? cell.dayNum : ""
                    color: !cell.valid ? "transparent"
                        : cell.isToday ? grid.cardBg
                        : cell.isSelected ? grid.bright
                        : cell.isWeekend ? grid.a(grid.dim, 0.85) : grid.bright
                    font.family: grid.font
                    font.pixelSize: 9
                    font.bold: cell.isToday || cell.isSelected
                }

                // The count is always present for a busy day, not just when the
                // two-line preview overflows. Its tone is the day's state:
                // warm for overdue, quiet for all-done, accent for open work.
                Rectangle {
                    id: countBadge
                    visible: cell.valid && cell.count > 0
                    x: cell.width - width - 2
                    y: 2
                    width: Math.max(11, countText.implicitWidth + 5)
                    height: 11
                    radius: 3
                    color: cell.anyOverdue ? grid.a(grid.warn, 0.20)
                        : cell.allDone ? grid.a(grid.dim, 0.10) : grid.a(grid.accent, 0.15)
                    border.width: cell.anyOverdue ? 1 : 0
                    border.color: grid.a(grid.warn, 0.5)

                    Text {
                        id: countText
                        anchors.centerIn: parent
                        text: cell.count
                        color: cell.anyOverdue ? grid.warn
                            : cell.allDone ? grid.a(grid.dim, 0.65) : grid.accent
                        font.family: grid.font
                        font.pixelSize: 7
                        font.bold: true
                    }
                }

                Column {
                    x: 4
                    y: 14
                    width: cell.width - 7
                    spacing: 1

                    Repeater {
                        model: Math.min(2, cell.list.length)
                        delegate: Item {
                            id: taskLine
                            required property int index
                            readonly property var task: cell.list[index]
                            readonly property bool timed: !grid.store.isDateOnly(task.due)
                            readonly property bool overdue: !task.done && task.due > 0 && task.due < grid.nowMs
                            readonly property color tone: task.done ? grid.a(grid.dim, 0.4)
                                : overdue ? grid.warn : grid.a(grid.dim, 0.9)

                            width: parent.width
                            height: 8

                            Rectangle {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                width: taskLine.timed ? 2 : 5
                                height: taskLine.timed ? 5 : 2
                                radius: 1
                                color: taskLine.tone
                            }
                            Text {
                                x: 5
                                width: parent.width - 5
                                anchors.verticalCenter: parent.verticalCenter
                                text: taskLine.timed ? grid.store.timeLabel(taskLine.task.due) : "all"
                                color: taskLine.tone
                                elide: Text.ElideRight
                                font.family: grid.font
                                font.pixelSize: 7
                                font.strikeout: taskLine.task.done
                            }
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: {
                        cell.hovered = true;
                        if (cell.valid && cell.count > 0) {
                            grid.previewIndex = cell.index;
                            hoverTimer.restart();
                        }
                    }
                    onExited: {
                        cell.hovered = false;
                        if (grid.previewIndex === cell.index) {
                            hoverTimer.stop();
                            grid.previewIndex = -1;
                            grid.shownIndex = -1;
                        }
                    }
                    onClicked: {
                        grid.shownIndex = -1;
                        if (cell.valid)
                            grid.dayClicked(cell.key);
                    }
                }
            }
        }
    }

    // Hover detail: a compact, read-only card over the grid. It has no pointer
    // handlers, so the cell underneath keeps the hover and the card cannot
    // flicker by stealing its own trigger.
    Rectangle {
        id: tip
        z: 100
        visible: grid.shownIndex >= 0 && grid.shownStats !== null && grid.shownStats.total > 0
        x: {
            if (grid.shownIndex < 0)
                return 0;
            var col = grid.shownIndex % 7;
            var rx = col * (grid.cellWidth + 1) + (grid.cellWidth - width) / 2;
            return Math.max(3, Math.min(grid.width - width - 3, rx));
        }
        y: {
            if (grid.shownIndex < 0)
                return 0;
            var row = Math.floor(grid.shownIndex / 7);
            var top = row * (grid.cellHeight + 1);
            var below = top + grid.cellHeight + 4;
            if (below + height <= grid.height - 2)
                return below;
            return Math.max(3, top - height - 4);
        }
        width: grid.tipWidth
        height: tipCol.implicitHeight + 14
        radius: 7
        color: grid.cardBg
        border.width: 1
        border.color: grid.a(grid.accent, 0.45)

        Column {
            id: tipCol
            x: 8
            y: 6
            width: parent.width - 16
            spacing: 3

            Row {
                width: parent.width
                Text {
                    width: parent.width - countLabel.width
                    text: grid.shownKey !== "" ? grid.store.dayTitle(grid.shownKey) : ""
                    color: grid.bright
                    elide: Text.ElideRight
                    font.family: grid.font
                    font.pixelSize: 9
                    font.bold: true
                }
                Text {
                    id: countLabel
                    text: grid.shownStats ? grid.shownStats.total : 0
                    color: grid.shownStats && grid.shownStats.overdue > 0 ? grid.warn : grid.accent
                    font.family: grid.font
                    font.pixelSize: 8
                    font.bold: true
                }
            }

            Text {
                width: parent.width
                text: grid.summary(grid.shownStats)
                color: grid.a(grid.dim, 0.9)
                elide: Text.ElideRight
                font.family: grid.font
                font.pixelSize: 7
            }

            Rectangle {
                width: parent.width
                height: 3
                radius: 1
                color: grid.a(grid.dim, 0.16)
                Rectangle {
                    width: parent.width * (grid.shownStats ? grid.shownStats.ratio : 0)
                    height: parent.height
                    radius: 1
                    color: grid.shownStats && grid.shownStats.overdue > 0 ? grid.warn : grid.accent
                }
            }

            Repeater {
                model: Math.min(4, grid.shownList.length)
                delegate: Item {
                    required property int index
                    readonly property var task: grid.shownList[index]
                    readonly property bool overdue: !task.done && task.due > 0 && task.due < grid.nowMs
                    width: tipCol.width
                    height: 11

                    Text {
                        x: 0
                        anchors.verticalCenter: parent.verticalCenter
                        text: task.done ? "\u2713" : overdue ? "!" : "\u00B7"
                        color: task.done ? grid.a(grid.dim, 0.5) : overdue ? grid.warn : grid.a(grid.dim, 0.8)
                        font.family: grid.font
                        font.pixelSize: 7
                        font.bold: overdue
                    }
                    Text {
                        x: 10
                        width: parent.width - 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: (grid.store.isDateOnly(task.due) ? "all day" : grid.store.timeLabel(task.due))
                            + "  " + task.text
                        color: task.done ? grid.a(grid.dim, 0.5) : grid.bright
                        elide: Text.ElideRight
                        font.family: grid.font
                        font.pixelSize: 7
                        font.strikeout: task.done
                    }
                }
            }

            Text {
                visible: grid.shownList.length > 4
                width: parent.width
                text: "+" + (grid.shownList.length - 4) + " more"
                color: grid.a(grid.dim, 0.6)
                font.family: grid.font
                font.pixelSize: 6
            }
        }
    }
}
