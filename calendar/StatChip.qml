import QtQuick

// Small tinted pill for header stats. Chips with an action become clickable
// and pick up a slightly stronger border on hover; informational chips stay
// quiet.
Rectangle {
    id: chip

    property string glyph: ""
    property string label: ""
    property color tone: "#888888"
    property color textColor: tone
    property string family: "monospace"
    property bool interactive: false

    signal clicked()

    implicitWidth: text.implicitWidth + 12
    implicitHeight: 18
    radius: 5
    color: Qt.rgba(tone.r, tone.g, tone.b, hover.containsMouse ? 0.17 : 0.12)
    border.width: 1
    border.color: Qt.rgba(tone.r, tone.g, tone.b, hover.containsMouse ? 0.42 : 0.25)

    Text {
        id: text
        anchors.centerIn: parent
        text: (chip.glyph !== "" ? chip.glyph + " " : "") + chip.label
        color: chip.textColor
        font.family: chip.family
        font.pixelSize: 10
    }

    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: chip.interactive
        enabled: chip.interactive
        cursorShape: Qt.PointingHandCursor
        onClicked: chip.clicked()
    }
}
