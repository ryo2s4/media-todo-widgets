import QtQuick

// SpecialTogether.qml: the shared bucket list, a deck of long-distance date
// ideas, and the daily two-way mood check-in.
Item {
    id: tog

    property var th
    property var sp
    property var chooser

    property int ideaIndex: 0
    property string ideaTime: "any"

    implicitHeight: col.implicitHeight

    readonly property var ideas: [
        { t: "Watch party, synced", d: "Pick a film, count down 3-2-1 in the call, press play together.", time: "evening", mode: "call" },
        { t: "Cook the same recipe", d: "Same dish, two kitchens, one call. Compare plates at the end.", time: "evening", mode: "call" },
        { t: "Virtual museum", d: "Open the same online exhibit and take turns describing a piece.", time: "15 min", mode: "call" },
        { t: "Twenty questions", d: "One question each, alternating. No repeats from last time.", time: "15 min", mode: "game" },
        { t: "Photo swap prompt", d: "Both take a photo of the same thing today: your window, your cup, your shoes.", time: "15 min", mode: "async" },
        { t: "Letter exchange", d: "Write one page, post it the same day. The wait is the point.", time: "weekend", mode: "gift" },
        { t: "Care package bingo", d: "Each fills a small box with five things the other misses.", time: "weekend", mode: "gift" },
        { t: "Playlist duel", d: "Five songs each, no skips, score each other's picks.", time: "evening", mode: "game" },
        { t: "Sleep-call timer", d: "Stay on the line until one of you is out. Mute, lights off.", time: "evening", mode: "call" },
        { t: "Same sky", d: "Send the moon or the sunset from where you are, at the same hour.", time: "15 min", mode: "async" },
        { t: "Cook-along breakfast", d: "A short call before work, same simple breakfast.", time: "15 min", mode: "call" },
        { t: "Map a future trip", d: "One city, one weekend, real prices. Save the plan in the bucket list.", time: "weekend", mode: "async" },
        { t: "Voice-note diary", d: "Three minutes each, same day, about nothing in particular.", time: "15 min", mode: "async" },
        { t: "Watch the same stars", d: "Find one constellation you can both see and describe it out loud.", time: "evening", mode: "call" }
    ]

    function a(c, v) { return Qt.rgba(c.r, c.g, c.b, v); }
    function pool() {
        if (tog.ideaTime === "any")
            return tog.ideas;
        return tog.ideas.filter(function (x) { return x.time === tog.ideaTime; });
    }
    function nextIdea() {
        var p = tog.pool();
        if (p.length === 0)
            return;
        tog.ideaIndex = (tog.ideaIndex + 1) % p.length;
    }
    function currentIdea() {
        var p = tog.pool();
        return p.length > 0 ? p[tog.ideaIndex % p.length] : null;
    }
    function doneCount() {
        var n = 0;
        for (var i = 0; i < sp.bucket.length; i++)
            if (sp.bucket[i].done)
                n++;
        return n;
    }
    function moodFace(v) {
        return ["\u00b7", "\u2639", "\u263d", "\u263a", "\u2665"][Math.max(0, Math.min(4, v - 1))];
    }

    Column {
        id: col
        width: parent.width
        spacing: 12

        // ───────── bucket list ─────────
        Row {
            width: parent.width
            Text {
                text: "OUR LIST"
                color: tog.th.dim
                font.family: tog.th.font
                font.pixelSize: 8
                font.bold: true
                font.letterSpacing: 1
            }
            Item { width: parent.width - 130; height: 1 }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: tog.doneCount() + " / " + tog.sp.bucket.length
                color: tog.a(tog.th.accent, 0.9)
                font.family: tog.th.font
                font.pixelSize: 9
            }
        }

        Row {
            width: parent.width
            height: 30
            spacing: 10

            Item {
                width: parent.width - 44
                height: 30
                TextInput {
                    id: bIn
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 4
                    height: 20
                    verticalAlignment: TextInput.AlignVCenter
                    color: tog.th.bright
                    font.family: tog.th.font
                    font.pixelSize: 11
                    selectByMouse: true
                    onAccepted: {
                        tog.sp.addBucket(text);
                        text = "";
                    }
                }
                Text {
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 6
                    visible: bIn.text === ""
                    text: "something to do together"
                    color: tog.a(tog.th.dim, 0.55)
                    font.family: tog.th.font
                    font.pixelSize: 11
                }
                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 1
                    color: bIn.activeFocus ? tog.a(tog.th.accent, 0.8) : tog.a(tog.th.dim, 0.28)
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "add"
                color: bAdd.containsMouse ? tog.th.accent : tog.a(tog.th.accent, 0.85)
                font.family: tog.th.font
                font.pixelSize: 10
                font.bold: true
                MouseArea {
                    id: bAdd
                    anchors.fill: parent
                    anchors.margins: -6
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        tog.sp.addBucket(bIn.text);
                        bIn.text = "";
                    }
                }
            }
        }

        Column {
            width: parent.width
            spacing: 2
            Repeater {
                model: tog.sp.bucket
                delegate: Rectangle {
                    id: brow
                    required property int index
                    required property var modelData
                    width: parent.width
                    height: 26
                    radius: 4
                    color: bma.containsMouse ? tog.a(tog.th.dim, 0.08) : "transparent"

                    Rectangle {
                        id: tick
                        x: 4
                        anchors.verticalCenter: parent.verticalCenter
                        width: 13
                        height: 13
                        radius: 3
                        color: brow.modelData.done ? tog.a(tog.th.accent, 0.9) : "transparent"
                        border.width: 1
                        border.color: brow.modelData.done ? tog.th.accent : tog.a(tog.th.dim, 0.5)
                        Text {
                            anchors.centerIn: parent
                            visible: brow.modelData.done
                            text: "\u2713"
                            color: "#140f0e"
                            font.pixelSize: 9
                            font.bold: true
                        }
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -4
                            cursorShape: Qt.PointingHandCursor
                            onClicked: tog.sp.toggleBucket(brow.index)
                        }
                    }
                    Text {
                        anchors.left: tick.right
                        anchors.leftMargin: 9
                        anchors.right: parent.right
                        anchors.rightMargin: 18
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideRight
                        text: brow.modelData.text
                        color: brow.modelData.done ? tog.a(tog.th.dim, 0.8) : tog.th.bright
                        font.family: tog.th.font
                        font.pixelSize: 10
                        font.strikeout: brow.modelData.done
                    }
                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: 4
                        anchors.verticalCenter: parent.verticalCenter
                        visible: bma.containsMouse
                        text: "\u2715"
                        color: tog.th.dim
                        font.family: tog.th.font
                        font.pixelSize: 9
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -4
                            cursorShape: Qt.PointingHandCursor
                            onClicked: tog.sp.removeBucket(brow.index)
                        }
                    }
                    MouseArea {
                        id: bma
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.NoButton
                    }
                }
            }
        }

        // ───────── long-distance ideas ─────────
        Rectangle {
            width: parent.width
            height: 1
            color: tog.a(tog.th.dim, 0.2)
        }

        Text {
            text: "APART, TOGETHER"
            color: tog.th.dim
            font.family: tog.th.font
            font.pixelSize: 8
            font.bold: true
            font.letterSpacing: 1
        }

        Rectangle {
            width: parent.width
            height: ideaCol.implicitHeight + 24
            radius: 9
            color: tog.a(tog.th.accent, 0.09)
            border.width: 1
            border.color: tog.a(tog.th.accent, 0.32)
            gradient: Gradient {
                GradientStop { position: 0.0; color: tog.a(tog.th.accent, 0.14) }
                GradientStop { position: 1.0; color: "transparent" }
            }

            Column {
                id: ideaCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: 12
                spacing: 6

                Row {
                    width: parent.width
                    Text {
                        text: tog.currentIdea() ? tog.currentIdea().t : "no ideas"
                        color: tog.th.bright
                        font.family: tog.th.font
                        font.pixelSize: 12
                        font.bold: true
                        width: parent.width - 90
                        elide: Text.ElideRight
                    }
                    Text {
                        text: tog.currentIdea() ? (tog.currentIdea().time + " \u00b7 " + tog.currentIdea().mode) : ""
                        color: tog.th.accent
                        font.family: tog.th.font
                        font.pixelSize: 8
                    }
                }
                Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: tog.currentIdea() ? tog.currentIdea().d : ""
                    color: tog.a(tog.th.bright, 0.85)
                    font.family: tog.th.font
                    font.pixelSize: 9
                    lineHeight: 1.3
                }
                Row {
                    spacing: 6
                    Repeater {
                        model: ["any", "15 min", "evening", "weekend"]
                        delegate: Rectangle {
                            required property string modelData
                            width: 58
                            height: 20
                            radius: 10
                            color: tog.ideaTime === modelData ? tog.a(tog.th.accent, 0.22) : "transparent"
                            border.width: 1
                            border.color: tog.ideaTime === modelData ? tog.th.accent : tog.a(tog.th.dim, 0.3)
                            Text {
                                anchors.centerIn: parent
                                text: modelData
                                color: tog.ideaTime === modelData ? tog.th.accent : tog.th.dim
                                font.family: tog.th.font
                                font.pixelSize: 8
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    tog.ideaTime = modelData;
                                    tog.ideaIndex = 0;
                                }
                            }
                        }
                    }
                    Rectangle {
                        width: 56
                        height: 20
                        radius: 10
                        color: tog.a(tog.th.accent, another.containsMouse ? 0.3 : 0.16)
                        Text {
                            anchors.centerIn: parent
                            text: "another"
                            color: tog.th.accent
                            font.family: tog.th.font
                            font.pixelSize: 8
                        }
                        MouseArea {
                            id: another
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: tog.nextIdea()
                        }
                    }
                }
            }
        }

        // ───────── mood check-in ─────────
        Rectangle {
            width: parent.width
            height: 1
            color: tog.a(tog.th.dim, 0.2)
        }

        Text {
            text: "TODAY, HOW ARE YOU?"
            color: tog.th.dim
            font.family: tog.th.font
            font.pixelSize: 8
            font.bold: true
            font.letterSpacing: 1
        }

        Row {
            width: parent.width
            spacing: 10
            Repeater {
                model: ["me", "partner"]
                delegate: Column {
                    id: moodCol
                    required property string modelData
                    width: (parent.width - 10) / 2
                    spacing: 3
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: moodCol.modelData === "me"
                            ? (tog.sp.profile.me.name || "you")
                            : (tog.sp.profile.partner.name || "partner")
                        color: tog.th.dim
                        font.family: tog.th.font
                        font.pixelSize: 9
                    }
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 3
                        Repeater {
                            model: 5
                            delegate: Rectangle {
                                required property int index
                                readonly property int level: index + 1
                                readonly property bool on: tog.sp.todayMood()[moodCol.modelData] >= level
                                width: 20
                                height: 20
                                radius: 10
                                color: on ? tog.a(tog.th.accent, 0.24 + index * 0.1) : "transparent"
                                border.width: 1
                                border.color: on ? tog.th.accent : tog.a(tog.th.dim, 0.3)
                                Text {
                                    anchors.centerIn: parent
                                    text: "\u2665"
                                    color: on ? tog.th.accent : tog.a(tog.th.dim, 0.45)
                                    font.pixelSize: 9
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: tog.sp.setMood(moodCol.modelData, level)
                                }
                            }
                        }
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: tog.moodFace(tog.sp.todayMood()[moodCol.modelData]) + " today"
                        color: tog.th.dim
                        font.family: tog.th.font
                        font.pixelSize: 8
                    }
                }
            }
        }

        Flow {
            width: parent.width
            spacing: 3
            Repeater {
                model: tog.sp.recentMoods(14)
                delegate: Rectangle {
                    required property var modelData
                    readonly property int v: Math.max(modelData.me, modelData.partner)
                    width: Math.floor((tog.width - 3 * 13) / 14)
                    height: 14
                    radius: 3
                    color: v === 0 ? tog.a(tog.th.dim, 0.12) : tog.a(tog.th.accent, 0.12 + v * 0.14)
                    border.width: modelData.date === tog.sp.todayStr() ? 1 : 0
                    border.color: tog.th.accent
                }
            }
        }
        Text {
            width: parent.width
            text: "Last 14 days. Both hearts are stored per day, so you can compare later."
            color: tog.a(tog.th.dim, 0.7)
            font.family: tog.th.font
            font.pixelSize: 8
        }
    }
}
