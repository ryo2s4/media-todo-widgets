import QtQuick

// TaskRow.qml: one roomy, read-only task line in the selected-day column.
// The status dot only reports state; the title opens the todo panel, where
// adding, completing and rescheduling live. Tags/repeat metadata sit on the
// time line.
Item {
    id: row

    property var task
    property var store
    property double nowMs: Date.now()
    property color accent: "#90cef4"
    property color warn: "#e8a15a"
    property color bright: "#dfe3e7"
    property color dim: "#8b9297"
    property color cardBg: "#0f1417"
    property string font: "JetBrainsMono Nerd Font"

    signal openRequested()

    function a(c, v) { return Qt.rgba(c.r, c.g, c.b, v); }

    readonly property bool overdue: !!task && !task.done && task.due > 0 && task.due < nowMs
    readonly property string meta: {
        if (!task)
            return "";
        var parts = [! (task.due > 0) ? "no due"
            : store.isDateOnly(task.due) ? "all day" : store.timeLabel(task.due)];
        if (String(task.repeat || "").trim() !== "")
            parts.push("\u21BB " + task.repeat);
        if (task.tags && task.tags.length > 0) {
            var tags = [];
            for (var i = 0; i < task.tags.length; i++)
                tags.push("#" + task.tags[i]);
            parts.push(tags.join(" "));
        }
        return parts.join("  \u00B7  ");
    }

    width: parent ? parent.width : 0
    height: 34

    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: 6
        gradient: Gradient {
            GradientStop {
                position: 0.0
                color: rowHover.hovered ? row.a(row.accent, row.overdue ? 0.075 : 0.055) : "transparent"
            }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }

    Rectangle {
        visible: rowHover.hovered
        x: 1
        y: 5
        width: 2
        height: parent.height - 10
        radius: 1
        color: row.overdue ? row.warn : row.a(row.accent, 0.7)
    }

    // A status dot, not a checkbox: the calendar cannot change task state.
    Rectangle {
        visible: task && !task.done
        x: 1
        y: 10
        width: 10
        height: 10
        radius: 5
        color: "transparent"
        border.width: 1
        border.color: row.overdue ? row.a(row.warn, 0.24) : row.a(row.accent, 0.20)
    }

    Rectangle {
        x: 3
        y: 12
        width: 6
        height: 6
        radius: 3
        color: task && task.done ? accent
            : row.overdue ? warn : Qt.rgba(dim.r, dim.g, dim.b, 0.55)
        opacity: task && task.done ? 0.9 : 0.85
    }

    Text {
        x: 17
        y: 3
        width: parent.width - (rowHover.hovered ? 29 : 21)
        text: task ? task.text : ""
        color: task && task.done ? Qt.rgba(dim.r, dim.g, dim.b, 0.5) : bright
        elide: Text.ElideRight
        font.family: row.font
        font.pixelSize: 10
        font.strikeout: task && task.done
    }

    Text {
        visible: rowHover.hovered
        anchors.right: parent.right
        anchors.rightMargin: 5
        y: 4
        text: "\u2197"
        color: row.a(row.accent, 0.7)
        font.family: row.font
        font.pixelSize: 8
    }

    Text {
        x: 17
        y: 19
        width: parent.width - 21
        text: row.meta
        color: task && task.done ? Qt.rgba(dim.r, dim.g, dim.b, 0.4)
            : row.overdue ? warn : Qt.rgba(dim.r, dim.g, dim.b, 0.8)
        elide: Text.ElideRight
        font.family: row.font
        font.pixelSize: 8
    }

    HoverHandler { id: rowHover }

    MouseArea {
        x: 16
        y: 0
        width: parent.width - 16
        height: parent.height
        cursorShape: Qt.PointingHandCursor
        onClicked: row.openRequested()
    }
}
