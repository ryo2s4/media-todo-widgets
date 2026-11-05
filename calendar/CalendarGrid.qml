import QtQuick

// CalendarGrid.qml: a compact month for the square panel.
// The full task titles live in the tasks column; each day cell shows the due
// times at a glance, with a small total when a day has more than two.
Item {
    id: grid

    property var store
    property string selectedKey: ""
    property int year: new Date().getFullYear()
    property int month: new Date().getMonth()
    property color accent: "#90cef4"
    property color bright: "#dfe3e7"
    property color dim: "#8b9297"
    property color cardBg: "#0f1417"
    property string font: "JetBrainsMono Nerd Font"
    property real cellHeight: 34

    signal dayClicked(string key)

    readonly property int firstDay: new Date(year, month, 1).getDay()
    readonly property int dayCount: new Date(year, month + 1, 0).getDate()

    implicitHeight: cellHeight * 6 + 5

    function a(c, v) { return Qt.rgba(c.r, c.g, c.b, v); }
    function keyFor(day) {
        var d = new Date(year, month, day);
        var p = function (n) { return (n < 10 ? "0" : "") + n; };
        return d.getFullYear() + "-" + p(d.getMonth() + 1) + "-" + p(d.getDate());
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
                readonly property bool isToday: valid && key === grid.store.todayKey()
                readonly property bool isSelected: valid && key === grid.selectedKey
                readonly property bool isWeekend: (index % 7) === 0 || (index % 7) === 6
                property bool hovered: false
                property var list: valid ? grid.store.tasksOn(key) : []

                width: (cells.width - 6) / 7
                height: grid.cellHeight

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 1
                    radius: 5
                    color: cell.isSelected ? grid.a(grid.accent, cell.hovered ? 0.17 : 0.11)
                        : cell.hovered ? grid.a(grid.dim, 0.07) : "transparent"
                    border.width: cell.isSelected ? 1 : 0
                    border.color: grid.a(grid.accent, 0.55)
                }

                Rectangle {
                    id: todayDot
                    visible: cell.isToday
                    x: 2
                    y: 2
                    width: 14
                    height: 14
                    radius: width / 2
                    color: grid.accent
                }

                Text {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.leftMargin: cell.isToday ? 2 : 4
                    anchors.topMargin: cell.isToday ? 2 : 2
                    width: cell.isToday ? todayDot.width : implicitWidth
                    height: cell.isToday ? todayDot.height : implicitHeight
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

                Item {
                    visible: cell.list.length > 2
                    x: cell.width - 13
                    y: 3
                    width: 10
                    height: 10

                    Rectangle {
                        anchors.fill: parent
                        radius: 3
                        color: grid.a(grid.accent, 0.14)
                    }
                    Text {
                        anchors.centerIn: parent
                        text: cell.list.length
                        color: grid.accent
                        font.family: grid.font
                        font.pixelSize: 6
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
                            readonly property bool overdue: !task.done && task.due < Date.now()
                            readonly property color tone: task.done ? grid.a(grid.dim, 0.4)
                                : overdue ? grid.accent : grid.a(grid.dim, 0.9)

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
                    onEntered: cell.hovered = true
                    onExited: cell.hovered = false
                    onClicked: if (cell.valid) grid.dayClicked(cell.key)
                }
            }
        }
    }
}
