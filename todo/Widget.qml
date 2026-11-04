pragma ComponentBehavior: Bound
import QtQuick
import Ryoku.PluginKit.Singletons

// Bar glyph: while a timer runs it shows the countdown (and the task name),
// otherwise the number of pending Urgent tasks. Click opens the todo board.
Item {
    id: root

    property var pluginApi
    property var screen
    property bool active: false
    property string density: "glyph"
    property real s: 1
    property real widthBudget: 0
    property bool open: false
    property real reveal: 0
    property bool tabActive: false
    signal requestClose()

    readonly property var service: pluginApi ? pluginApi.mainInstance : null
    readonly property bool showTask: (service && service.settings && service.settings.showTask !== undefined) ? service.settings.showTask : true
    readonly property bool showGoal: (service && service.settings && service.settings.showGoal !== undefined) ? service.settings.showGoal : true
    readonly property bool hot: service ? (service.running || service.urgent > 0) : false
    readonly property string label: {
        if (!service || !service.available)
            return "";
        if (service.running) {
            var t = service.fmt(service.remaining);
            if (showTask && service.task !== "")
                t += "  " + service.task;
            return t;
        }
        if (service.urgent > 0)
            return String(service.urgent);
        return showGoal ? (service.doneToday + "/" + service.goal) : "";
    }

    implicitWidth: row.implicitWidth
    implicitHeight: Math.max(row.implicitHeight, 18 * root.s)

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6 * root.s

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: (root.service && root.service.running) ? "\u25B6" : "\u25C6"
            color: root.hot ? Theme.accent : Theme.dim
            font.family: Theme.mono
            font.pixelSize: 13 * root.s
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.label !== ""
            text: root.label
            color: (root.service && root.service.urgent > 0 && !root.service.running) ? Theme.accent : Theme.bright
            font.family: Theme.font
            font.pixelSize: 13 * root.s
            elide: Text.ElideRight
            width: root.widthBudget > 0 ? Math.min(implicitWidth, root.widthBudget) : implicitWidth
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: if (root.service) root.service.toggleBoard()
    }
}
