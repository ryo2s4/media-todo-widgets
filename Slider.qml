import QtQuick

// Horizontal slider. value, from and to are numbers; `moved(value)` fires while dragging.
Item {
    id: sl

    property var th
    property real from: 0
    property real to: 1
    property real value: 0
    property bool enabled: true
    signal moved(real value)

    implicitWidth: 160
    implicitHeight: 22

    readonly property real frac: to > from ? Math.max(0, Math.min(1, (value - from) / (to - from))) : 0

    Rectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 4
        radius: 2
        color: Qt.rgba(sl.th.dim.r, sl.th.dim.g, sl.th.dim.b, 0.3)

        Rectangle {
            height: parent.height
            radius: 2
            width: parent.width * sl.frac
            color: sl.enabled ? sl.th.accent : sl.th.dim
        }
        Rectangle {
            x: parent.width * sl.frac - width / 2
            anchors.verticalCenter: parent.verticalCenter
            width: area.pressed ? 14 : 11
            height: width
            radius: width / 2
            color: sl.enabled ? sl.th.bright : sl.th.dim
            border.width: 2
            border.color: sl.enabled ? sl.th.accent : sl.th.dim
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        enabled: sl.enabled
        preventStealing: true
        cursorShape: Qt.PointingHandCursor
        function set(mx) {
            var f = Math.max(0, Math.min(1, mx / width));
            sl.moved(sl.from + f * (sl.to - sl.from));
        }
        onPressed: function (mouse) { set(mouse.x); }
        onPositionChanged: function (mouse) { if (pressed) set(mouse.x); }
    }
}
