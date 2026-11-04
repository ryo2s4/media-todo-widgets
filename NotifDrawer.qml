import QtQuick

// Notifications shown under every tab.
Item {
    id: drawer

    property var th
    property var nf
    property bool expanded: true

    function a(c, v) { return Qt.rgba(c.r, c.g, c.b, v); }

    implicitHeight: expanded ? 176 : 34
    height: implicitHeight
    clip: true
    Behavior on height { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

    // separator
    Rectangle {
        width: parent.width
        height: 1
        color: drawer.a(drawer.th.dim, 0.25)
    }

    // header
    Item {
        id: head
        y: 6
        width: parent.width
        height: 26

        Text {
            id: title
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "Notifications"
            color: drawer.th.bright
            font.family: drawer.th.font
            font.pixelSize: 12
            font.bold: true
        }
        Rectangle {
            anchors.left: title.right
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            visible: drawer.nf.items.length > 0
            width: countText.implicitWidth + 10
            height: 16
            radius: 8
            color: drawer.a(drawer.th.accent, 0.2)
            Text {
                id: countText
                anchors.centerIn: parent
                text: drawer.nf.items.length
                color: drawer.th.accent
                font.family: drawer.th.font
                font.pixelSize: 10
                font.bold: true
            }
        }
        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: drawer.nf.items.length > 0
                text: "Clear all"
                color: clearArea.containsMouse ? drawer.th.accent : drawer.th.dim
                font.family: drawer.th.font
                font.pixelSize: 11
                MouseArea {
                    id: clearArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: drawer.nf.clear()
                }
            }
            IconBtn {
                box: 22
                size: 11
                glyph: drawer.expanded ? "\u25BE" : "\u25B4"
                idle: drawer.th.dim
                hot: drawer.th.accent
                family: drawer.th.font
                onClicked: drawer.expanded = !drawer.expanded
            }
        }
    }

    ListView {
        id: list
        anchors.top: head.bottom
        anchors.topMargin: 6
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        clip: true
        spacing: 6
        boundsBehavior: Flickable.StopAtBounds
        model: drawer.nf.items

        delegate: Rectangle {
            id: card
            required property var modelData

            width: list.width
            height: cardCol.implicitHeight + 16
            radius: drawer.th.radius
            color: drawer.a(drawer.th.dim, 0.08)
            border.width: 1
            border.color: drawer.a(drawer.th.dim, 0.16)

            Column {
                id: cardCol
                x: 10
                y: 8
                width: parent.width - 20
                spacing: 3

                Item {
                    width: parent.width
                    height: 14
                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: card.modelData.app !== "" ? card.modelData.app : "notification"
                        color: drawer.th.accent
                        font.family: drawer.th.font
                        font.pixelSize: 10
                    }
                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: drawer.nf.ago(card.modelData.t, drawer.nf.tick)
                            color: drawer.th.dim
                            font.family: drawer.th.font
                            font.pixelSize: 10
                        }
                        IconBtn {
                            box: 16
                            size: 9
                            glyph: "\u2715"
                            idle: drawer.th.dim
                            hot: drawer.th.accent
                            family: drawer.th.font
                            onClicked: drawer.nf.dismiss(card.modelData.id)
                        }
                    }
                }
                Text {
                    width: parent.width
                    visible: card.modelData.summary !== ""
                    text: card.modelData.summary
                    elide: Text.ElideRight
                    color: drawer.th.bright
                    font.family: drawer.th.font
                    font.pixelSize: 12
                    font.bold: true
                }
                Text {
                    width: parent.width
                    visible: card.modelData.body !== ""
                    text: card.modelData.body
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    color: drawer.th.dim
                    font.family: drawer.th.font
                    font.pixelSize: 11
                }
            }
        }

        Text {
            anchors.centerIn: parent
            visible: drawer.nf.items.length === 0
            text: "No notifications"
            color: drawer.a(drawer.th.dim, 0.8)
            font.family: drawer.th.font
            font.pixelSize: 11
        }
    }
}
