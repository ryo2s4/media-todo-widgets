import QtQuick

// MonthPicker.qml: a compact month/year chooser that overlays the month card.
// It keeps the square layout intact instead of pushing a second card into the
// body. Counts are read from the same Store as the grid.
Item {
    id: picker

    property int year: new Date().getFullYear()
    property int month: new Date().getMonth()
    property int todayYear: new Date().getFullYear()
    property int todayMonth: new Date().getMonth()
    property var store
    property color accent: "#90cef4"
    property color warn: "#e8a15a"
    property color bright: "#dfe3e7"
    property color dim: "#8b9297"
    property color cardBg: "#0f1417"
    property string font: "JetBrainsMono Nerd Font"
    property int motionFast: 100

    signal picked(int year, int month)
    signal todayClicked()
    signal closed()

    visible: false
    z: 50

    property int shownYear: year

    function a(c, v) { return Qt.rgba(c.r, c.g, c.b, v); }

    onVisibleChanged: {
        if (visible)
            shownYear = year;
    }
    onYearChanged: {
        if (visible && shownYear !== year)
            shownYear = year;
    }

    Rectangle {
        anchors.fill: parent
        color: picker.a(picker.cardBg, 0.90)

        MouseArea {
            anchors.fill: parent
            onClicked: picker.closed()
        }
    }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: Math.min(parent.width - 16, 272)
        height: Math.min(parent.height - 16, 194)
        radius: 8
        color: picker.cardBg
        border.width: 1
        border.color: picker.a(picker.accent, 0.38)

        // Swallow blank-card clicks so only the scrim or close button closes.
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
        }

        Row {
            id: head
            x: 10
            y: 8
            width: parent.width - 20
            height: 18

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "months"
                color: picker.a(picker.dim, 0.8)
                font.family: picker.font
                font.pixelSize: 7
                font.letterSpacing: 0.7
            }
            Item { width: parent.width - 122; height: 1 }
            IconBtn {
                box: 16
                size: 10
                glyph: "\u2039"
                idle: picker.dim
                hot: picker.accent
                family: picker.font
                duration: picker.motionFast
                onClicked: picker.shownYear = picker.shownYear - 1
            }
            Text {
                width: 42
                anchors.verticalCenter: parent.verticalCenter
                text: picker.shownYear
                color: picker.bright
                horizontalAlignment: Text.AlignHCenter
                font.family: picker.font
                font.pixelSize: 9
                font.bold: true
            }
            IconBtn {
                box: 16
                size: 10
                glyph: "\u203A"
                idle: picker.dim
                hot: picker.accent
                family: picker.font
                duration: picker.motionFast
                onClicked: picker.shownYear = picker.shownYear + 1
            }
        }

        Grid {
            id: months
            x: 10
            y: 31
            width: parent.width - 20
            columns: 3
            spacing: 3

            Repeater {
                model: 12
                delegate: Rectangle {
                    id: monthCell
                    required property int index
                    readonly property var stats: picker.store ? picker.store.monthStats(picker.shownYear, index) : null
                    readonly property bool current: index === picker.month && picker.shownYear === picker.year
                    readonly property bool actual: index === picker.todayMonth && picker.shownYear === picker.todayYear

                    width: (months.width - 6) / 3
                    height: 24
                    radius: 5
                    color: current ? picker.a(picker.accent, 0.14)
                        : hover.containsMouse ? picker.a(picker.dim, 0.07) : "transparent"
                    border.width: current ? 1 : 0
                    border.color: picker.a(picker.accent, 0.55)

                    Text {
                        x: 6
                        anchors.verticalCenter: parent.verticalCenter
                        text: ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
                               "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"][index]
                        color: current || actual ? picker.accent : picker.a(picker.bright, 0.9)
                        font.family: picker.font
                        font.pixelSize: 8
                        font.bold: current
                    }
                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: 5
                        anchors.verticalCenter: parent.verticalCenter
                        visible: stats && stats.total > 0
                        text: stats ? stats.total : ""
                        color: stats && stats.overdue > 0 ? picker.warn : picker.a(picker.dim, 0.7)
                        font.family: picker.font
                        font.pixelSize: 6
                    }
                    Rectangle {
                        visible: actual
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.rightMargin: 4
                        anchors.topMargin: 4
                        width: 3
                        height: 3
                        radius: 1.5
                        color: picker.accent
                    }
                    MouseArea {
                        id: hover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: picker.picked(picker.shownYear, index)
                    }
                }
            }
        }

        Row {
            x: 10
            y: parent.height - 22
            width: parent.width - 20
            height: 14

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "today"
                color: todayHover.hovered ? picker.accent : picker.a(picker.dim, 0.85)
                font.family: picker.font
                font.pixelSize: 8
                HoverHandler { id: todayHover }
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    cursorShape: Qt.PointingHandCursor
                    onClicked: picker.todayClicked()
                }
            }
            Item { width: parent.width - 76; height: 1 }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "close \u00D7"
                color: closeHover.hovered ? picker.accent : picker.a(picker.dim, 0.85)
                font.family: picker.font
                font.pixelSize: 8
                HoverHandler { id: closeHover }
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    cursorShape: Qt.PointingHandCursor
                    onClicked: picker.closed()
                }
            }
        }
    }
}
