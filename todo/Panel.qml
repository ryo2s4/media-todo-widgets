import QtQuick
import Ryoku.PluginKit.Singletons

// Tiny summary panel. The main way to use this plugin is clicking the glyph,
// which opens the todo board directly.
Item {
    id: root

    property var pluginApi
    property string density: "full"
    property real s: 1
    property real widthBudget: 280
    property bool active: false

    readonly property var service: pluginApi ? pluginApi.mainInstance : null

    implicitWidth: widthBudget
    implicitHeight: col.implicitHeight + 28 * s

    Column {
        id: col
        x: 14 * root.s
        y: 14 * root.s
        width: root.width - 28 * root.s
        spacing: 8 * root.s

        Text {
            text: "Todo"
            color: Theme.bright
            font.family: Theme.display
            font.pixelSize: 15 * root.s
        }
        Text {
            text: root.service && root.service.available ? (root.service.urgent + " urgent \u00B7 " + root.service.pending + " pending") : "Start the board: qs -c todo"
            color: Theme.dim
            font.family: Theme.font
            font.pixelSize: 12 * root.s
        }
        Text {
            visible: root.service && root.service.available
            text: root.service ? ("Today " + root.service.doneToday + "/" + root.service.goal + (root.service.streak > 0 ? "  \u25C6 " + root.service.streak + "d" : "")) : ""
            color: Theme.dim
            font.family: Theme.font
            font.pixelSize: 12 * root.s
        }
        Rectangle {
            visible: root.service && root.service.available && root.service.goal > 0
            width: parent.width
            height: 3 * root.s
            radius: 1.5 * root.s
            color: Qt.rgba(Theme.dim.r, Theme.dim.g, Theme.dim.b, 0.2)
            Rectangle {
                width: parent.width * (root.service ? Math.min(1, root.service.doneToday / Math.max(1, root.service.goal)) : 0)
                height: parent.height
                radius: parent.radius
                color: Theme.accent
            }
        }
        Text {
            visible: root.service && root.service.available && root.service.running
            text: root.service ? (root.service.mode + "  " + root.service.fmt(root.service.remaining)) : ""
            color: Theme.dim
            font.family: Theme.font
            font.pixelSize: 12 * root.s
        }
        Text {
            visible: root.service && root.service.running && root.service.task !== ""
            width: parent.width
            elide: Text.ElideRight
            text: root.service ? ("\u25B6 " + root.service.task) : ""
            color: Theme.accent
            font.family: Theme.font
            font.pixelSize: 12 * root.s
        }
        Text {
            text: "Open board"
            color: openArea.containsMouse ? Theme.accent : Theme.bright
            font.family: Theme.font
            font.pixelSize: 12 * root.s
            font.bold: true
            MouseArea {
                id: openArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: if (root.service) root.service.toggleBoard()
            }
        }
    }
}
