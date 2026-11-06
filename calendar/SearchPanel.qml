import QtQuick

// SearchPanel.qml: a read-only search across every todo task.
// Results are grouped by due date; picking one selects that day, or opens the
// todo panel when the task has no date. Nothing here writes tasks.json.
Rectangle {
    id: panel

    property bool active: false
    property var store
    property string query: ""
    property double nowMs: Date.now()
    property color accent: "#90cef4"
    property color warn: "#e8a15a"
    property color bright: "#dfe3e7"
    property color dim: "#8b9297"
    property color cardBg: "#0f1417"
    property string font: "JetBrainsMono Nerd Font"
    property real cornerRadius: 12
    property bool highContrast: false

    signal closed()
    signal taskActivated(var task)

    readonly property var groups: store ? store.searchGroups(query) : []
    readonly property int resultCount: {
        var n = 0;
        for (var i = 0; i < groups.length; i++)
            n += groups[i].tasks.length;
        return n;
    }

    function a(c, v) { return Qt.rgba(c.r, c.g, c.b, v); }
    function focusField() { searchIn.forceActiveFocus(); }

    visible: active
    z: 60
    radius: panel.cornerRadius
    color: panel.a(panel.cardBg, 0.985)
    border.width: 1
    border.color: panel.a(panel.dim, panel.highContrast ? 0.55 : 0.28)

    onActiveChanged: {
        if (active) {
            query = "";
            searchIn.text = "";
            Qt.callLater(searchIn.forceActiveFocus);
        } else {
            query = "";
            searchIn.text = "";
        }
    }

    Item {
        id: searchHead
        x: 10
        y: 8
        width: parent.width - 20
        height: 22

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "\u2315"
            color: panel.a(panel.accent, 0.9)
            font.family: panel.font
            font.pixelSize: 13
        }

        TextInput {
            id: searchIn
            x: 19
            width: parent.width - 19 - 20
            anchors.verticalCenter: parent.verticalCenter
            height: 20
            color: panel.bright
            selectionColor: panel.a(panel.accent, 0.45)
            selectedTextColor: panel.bright
            font.family: panel.font
            font.pixelSize: 10
            clip: true
            selectByMouse: true
            focus: panel.active
            Accessible.name: "Search tasks"

            onTextChanged: {
                if (panel.query !== text)
                    panel.query = text;
            }
            Keys.onEscapePressed: function (event) {
                panel.closed();
                event.accepted = true;
            }
            Keys.onReturnPressed: function (event) {
                if (panel.groups.length > 0 && panel.groups[0].tasks.length > 0)
                    panel.taskActivated(panel.groups[0].tasks[0]);
                event.accepted = true;
            }
        }

        Text {
            visible: searchIn.text === ""
            x: 19
            anchors.verticalCenter: parent.verticalCenter
            text: "search tasks or #tag"
            color: panel.a(panel.dim, 0.55)
            font.family: panel.font
            font.pixelSize: 9
        }

        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: "\u2715"
            color: closeHover.hovered ? panel.accent : panel.a(panel.dim, 0.7)
            font.family: panel.font
            font.pixelSize: 10
            HoverHandler { id: closeHover }
            MouseArea {
                anchors.fill: parent
                anchors.margins: -5
                cursorShape: Qt.PointingHandCursor
                Accessible.name: "Close search"
                onClicked: panel.closed()
            }
        }
    }

    Text {
        id: searchMeta
        x: 10
        y: 31
        width: parent.width - 20
        text: panel.query.trim() === "" ? "type to search  \u00B7  esc closes"
            : panel.resultCount + (panel.resultCount === 1 ? " result" : " results")
                + "  \u00B7  \u21B5 opens first"
        color: panel.a(panel.dim, 0.68)
        elide: Text.ElideRight
        font.family: panel.font
        font.pixelSize: 7
    }

    Flickable {
        id: resultFlick
        x: 10
        y: 45
        width: parent.width - 20
        height: parent.height - y - 10
        contentWidth: width
        contentHeight: resultCol.height
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        Column {
            id: resultCol
            width: resultFlick.width
            spacing: 4

            Item {
                visible: panel.query.trim() === "" || panel.resultCount === 0
                width: resultCol.width
                height: 132

                Column {
                    anchors.centerIn: parent
                    spacing: 4
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: panel.query.trim() === "" ? "\u2315" : "\u263E"
                        color: panel.a(panel.accent, 0.55)
                        font.family: panel.font
                        font.pixelSize: 20
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: panel.query.trim() === "" ? "search all tasks" : "no matches"
                        color: panel.a(panel.dim, 0.78)
                        font.family: panel.font
                        font.pixelSize: 9
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: panel.query.trim() === "" ? "title, tag, or a few letters" : "try another word"
                        color: panel.a(panel.dim, 0.45)
                        font.family: panel.font
                        font.pixelSize: 7
                    }
                }
            }

            Repeater {
                model: panel.groups

                delegate: Column {
                    id: groupCol
                    required property var modelData
                    width: resultCol.width
                    spacing: 2

                    Item {
                        width: groupCol.width
                        height: 13

                        Text {
                            x: 2
                            anchors.verticalCenter: parent.verticalCenter
                            text: groupCol.modelData.title
                            color: panel.accent
                            font.family: panel.font
                            font.pixelSize: 7
                            font.bold: true
                            font.letterSpacing: 0.6
                        }
                        Text {
                            anchors.right: parent.right
                            anchors.rightMargin: 2
                            anchors.verticalCenter: parent.verticalCenter
                            text: groupCol.modelData.tasks.length
                            color: panel.a(panel.accent, 0.7)
                            font.family: panel.font
                            font.pixelSize: 7
                        }
                    }

                    Repeater {
                        model: groupCol.modelData.tasks

                        delegate: TaskRow {
                            required property var modelData
                            task: modelData
                            store: panel.store
                            nowMs: panel.nowMs
                            accent: panel.accent
                            warn: panel.warn
                            bright: panel.bright
                            dim: panel.dim
                            cardBg: panel.cardBg
                            font: panel.font
                            width: groupCol.width
                            onOpenRequested: panel.taskActivated(modelData)
                        }
                    }
                }
            }
        }
    }
}
