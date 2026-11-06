import QtQuick

// A small pill switch used by Settings. `duration: 0` keeps it still when the
// panel is in reduced-motion mode.
Rectangle {
    id: tg

    property bool on: false
    property color accent: "#90cef4"
    property color dim: "#8b9297"
    property int duration: 120
    signal toggled()

    implicitWidth: 34
    implicitHeight: 18
    radius: 9
    color: on ? Qt.rgba(accent.r, accent.g, accent.b, 0.28) : Qt.rgba(dim.r, dim.g, dim.b, 0.18)
    border.width: 1
    border.color: on ? accent : Qt.rgba(dim.r, dim.g, dim.b, 0.55)

    Rectangle {
        width: 12
        height: 12
        radius: 6
        y: 3
        x: tg.on ? tg.width - width - 3 : 3
        color: tg.on ? tg.accent : tg.dim
        Behavior on x { NumberAnimation { duration: tg.duration } }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: tg.toggled()
    }
}
