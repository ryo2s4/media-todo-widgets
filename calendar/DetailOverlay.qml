import QtQuick

// DetailOverlay.qml: a compact, read-only card over the whole panel for the
// moon and weather strips. The dimmed backdrop closes it; Escape is handled by
// the panel's focus scope.
Item {
    id: overlay

    property string mode: ""
    property var wx
    property color accent: "#90cef4"
    property color warn: "#e8a15a"
    property color bright: "#dfe3e7"
    property color dim: "#8b9297"
    property color cardBg: "#0f1417"
    property string font: "JetBrainsMono Nerd Font"
    property bool highContrast: false

    signal closed()

    visible: mode !== ""
    z: 90

    function a(c, v) { return Qt.rgba(c.r, c.g, c.b, v); }
    function title() {
        return mode === "moon" ? "moon" : mode === "weather" ? "weather" : "";
    }
    function subtitle() {
        if (mode === "moon")
            return "phase, light, next new / full";
        if (mode === "weather")
            return "current conditions and three days";
        return "";
    }

    Rectangle {
        anchors.fill: parent
        color: overlay.a(overlay.cardBg, 0.68)

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.ArrowCursor
            onClicked: overlay.closed()
        }
    }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: Math.min(parent.width - 28, 468)
        height: Math.min(parent.height - 28, 278)
        radius: 12
        color: overlay.a(overlay.cardBg, 0.985)
        border.width: 1
        border.color: overlay.a(overlay.accent, overlay.highContrast ? 0.55 : 0.28)

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
        }

        Text {
            x: 14
            y: 10
            text: overlay.title()
            color: overlay.bright
            font.family: overlay.font
            font.pixelSize: 13
            font.bold: true
        }
        Text {
            x: 14
            y: 26
            width: card.width - 80
            text: overlay.subtitle()
            color: overlay.a(overlay.dim, 0.7)
            elide: Text.ElideRight
            font.family: overlay.font
            font.pixelSize: 8
        }

        Text {
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.top: parent.top
            anchors.topMargin: 10
            text: "\u2715"
            color: closeHover.hovered ? overlay.accent : overlay.a(overlay.dim, 0.7)
            font.family: overlay.font
            font.pixelSize: 10
            HoverHandler { id: closeHover }
            MouseArea {
                anchors.fill: parent
                anchors.margins: -5
                cursorShape: Qt.PointingHandCursor
                Accessible.name: "Close details"
                onClicked: overlay.closed()
            }
        }

        Rectangle {
            x: 14
            y: 42
            width: parent.width - 28
            height: 1
            color: overlay.a(overlay.dim, 0.16)
        }

        Item {
            id: body
            x: 14
            y: 50
            width: parent.width - 28
            height: parent.height - 60

            MoonDetail {
                visible: overlay.mode === "moon"
                anchors.fill: parent
                accent: overlay.accent
                bright: overlay.bright
                dim: overlay.dim
                cardBg: overlay.cardBg
                font: overlay.font
            }

            WeatherDetail {
                visible: overlay.mode === "weather"
                anchors.fill: parent
                wx: overlay.wx
                accent: overlay.accent
                warn: overlay.warn
                bright: overlay.bright
                dim: overlay.dim
                cardBg: overlay.cardBg
                font: overlay.font
            }
        }
    }
}
