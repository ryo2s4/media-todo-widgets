import QtQuick

// MoonLine.qml: the lunar month as a moving line.
// Nine little phase moons mark the cycle; the filled track and the larger
// marker show exactly where the current moon is in the synodic month.
Item {
    id: ml

    property color accent: "#90cef4"
    property color bright: "#dfe3e7"
    property color dim: "#8b9297"
    property color cardBg: "#0f1417"
    property string font: "JetBrainsMono Nerd Font"

    implicitHeight: 48

    readonly property real trackX: 10
    readonly property real trackW: Math.max(1, width - trackX * 2)
    readonly property real frac: Math.max(0, Math.min(1, phaseSrc.phase))

    function a(c, v) { return Qt.rgba(c.r, c.g, c.b, v); }

    // Only this instance advances with the clock; the little moons below are
    // fixed phase samples and the marker is bound to this one.
    Moon {
        id: phaseSrc
        visible: false
        width: 2
        height: 2
        pad: 0
        glowStrength: 0
        live: true
        litColor: ml.bright
        shadeColor: ml.cardBg
        rimColor: ml.bright
    }

    Text {
        x: ml.trackX
        y: 0
        text: phaseSrc.phaseName
        color: ml.bright
        font.family: ml.font
        font.pixelSize: 9
    }
    Text {
        anchors.right: parent.right
        anchors.rightMargin: ml.trackX
        y: 0
        text: Math.round(phaseSrc.illumination * 100) + "% lit \u00B7 day " + phaseSrc.lunarDay + " / 29"
        color: ml.a(ml.dim, 0.9)
        font.family: ml.font
        font.pixelSize: 7
    }

    Rectangle {
        id: track
        x: ml.trackX
        y: 24
        width: ml.trackW
        height: 1
        radius: 1
        color: ml.a(ml.dim, 0.25)
    }
    Rectangle {
        x: track.x
        y: 24
        height: 2
        radius: 1
        width: Math.max(0, marker.x + marker.width / 2 - x)
        color: ml.a(ml.accent, 0.9)
    }

    Repeater {
        model: 9
        delegate: Moon {
            required property int index
            x: ml.trackX + (index / 8) * ml.trackW - 6
            y: 18
            width: 12
            height: 12
            live: false
            phase: index / 8
            pad: 0.5
            craters: false
            glowStrength: 0
            litColor: ml.bright
            shadeColor: ml.cardBg
            rimColor: ml.a(ml.bright, 0.8)
            opacity: 0.75
        }
    }

    Moon {
        id: marker
        x: Math.max(2, Math.min(ml.width - 24, ml.trackX + ml.frac * ml.trackW - 11))
        y: 13
        width: 22
        height: 22
        live: false
        phase: phaseSrc.phase
        pad: 1
        craters: false
        glowColor: ml.accent
        glowStrength: 0.38
        litColor: ml.bright
        shadeColor: ml.cardBg
        rimColor: ml.bright
    }

    Text {
        x: ml.trackX
        y: 37
        text: "new"
        color: ml.a(ml.dim, 0.8)
        font.family: ml.font
        font.pixelSize: 7
    }
    Text {
        x: ml.trackX + ml.trackW * 0.25 - width / 2
        y: 37
        text: "first quarter"
        color: ml.a(ml.dim, 0.8)
        font.family: ml.font
        font.pixelSize: 7
    }
    Text {
        x: ml.trackX + ml.trackW * 0.5 - width / 2
        y: 37
        text: "full"
        color: ml.a(ml.dim, 0.8)
        font.family: ml.font
        font.pixelSize: 7
    }
    Text {
        x: ml.trackX + ml.trackW * 0.75 - width / 2
        y: 37
        text: "last quarter"
        color: ml.a(ml.dim, 0.8)
        font.family: ml.font
        font.pixelSize: 7
    }
    Text {
        x: ml.trackX + ml.trackW - width
        y: 37
        text: "new"
        color: ml.a(ml.dim, 0.8)
        font.family: ml.font
        font.pixelSize: 7
    }
}
