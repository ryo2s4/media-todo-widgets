import QtQuick

// SettingToggle.qml: one labelled switch row in the settings sheet.
// The whole row is clickable; the switch is a visual indicator only.
Item {
    id: row

    property string label: ""
    property string hint: ""
    property bool on: false
    property color accent: "#90cef4"
    property color bright: "#dfe3e7"
    property color dim: "#8b9297"
    property string font: "JetBrainsMono Nerd Font"
    property int duration: 120

    signal toggled()

    implicitHeight: 37

    function a(c, v) { return Qt.rgba(c.r, c.g, c.b, v); }

    Column {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - 46
        spacing: 1

        Text {
            width: parent.width
            text: row.label
            color: row.bright
            font.family: row.font
            font.pixelSize: 9
            elide: Text.ElideRight
        }
        Text {
            width: parent.width
            text: row.hint
            color: row.a(row.dim, 0.62)
            font.family: row.font
            font.pixelSize: 7
            elide: Text.ElideRight
        }
    }

    Toggle {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        on: row.on
        accent: row.accent
        dim: row.dim
        duration: row.duration
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: row.toggled()
    }
}
