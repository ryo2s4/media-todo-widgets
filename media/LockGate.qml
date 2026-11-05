import QtQuick

// LockGate.qml: the passphrase screen in front of the Special tab.
// It never sees the archive itself; it only hands the passphrase to Special.qml,
// which pipes it into gpg over stdin.
Item {
    id: lg

    property var th
    property var sp
    property bool active: false

    implicitHeight: col.implicitHeight + 40

    function submit() {
        if (sp.busy)
            return;
        if (sp.vaultExists) {
            var p = pass.text;
            pass.text = "";
            sp.unlock(p);
        } else {
            if (pass.text !== confirm.text) {
                sp.error = "The two passphrases don't match.";
                shakeAnim.restart();
                return;
            }
            var q = pass.text;
            pass.text = "";
            confirm.text = "";
            sp.create(q);
        }
    }

    onActiveChanged: if (active) Qt.callLater(pass.forceActiveFocus)

    Connections {
        target: lg.sp
        function onErrorChanged() { if (lg.sp.error !== "") shakeAnim.restart(); }
    }

    Component.onCompleted: if (active) Qt.callLater(pass.forceActiveFocus)

    SequentialAnimation {
        id: shakeAnim
        loops: 1
        NumberAnimation { target: box; property: "anchors.horizontalCenterOffset"; to: -8; duration: 50 }
        NumberAnimation { target: box; property: "anchors.horizontalCenterOffset"; to: 8; duration: 70 }
        NumberAnimation { target: box; property: "anchors.horizontalCenterOffset"; to: -5; duration: 70 }
        NumberAnimation { target: box; property: "anchors.horizontalCenterOffset"; to: 0; duration: 60 }
    }

    Column {
        id: col
        anchors.horizontalCenter: parent.horizontalCenter
        y: 18
        width: parent.width - 30
        spacing: 12

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "\u2665"
            color: lg.th.accent
            font.family: lg.th.font
            font.pixelSize: 34
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Special"
            color: lg.th.bright
            font.family: lg.th.font
            font.pixelSize: 20
            font.bold: true
        }
        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: lg.sp.vaultExists ? "Locked. Enter your passphrase." : "No vault yet. Choose a passphrase to create one."
            color: lg.th.dim
            font.family: lg.th.font
            font.pixelSize: 11
        }

        Item { width: 1; height: 4 }

        Rectangle {
            id: box
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width
            height: 34
            radius: 6
            color: Qt.rgba(lg.th.dim.r, lg.th.dim.g, lg.th.dim.b, 0.10)
            border.width: 1
            border.color: pass.activeFocus ? lg.th.accent : Qt.rgba(lg.th.dim.r, lg.th.dim.g, lg.th.dim.b, 0.3)

            TextInput {
                id: pass
                anchors.fill: parent
                anchors.margins: 9
                verticalAlignment: TextInput.AlignVCenter
                echoMode: TextInput.Password
                passwordCharacter: "\u2022"
                color: lg.th.bright
                font.family: lg.th.font
                font.pixelSize: 13
                font.letterSpacing: 3
                selectByMouse: true
                onAccepted: {
                    if (!lg.sp.vaultExists && confirm.text === "") {
                        confirm.forceActiveFocus();
                        return;
                    }
                    lg.submit();
                }
                Keys.onTabPressed: function (event) {
                    confirm.forceActiveFocus();
                    event.accepted = true;
                }
                onTextChanged: lg.sp.touch()
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: 10
                visible: pass.text === ""
                text: "passphrase"
                color: Qt.rgba(lg.th.dim.r, lg.th.dim.g, lg.th.dim.b, 0.7)
                font.family: lg.th.font
                font.pixelSize: 12
            }
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width
            height: 34
            radius: 6
            visible: !lg.sp.vaultExists
            color: Qt.rgba(lg.th.dim.r, lg.th.dim.g, lg.th.dim.b, 0.10)
            border.width: 1
            border.color: confirm.activeFocus ? lg.th.accent : Qt.rgba(lg.th.dim.r, lg.th.dim.g, lg.th.dim.b, 0.3)
            TextInput {
                id: confirm
                anchors.fill: parent
                anchors.margins: 9
                verticalAlignment: TextInput.AlignVCenter
                echoMode: TextInput.Password
                passwordCharacter: "\u2022"
                color: lg.th.bright
                font.family: lg.th.font
                font.pixelSize: 13
                font.letterSpacing: 3
                selectByMouse: true
                onAccepted: lg.submit()
                Keys.onTabPressed: function (event) {
                    pass.forceActiveFocus();
                    event.accepted = true;
                }
                Keys.onBacktabPressed: function (event) {
                    pass.forceActiveFocus();
                    event.accepted = true;
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: 10
                visible: confirm.text === ""
                text: "repeat it"
                color: Qt.rgba(lg.th.dim.r, lg.th.dim.g, lg.th.dim.b, 0.7)
                font.family: lg.th.font
                font.pixelSize: 12
            }
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width
            height: 32
            radius: 6
            color: Qt.rgba(lg.th.accent.r, lg.th.accent.g, lg.th.accent.b, hover.containsMouse ? 0.32 : 0.2)
            border.width: 1
            border.color: lg.th.accent
            Text {
                anchors.centerIn: parent
                text: lg.sp.busy ? "working\u2026" : (lg.sp.vaultExists ? "Unlock" : "Create vault")
                color: lg.th.accent
                font.family: lg.th.font
                font.pixelSize: 12
                font.bold: true
            }
            MouseArea {
                id: hover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: lg.submit()
            }
        }

        Text {
            width: parent.width
            visible: lg.sp.error !== ""
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: lg.sp.error
            color: lg.th.accent
            font.family: lg.th.font
            font.pixelSize: 10
        }
        Text {
            width: parent.width
            visible: lg.sp.info !== ""
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: lg.sp.info
            color: lg.th.dim
            font.family: lg.th.font
            font.pixelSize: 10
        }
        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: lg.sp.vaultExists
                ? "Auto-locks after " + lg.sp.autoLockMinutes + " min."
                : "12+ characters, not just digits. There is no recovery: the archive is exactly as strong as this phrase."
            color: Qt.rgba(lg.th.dim.r, lg.th.dim.g, lg.th.dim.b, 0.85)
            font.family: lg.th.font
            font.pixelSize: 9
            lineHeight: 1.3
        }
    }
}
