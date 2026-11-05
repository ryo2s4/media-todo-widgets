import QtQuick
import QtQuick.Layouts

// Tray.qml: the strip under the calendar — moon, clock, weather.
Item {
    id: tray

    property var cfg
    property var wx
    property color accent
    property color bright
    property color dim
    property string font: "JetBrainsMono Nerd Font"
    property real s: 1

    implicitHeight: 104 * s

    property date now: new Date()
    function a(c, v) { return Qt.rgba(c.r, c.g, c.b, v); }

    Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: tray.now = new Date()
    }

    RowLayout {
        anchors.fill: parent
        spacing: 14

        // ── moon ──
        Row {
            Layout.preferredWidth: 172 * tray.s
            Layout.fillHeight: true
            spacing: 10

            Moon {
                id: moon
                width: 56 * tray.s
                height: 56 * tray.s
                anchors.verticalCenter: parent.verticalCenter
                litColor: tray.bright
                shadeColor: "#0d1116"
                rimColor: tray.bright
                glowColor: tray.accent
                glowStrength: 0.20
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 66 * tray.s
                spacing: 2
                Text {
                    width: parent.width
                    text: moon.phaseName
                    color: tray.bright
                    elide: Text.ElideRight
                    font.family: tray.font
                    font.pixelSize: 11 * tray.s
                }
                Text {
                    text: Math.round(moon.illumination * 100) + "% lit"
                    color: tray.accent
                    font.family: tray.font
                    font.pixelSize: 9 * tray.s
                }
                Text {
                    text: "day " + moon.lunarDay + " / 29"
                    color: tray.a(tray.dim, 0.85)
                    font.family: tray.font
                    font.pixelSize: 8 * tray.s
                }
            }
        }

        Rectangle {
            Layout.preferredWidth: 1
            Layout.preferredHeight: 58 * tray.s
            color: tray.a(tray.dim, 0.18)
        }

        // ── clock ──
        Column {
            Layout.preferredWidth: 178 * tray.s
            Layout.alignment: Qt.AlignVCenter
            spacing: 0

            Row {
                spacing: 4
                Text {
                    id: hhmm
                    text: Qt.formatTime(tray.now, "HH:mm")
                    color: tray.bright
                    font.family: tray.font
                    font.pixelSize: 32 * tray.s
                    font.bold: true
                }
                Text {
                    anchors.bottom: hhmm.bottom
                    anchors.bottomMargin: 5 * tray.s
                    text: Qt.formatTime(tray.now, "ss")
                    color: tray.accent
                    font.family: tray.font
                    font.pixelSize: 11 * tray.s
                }
            }
            Text {
                text: Qt.formatDate(tray.now, "ddd d MMM yyyy")
                color: tray.dim
                font.family: tray.font
                font.pixelSize: 9 * tray.s
            }
            Text {
                text: "week " + Qt.formatDate(tray.now, "ww")
                color: tray.a(tray.dim, 0.7)
                font.family: tray.font
                font.pixelSize: 8 * tray.s
            }
        }

        Rectangle {
            Layout.preferredWidth: 1
            Layout.preferredHeight: 58 * tray.s
            color: tray.a(tray.dim, 0.18)
        }

        // ── weather ──
        Column {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 1

            Row {
                spacing: 7
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: tray.glyph(tray.wx ? tray.wx.kind : "", tray.wx ? tray.wx.isDay : true)
                    color: tray.accent
                    font.family: tray.font
                    font.pixelSize: 19 * tray.s
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: (tray.wx && tray.wx.ready ? Math.round(tray.wx.temp) : "--") + (tray.wx ? tray.wx.unitSym : "\u00B0C")
                    color: tray.bright
                    font.family: tray.font
                    font.pixelSize: 25 * tray.s
                    font.bold: true
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: tray.wx && tray.wx.ready ? "\u2191" + Math.round(tray.wx.hi) + "  \u2193" + Math.round(tray.wx.lo) : ""
                    color: tray.a(tray.dim, 0.8)
                    font.family: tray.font
                    font.pixelSize: 8 * tray.s
                }
            }
            Text {
                width: parent.width
                text: tray.wx && tray.wx.ready ? tray.wx.desc : (tray.wx ? tray.wx.status : "")
                color: tray.dim
                elide: Text.ElideRight
                font.family: tray.font
                font.pixelSize: 9 * tray.s
            }
            Text {
                width: parent.width
                text: tray.wx && tray.wx.place !== "" ? tray.wx.place : "locating\u2026"
                color: tray.a(tray.dim, 0.7)
                elide: Text.ElideRight
                font.family: tray.font
                font.pixelSize: 8 * tray.s
            }
        }
    }

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
}
