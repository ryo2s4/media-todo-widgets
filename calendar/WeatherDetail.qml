import QtQuick

// WeatherDetail.qml: current conditions, a conservative local heads-up, and
// the next three days. No radar or official alert feed is involved.
Item {
    id: wd

    property var wx
    property color accent: "#90cef4"
    property color warn: "#e8a15a"
    property color bright: "#dfe3e7"
    property color dim: "#8b9297"
    property color cardBg: "#0f1417"
    property string font: "JetBrainsMono Nerd Font"

    implicitHeight: 190

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

    function hourLabel(h) {
        var hh = Math.floor(h);
        var mm = Math.round((h - hh) * 60);
        if (mm === 60) { hh += 1; mm = 0; }
        return (hh < 10 ? "0" : "") + hh + ":" + (mm < 10 ? "0" : "") + mm;
    }

    Text {
        visible: !(wd.wx && wd.wx.ready)
        anchors.centerIn: parent
        width: parent.width - 30
        horizontalAlignment: Text.AlignHCenter
        text: wd.wx ? (wd.wx.status || "weather unavailable") : "weather unavailable"
        color: wd.a(wd.dim, 0.8)
        font.family: wd.font
        font.pixelSize: 10
        wrapMode: Text.WordWrap
    }

    Item {
        id: current
        visible: wd.wx && wd.wx.ready
        width: parent.width
        height: 56

        Text {
            x: 0
            y: 0
            text: wd.glyph(wd.wx ? wd.wx.kind : "", wd.wx ? wd.wx.isDay : true)
            color: wd.accent
            font.family: wd.font
            font.pixelSize: 32
        }

        Text {
            x: 44
            y: 0
            text: Math.round(wd.wx ? wd.wx.temp : 0) + (wd.wx ? wd.wx.unitSym : "")
            color: wd.bright
            font.family: wd.font
            font.pixelSize: 26
            font.bold: true
        }

        Text {
            x: 46
            y: 34
            width: parent.width - 210
            text: wd.wx ? wd.wx.desc : ""
            color: wd.a(wd.dim, 0.9)
            elide: Text.ElideRight
            font.family: wd.font
            font.pixelSize: 9
        }

        Column {
            anchors.right: parent.right
            anchors.top: parent.top
            spacing: 2
            Text {
                anchors.right: parent.right
                text: wd.wx ? ("\u2191" + Math.round(wd.wx.hi) + "  \u2193" + Math.round(wd.wx.lo)) : ""
                color: wd.bright
                font.family: wd.font
                font.pixelSize: 9
            }
            Text {
                anchors.right: parent.right
                width: 190
                horizontalAlignment: Text.AlignRight
                text: wd.wx && wd.wx.place !== "" ? wd.wx.place : "nearby"
                color: wd.a(wd.dim, 0.75)
                elide: Text.ElideRight
                font.family: wd.font
                font.pixelSize: 8
            }
        }
    }

    Row {
        id: metrics
        visible: wd.wx && wd.wx.ready
        y: 59
        width: parent.width
        spacing: 14

        Text {
            text: "feels " + Math.round(wd.wx ? wd.wx.feels : 0) + (wd.wx ? wd.wx.unitSym : "")
            color: wd.a(wd.dim, 0.85)
            font.family: wd.font
            font.pixelSize: 8
        }
        Text {
            text: "humidity " + (wd.wx ? wd.wx.humidity : 0) + "%"
            color: wd.a(wd.dim, 0.85)
            font.family: wd.font
            font.pixelSize: 8
        }
        Text {
            text: "wind " + Math.round(wd.wx ? wd.wx.wind : 0) + " km/h"
            color: wd.a(wd.dim, 0.85)
            font.family: wd.font
            font.pixelSize: 8
        }
        Text {
            text: "sun " + wd.hourLabel(wd.wx ? wd.wx.sunrise : 0) + "\u2013" + wd.hourLabel(wd.wx ? wd.wx.sunset : 0)
            color: wd.a(wd.dim, 0.85)
            font.family: wd.font
            font.pixelSize: 8
        }
    }

    Rectangle {
        id: advisory
        visible: wd.wx && wd.wx.advisory !== null
        y: 80
        width: parent.width
        height: 24
        radius: 5
        color: wd.a(wd.warn, 0.09)
        border.width: 1
        border.color: wd.a(wd.warn, 0.25)

        Text {
            x: 7
            anchors.verticalCenter: parent.verticalCenter
            text: "\u26A0"
            color: wd.warn
            font.family: wd.font
            font.pixelSize: 9
        }
        Text {
            x: 20
            width: parent.width - 155
            anchors.verticalCenter: parent.verticalCenter
            text: wd.wx && wd.wx.advisory ? wd.wx.advisory.text : ""
            color: wd.bright
            elide: Text.ElideRight
            font.family: wd.font
            font.pixelSize: 8
        }
        Text {
            anchors.right: parent.right
            anchors.rightMargin: 7
            anchors.verticalCenter: parent.verticalCenter
            text: "local hint"
            color: wd.a(wd.warn, 0.85)
            font.family: wd.font
            font.pixelSize: 7
        }
    }

    Text {
        id: forecastLabel
        visible: wd.wx && wd.wx.ready
        y: advisory.visible ? 112 : 86
        text: "NEXT THREE DAYS"
        color: wd.a(wd.dim, 0.72)
        font.family: wd.font
        font.pixelSize: 7
        font.letterSpacing: 0.7
    }

    Row {
        visible: wd.wx && wd.wx.ready
        y: forecastLabel.y + 12
        width: parent.width
        spacing: 4

        Repeater {
            model: wd.wx && wd.wx.days ? Math.min(3, wd.wx.days.length) : 0

            delegate: Rectangle {
                required property int index
                width: (wd.width - 8) / 3
                height: 48
                radius: 5
                color: wd.a(wd.dim, 0.035)
                border.width: 1
                border.color: wd.a(wd.dim, 0.12)

                readonly property var day: wd.wx.days[index]

                Text {
                    x: 6
                    y: 5
                    text: parent.day ? parent.day.label : ""
                    color: wd.a(wd.dim, 0.85)
                    font.family: wd.font
                    font.pixelSize: 8
                }
                Text {
                    x: 6
                    y: 17
                    text: wd.glyph(parent.day ? parent.day.kind : "", true)
                    color: wd.accent
                    font.family: wd.font
                    font.pixelSize: 16
                }
                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    text: parent.day ? ("\u2191" + Math.round(parent.day.hi) + " \u2193" + Math.round(parent.day.lo)) : ""
                    color: wd.bright
                    font.family: wd.font
                    font.pixelSize: 7
                }
            }
        }
    }

    Text {
        visible: wd.wx && wd.wx.ready && wd.wx.advisory !== null
        y: 174
        text: "not an official weather alert"
        color: wd.a(wd.dim, 0.45)
        font.family: wd.font
        font.pixelSize: 7
    }
}
