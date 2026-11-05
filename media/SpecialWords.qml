import QtQuick

// SpecialWords.qml: the things you two said, plus letters that stay sealed
// until their date. A sealed letter's text is never instantiated before then.
Item {
    id: words

    property var th
    property var sp
    property var chooser

    property bool composing: false
    property string who: "me"
    property int reading: -1

    implicitHeight: col.implicitHeight

    function a(c, v) { return Qt.rgba(c.r, c.g, c.b, v); }

    Column {
        id: col
        width: parent.width
        spacing: 10

        // ───────── quotes ─────────
        Text {
            text: "OUR QUOTES"
            color: words.th.dim
            font.family: words.th.font
            font.pixelSize: 8
            font.bold: true
            font.letterSpacing: 1
        }

        Row {
            width: parent.width
            height: 30
            spacing: 10

            Item {
                width: parent.width - 72
                height: 30
                TextInput {
                    id: qIn
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 4
                    height: 20
                    verticalAlignment: TextInput.AlignVCenter
                    color: words.th.bright
                    font.family: words.th.font
                    font.pixelSize: 11
                    selectByMouse: true
                    onAccepted: {
                        words.sp.addQuote(text, words.who);
                        text = "";
                    }
                }
                Text {
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 6
                    visible: qIn.text === ""
                    text: "something worth keeping"
                    color: words.a(words.th.dim, 0.55)
                    font.family: words.th.font
                    font.pixelSize: 11
                }
                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 1
                    color: qIn.activeFocus ? words.a(words.th.accent, 0.8) : words.a(words.th.dim, 0.28)
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: 22
                text: words.who === "me" ? "me" : "them"
                color: whoMa.containsMouse ? words.th.bright : words.a(words.th.dim, 0.8)
                font.family: words.th.font
                font.pixelSize: 9
                MouseArea {
                    id: whoMa
                    anchors.fill: parent
                    anchors.margins: -6
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: words.who = words.who === "me" ? "partner" : "me"
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "add"
                color: qAdd.containsMouse ? words.th.accent : words.a(words.th.accent, 0.85)
                font.family: words.th.font
                font.pixelSize: 10
                font.bold: true
                MouseArea {
                    id: qAdd
                    anchors.fill: parent
                    anchors.margins: -6
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        words.sp.addQuote(qIn.text, words.who);
                        qIn.text = "";
                        qIn.forceActiveFocus();
                    }
                }
            }
        }

        Column {
            width: parent.width
            spacing: 4
            Repeater {
                model: words.sp.quotes
                delegate: Rectangle {
                    id: qrow
                    required property int index
                    required property var modelData
                    width: parent.width
                    height: qcol.implicitHeight + 12
                    radius: 5
                    color: qma.containsMouse ? words.a(words.th.dim, 0.1) : "transparent"
                    Column {
                        id: qcol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.margins: 8
                        spacing: 1
                        Text {
                            width: parent.width - 14
                            wrapMode: Text.WordWrap
                            text: "\u201c" + qrow.modelData.text + "\u201d"
                            color: words.th.bright
                            font.family: words.th.font
                            font.pixelSize: 10
                        }
                        Text {
                            text: (qrow.modelData.who === "me" ? "you" : "them") + (qrow.modelData.date ? " \u00b7 " + qrow.modelData.date : "")
                            color: words.th.dim
                            font.family: words.th.font
                            font.pixelSize: 8
                        }
                    }
                    Text {
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 4
                        visible: qma.containsMouse
                        text: "\u2715"
                        color: words.th.dim
                        font.family: words.th.font
                        font.pixelSize: 9
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -5
                            cursorShape: Qt.PointingHandCursor
                            onClicked: words.sp.removeQuote(qrow.index)
                        }
                    }
                    MouseArea {
                        id: qma
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.NoButton
                    }
                }
            }
        }

        // ───────── sealed letters ─────────
        Rectangle {
            width: parent.width
            height: 1
            color: words.a(words.th.dim, 0.2)
        }

        Row {
            width: parent.width
            Text {
                text: "SEALED LETTERS"
                color: words.th.dim
                font.family: words.th.font
                font.pixelSize: 8
                font.bold: true
                font.letterSpacing: 1
            }
            Item { width: parent.width - 120; height: 1 }
            Text {
                text: words.composing ? "cancel" : "+ write one"
                color: words.th.accent
                font.family: words.th.font
                font.pixelSize: 9
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    cursorShape: Qt.PointingHandCursor
                    onClicked: words.composing = !words.composing
                }
            }
        }

        Column {
            width: parent.width
            spacing: 6
            visible: words.composing

            Rectangle {
                width: parent.width
                height: 78
                radius: 5
                color: words.a(words.th.dim, 0.08)
                border.width: 1
                border.color: noteIn.activeFocus ? words.th.accent : words.a(words.th.dim, 0.22)
                TextEdit {
                    id: noteIn
                    anchors.fill: parent
                    anchors.margins: 7
                    wrapMode: TextEdit.Wrap
                    color: words.th.bright
                    font.family: words.th.font
                    font.pixelSize: 11
                    selectByMouse: true
                    clip: true
                }
                Text {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.margins: 7
                    visible: noteIn.text === ""
                    text: "say it now, let the date decide when it is read"
                    color: words.a(words.th.dim, 0.7)
                    font.family: words.th.font
                    font.pixelSize: 10
                }
            }
            Row {
                width: parent.width
                spacing: 6
                Rectangle {
                    width: 142
                    height: 28
                    radius: 5
                    color: words.a(words.th.dim, 0.08)
                    border.width: 1
                    border.color: whenIn.activeFocus ? words.th.accent : words.a(words.th.dim, 0.22)
                    TextInput {
                        id: whenIn
                        anchors.fill: parent
                        anchors.margins: 6
                        verticalAlignment: TextInput.AlignVCenter
                        color: words.th.bright
                        font.family: words.th.font
                        font.pixelSize: 10
                        selectByMouse: true
                        onAccepted: sealBtn.seal()
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: 6
                        visible: whenIn.text === ""
                        text: "open on YYYY-MM-DD"
                        color: words.a(words.th.dim, 0.7)
                        font.family: words.th.font
                        font.pixelSize: 9
                    }
                }
                Rectangle {
                    id: sealBtn
                    width: parent.width - 148
                    height: 28
                    radius: 5
                    color: words.a(words.th.accent, sealMa.containsMouse ? 0.3 : 0.18)
                    border.width: 1
                    border.color: words.th.accent
                    function seal() {
                        if (noteIn.text.trim() === "")
                            return;
                        words.sp.addNote(noteIn.text, whenIn.text.trim());
                        noteIn.text = "";
                        whenIn.text = "";
                        words.composing = false;
                    }
                    Text {
                        anchors.centerIn: parent
                        text: "\u2731 seal it"
                        color: words.th.accent
                        font.family: words.th.font
                        font.pixelSize: 10
                        font.bold: true
                    }
                    MouseArea {
                        id: sealMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: sealBtn.seal()
                    }
                }
            }
        }

        Column {
            width: parent.width
            spacing: 6
            Repeater {
                model: words.sp.notes
                delegate: Rectangle {
                    id: noteRow
                    required property int index
                    required property var modelData
                    readonly property bool ready: words.sp.noteReady(modelData)
                    readonly property bool open: words.reading === index
                    width: parent.width
                    height: ncol.implicitHeight + 18
                    radius: 7
                    color: ready ? words.a(words.th.accent, 0.08) : words.a(words.th.dim, 0.06)
                    border.width: 1
                    border.color: ready ? words.a(words.th.accent, 0.35) : words.a(words.th.dim, 0.25)

                    Column {
                        id: ncol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.margins: 10
                        spacing: 4

                        Row {
                            width: parent.width
                            Text {
                                text: noteRow.ready ? "\u2731 opened letter" : "\u2731 sealed"
                                color: noteRow.ready ? words.th.accent : words.th.dim
                                font.family: words.th.font
                                font.pixelSize: 9
                                font.bold: true
                            }
                            Item { width: parent.width - 170; height: 1 }
                            Text {
                                text: noteRow.ready ? (noteRow.modelData.unlockAt || "no date")
                                    : (words.sp.noteDays(noteRow.modelData) === null ? "no date"
                                        : (words.sp.noteDays(noteRow.modelData) + " days \u00b7 " + noteRow.modelData.unlockAt))
                                color: words.th.dim
                                font.family: words.th.font
                                font.pixelSize: 9
                            }
                        }
                        Text {
                            width: parent.width
                            visible: noteRow.open && noteRow.ready
                            wrapMode: Text.WordWrap
                            text: noteRow.modelData.text
                            color: words.th.bright
                            font.family: words.th.font
                            font.pixelSize: 10
                            lineHeight: 1.25
                        }
                        Text {
                            width: parent.width
                            visible: !noteRow.ready
                            wrapMode: Text.WordWrap
                            text: "The words stay inside the vault until the date. Nothing is rendered early."
                            color: words.a(words.th.dim, 0.75)
                            font.family: words.th.font
                            font.pixelSize: 8
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: noteRow.ready ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: {
                            if (!noteRow.ready)
                                return;
                            words.reading = noteRow.open ? -1 : noteRow.index;
                            words.sp.openNote(noteRow.index);
                        }
                    }
                }
            }
        }
    }
}
