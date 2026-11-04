import QtQuick

Rectangle {
    id: tg

    property bool on: false
    property color accent: "#e8553a"
    property color dim: "#888888"
    signal toggled()

    implicitWidth: 34
    implicitHeight: 18
    radius: 9
    color: on ? Qt.rgba(accent.r, accent.g, accent.b, 0.35) : Qt.rgba(dim.r, dim.g, dim.b, 0.25)
    border.width: 1
    border.color: on ? accent : dim

    Rectangle {
        width: 12
        height: 12
        radius: 6
        y: 3
        x: tg.on ? tg.width - width - 3 : 3
        color: tg.on ? tg.accent : tg.dim
        Behavior on x { NumberAnimation { duration: 120 } }
    }
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: tg.toggled()
    }
}
