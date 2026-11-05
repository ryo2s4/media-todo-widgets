import QtQuick

Item {
    id: f

    property var th
    property string label: ""
    property string text: ""
    property string placeholder: ""
    property bool secret: false
    property bool browse: false
    property alias live: input.text
    signal committed(string value)
    signal browseRequested()

    implicitWidth: 200
    implicitHeight: (label !== "" ? 16 : 0) + 28

    function a(c, v) { return Qt.rgba(c.r, c.g, c.b, v); }
    function clear() { input.text = ""; }

    Text {
        id: lbl
        visible: f.label !== ""
        height: visible ? 16 : 0
        text: f.label
        color: f.th.dim
        font.family: f.th.font
        font.pixelSize: 10
    }

    Rectangle {
        id: box
        y: lbl.height
        width: parent.width
        height: 28
        radius: 5
        color: f.a(f.th.dim, 0.08)
        border.width: 1
        border.color: input.activeFocus ? f.th.accent : f.a(f.th.dim, 0.22)

        TextInput {
            id: input
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.right: browseBtn.visible ? browseBtn.left : parent.right
            anchors.margins: 7
            verticalAlignment: TextInput.AlignVCenter
            clip: true
            text: f.text
            echoMode: f.secret ? TextInput.Password : TextInput.Normal
            color: f.th.bright
            selectByMouse: true
            font.family: f.th.font
            font.pixelSize: 11
            onEditingFinished: f.committed(text)
        }
        Text {
            id: browseBtn
            visible: f.browse
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            anchors.rightMargin: 8
            text: "Browse"
            color: browseMouse.containsMouse ? f.th.bright : f.th.accent
            font.family: f.th.font
            font.pixelSize: 10
            font.bold: true
            MouseArea {
                id: browseMouse
                anchors.fill: parent
                anchors.margins: -4
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: f.browseRequested()
            }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: 7
            anchors.right: parent.right
            anchors.rightMargin: 7
            elide: Text.ElideRight
            visible: input.text === "" && !input.activeFocus
            text: f.placeholder
            color: f.a(f.th.dim, 0.7)
            font.family: f.th.font
            font.pixelSize: 11
        }
    }
}
