import QtQuick

// Small tinted pill for header stats.
Rectangle {
    id: chip

    property string glyph: ""
    property string label: ""
    property color tone: "#888888"
    property color textColor: tone
    property string family: "monospace"

    implicitWidth: text.implicitWidth + 12
    implicitHeight: 18
    radius: 5
    color: Qt.rgba(tone.r, tone.g, tone.b, 0.12)
    border.width: 1
    border.color: Qt.rgba(tone.r, tone.g, tone.b, 0.25)

    Text {
        id: text
        anchors.centerIn: parent
        text: (chip.glyph !== "" ? chip.glyph + " " : "") + chip.label
        color: chip.textColor
        font.family: chip.family
        font.pixelSize: 10
    }
}
