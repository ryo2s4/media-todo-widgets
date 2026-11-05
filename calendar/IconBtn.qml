import QtQuick

// A flat glyph button: dim by default, accent on hover or when `on`.
Item {
    id: ib

    property string glyph: ""
    property real size: 14
    property real box: 26
    property bool on: false
    property color idle: "#888888"
    property color hot: "#ffffff"
    property string family: "monospace"
    signal clicked()

    implicitWidth: box
    implicitHeight: box

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: (ma.containsMouse || ib.on) ? Qt.rgba(ib.hot.r, ib.hot.g, ib.hot.b, 0.12) : "transparent"
        Behavior on color { ColorAnimation { duration: 120 } }
    }
    Text {
        anchors.centerIn: parent
        text: ib.glyph
        color: (ma.containsMouse || ib.on) ? ib.hot : ib.idle
        font.family: ib.family
        font.pixelSize: ib.size
        scale: ma.pressed ? 0.86 : 1
        Behavior on scale { NumberAnimation { duration: 90 } }
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: ib.clicked()
    }
}
