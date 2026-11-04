import QtQuick

// One task row. `st` is the Store, `theme` the colour object and `host` the
// panel window (selection, editing, drag callbacks).
Item {
    id: row

    required property int ord
    property var st
    property var theme
    property var host
    property int quad: 0

    readonly property var src: st ? st.byId[ord] : undefined
    property var task: ({ text: "", quad: 0, done: false, ord: -1, due: 0, repeat: "", note: "", subs: [], tags: [], pomos: 0 })
    onSrcChanged: if (src) task = src
    Component.onCompleted: if (src) task = src

    readonly property bool expanded: host.expandedId === ord
    readonly property bool selected: host.selId === ord
    readonly property bool picked: host ? host.isPicked(ord) : false
    readonly property bool active: st ? st.activeTaskId === ord : false
    property bool editing: false

    readonly property int subsDone: {
        var n = 0;
        for (var i = 0; i < task.subs.length; i++)
            if (task.subs[i].d)
                n++;
        return n;
    }

    function a(c, v) { return Qt.rgba(c.r, c.g, c.b, v); }
    function tagColor(name) {
        var h = 0;
        for (var i = 0; i < name.length; i++)
            h = (h * 31 + name.charCodeAt(i)) % 360;
        return Qt.hsla(h / 360, 0.55, 0.68, 1);
    }
    function dayOn(d) {
        var r = task.repeat;
        if (r.indexOf("days:") !== 0)
            return false;
        return r.substring(5).split(",").indexOf(String(d)) >= 0;
    }
    function repeatLabel() {
        var r = task.repeat;
        if (r === "")
            return "no repeat";
        if (r === "daily" || r === "weekly")
            return r;
        return "days";
    }

    function startEdit() {
        editing = true;
        editor.text = task.text;
        editor.forceActiveFocus();
        editor.selectAll();
    }
    function endEdit(doSave, refocus) {
        if (!editing)
            return;
        editing = false;
        if (doSave)
            st.setText(ord, editor.text);
        if (host.editId === ord)
            host.editId = -1;
        if (refocus)
            host.focusKb();
    }

    Connections {
        target: row.host
        function onEditIdChanged() {
            if (row.host.editId === row.ord)
                row.startEdit();
        }
    }

    implicitHeight: head.height + (expanded ? ex.implicitHeight + 10 : 0)
    height: implicitHeight
    clip: true
    opacity: host.dragId === ord ? 0.3 : 1
    Behavior on height { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

    // ───────── the row itself ─────────
    Item {
        id: head
        width: parent.width
        height: Math.max(30, mainCol.implicitHeight + 12)

        Rectangle {
            anchors.fill: parent
            radius: row.theme.radius
            color: row.selected ? row.a(row.theme.accent, 0.10) : (row.picked ? row.a(row.theme.accent, 0.18) : (hover.hovered ? row.a(row.theme.dim, 0.14) : "transparent"))
            border.width: (row.selected || row.active) ? 1 : 0
            border.color: row.a(row.theme.accent, row.active ? 0.55 : 0.5)
            Behavior on color { ColorAnimation { duration: 120 } }
        }
        Rectangle {
            visible: row.active || row.selected || row.picked
            anchors.left: parent.left
            anchors.leftMargin: 2
            anchors.verticalCenter: parent.verticalCenter
            width: 2
            height: Math.max(12, parent.height - 12)
            radius: 1
            color: row.theme.accent
            opacity: row.active ? 1 : 0.7
        }
        HoverHandler { id: hover }
        TapHandler {
            onTapped: {
                if (row.host.selectMode)
                    row.host.toggleSelect(row.ord);
                else {
                    row.host.selId = row.ord;
                    row.host.focusKb();
                }
            }
        }
        DragHandler {
            enabled: !row.editing && !row.expanded
            target: null
            onActiveChanged: {
                if (active)
                    row.host.beginDrag(row.ord, row.task.text, centroid.scenePosition);
                else
                    row.host.endDrag();
            }
            onCentroidChanged: if (active) row.host.updateDrag(centroid.scenePosition)
        }

        // selection box (only in select mode)
        Rectangle {
            visible: row.host.selectMode
            anchors.left: parent.left
            anchors.leftMargin: 6
            anchors.top: parent.top
            anchors.topMargin: 9
            width: 12
            height: 12
            radius: 3
            color: row.picked ? row.theme.accent : "transparent"
            border.width: 1
            border.color: row.picked ? row.theme.accent : row.theme.dim
            Text {
                anchors.centerIn: parent
                visible: row.picked
                text: "\u2713"
                color: row.theme.cardBot
                font.pixelSize: 9
                font.bold: true
            }
        }

        // done circle
        Rectangle {
            id: check
            anchors.left: parent.left
            anchors.leftMargin: row.host.selectMode ? 22 : 8
            anchors.top: parent.top
            anchors.topMargin: 8
            width: 14
            height: 14
            radius: 7
            color: row.task.done ? row.theme.accent : "transparent"
            border.width: 1
            border.color: (row.task.done || row.quad === 3) ? row.theme.accent : row.theme.dim
            Behavior on color { ColorAnimation { duration: 140 } }
            Text {
                anchors.centerIn: parent
                text: "\u2713"
                color: row.theme.cardBot
                font.pixelSize: 10
                font.bold: true
                scale: row.task.done ? 1 : 0
                Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
            }
            MouseArea {
                anchors.fill: parent
                anchors.margins: -5
                cursorShape: Qt.PointingHandCursor
                onClicked: row.st.toggleDone(row.ord)
            }
        }

        // play / expand / delete
        Row {
            id: actions
            anchors.right: parent.right
            anchors.rightMargin: 4
            anchors.top: parent.top
            anchors.topMargin: 3
            visible: hover.hovered || row.selected || row.active || row.expanded

            IconBtn {
                box: 22
                size: 11
                glyph: (row.active && row.st.running) ? "\u275A\u275A" : "\u25B6"
                on: row.active
                idle: row.theme.dim
                hot: row.theme.accent
                family: row.theme.font
                onClicked: {
                    if (row.active && row.st.running)
                        row.st.toggleRun();
                    else
                        row.st.startTask(row.ord);
                }
            }
            IconBtn {
                box: 22
                size: 11
                glyph: row.expanded ? "\u25B4" : "\u25BE"
                idle: row.theme.dim
                hot: row.theme.accent
                family: row.theme.font
                onClicked: row.host.expandedId = row.expanded ? -1 : row.ord
            }
            IconBtn {
                box: 22
                size: 10
                glyph: "\u2715"
                idle: row.theme.dim
                hot: row.theme.accent
                family: row.theme.font
                onClicked: row.st.removeTask(row.ord)
            }
        }

        Column {
            id: mainCol
            anchors.left: check.right
            anchors.leftMargin: 8
            anchors.right: parent.right
            anchors.rightMargin: 74
            anchors.top: parent.top
            anchors.topMargin: 6
            spacing: 3

            Item {
                width: parent.width
                implicitHeight: row.editing ? editor.implicitHeight : label.implicitHeight
                height: implicitHeight

                Text {
                    id: label
                    width: parent.width
                    visible: !row.editing
                    text: row.task.text
                    wrapMode: Text.Wrap
                    color: row.task.done ? row.theme.dim : row.theme.bright
                    font.family: row.theme.font
                    font.pixelSize: 12
                    font.strikeout: row.task.done
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            row.host.selId = row.ord;
                            row.host.focusKb();
                        }
                        onDoubleClicked: row.host.editId = row.ord
                    }
                }

                TextInput {
                    id: editor
                    width: parent.width
                    visible: row.editing
                    wrapMode: TextInput.Wrap
                    color: row.theme.accent
                    selectByMouse: true
                    font.family: row.theme.font
                    font.pixelSize: 12
                    onAccepted: row.endEdit(true, true)
                    Keys.onEscapePressed: row.endEdit(false, true)
                    onActiveFocusChanged: if (!activeFocus) row.endEdit(true, false)
                }
            }

            // chips: due, repeat, subtasks, pomodoros, tags
            Flow {
                width: parent.width
                spacing: 8
                visible: row.task.due > 0 || row.task.repeat !== "" || row.task.subs.length > 0 || row.task.pomos > 0 || row.task.tags.length > 0 || row.task.focusMs > 0 || row.task.snooze > 0

                Text {
                    visible: row.task.due > 0
                    text: "\u25F7 " + (row.st ? row.st.fmtDue(row.task.due) : "")
                    color: (!row.task.done && row.task.due > 0 && row.task.due < Date.now()) ? row.theme.accent : row.theme.dim
                    font.family: row.theme.font
                    font.pixelSize: 10
                }
                Text {
                    visible: row.task.repeat !== ""
                    text: "\u21BB"
                    color: row.theme.dim
                    font.family: row.theme.font
                    font.pixelSize: 10
                }
                Text {
                    visible: row.task.subs.length > 0
                    text: "\u2610 " + row.subsDone + "/" + row.task.subs.length
                    color: row.theme.dim
                    font.family: row.theme.font
                    font.pixelSize: 10
                }
                Text {
                    visible: row.task.pomos > 0
                    text: "\u25CF " + row.task.pomos
                    color: row.theme.dim
                    font.family: row.theme.font
                    font.pixelSize: 10
                }
                Text {
                    visible: row.task.focusMs > 0
                    text: "\u25F7 " + (row.st ? row.st.focusText(row.task.focusMs) : "")
                    color: row.theme.dim
                    font.family: row.theme.font
                    font.pixelSize: 10
                }
                Text {
                    visible: row.task.snooze > 0
                    text: "\u23F0 " + (row.st ? row.st.fmtDue(row.task.snooze) : "")
                    color: row.theme.accent
                    font.family: row.theme.font
                    font.pixelSize: 10
                }
                Repeater {
                    model: row.task.tags
                    delegate: Rectangle {
                        id: chip
                        required property string modelData
                        width: chipLabel.implicitWidth + 10
                        height: 14
                        radius: 3
                        color: row.a(row.tagColor(modelData), 0.18)
                        Text {
                            id: chipLabel
                            anchors.centerIn: parent
                            text: "#" + chip.modelData
                            color: row.tagColor(chip.modelData)
                            font.family: row.theme.font
                            font.pixelSize: 10
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: row.st.tagFilter = chip.modelData
                        }
                    }
                }
            }

            // subtask progress
            Rectangle {
                visible: row.task.subs.length > 0
                width: parent.width
                height: 2
                radius: 1
                color: row.a(row.theme.dim, 0.15)
                Rectangle {
                    height: parent.height
                    radius: 1
                    color: row.theme.accent
                    width: row.task.subs.length > 0 ? parent.width * (row.subsDone / row.task.subs.length) : 0
                }
            }
        }
    }

    // ───────── expanded area ─────────
    Column {
        id: ex
        x: 8
        y: head.height + 4
        width: row.width - 16
        spacing: 8
        visible: row.expanded

        // due + repeat
        Row {
            spacing: 8
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Due"
                color: row.theme.dim
                font.family: row.theme.font
                font.pixelSize: 11
            }
            Rectangle {
                width: 170
                height: 24
                radius: 4
                color: row.a(row.theme.dim, 0.08)
                border.width: 1
                border.color: dueIn.activeFocus ? row.theme.accent : row.a(row.theme.dim, 0.2)
                TextInput {
                    id: dueIn
                    anchors.fill: parent
                    anchors.margins: 6
                    verticalAlignment: TextInput.AlignVCenter
                    clip: true
                    color: row.theme.bright
                    font.family: row.theme.font
                    font.pixelSize: 11
                    text: row.st ? row.st.dueEdit(row.task.due) : ""
                    onAccepted: row.host.focusKb()
                    onEditingFinished: {
                        if (!row.st.setDue(row.ord, text))
                            text = row.st.dueEdit(row.task.due);
                    }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 6
                    visible: dueIn.text === "" && !dueIn.activeFocus
                    text: "tomorrow 17:30"
                    color: row.a(row.theme.dim, 0.7)
                    font.family: row.theme.font
                    font.pixelSize: 11
                }
            }
            Rectangle {
                width: repLabel.implicitWidth + 18
                height: 24
                radius: 4
                color: row.task.repeat !== "" ? row.a(row.theme.accent, 0.18) : "transparent"
                border.width: 1
                border.color: row.task.repeat !== "" ? row.theme.accent : row.a(row.theme.dim, 0.3)
                Text {
                    id: repLabel
                    anchors.centerIn: parent
                    text: "\u21BB " + row.repeatLabel()
                    color: row.task.repeat !== "" ? row.theme.accent : row.theme.dim
                    font.family: row.theme.font
                    font.pixelSize: 11
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: row.st.cycleRepeat(row.ord)
                }
            }
        }

        // snooze reminders (5/15/60 min, tonight, tomorrow)
        Row {
            spacing: 6
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Snooze"
                color: row.theme.dim
                font.family: row.theme.font
                font.pixelSize: 11
            }
            Repeater {
                model: ["15m", "1h", "Tonight", "Tomorrow"]
                delegate: Rectangle {
                    id: snzBtn
                    required property int index
                    required property string modelData
                    width: snzLabel.implicitWidth + 12
                    height: 20
                    radius: 4
                    color: row.a(row.theme.dim, 0.08)
                    border.width: 1
                    border.color: row.a(row.theme.dim, 0.3)
                    Text {
                        id: snzLabel
                        anchors.centerIn: parent
                        text: snzBtn.modelData
                        color: row.theme.dim
                        font.family: row.theme.font
                        font.pixelSize: 10
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (snzBtn.index === 0)
                                row.st.snoozeTask(row.ord, 15);
                            else if (snzBtn.index === 1)
                                row.st.snoozeTask(row.ord, 60);
                            else if (snzBtn.index === 2)
                                row.st.snoozeTonight(row.ord);
                            else
                                row.st.snoozeTomorrow(row.ord);
                        }
                    }
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: row.task.snooze > 0
                text: "clear"
                color: row.theme.accent
                font.family: row.theme.font
                font.pixelSize: 10
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    cursorShape: Qt.PointingHandCursor
                    onClicked: row.st.clearSnooze(row.ord)
                }
            }
        }

        // weekday picker (only for "days" repeat)
        Row {
            visible: row.task.repeat.indexOf("days:") === 0
            spacing: 4
            Repeater {
                model: ["S", "M", "T", "W", "T", "F", "S"]
                delegate: Rectangle {
                    id: dayChip
                    required property int index
                    required property string modelData
                    readonly property bool on: row.dayOn(index)
                    width: 24
                    height: 22
                    radius: 4
                    color: on ? row.a(row.theme.accent, 0.25) : "transparent"
                    border.width: 1
                    border.color: on ? row.theme.accent : row.a(row.theme.dim, 0.3)
                    Text {
                        anchors.centerIn: parent
                        text: dayChip.modelData
                        color: dayChip.on ? row.theme.accent : row.theme.dim
                        font.family: row.theme.font
                        font.pixelSize: 10
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: row.st.toggleDay(row.ord, dayChip.index)
                    }
                }
            }
        }

        // note
        Rectangle {
            width: parent.width
            height: Math.max(44, noteEdit.contentHeight + 14)
            radius: 4
            color: row.a(row.theme.dim, 0.08)
            border.width: 1
            border.color: noteEdit.activeFocus ? row.theme.accent : row.a(row.theme.dim, 0.2)
            TextEdit {
                id: noteEdit
                anchors.fill: parent
                anchors.margins: 7
                wrapMode: TextEdit.Wrap
                color: row.theme.bright
                selectByMouse: true
                font.family: row.theme.font
                font.pixelSize: 11
                text: row.task.note
                onActiveFocusChanged: {
                    if (!activeFocus && text !== row.task.note)
                        row.st.setNote(row.ord, text);
                }
            }
            Text {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.margins: 7
                visible: noteEdit.text === "" && !noteEdit.activeFocus
                text: "Note"
                color: row.a(row.theme.dim, 0.7)
                font.family: row.theme.font
                font.pixelSize: 11
            }
        }

        // subtasks
        Repeater {
            model: row.task.subs
            delegate: Item {
                id: subRow
                required property int index
                required property var modelData
                width: ex.width
                height: 22

                Rectangle {
                    id: subCheck
                    x: 2
                    anchors.verticalCenter: parent.verticalCenter
                    width: 12
                    height: 12
                    radius: 6
                    color: subRow.modelData.d ? row.theme.accent : "transparent"
                    border.width: 1
                    border.color: subRow.modelData.d ? row.theme.accent : row.theme.dim
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -4
                        cursorShape: Qt.PointingHandCursor
                        onClicked: row.st.toggleSub(row.ord, subRow.index)
                    }
                }
                Text {
                    x: 22
                    width: parent.width - 48
                    anchors.verticalCenter: parent.verticalCenter
                    text: subRow.modelData.t
                    elide: Text.ElideRight
                    color: subRow.modelData.d ? row.theme.dim : row.theme.bright
                    font.family: row.theme.font
                    font.pixelSize: 11
                    font.strikeout: subRow.modelData.d
                }
                IconBtn {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    box: 20
                    size: 10
                    glyph: "\u2715"
                    idle: row.theme.dim
                    hot: row.theme.accent
                    family: row.theme.font
                    onClicked: row.st.removeSub(row.ord, subRow.index)
                }
            }
        }

        Rectangle {
            width: parent.width
            height: 24
            radius: 4
            color: row.a(row.theme.dim, 0.08)
            border.width: 1
            border.color: subIn.activeFocus ? row.theme.accent : row.a(row.theme.dim, 0.2)
            TextInput {
                id: subIn
                anchors.fill: parent
                anchors.margins: 6
                verticalAlignment: TextInput.AlignVCenter
                clip: true
                color: row.theme.bright
                font.family: row.theme.font
                font.pixelSize: 11
                onAccepted: {
                    row.st.addSub(row.ord, text);
                    text = "";
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: 6
                visible: subIn.text === "" && !subIn.activeFocus
                text: "Add subtask"
                color: row.a(row.theme.dim, 0.7)
                font.family: row.theme.font
                font.pixelSize: 11
            }
        }

        Text {
            text: "\u25CF " + row.task.pomos + " pomodoro" + (row.task.pomos === 1 ? "" : "s")
            color: row.theme.dim
            font.family: row.theme.font
            font.pixelSize: 10
        }

        Text {
            text: "\u2606 Save as template"
            color: row.theme.accent
            font.family: row.theme.font
            font.pixelSize: 10
            MouseArea {
                anchors.fill: parent
                anchors.margins: -4
                cursorShape: Qt.PointingHandCursor
                onClicked: row.st.saveTemplateFromTask(row.ord)
            }
        }
    }
}
