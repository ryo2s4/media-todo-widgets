import QtQuick

// Sheet.qml: a floating card used by Sheets.qml. Children are stacked under the
// heading; the height follows the content unless cardHeight is set.
Rectangle {
    id: sheet
    property var theme
    property string heading: ""
    property int cardWidth: 320
    property int cardHeight: -1
    signal closed()

    width: cardWidth
    height: (cardHeight > 0) ? cardHeight : Math.min(parent ? parent.height - 36 : 460, body.implicitHeight + 38)
    radius: theme.radius + 2
    color: "transparent"
    gradient: Gradient {
        GradientStop { position: 0.0; color: Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.16) }
        GradientStop { position: 0.10; color: theme.cardBot }
        GradientStop { position: 1.0; color: theme.cardBot }
    }
    border.width: 1
    border.color: Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.5)
    anchors.centerIn: parent
    z: 200

    opacity: visible ? 1 : 0
    scale: visible ? 1 : 0.96
    Behavior on opacity { NumberAnimation { duration: 130 } }
    Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

    // hairline accent along the top edge
    Rectangle {
        width: parent.width - 44
        height: 1
        anchors.top: parent.top
        anchors.topMargin: 1
        anchors.horizontalCenter: parent.horizontalCenter
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 0.5; color: Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.9) }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }

    default property alias content: body.data

    Column {
        id: body
        x: 14
        y: 14
        width: sheet.width - 28
        spacing: 8
        Item {
            width: parent.width
            height: 20
            Rectangle {
                width: 3
                height: 14
                radius: 1.5
                anchors.verticalCenter: parent.verticalCenter
                color: sheet.theme.accent
            }
            Text {
                anchors.left: parent.left
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                text: sheet.heading
                color: sheet.theme.bright
                font.family: sheet.theme.font
                font.pixelSize: 14
                font.bold: true
            }
        }
    }

    Item {
        width: 22
        height: 22
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 8
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: closeHover.hovered ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.16) : "transparent"
            Behavior on color { ColorAnimation { duration: 120 } }
        }
        Text {
            anchors.centerIn: parent
            text: "\u2715"
            color: closeHover.hovered ? sheet.theme.accent : sheet.theme.dim
            font.family: sheet.theme.font
            font.pixelSize: 11
        }
        HoverHandler { id: closeHover }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: sheet.closed()
        }
    }
}
