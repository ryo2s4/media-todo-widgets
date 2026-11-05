import QtQuick

// SpecialMemories.qml: the photo wall. Thumbnails come straight from the
// decrypted tmpfs dir; nothing here knows about encryption.
Item {
    id: mem

    property var th
    property var sp
    property var chooser
    property bool onlyFav: false
    signal openMemory(int index)

    implicitHeight: col.implicitHeight

    function a(c, v) { return Qt.rgba(c.r, c.g, c.b, v); }
    function shown() {
        var out = [];
        for (var i = 0; i < sp.memories.length; i++) {
            if (mem.onlyFav && !sp.memories[i].fav)
                continue;
            out.push({ i: i, m: sp.memories[i] });
        }
        return out;
    }

    Column {
        id: col
        width: parent.width
        spacing: 10

        Item {
            width: parent.width
            height: 22

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 20

                Text {
                    text: "+ photo"
                    color: addMa.containsMouse ? mem.th.accent : mem.a(mem.th.accent, 0.85)
                    font.family: mem.th.font
                    font.pixelSize: 10
                    font.bold: true
                    MouseArea {
                        id: addMa
                        anchors.fill: parent
                        anchors.margins: -8
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: mem.chooser.open("sp:memories")
                    }
                }
                Text {
                    text: "folder"
                    color: folderMa.containsMouse ? mem.th.bright : mem.a(mem.th.dim, 0.8)
                    font.family: mem.th.font
                    font.pixelSize: 10
                    MouseArea {
                        id: folderMa
                        anchors.fill: parent
                        anchors.margins: -8
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: mem.chooser.openDir("sp:importDir")
                    }
                }
            }

            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: "\u2665 " + mem.shown().length
                color: mem.onlyFav ? mem.th.accent : mem.a(mem.th.dim, 0.75)
                font.family: mem.th.font
                font.pixelSize: 10
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -8
                    cursorShape: Qt.PointingHandCursor
                    onClicked: mem.onlyFav = !mem.onlyFav
                }
            }
        }

        Text {
            width: parent.width
            visible: mem.shown().length === 0
            wrapMode: Text.WordWrap
            text: mem.onlyFav ? "No favourites yet. Open a photo and tap the heart."
                : "No memories yet. Add a photo, or import a folder."
            color: mem.a(mem.th.dim, 0.85)
            font.family: mem.th.font
            font.pixelSize: 10
        }

        GridView {
            id: grid
            width: parent.width
            height: contentHeight
            cellWidth: Math.floor(width / 3)
            cellHeight: cellWidth + 26
            interactive: false
            clip: true

            model: mem.shown()

            delegate: Item {
                id: cell
                required property var modelData
                width: grid.cellWidth
                height: grid.cellHeight

                Rectangle {
                    id: thumb
                    x: 3
                    y: 3
                    width: parent.width - 6
                    height: parent.width - 6
                    radius: 6
                    color: mem.a(mem.th.dim, 0.12)
                    clip: true

                    Image {
                        anchors.fill: parent
                        source: mem.sp.memoryUrl(cell.modelData.m)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        sourceSize.width: 320
                        sourceSize.height: 320
                    }
                    Rectangle {
                        visible: cell.modelData.m.fav
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 4
                        width: 16
                        height: 16
                        radius: 8
                        color: Qt.rgba(0, 0, 0, 0.55)
                        Text {
                            anchors.centerIn: parent
                            text: "\u2665"
                            color: mem.th.accent
                            font.pixelSize: 9
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: mem.openMemory(cell.modelData.i)
                    }
                }
                Text {
                    anchors.top: thumb.bottom
                    anchors.topMargin: 2
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 4
                    anchors.rightMargin: 4
                    elide: Text.ElideRight
                    text: cell.modelData.m.date || cell.modelData.m.caption || " "
                    color: mem.th.dim
                    font.family: mem.th.font
                    font.pixelSize: 8
                }
            }
        }
    }
}
