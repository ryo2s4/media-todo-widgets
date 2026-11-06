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
    property int duration: 120
    signal clicked()

    implicitWidth: box
    implicitHeight: box

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: (ma.containsMouse || ib.on) ? Qt.rgba(ib.hot.r, ib.hot.g, ib.hot.b, 0.12) : "transparent"
        Behavior on color { ColorAnimation { duration: ib.duration } }
    }
    Text {
        anchors.centerIn: parent
        text: ib.glyph
        color: (ma.containsMouse || ib.on) ? ib.hot : ib.idle
        font.family: ib.family
        font.pixelSize: ib.size
        scale: ma.pressed ? 0.86 : 1
        Behavior on scale { NumberAnimation { duration: Math.round(ib.duration * 0.65) } }
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: ib.clicked()
    }
}
