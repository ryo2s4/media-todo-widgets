import QtQuick

// Row of rounded chips. model: [{ label: "Arabic", value: "ar" }, ...]
Row {
    id: ch

    property var th
    property var model: []
    property var current
    signal picked(var value)

    spacing: 6

    Repeater {
        model: ch.model
        delegate: Rectangle {
            id: chip
            required property var modelData
            readonly property bool on: ch.current === modelData.value
            width: txt.implicitWidth + 20
            height: 24
            radius: 12
            color: on ? Qt.rgba(ch.th.accent.r, ch.th.accent.g, ch.th.accent.b, 0.20) : "transparent"
            border.width: 1
            border.color: on ? ch.th.accent : Qt.rgba(ch.th.dim.r, ch.th.dim.g, ch.th.dim.b, 0.35)
            Text {
                id: txt
                anchors.centerIn: parent
                text: chip.modelData.label
                color: chip.on ? ch.th.accent : ch.th.dim
                font.family: ch.th.font
                font.pixelSize: 11
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: ch.picked(chip.modelData.value)
            }
        }
    }
}
