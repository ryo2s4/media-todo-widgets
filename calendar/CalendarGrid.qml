import QtQuick

// CalendarGrid.qml: one month, seven columns, tasks written inside the days.
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
    property real cellHeight: 62
    property real s: 1

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
                    radius: 6 * grid.s
                    color: cell.isSelected ? grid.a(grid.accent, cell.hovered ? 0.16 : 0.10)
                        : cell.hovered ? grid.a(grid.dim, 0.07) : "transparent"
                    border.width: cell.isSelected ? 1 : 0
                    border.color: grid.a(grid.accent, 0.55)
                }

                Rectangle {
                    id: todayDot
                    visible: cell.isToday
                    x: 3 * grid.s
                    y: 3 * grid.s
                    width: 18 * grid.s
                    height: 18 * grid.s
                    radius: width / 2
                    color: grid.accent
                }

                Text {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.leftMargin: cell.isToday ? 3 * grid.s : 5 * grid.s
                    anchors.topMargin: 3 * grid.s
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
                    font.pixelSize: 11 * grid.s
                    font.bold: cell.isToday || cell.isSelected
                }

                Column {
                    x: 4 * grid.s
                    y: 22 * grid.s
                    width: cell.width - 7 * grid.s
                    spacing: 1

                    Repeater {
                        model: Math.min(2, cell.list.length)
                        delegate: Item {
                            id: taskLine
                            required property int index
                            readonly property var task: cell.list[index]
                            readonly property bool timed: !grid.store.isDateOnly(task.due)
                            readonly property bool overdue: !task.done && task.due < Date.now()

                            width: parent.width
                            height: 11 * grid.s

                            Rectangle {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                width: 2 * grid.s
                                height: 8 * grid.s
                                radius: 1
                                color: taskLine.task.done ? grid.a(grid.dim, 0.35)
                                    : taskLine.overdue ? grid.accent : grid.a(grid.accent, 0.8)
                            }
                            Text {
                                visible: taskLine.timed
                                x: 5 * grid.s
                                anchors.verticalCenter: parent.verticalCenter
                                width: 23 * grid.s
                                text: taskLine.timed ? grid.store.timeLabel(taskLine.task.due) : ""
                                color: taskLine.overdue ? grid.accent : grid.a(grid.dim, 0.9)
                                font.family: grid.font
                                font.pixelSize: 7 * grid.s
                            }
                            Text {
                                x: taskLine.timed ? 29 * grid.s : 6 * grid.s
                                width: parent.width - (taskLine.timed ? 30 * grid.s : 7 * grid.s)
                                anchors.verticalCenter: parent.verticalCenter
                                text: taskLine.task.text
                                color: taskLine.task.done ? grid.a(grid.dim, 0.55) : grid.bright
                                elide: Text.ElideRight
                                font.family: grid.font
                                font.pixelSize: 8 * grid.s
                                font.strikeout: taskLine.task.done
                            }
                        }
                    }
                }

                Text {
                    visible: cell.list.length > 2
                    x: 5 * grid.s
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 3 * grid.s
                    text: "+" + (cell.list.length - 2) + " more"
                    color: grid.a(grid.dim, 0.8)
                    font.family: grid.font
                    font.pixelSize: 7 * grid.s
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
