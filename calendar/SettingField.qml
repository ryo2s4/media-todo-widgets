import QtQuick

// A labelled single-line field for Settings.
Item {
    id: field

    property string label: ""
    property string placeholder: ""
    property alias text: input.text
    property alias cursorPosition: input.cursorPosition
    property color accent: "#90cef4"
    property color bright: "#dfe3e7"
    property color dim: "#8b9297"
    property string font: "JetBrainsMono Nerd Font"
    signal committed(string value)

    implicitHeight: 46

    function a(c, v) { return Qt.rgba(c.r, c.g, c.b, v); }

    Text {
        x: 0
        y: 0
        text: field.label
        color: field.a(field.dim, 0.9)
        font.family: field.font
        font.pixelSize: 9
    }

    Rectangle {
        x: 0
        y: 16
        width: parent.width
        height: 30
        radius: 5
        color: field.a(field.dim, 0.06)
        border.width: 1
        border.color: input.activeFocus ? field.accent : field.a(field.dim, 0.22)

        TextInput {
            id: input
            anchors.fill: parent
            anchors.margins: 8
            verticalAlignment: TextInput.AlignVCenter
            color: field.bright
            selectionColor: field.a(field.accent, 0.45)
            selectedTextColor: field.bright
            font.family: field.font
            font.pixelSize: 10
            clip: true
            onEditingFinished: field.committed(input.text)
        }

        Text {
            x: 9
            width: parent.width - 18
            anchors.verticalCenter: parent.verticalCenter
            visible: input.text === ""
            text: field.placeholder
            color: field.a(field.dim, 0.55)
            elide: Text.ElideRight
            font.family: field.font
            font.pixelSize: 10
        }
    }
}
