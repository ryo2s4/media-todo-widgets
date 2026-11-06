import QtQuick

// MoonDetail.qml: the small moon card's detail view.
// Deliberately limited to the phase, illumination and the next new/full dates;
// rise/set and other ephemeris data stay out of the V1 calendar.
Item {
    id: md

    property color accent: "#90cef4"
    property color bright: "#dfe3e7"
    property color dim: "#8b9297"
    property color cardBg: "#0f1417"
    property string font: "JetBrainsMono Nerd Font"

    implicitHeight: 164

    function a(c, v) { return Qt.rgba(c.r, c.g, c.b, v); }

    Moon {
        id: moon
        x: 2
        y: 6
        width: 88
        height: 88
        live: true
        pad: 3
        craters: true
        glowStrength: 0.20
        litColor: md.bright
        shadeColor: md.cardBg
        rimColor: md.bright
        glowColor: md.accent
    }

    Column {
        x: 108
        y: 0
        width: parent.width - x
        spacing: 2

        Text {
            text: moon.phaseName
            color: md.bright
            font.family: md.font
            font.pixelSize: 17
            font.bold: true
            elide: Text.ElideRight
            width: parent.width
        }

        Text {
            text: Math.round(moon.illumination * 100) + "% illuminated"
            color: md.accent
            font.family: md.font
            font.pixelSize: 9
        }

        Item { width: 1; height: 7 }

        Text {
            text: "NEXT NEW"
            color: md.a(md.dim, 0.78)
            font.family: md.font
            font.pixelSize: 7
            font.letterSpacing: 0.7
        }
        Text {
            text: Qt.formatDate(moon.nextNew, "ddd d MMM")
            color: md.bright
            font.family: md.font
            font.pixelSize: 10
        }

        Item { width: 1; height: 3 }

        Text {
            text: "NEXT FULL"
            color: md.a(md.dim, 0.78)
            font.family: md.font
            font.pixelSize: 7
            font.letterSpacing: 0.7
        }
        Text {
            text: Qt.formatDate(moon.nextFull, "ddd d MMM")
            color: md.bright
            font.family: md.font
            font.pixelSize: 10
        }
    }

    Text {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        text: "phase and illumination are approximate"
        color: md.a(md.dim, 0.42)
        font.family: md.font
        font.pixelSize: 7
    }
}
