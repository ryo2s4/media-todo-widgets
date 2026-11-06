import QtQuick

// WeatherStrip.qml: one compact row under the lunar line.
Item {
    id: strip

    property var wx
    property color accent: "#90cef4"
    property color bright: "#dfe3e7"
    property color dim: "#8b9297"
    property color warn: "#e8a15a"
    property color cardBg: "#0f1417"
    property string font: "JetBrainsMono Nerd Font"

    signal clicked()

    implicitHeight: 36

    Accessible.role: Accessible.Button
    Accessible.name: "Weather details"

    function a(c, v) { return Qt.rgba(c.r, c.g, c.b, v); }

    function glyph(kind, day) {
        if (kind === "clear")
            return day ? "\uE30D" : "\uE32B";
        if (kind === "clouds")
            return day ? "\uE302" : "\uE37B";
        if (kind === "fog")
            return "\uE313";
        if (kind === "rain")
            return "\uE318";
        if (kind === "snow")
            return "\uE31A";
        if (kind === "storm")
            return "\uE31D";
        return "\uE312";
    }

    Rectangle {
        anchors.fill: parent
        radius: 8
        gradient: Gradient {
            GradientStop { position: 0.0; color: strip.a(strip.bright, 0.045) }
            GradientStop { position: 1.0; color: strip.a(strip.cardBg, 0.10) }
        }
        border.width: 1
        border.color: strip.a(strip.dim, 0.15)
    }

    Rectangle {
        anchors.left: parent.left
        anchors.leftMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        width: 26
        height: 26
        radius: 8
        color: strip.a(strip.accent, 0.09)
        border.width: 1
        border.color: strip.a(strip.accent, 0.20)

        Text {
            anchors.centerIn: parent
            text: strip.glyph(strip.wx ? strip.wx.kind : "", strip.wx ? strip.wx.isDay : true)
            color: strip.accent
            font.family: strip.font
            font.pixelSize: 16
        }
    }

    Row {
        anchors.left: parent.left
        anchors.leftMargin: 44
        anchors.verticalCenter: parent.verticalCenter
        spacing: 7

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: (strip.wx && strip.wx.ready ? Math.round(strip.wx.temp) : "--") + (strip.wx ? strip.wx.unitSym : "\u00B0C")
            color: strip.bright
            font.family: strip.font
            font.pixelSize: 17
            font.bold: true
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, 128)
            text: strip.wx && strip.wx.ready ? strip.wx.desc : (strip.wx ? strip.wx.status : "")
            color: strip.dim
            elide: Text.ElideRight
            font.family: strip.font
            font.pixelSize: 9
        }
    }

    Row {
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        spacing: 7

        Text {
            visible: strip.wx && strip.wx.advisory !== null
            anchors.verticalCenter: parent.verticalCenter
            text: "\u26A0"
            color: strip.warn
            font.family: strip.font
            font.pixelSize: 8
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: strip.wx && strip.wx.ready ? "\u2191" + Math.round(strip.wx.hi) + "  \u2193" + Math.round(strip.wx.lo) : ""
            color: strip.a(strip.dim, 0.8)
            font.family: strip.font
            font.pixelSize: 8
        }
        Rectangle {
            width: 1
            height: 14
            color: strip.a(strip.dim, 0.18)
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, 112)
            text: strip.wx && strip.wx.place !== "" ? strip.wx.place : "locating\u2026"
            color: strip.a(strip.dim, 0.7)
            elide: Text.ElideRight
            font.family: strip.font
            font.pixelSize: 8
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: strip.clicked()
    }
}
