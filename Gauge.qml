import QtQuick

// A ring gauge. value: 0..1, text: shown in the middle, label: shown below.
Item {
    id: g

    property var th
    property real value: 0
    property string text: ""
    property string label: ""
    property color tint: "#e8553a"

    implicitWidth: 70
    implicitHeight: 86

    Canvas {
        id: cv
        width: 62
        height: 62
        anchors.horizontalCenter: parent.horizontalCenter
        property real v: Math.max(0, Math.min(1, g.value))
        property string fg: g.tint.toString()
        property string track: g.th.dim.toString()
        onVChanged: requestPaint()
        onFgChanged: requestPaint()
        onTrackChanged: requestPaint()
        Component.onCompleted: requestPaint()
        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            var cx = width / 2;
            var cy = height / 2;
            var r = width / 2 - 6;
            var a0 = 0.75 * Math.PI;
            var span = 1.5 * Math.PI;
            ctx.lineWidth = 5;
            ctx.lineCap = "round";
            ctx.globalAlpha = 0.25;
            ctx.strokeStyle = track;
            ctx.beginPath();
            ctx.arc(cx, cy, r, a0, a0 + span, false);
            ctx.stroke();
            if (v > 0.005) {
                ctx.globalAlpha = 1;
                ctx.strokeStyle = fg;
                ctx.beginPath();
                ctx.arc(cx, cy, r, a0, a0 + span * v, false);
                ctx.stroke();
            }
        }
    }

    Text {
        anchors.centerIn: cv
        text: g.text
        color: g.th.bright
        font.family: g.th.font
        font.pixelSize: 12
        font.bold: true
    }
    Text {
        anchors.top: cv.bottom
        anchors.topMargin: 2
        anchors.horizontalCenter: parent.horizontalCenter
        text: g.label
        color: g.th.dim
        font.family: g.th.font
        font.pixelSize: 10
    }
}
