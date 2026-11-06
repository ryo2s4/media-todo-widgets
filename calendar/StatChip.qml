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

    implicitWidth: text.implicitWidth + 14
    implicitHeight: 19
    radius: 6
    color: "transparent"
    gradient: Gradient {
        GradientStop { position: 0.0; color: Qt.rgba(tone.r, tone.g, tone.b, hover.containsMouse ? 0.20 : 0.14) }
        GradientStop { position: 1.0; color: Qt.rgba(tone.r, tone.g, tone.b, hover.containsMouse ? 0.08 : 0.045) }
    }
    border.width: 1
    border.color: Qt.rgba(tone.r, tone.g, tone.b, hover.containsMouse ? 0.50 : 0.28)

    Behavior on border.color { ColorAnimation { duration: 130 } }

    Text {
        id: text
        anchors.centerIn: parent
        text: (chip.glyph !== "" ? chip.glyph + " " : "") + chip.label
        color: chip.textColor
        font.family: chip.family
        font.pixelSize: 9
    }

    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: chip.interactive
        enabled: chip.interactive
        cursorShape: chip.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: chip.clicked()
    }
}
