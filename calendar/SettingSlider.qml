import QtQuick

// A compact, theme-matched slider. The parent owns the value binding and
// persists it in `onMoved`; the control itself never writes settings.
Item {
    id: slider

    property string label: ""
    property string valueText: ""
    property real from: 0
    property real to: 1
    property real step: 0.01
    property real value: 0
    property color accent: "#90cef4"
    property color dim: "#8b9297"
    property string font: "JetBrainsMono Nerd Font"
    signal moved(real value)

    implicitHeight: 40
    readonly property real ratio: Math.max(0, Math.min(1, (value - from) / Math.max(0.0001, to - from)))

    function a(c, v) { return Qt.rgba(c.r, c.g, c.b, v); }

    function setFromX(x) {
        var r = Math.max(0, Math.min(1, x / Math.max(1, track.width)));
        var v = from + r * (to - from);
        var n = Math.round(v / step) * step;
        slider.moved(Math.round(n * 1000) / 1000);
    }

    Text {
        x: 0
        y: 0
        text: slider.label
        color: slider.a(slider.dim, 0.9)
        font.family: slider.font
        font.pixelSize: 9
    }

    Text {
        anchors.right: parent.right
        y: 0
        text: slider.valueText
        color: slider.accent
        font.family: slider.font
        font.pixelSize: 9
    }

    Item {
        id: track
        x: 0
        y: 22
        width: parent.width
        height: 16

        Rectangle {
            x: 0
            y: 7
            width: parent.width
            height: 2
            radius: 1
            color: slider.a(slider.dim, 0.28)
        }

        Rectangle {
            x: 0
            y: 7
            width: slider.ratio * parent.width
            height: 2
            radius: 1
            color: slider.accent
        }

        Rectangle {
            x: Math.max(0, Math.min(parent.width - 10, slider.ratio * parent.width - 5))
            y: 2
            width: 10
            height: 10
            radius: 5
            color: slider.accent
            border.width: 1
            border.color: slider.a(slider.accent, 0.65)
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onPressed: function (mouse) { slider.setFromX(mouse.x); }
            onPositionChanged: function (mouse) {
                if (pressed)
                    slider.setFromX(mouse.x);
            }
        }
    }
}
