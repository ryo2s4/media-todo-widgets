import QtQuick
import QtQuick.Effects

// MemoryViewer.qml: full-bleed look at one memory. Editing writes straight back
// into the vault (captions, date, city, favourite) and fires `save` on change.
FocusScope {
    id: mv

    property var th
    property var sp
    property int index: -1
    property bool confirmDelete: false
    signal closed()

    visible: index >= 0
    enabled: visible
    focus: visible
    z: 80

    function a(c, v) { return Qt.rgba(c.r, c.g, c.b, v); }
    function current() {
        return (mv.index >= 0 && mv.index < mv.sp.memories.length) ? mv.sp.memories[mv.index] : null;
    }
    function step(d) {
        var n = mv.sp.memories.length;
        if (n === 0)
            return;
        mv.confirmDelete = false;
        mv.index = (mv.index + d + n) % n;
    }
    function close() {
        mv.confirmDelete = false;
        mv.index = -1;
        mv.closed();
    }
    function del() {
        if (!mv.confirmDelete) {
            mv.confirmDelete = true;
            confirmTimer.restart();
            return;
        }
        var n = mv.sp.memories.length;
        mv.sp.removeMemory(mv.index);
        if (n <= 1) {
            mv.close();
        } else {
            mv.index = Math.min(mv.index, n - 2);
            mv.confirmDelete = false;
        }
    }

    onIndexChanged: if (index >= 0) Qt.callLater(mv.forceActiveFocus)
    onVisibleChanged: if (visible) Qt.callLater(mv.forceActiveFocus)

    Keys.onPressed: function (event) {
        var k = event.key;
        if (k === Qt.Key_Escape) {
            mv.close();
        } else if (k === Qt.Key_Left) {
            mv.step(-1);
        } else if (k === Qt.Key_Right) {
            mv.step(1);
        } else if (k === Qt.Key_F) {
            if (mv.index >= 0)
                mv.sp.toggleFav(mv.index);
        } else if (k === Qt.Key_Delete) {
            if (mv.index >= 0)
                mv.del();
        } else {
            return;
        }
        event.accepted = true;
    }

    Timer {
        id: confirmTimer
        interval: 2500
        onTriggered: mv.confirmDelete = false
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0.03, 0.02, 0.02, 0.96)
    }

    // photo
    Image {
        id: photo
        anchors.top: topBar.bottom
        anchors.bottom: editor.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 10
        source: mv.current() ? mv.sp.memoryUrl(mv.current()) : ""
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        cache: false
    }

    // top bar
    Item {
        id: topBar
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 10
        height: 30

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: (mv.index + 1) + " / " + mv.sp.memories.length
            color: mv.th.dim
            font.family: mv.th.font
            font.pixelSize: 10
        }
        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10

            Text {
                text: mv.current() && mv.current().fav ? "\u2665" : "\u2661"
                color: mv.th.accent
                font.family: mv.th.font
                font.pixelSize: 16
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (mv.index >= 0) mv.sp.toggleFav(mv.index)
                }
            }
            Text {
                text: mv.confirmDelete ? "sure?" : "delete"
                color: mv.confirmDelete ? mv.th.accent : mv.a(mv.th.dim, 0.9)
                font.family: mv.th.font
                font.pixelSize: 10
                font.bold: mv.confirmDelete
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    cursorShape: Qt.PointingHandCursor
                    onClicked: mv.del()
                }
            }
            Rectangle {
                width: 52
                height: 22
                radius: 4
                color: closeMa.containsMouse ? mv.a(mv.th.accent, 0.18) : mv.a(mv.th.dim, 0.06)
                border.width: 1
                border.color: closeMa.containsMouse ? mv.th.accent : mv.a(mv.th.dim, 0.3)
                Text {
                    anchors.centerIn: parent
                    text: "close"
                    color: mv.th.bright
                    font.family: mv.th.font
                    font.pixelSize: 10
                }
                MouseArea {
                    id: closeMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: mv.close()
                }
            }
        }
    }

    // prev / next
    Repeater {
        model: [{ d: -1, g: "\u2039", side: true }, { d: 1, g: "\u203a", side: false }]
        delegate: Text {
            required property var modelData
            anchors.verticalCenter: photo.verticalCenter
            anchors.left: modelData.side ? parent.left : undefined
            anchors.right: modelData.side ? undefined : parent.right
            anchors.leftMargin: 4
            anchors.rightMargin: 4
            text: modelData.g
            color: mv.th.bright
            font.family: mv.th.font
            font.pixelSize: 30
            opacity: 0.6
            MouseArea {
                anchors.fill: parent
                anchors.margins: -8
                cursorShape: Qt.PointingHandCursor
                onClicked: mv.step(modelData.d)
            }
        }
    }

    // editor
    Column {
        id: editor
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 10
        spacing: 6

        Rectangle {
            width: parent.width
            height: 30
            radius: 5
            color: mv.a(mv.th.dim, 0.1)
            border.width: 1
            border.color: capIn.activeFocus ? mv.th.accent : mv.a(mv.th.dim, 0.25)
            TextInput {
                id: capIn
                anchors.fill: parent
                anchors.margins: 6
                verticalAlignment: TextInput.AlignVCenter
                color: mv.th.bright
                font.family: mv.th.font
                font.pixelSize: 11
                text: mv.current() ? mv.current().caption : ""
                selectByMouse: true
                onEditingFinished: if (mv.index >= 0) mv.sp.setMemory(mv.index, "caption", text)
            }
        }
        Row {
            width: parent.width
            spacing: 8
            Rectangle {
                width: (parent.width - 8) / 2
                height: 26
                radius: 5
                color: mv.a(mv.th.dim, 0.1)
                border.width: 1
                border.color: dateIn.activeFocus ? mv.th.accent : mv.a(mv.th.dim, 0.25)
                TextInput {
                    id: dateIn
                    anchors.fill: parent
                    anchors.margins: 5
                    verticalAlignment: TextInput.AlignVCenter
                    color: mv.th.bright
                    font.family: mv.th.font
                    font.pixelSize: 10
                    text: mv.current() ? mv.current().date : ""
                    selectByMouse: true
                    onEditingFinished: if (mv.index >= 0) mv.sp.setMemory(mv.index, "date", text.trim())
                }
            }
            Rectangle {
                width: (parent.width - 8) / 2
                height: 26
                radius: 5
                color: mv.a(mv.th.dim, 0.1)
                border.width: 1
                border.color: cityIn.activeFocus ? mv.th.accent : mv.a(mv.th.dim, 0.25)
                TextInput {
                    id: cityIn
                    anchors.fill: parent
                    anchors.margins: 5
                    verticalAlignment: TextInput.AlignVCenter
                    color: mv.th.bright
                    font.family: mv.th.font
                    font.pixelSize: 10
                    text: mv.current() ? mv.current().city : ""
                    selectByMouse: true
                    onEditingFinished: if (mv.index >= 0) mv.sp.setMemory(mv.index, "city", text.trim())
                }
            }
        }
        Text {
            width: parent.width
            text: "caption \u00b7 date \u00b7 city      \u2190 \u2192 move   F favourite   Del remove   Esc close"
            color: mv.a(mv.th.dim, 0.7)
            font.family: mv.th.font
            font.pixelSize: 8
        }
    }
}
