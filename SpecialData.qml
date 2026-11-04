import QtQuick

// SpecialData.qml: where the vault lives and how it leaves. Everything here
// makes the trade-off explicit: an export is plaintext, a backup is not.
Item {
    id: dat

    property var th
    property var sp
    property var chooser
    property string confirmText: ""

    implicitHeight: col.implicitHeight

    function a(c, v) { return Qt.rgba(c.r, c.g, c.b, v); }
    function sizeText() {
        return sp.vaultExists ? "vault.gpg present" : "no archive yet";
    }

    Column {
        id: col
        width: parent.width
        spacing: 12

        Text {
            text: "THE VAULT"
            color: dat.th.dim
            font.family: dat.th.font
            font.pixelSize: 8
            font.bold: true
            font.letterSpacing: 1
        }

        Rectangle {
            width: parent.width
            height: vaultCol.implicitHeight + 20
            radius: 7
            color: dat.a(dat.th.dim, 0.06)
            border.width: 1
            border.color: dat.a(dat.th.dim, 0.2)

            Column {
                id: vaultCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: 10
                spacing: 6

                Text {
                    width: parent.width
                    elide: Text.ElideMiddle
                    text: dat.sp.vaultPath
                    color: dat.th.bright
                    font.family: dat.th.font
                    font.pixelSize: 10
                }
                Text {
                    text: dat.sizeText() + " \u00b7 " + (dat.sp.unlocked ? "unlocked (tmpfs)" : "locked")
                    color: dat.th.dim
                    font.family: dat.th.font
                    font.pixelSize: 8
                }
                Row {
                    spacing: 6
                    Rectangle {
                        width: 92
                        height: 24
                        radius: 4
                        color: dat.a(dat.th.dim, 0.1)
                        border.width: 1
                        border.color: dat.a(dat.th.dim, 0.3)
                        Text {
                            anchors.centerIn: parent
                            text: "change folder"
                            color: dat.th.bright
                            font.family: dat.th.font
                            font.pixelSize: 9
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: dat.chooser.openDir("sp:vaultPath")
                        }
                    }
                    Rectangle {
                        width: 92
                        height: 24
                        radius: 4
                        color: dat.a(dat.th.dim, 0.1)
                        border.width: 1
                        border.color: dat.a(dat.th.dim, 0.3)
                        Text {
                            anchors.centerIn: parent
                            text: "lock now"
                            color: dat.th.bright
                            font.family: dat.th.font
                            font.pixelSize: 9
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: dat.sp.lock()
                        }
                    }
                    Rectangle {
                        width: 92
                        height: 24
                        radius: 4
                        color: dat.a(dat.th.accent, 0.12)
                        border.width: 1
                        border.color: dat.a(dat.th.accent, 0.5)
                        Text {
                            anchors.centerIn: parent
                            text: "backup"
                            color: dat.th.accent
                            font.family: dat.th.font
                            font.pixelSize: 9
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: dat.chooser.openDir("sp:backupDir")
                        }
                    }
                }
            }
        }

        // ───────── export ─────────
        Text {
            text: "MEMORY BOOK"
            color: dat.th.dim
            font.family: dat.th.font
            font.pixelSize: 8
            font.bold: true
            font.letterSpacing: 1
        }
        Text {
            width: parent.width
            wrapMode: Text.WordWrap
            text: "Writes memory-book.html, memory-book.md and an images folder. The copy is NOT encrypted: treat it like a printed album."
            color: dat.a(dat.th.dim, 0.85)
            font.family: dat.th.font
            font.pixelSize: 9
            lineHeight: 1.3
        }
        Rectangle {
            width: 130
            height: 26
            radius: 5
            color: dat.a(dat.th.accent, expMa.containsMouse ? 0.28 : 0.16)
            border.width: 1
            border.color: dat.th.accent
            Text {
                anchors.centerIn: parent
                text: "export memory book"
                color: dat.th.accent
                font.family: dat.th.font
                font.pixelSize: 9
            }
            MouseArea {
                id: expMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: dat.chooser.openDir("sp:exportDir")
            }
        }

        // ───────── danger ─────────
        Rectangle {
            width: parent.width
            height: 1
            color: dat.a(dat.th.dim, 0.2)
        }
        Text {
            text: "DANGER ZONE"
            color: dat.th.dim
            font.family: dat.th.font
            font.pixelSize: 8
            font.bold: true
            font.letterSpacing: 1
        }
        Text {
            width: parent.width
            wrapMode: Text.WordWrap
            text: "Deleting removes vault.gpg and its backup. There is no recovery without a copy you made yourself."
            color: dat.a(dat.th.dim, 0.85)
            font.family: dat.th.font
            font.pixelSize: 9
            lineHeight: 1.3
        }
        Row {
            width: parent.width
            spacing: 6
            Rectangle {
                width: parent.width - 96
                height: 26
                radius: 5
                color: dat.a(dat.th.dim, 0.08)
                border.width: 1
                border.color: delIn.activeFocus ? dat.th.accent : dat.a(dat.th.dim, 0.25)
                TextInput {
                    id: delIn
                    anchors.fill: parent
                    anchors.margins: 6
                    verticalAlignment: TextInput.AlignVCenter
                    color: dat.th.bright
                    font.family: dat.th.font
                    font.pixelSize: 10
                    selectByMouse: true
                    onTextChanged: dat.confirmText = text.trim()
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 6
                    visible: delIn.text === ""
                    text: "type delete to confirm"
                    color: dat.a(dat.th.dim, 0.7)
                    font.family: dat.th.font
                    font.pixelSize: 9
                }
            }
            Rectangle {
                width: 90
                height: 26
                radius: 5
                color: dat.confirmText === "delete" ? dat.a(dat.th.accent, 0.26) : "transparent"
                border.width: 1
                border.color: dat.confirmText === "delete" ? dat.th.accent : dat.a(dat.th.dim, 0.25)
                Text {
                    anchors.centerIn: parent
                    text: "delete vault"
                    color: dat.confirmText === "delete" ? dat.th.accent : dat.a(dat.th.dim, 0.6)
                    font.family: dat.th.font
                    font.pixelSize: 9
                }
                MouseArea {
                    anchors.fill: parent
                    enabled: dat.confirmText === "delete"
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        dat.sp.deleteVault();
                        delIn.text = "";
                    }
                }
            }
        }

        Text {
            width: parent.width
            visible: dat.sp.info !== ""
            wrapMode: Text.WordWrap
            text: dat.sp.info
            color: dat.th.accent
            font.family: dat.th.font
            font.pixelSize: 9
        }
        Text {
            width: parent.width
            visible: dat.sp.error !== ""
            wrapMode: Text.WordWrap
            text: dat.sp.error
            color: dat.th.accent
            font.family: dat.th.font
            font.pixelSize: 9
        }
        Text {
            width: parent.width
            text: "Auto-lock: " + dat.sp.autoLockMinutes + " min \u00b7 " + (dat.sp.lockOnClose ? "locks when the panel closes" : "stays unlocked after close")
            color: dat.a(dat.th.dim, 0.7)
            font.family: dat.th.font
            font.pixelSize: 8
        }
    }
}
