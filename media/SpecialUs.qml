import QtQuick

// SpecialUs.qml: the quiet front page. One banner, the two of you in the
// bottom corners, two numbers that matter, and today's memory.
Item {
    id: us

    property var th
    property var sp
    property var frames
    property var chooser
    signal viewMemory(int index)

    implicitHeight: col.implicitHeight
    readonly property var dayMem: sp.thisDayMemory()

    readonly property string nameMe: sp.profile.me.name !== "" ? sp.profile.me.name : "you"
    readonly property string nameThem: sp.profile.partner.name !== "" ? sp.profile.partner.name : "them"
    readonly property var sideCounts: sp.countdowns().filter(function (c) { return c.label !== "Next meet"; })

    function partnerField(key) {
        return us.sp.profile.partner && us.sp.profile.partner[key]
            ? String(us.sp.profile.partner[key]).trim() : "";
    }
    readonly property string partnerHobbies: partnerField("hobbies")
    readonly property string partnerWeight: partnerField("weight")
    readonly property string partnerAgeText: {
        var manual = partnerField("age");
        if (manual !== "")
            return manual;
        var b = us.sp.parseDate(us.sp.profile.birthdayPartner);
        if (!b)
            return "";
        var t = new Date();
        var n = t.getFullYear() - b.getFullYear();
        var m = t.getMonth() - b.getMonth();
        if (m < 0 || (m === 0 && t.getDate() < b.getDate()))
            n--;
        return n >= 0 ? String(n) : "";
    }
    readonly property bool partnerHasInfo: partnerHobbies !== "" || partnerWeight !== "" || partnerAgeText !== ""

    function a(c, v) { return Qt.rgba(c.r, c.g, c.b, v); }
    function initial(who) {
        var n = sp.profile[who] ? sp.profile[who].name : "";
        return n !== "" ? n.charAt(0).toUpperCase() : "\u00b7";
    }
    function memoryIndex(m) {
        for (var i = 0; i < sp.memories.length; i++)
            if (sp.memories[i].file === m.file)
                return i;
        return -1;
    }
    function dayText(v) { return v === null ? "\u2014" : v; }
    function onThisDay(m) {
        var d = m ? sp.parseDate(m.date) : null;
        var t = new Date();
        return !!d && d.getMonth() === t.getMonth() && d.getDate() === t.getDate();
    }

    Column {
        id: col
        width: parent.width
        spacing: 14

        // ───────── banner + the two of you ─────────
        Item {
            id: hero
            width: parent.width
            height: 176

            Rectangle {
                anchors.fill: parent
                radius: 10
                gradient: Gradient {
                    GradientStop { position: 0.0; color: us.a(us.th.accent, 0.16) }
                    GradientStop { position: 1.0; color: us.a(us.th.cardBot, 0.35) }
                }
                border.width: 1
                border.color: us.a(us.th.dim, 0.16)
            }
            SpecialBanner {
                anchors.fill: parent
                source: us.sp.unlocked && us.sp.profile.banner !== "" ? us.sp.url(us.sp.profile.banner) : ""
                radius: 10
            }
            Rectangle {
                anchors.fill: parent
                radius: 10
                gradient: Gradient {
                    GradientStop { position: 0.0; color: us.a(us.th.cardBot, 0.38) }
                    GradientStop { position: 0.55; color: us.a(us.th.cardBot, 0.24) }
                    GradientStop { position: 1.0; color: us.a(us.th.cardBot, 0.92) }
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: us.chooser.open("sp:banner")
            }

            Text {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 10
                text: us.sp.profile.banner !== "" ? "banner" : "+ banner"
                color: us.a(us.th.bright, bannerMa.containsMouse ? 0.95 : 0.6)
                font.family: us.th.font
                font.pixelSize: 8
                MouseArea {
                    id: bannerMa
                    anchors.fill: parent
                    anchors.margins: -6
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: us.chooser.open("sp:banner")
                }
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 28
                spacing: 7
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, 140)
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignRight
                    text: us.nameMe
                    color: us.th.bright
                    font.family: us.th.font
                    font.pixelSize: 16
                    font.bold: true
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "\u2665"
                    color: us.th.accent
                    font.family: us.th.font
                    font.pixelSize: 12
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, 140)
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignLeft
                    text: us.nameThem
                    color: us.th.bright
                    font.family: us.th.font
                    font.pixelSize: 16
                    font.bold: true
                }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 54
                text: us.sp.profile.since !== "" ? "together since " + us.sp.profile.since : "together"
                color: us.a(us.th.dim, 0.9)
                font.family: us.th.font
                font.pixelSize: 8
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 80
                spacing: 34
                Column {
                    spacing: 0
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: us.dayText(us.sp.daysSince(us.sp.profile.since))
                        color: us.th.accent
                        font.family: us.th.font
                        font.pixelSize: 22
                        font.bold: true
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "days since we met"
                        color: us.a(us.th.dim, 0.9)
                        font.family: us.th.font
                        font.pixelSize: 7
                    }
                }
                Column {
                    spacing: 0
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: us.dayText(us.sp.daysUntil(us.sp.profile.nextMeet))
                        color: us.th.accent
                        font.family: us.th.font
                        font.pixelSize: 22
                        font.bold: true
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "days until we meet"
                        color: us.a(us.th.dim, 0.9)
                        font.family: us.th.font
                        font.pixelSize: 7
                    }
                }
            }

            Repeater {
                model: ["me", "partner"]
                delegate: Item {
                    id: corner
                    required property string modelData
                    readonly property var who: us.sp.profile[modelData]
                    readonly property var def: (us.frames && who.frame !== "") ? us.frames.get(who.frame) : null
                    readonly property bool mine: modelData === "me"
                    readonly property real d: 76

                    x: mine ? 14 : hero.width - width - 14
                    y: hero.height - d - 12
                    width: d
                    height: d

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: us.a(us.th.cardBot, 0.7)
                        border.width: 1
                        border.color: us.a(us.th.bright, 0.18)
                    }
                    Text {
                        anchors.centerIn: parent
                        text: us.initial(corner.modelData)
                        color: us.a(us.th.bright, 0.75)
                        font.family: us.th.font
                        font.pixelSize: 18
                        font.bold: true
                    }
                    RoundImage {
                        anchors.fill: parent
                        source: us.sp.avatarUrl(corner.modelData)
                        visible: source != "" && status === Image.Ready
                    }
                    Image {
                        anchors.centerIn: parent
                        width: corner.width * 1.34
                        height: width
                        source: corner.def ? us.frames.fileUrl(corner.def) : ""
                        visible: corner.def !== null
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: us.sp.avatarEditable(corner.modelData) ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: if (us.sp.avatarEditable(corner.modelData))
                            us.chooser.open("sp:" + corner.modelData)
                    }
                    Rectangle {
                        visible: us.frames !== null
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: -2
                        width: 17
                        height: 17
                        radius: 8.5
                        color: us.a(us.th.cardBot, 0.92)
                        border.width: 1
                        border.color: us.a(us.th.dim, 0.55)
                        Text {
                            anchors.centerIn: parent
                            text: "\u2726"
                            color: us.a(us.th.dim, 0.95)
                            font.pixelSize: 8
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: us.sp.setPerson(corner.modelData, "frame",
                                us.frames.nextId(corner.who.frame))
                        }
                    }
                }
            }
        }

        // ───────── partner details ─────────
        Rectangle {
            width: parent.width
            height: aboutCol.implicitHeight + 20
            radius: 8
            color: us.a(us.th.cardBot, 0.42)
            border.width: 1
            border.color: us.a(us.th.dim, 0.16)

            Column {
                id: aboutCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 10
                spacing: 6

                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: "ABOUT " + us.nameThem.toUpperCase()
                    color: us.a(us.th.accent, 0.9)
                    font.family: us.th.font
                    font.pixelSize: 8
                    font.bold: true
                    font.letterSpacing: 1
                }
                Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: us.partnerHobbies !== "" ? us.partnerHobbies : "No hobbies added yet"
                    color: us.partnerHobbies !== "" ? us.th.bright : us.a(us.th.dim, 0.6)
                    font.family: us.th.font
                    font.pixelSize: 10
                    lineHeight: 1.2
                }
                Row {
                    spacing: 28
                    Column {
                        spacing: 0
                        Text {
                            text: us.partnerAgeText !== "" ? us.partnerAgeText : "\u2014"
                            color: us.partnerAgeText !== "" ? us.th.bright : us.a(us.th.dim, 0.5)
                            font.family: us.th.font
                            font.pixelSize: 13
                            font.bold: true
                        }
                        Text {
                            text: "age"
                            color: us.a(us.th.dim, 0.75)
                            font.family: us.th.font
                            font.pixelSize: 7
                        }
                    }
                    Column {
                        spacing: 0
                        Text {
                            text: us.partnerWeight !== "" ? us.partnerWeight : "\u2014"
                            color: us.partnerWeight !== "" ? us.th.bright : us.a(us.th.dim, 0.5)
                            font.family: us.th.font
                            font.pixelSize: 13
                            font.bold: true
                        }
                        Text {
                            text: "weight"
                            color: us.a(us.th.dim, 0.75)
                            font.family: us.th.font
                            font.pixelSize: 7
                        }
                    }
                }
                Text {
                    width: parent.width
                    visible: !us.partnerHasInfo
                    wrapMode: Text.WordWrap
                    text: "Add hobbies, age and weight in Settings > Special."
                    color: us.a(us.th.dim, 0.7)
                    font.family: us.th.font
                    font.pixelSize: 8
                }
            }
        }

        // ───────── the small countdowns, as one quiet line ─────────
        Flow {
            width: parent.width
            spacing: 14
            visible: us.sideCounts.length > 0
            Repeater {
                model: us.sideCounts
                delegate: Row {
                    required property var modelData
                    spacing: 4
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.days <= 0 ? "today" : (modelData.days === 1 ? "tomorrow" : modelData.days + "d")
                        color: us.th.accent
                        font.family: us.th.font
                        font.pixelSize: 9
                        font.bold: true
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.label
                        color: us.a(us.th.dim, 0.85)
                        font.family: us.th.font
                        font.pixelSize: 8
                    }
                }
            }
        }

        // ───────── dates, just two underlines ─────────
        Row {
            width: parent.width
            spacing: 18
            Repeater {
                model: [
                    { key: "since", label: "together since", value: us.sp.profile.since },
                    { key: "nextMeet", label: "next meet", value: us.sp.profile.nextMeet }
                ]
                delegate: Item {
                    required property var modelData
                    width: (parent.width - 18) / 2
                    height: 30
                    Text {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        text: parent.modelData.label
                        color: us.a(us.th.dim, 0.75)
                        font.family: us.th.font
                        font.pixelSize: 7
                    }
                    TextInput {
                        id: dateIn
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: 16
                        text: parent.modelData.value
                        color: us.th.bright
                        font.family: us.th.font
                        font.pixelSize: 9
                        selectByMouse: true
                        onEditingFinished: us.sp.setMeta(parent.modelData.key, text.trim())
                    }
                    Text {
                        anchors.left: parent.left
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 2
                        visible: dateIn.text === "" && !dateIn.activeFocus
                        text: "YYYY-MM-DD"
                        color: us.a(us.th.dim, 0.4)
                        font.family: us.th.font
                        font.pixelSize: 9
                    }
                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: 1
                        color: dateIn.activeFocus ? us.a(us.th.accent, 0.8) : us.a(us.th.dim, 0.28)
                    }
                }
            }
        }

        // ───────── on this day ─────────
        Item {
            width: parent.width
            height: us.dayMem !== null ? 54 : 0
            visible: us.dayMem !== null

            Row {
                width: parent.width
                spacing: 10
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                    width: 46
                    height: 46
                    radius: 5
                    color: us.a(us.th.dim, 0.12)
                    Image {
                        anchors.fill: parent
                        anchors.margins: 1
                        source: us.sp.unlocked ? us.sp.memoryUrl(us.dayMem) : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        clip: true
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: us.viewMemory(us.memoryIndex(us.dayMem))
                    }
                }
                Column {
                    width: parent.width - 56
                    spacing: 2
                    Text {
                        text: !us.onThisDay(us.dayMem)
                            ? "from your memories"
                            : (us.sp.yearsAgo(us.dayMem) > 0
                                ? "on this day, " + us.sp.yearsAgo(us.dayMem) + (us.sp.yearsAgo(us.dayMem) === 1 ? " year ago" : " years ago")
                                : "on this day")
                        color: us.a(us.th.accent, 0.9)
                        font.family: us.th.font
                        font.pixelSize: 8
                    }
                    Text {
                        width: parent.width
                        wrapMode: Text.WordWrap
                        maximumLineCount: 1
                        elide: Text.ElideRight
                        text: us.dayMem ? (us.dayMem.caption || "a memory") : ""
                        color: us.th.bright
                        font.family: us.th.font
                        font.pixelSize: 10
                    }
                    Text {
                        width: parent.width
                        text: us.dayMem
                            ? [us.dayMem.date, us.dayMem.city].filter(function (x) { return !!x; }).join(" \u00b7 ")
                            : ""
                        color: us.a(us.th.dim, 0.75)
                        font.family: us.th.font
                        font.pixelSize: 8
                    }
                }
            }
        }
    }
}
