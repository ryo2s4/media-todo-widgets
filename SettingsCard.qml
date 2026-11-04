import QtQuick

// Settings overlay. One section at a time; every change applies immediately and
// is saved to settings.json.
Rectangle {
    id: sc

    property var th
    property var cfg
    property var cava
    property var chooser
    property var frames
    property var special
    signal closed()

    property string section: "Profile"
    readonly property var sections: {
        var a = ["Profile", "Home", "Weather", "Quotes", "Music", "Games", "Apps"];
        if (sc.special && sc.special.specialVisible)
            a.push("Special");
        a.push("Look");
        return a;
    }

    // seven taps on About, inside Look, bring the hidden tab back
    property int knocks: 0
    function knock() {
        sc.knocks++;
        knockReset.restart();
        if (sc.knocks >= 7) {
            sc.knocks = 0;
            knockReset.stop();
            if (sc.special) {
                sc.special.revealSpecial();
                sc.section = "Special";
            }
        }
    }
    Timer {
        id: knockReset
        interval: 3000
        onTriggered: sc.knocks = 0
    }
    Connections {
        target: sc.special
        function onSpecialVisibleChanged() {
            if (sc.special && !sc.special.specialVisible && sc.section === "Special")
                sc.section = "Look";
        }
    }

    function a(c, v) { return Qt.rgba(c.r, c.g, c.b, v); }

    radius: th.radius
    color: th.cardBot
    border.width: 1
    border.color: a(th.accent, 0.45)

    // ───────── small pieces ─────────
    component TRow: Item {
        id: tr
        property var th
        property string label: ""
        property bool on: false
        signal toggled()
        width: parent ? parent.width : 200
        height: 26
        Text {
            anchors.left: parent.left
            anchors.right: sw.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            text: tr.label
            color: tr.th.bright
            font.family: tr.th.font
            font.pixelSize: 12
        }
        Toggle {
            id: sw
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            on: tr.on
            accent: tr.th.accent
            dim: tr.th.dim
            onToggled: tr.toggled()
        }
    }

    component Label2: Text {
        property var th
        color: th.dim
        font.family: th.font
        font.pixelSize: 10
        wrapMode: Text.Wrap
    }

    component Btn: Rectangle {
        id: btn
        property var th
        property string label: ""
        property bool primary: false
        signal clicked()

        width: btnText.implicitWidth + 26
        height: 26
        radius: 5
        color: primary ? a(th.accent, btnMa.containsMouse ? 0.3 : 0.18) : "transparent"
        border.width: 1
        border.color: primary ? th.accent : a(th.dim, 0.35)
        Text {
            id: btnText
            anchors.centerIn: parent
            text: btn.label
            color: btn.primary ? btn.th.accent : (btnMa.containsMouse ? btn.th.bright : btn.th.dim)
            font.family: btn.th.font
            font.pixelSize: 10
            font.bold: btn.primary
        }
        MouseArea {
            id: btnMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.clicked()
        }
    }

    component ChipRow: Item {
        id: cr
        property var th
        property string label: ""
        property var model: []
        property var current
        signal picked(var value)
        width: parent ? parent.width : 200
        height: 28
        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: cr.label
            color: cr.th.bright
            font.family: cr.th.font
            font.pixelSize: 12
        }
        Chips {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            th: cr.th
            model: cr.model
            current: cr.current
            onPicked: function (v) { cr.picked(v); }
        }
    }

    component SliderRow: Item {        id: sr
        property var th
        property string label: ""
        property string valueText: ""
        property real from: 0
        property real to: 1
        property real value: 0
        signal moved(real v)
        width: parent ? parent.width : 200
        height: 26
        Text {
            id: srl
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 130
            text: sr.label
            color: sr.th.bright
            font.family: sr.th.font
            font.pixelSize: 12
        }
        Text {
            id: srv
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 48
            horizontalAlignment: Text.AlignRight
            text: sr.valueText
            color: sr.th.dim
            font.family: sr.th.font
            font.pixelSize: 11
        }
        Slider {
            anchors.left: srl.right
            anchors.right: srv.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            th: sr.th
            from: sr.from
            to: sr.to
            value: sr.value
            onMoved: function (v) { sr.moved(v); }
        }
    }

    // ───────── title bar and section tabs ─────────
    Item {
        id: bar
        x: 16
        y: 12
        width: parent.width - 32
        height: 26
        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "Settings"
            color: sc.th.bright
            font.family: sc.th.font
            font.pixelSize: 15
            font.bold: true
        }
        IconBtn {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            size: 12
            glyph: "\u2715"
            idle: sc.th.dim
            hot: sc.th.accent
            family: sc.th.font
            onClicked: sc.closed()
        }
    }

    Flow {
        id: tabs
        anchors.top: bar.bottom
        anchors.topMargin: 10
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        spacing: 6
        Repeater {
            model: sc.sections
            delegate: Rectangle {
                id: pill
                required property string modelData
                readonly property bool on: sc.section === modelData
                width: pillText.implicitWidth + 20
                height: 24
                radius: 12
                color: on ? sc.a(sc.th.accent, 0.20) : "transparent"
                border.width: 1
                border.color: on ? sc.th.accent : sc.a(sc.th.dim, 0.3)
                Text {
                    id: pillText
                    anchors.centerIn: parent
                    text: pill.modelData
                    color: pill.on ? sc.th.accent : sc.th.dim
                    font.family: sc.th.font
                    font.pixelSize: 11
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: sc.section = pill.modelData
                }
            }
        }
    }

    Rectangle {
        id: rule
        anchors.top: tabs.bottom
        anchors.topMargin: 10
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        height: 1
        color: sc.a(sc.th.dim, 0.25)
    }

    Flickable {
        id: flick
        anchors.top: rule.bottom
        anchors.topMargin: 12
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 12
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        contentWidth: width
        contentHeight: body.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Item {
            id: body
            width: flick.width
            implicitHeight: Math.max(pProfile.implicitHeight, pHome.implicitHeight, pWeather.implicitHeight, pQuotes.implicitHeight,
                                     pMusic.implicitHeight, pGames.implicitHeight, pApps.implicitHeight, pSpecial.implicitHeight,
                                     pLook.implicitHeight) + 8

            // ───────── Profile ─────────
            Column {
                id: pProfile
                width: parent.width
                visible: sc.section === "Profile"
                spacing: 10

                Field {
                    width: parent.width
                    th: sc.th
                    label: "Name in the greeting (empty = username)"
                    placeholder: sc.cfg.user
                    text: sc.cfg.name
                    onCommitted: function (v) { sc.cfg.set("name", v); }
                }
                Field {
                    width: parent.width
                    th: sc.th
                    label: "Line under the name (optional)"
                    placeholder: "shown below your name"
                    text: sc.cfg.subtitle
                    onCommitted: function (v) { sc.cfg.set("subtitle", v); }
                }
                ChipRow {
                    th: sc.th
                    label: "Greeting language"
                    model: [{ label: "Arabic", value: "ar" }, { label: "English", value: "en" }]
                    current: sc.cfg.lang
                    onPicked: function (v) { sc.cfg.set("lang", v); }
                }
                Field {
                    width: parent.width
                    th: sc.th
                    label: "Profile picture (click it on the Home tab to change it)"
                    placeholder: sc.cfg.home + "/.face"
                    browse: true
                    text: sc.cfg.avatarPath
                    onCommitted: function (v) { sc.cfg.set("avatarPath", v.trim()); }
                    onBrowseRequested: sc.chooser.open("avatarPath")
                }
                Label2 {
                    th: sc.th
                    width: parent.width
                    text: "Profile frame (you can also hover your picture on the Home tab and press Frame)"
                }
                Flow {
                    width: parent.width
                    spacing: 8
                    Repeater {
                        model: sc.frames ? [{ id: "", name: "None", kind: "none" }].concat(sc.frames.all) : []
                        delegate: Rectangle {
                            id: fcell
                            required property var modelData
                            readonly property bool on: sc.cfg.avatarFrame === modelData.id
                            width: 60
                            height: 78
                            radius: 6
                            color: on ? sc.a(sc.th.accent, 0.14) : sc.a(sc.th.dim, 0.08)
                            border.width: 1
                            border.color: on ? sc.th.accent : sc.a(sc.th.dim, 0.22)
                            Item {
                                x: 4
                                y: 4
                                width: 52
                                height: 52
                                Text {
                                    anchors.centerIn: parent
                                    visible: fcell.modelData.id === ""
                                    text: "\u2715"
                                    color: sc.th.dim
                                    font.family: sc.th.font
                                    font.pixelSize: 16
                                }
                                Image {
                                    anchors.fill: parent
                                    visible: fcell.modelData.id !== ""
                                    source: fcell.modelData.id === "" ? "" : (fcell.modelData.kind === "anim" ? sc.frames.gifUrl(fcell.modelData) : sc.frames.fileUrl(fcell.modelData))
                                    sourceSize: Qt.size(120, 120)
                                    fillMode: Image.PreserveAspectFit
                                    asynchronous: true
                                    smooth: true
                                }
                            }
                            Text {
                                x: 2
                                y: 58
                                width: parent.width - 4
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                                text: fcell.modelData.name
                                color: fcell.on ? sc.th.accent : sc.th.dim
                                font.family: sc.th.font
                                font.pixelSize: 9
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: sc.cfg.set("avatarFrame", fcell.modelData.id)
                            }
                        }
                    }
                }
                Field {
                    width: parent.width
                    th: sc.th
                    label: "Your own frame (a PNG with a transparent middle)"
                    placeholder: "empty = none"
                    browse: true
                    text: sc.cfg.customFramePath
                    onCommitted: function (v) { sc.cfg.set("customFramePath", v.trim()); }
                    onBrowseRequested: sc.chooser.open("customFramePath")
                }
                SliderRow {
                    th: sc.th
                    visible: sc.cfg.customFramePath !== ""
                    label: "Size of the middle"
                    valueText: Math.round(sc.cfg.customFrameHole * 100) + "%"
                    from: 0.4
                    to: 0.95
                    value: sc.cfg.customFrameHole
                    onMoved: function (v) { sc.cfg.set("customFrameHole", Math.round(v * 100) / 100); }
                }
                Field {
                    width: parent.width
                    th: sc.th
                    label: "Banner behind the profile (image or GIF)"
                    placeholder: "empty = plain sky colours for the time of day"
                    browse: true
                    text: sc.cfg.bannerPath
                    onCommitted: function (v) { sc.cfg.set("bannerPath", v.trim()); }
                    onBrowseRequested: sc.chooser.open("bannerPath")
                }
                SliderRow {
                    th: sc.th
                    label: "Banner darkening"
                    valueText: Math.round(sc.cfg.bannerDim * 100) + "%"
                    from: 0
                    to: 0.9
                    value: sc.cfg.bannerDim
                    onMoved: function (v) { sc.cfg.set("bannerDim", Math.round(v * 20) / 20); }
                }
                Label2 {
                    th: sc.th
                    width: parent.width
                    visible: sc.chooser.error !== ""
                    text: sc.chooser.error
                    color: sc.th.accent
                }
                Field {
                    width: parent.width
                    th: sc.th
                    label: "Morning greeting (5:00 - 11:59)"
                    placeholder: sc.cfg.defaultGreeting(0)
                    text: sc.cfg.greetMorning
                    onCommitted: function (v) { sc.cfg.set("greetMorning", v); }
                }
                Field {
                    width: parent.width
                    th: sc.th
                    label: "Afternoon greeting (12:00 - 15:59)"
                    placeholder: sc.cfg.defaultGreeting(1)
                    text: sc.cfg.greetDay
                    onCommitted: function (v) { sc.cfg.set("greetDay", v); }
                }
                Field {
                    width: parent.width
                    th: sc.th
                    label: "Evening greeting (16:00 - 20:59)"
                    placeholder: sc.cfg.defaultGreeting(2)
                    text: sc.cfg.greetEvening
                    onCommitted: function (v) { sc.cfg.set("greetEvening", v); }
                }
                Field {
                    width: parent.width
                    th: sc.th
                    label: "Night greeting (21:00 - 4:59)"
                    placeholder: sc.cfg.defaultGreeting(3)
                    text: sc.cfg.greetNight
                    onCommitted: function (v) { sc.cfg.set("greetNight", v); }
                }
            }

            // ───────── Home ─────────
            Column {
                id: pHome
                width: parent.width
                visible: sc.section === "Home"
                spacing: 8

                Label2 { th: sc.th; width: parent.width; text: "Choose which cards the Home tab shows." }
                TRow { th: sc.th; label: "Quote"; on: sc.cfg.showQuote; onToggled: sc.cfg.set("showQuote", !sc.cfg.showQuote) }
                TRow { th: sc.th; label: "System"; on: sc.cfg.showSystem; onToggled: sc.cfg.set("showSystem", !sc.cfg.showSystem) }
                TRow { th: sc.th; label: "Volume, brightness and power"; on: sc.cfg.showQuick; onToggled: sc.cfg.set("showQuick", !sc.cfg.showQuick) }
                TRow { th: sc.th; label: "App buttons"; on: sc.cfg.showLaunchers; onToggled: sc.cfg.set("showLaunchers", !sc.cfg.showLaunchers) }
                TRow { th: sc.th; label: "Continue playing"; on: sc.cfg.showContinue; onToggled: sc.cfg.set("showContinue", !sc.cfg.showContinue) }
                TRow { th: sc.th; label: "Recent screenshots"; on: sc.cfg.showShots; onToggled: sc.cfg.set("showShots", !sc.cfg.showShots) }
                TRow { th: sc.th; label: "Calendar and Todo"; on: sc.cfg.showCalendar; onToggled: sc.cfg.set("showCalendar", !sc.cfg.showCalendar) }
                TRow { th: sc.th; label: "Scratch note"; on: sc.cfg.showNote; onToggled: sc.cfg.set("showNote", !sc.cfg.showNote) }
                ChipRow {
                    th: sc.th
                    label: "System card shows"
                    model: [{ label: "Gauges", value: "gauges" }, { label: "Graphs", value: "graphs" }]
                    current: sc.cfg.systemView
                    onPicked: function (v) { sc.cfg.set("systemView", v); }
                }
                Field {
                    width: parent.width
                    th: sc.th
                    label: "Screenshots folder"
                    placeholder: sc.cfg.home + "/Pictures/Screenshots"
                    text: sc.cfg.shotsDir
                    onCommitted: function (v) { sc.cfg.set("shotsDir", v.trim()); }
                }
                Field {
                    width: parent.width
                    th: sc.th
                    label: "Lock command"
                    placeholder: "loginctl lock-session"
                    text: sc.cfg.lockCmd
                    onCommitted: function (v) { sc.cfg.set("lockCmd", v.trim() !== "" ? v.trim() : "loginctl lock-session"); }
                }
            }

            // ───────── Weather ─────────
            Column {
                id: pWeather
                width: parent.width
                visible: sc.section === "Weather"
                spacing: 10

                TRow { th: sc.th; label: "Show weather"; on: sc.cfg.weatherEnabled; onToggled: sc.cfg.set("weatherEnabled", !sc.cfg.weatherEnabled) }
                TRow { th: sc.th; label: "Rain, snow and clouds over the banner"; on: sc.cfg.weatherFx; onToggled: sc.cfg.set("weatherFx", !sc.cfg.weatherFx) }
                Field {
                    width: parent.width
                    th: sc.th
                    label: "City"
                    placeholder: "e.g. Damascus (empty = guess from your IP address)"
                    text: sc.cfg.city
                    onCommitted: function (v) { sc.cfg.set("city", v.trim()); }
                }
                ChipRow {
                    th: sc.th
                    label: "Temperature"
                    model: [{ label: "Celsius", value: "c" }, { label: "Fahrenheit", value: "f" }]
                    current: sc.cfg.units
                    onPicked: function (v) { sc.cfg.set("units", v); }
                }
                Label2 {
                    th: sc.th
                    width: parent.width
                    text: "Data from Open-Meteo, no account needed. With an empty city the location is guessed from your IP address by ipwho.is."
                }
            }

            // ───────── Quotes ─────────
            Column {
                id: pQuotes
                width: parent.width
                visible: sc.section === "Quotes"
                spacing: 10

                ChipRow {
                    th: sc.th
                    label: "Quote of the day"
                    model: [{ label: "Same all day", value: "daily" }, { label: "Random", value: "random" }]
                    current: sc.cfg.quoteMode
                    onPicked: function (v) { sc.cfg.set("quoteMode", v); }
                }
                TRow {
                    th: sc.th
                    label: "Include the built-in quotes (" + sc.cfg.builtinQuotes.length + ")"
                    on: sc.cfg.useBuiltinQuotes
                    onToggled: sc.cfg.set("useBuiltinQuotes", !sc.cfg.useBuiltinQuotes)
                }
                Label2 {
                    th: sc.th
                    visible: sc.cfg.customQuotes.length > 0
                    text: "Your quotes"
                }
                Repeater {
                    model: sc.cfg.customQuotes
                    delegate: Rectangle {
                        id: qrow
                        required property int index
                        required property string modelData
                        width: pQuotes.width
                        height: Math.max(30, qtext.implicitHeight + 14)
                        radius: 5
                        color: sc.a(sc.th.dim, 0.08)
                        border.width: 1
                        border.color: sc.a(sc.th.dim, 0.18)
                        Text {
                            id: qtext
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            anchors.right: delBtn.left
                            anchors.rightMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            wrapMode: Text.Wrap
                            text: qrow.modelData
                            color: sc.th.bright
                            font.family: sc.th.font
                            font.pixelSize: 11
                        }
                        IconBtn {
                            id: delBtn
                            anchors.right: parent.right
                            anchors.rightMargin: 4
                            anchors.verticalCenter: parent.verticalCenter
                            box: 22
                            size: 10
                            glyph: "\u2715"
                            idle: sc.th.dim
                            hot: sc.th.accent
                            family: sc.th.font
                            onClicked: sc.cfg.removeQuote(qrow.index)
                        }
                    }
                }
                Field {
                    id: addQuote
                    width: parent.width
                    th: sc.th
                    label: "Add a quote (press Enter)"
                    placeholder: "Type a quote..."
                    onCommitted: function (v) {
                        if (v.trim() !== "") {
                            sc.cfg.addQuote(v);
                            addQuote.clear();
                        }
                    }
                }
            }

            // ───────── Music ─────────
            Column {
                id: pMusic
                width: parent.width
                visible: sc.section === "Music"
                spacing: 10

                Field {
                    width: parent.width
                    th: sc.th
                    label: "Background image or GIF"
                    placeholder: "empty = the album cover, blurred"
                    browse: true
                    text: sc.cfg.musicBg
                    onCommitted: function (v) { sc.cfg.set("musicBg", v.trim()); }
                    onBrowseRequested: sc.chooser.open("musicBg")
                }
                TRow { th: sc.th; label: "Background moves with the bass"; on: sc.cfg.bgReact; onToggled: sc.cfg.set("bgReact", !sc.cfg.bgReact) }
                TRow {
                    th: sc.th
                    label: sc.cava.available ? "Cava visualizer" : "Cava visualizer (cava is not installed)"
                    on: sc.cfg.cavaEnabled
                    onToggled: sc.cfg.set("cavaEnabled", !sc.cfg.cavaEnabled)
                }
                ChipRow {
                    th: sc.th
                    label: "Bars"
                    model: [{ label: "16", value: 16 }, { label: "24", value: 24 }, { label: "32", value: 32 }, { label: "48", value: 48 }]
                    current: sc.cfg.cavaBars
                    onPicked: function (v) { sc.cfg.set("cavaBars", v); }
                }
                ChipRow {
                    th: sc.th
                    label: "Cava audio input"
                    model: [{ label: "pipewire", value: "pipewire" }, { label: "pulse", value: "pulse" }]
                    current: sc.cfg.cavaMethod
                    onPicked: function (v) { sc.cfg.set("cavaMethod", v); }
                }
                TRow { th: sc.th; label: "Lyrics (from LRCLIB)"; on: sc.cfg.lyricsEnabled; onToggled: sc.cfg.set("lyricsEnabled", !sc.cfg.lyricsEnabled) }
                SliderRow {
                    th: sc.th
                    label: "Lyrics timing"
                    valueText: (sc.cfg.lyricsOffset > 0 ? "+" : "") + sc.cfg.lyricsOffset + " ms"
                    from: -2000
                    to: 2000
                    value: sc.cfg.lyricsOffset
                    onMoved: function (v) { sc.cfg.set("lyricsOffset", Math.round(v / 100) * 100); }
                }
                Label2 {
                    th: sc.th
                    width: parent.width
                    text: "Positive timing shows each line later, negative earlier. Use it when the lyrics run ahead of or behind the song."
                }
            }

            // ───────── Games ─────────
            Column {
                id: pGames
                width: parent.width
                visible: sc.section === "Games"
                spacing: 10

                TRow { th: sc.th; label: "Close the panel after launching a game"; on: sc.cfg.closeOnLaunch; onToggled: sc.cfg.set("closeOnLaunch", !sc.cfg.closeOnLaunch) }
                Field {
                    width: parent.width
                    th: sc.th
                    label: "Steam Web API key (lists games you don't have installed)"
                    placeholder: "paste the key here"
                    secret: true
                    text: sc.cfg.steamKey
                    onCommitted: function (v) { sc.cfg.set("steamKey", v.trim()); }
                }
                Field {
                    width: parent.width
                    th: sc.th
                    label: "SteamID64 (empty = detected from Steam)"
                    placeholder: "7656119..."
                    text: sc.cfg.steamId
                    onCommitted: function (v) { sc.cfg.set("steamId", v.trim()); }
                }
                Label2 {
                    th: sc.th
                    width: parent.width
                    text: "Get a free key at steamcommunity.com/dev/apikey (any domain name works). Your profile's game details must be public. The key is stored as plain text in settings.json."
                }
            }

            // ───────── Apps ─────────
            Column {
                id: pApps
                width: parent.width
                visible: sc.section === "Apps"
                spacing: 10

                Label2 {
                    th: sc.th
                    width: parent.width
                    text: "Extra buttons for the Home tab, next to Steam, Discord and Proton VPN."
                }
                Repeater {
                    model: sc.cfg.customApps
                    delegate: Rectangle {
                        id: arow
                        required property int index
                        required property var modelData
                        width: pApps.width
                        height: 40
                        radius: 5
                        color: sc.a(sc.th.dim, 0.08)
                        border.width: 1
                        border.color: sc.a(sc.th.dim, 0.18)
                        Column {
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            anchors.right: adel.left
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2
                            Text {
                                width: parent.width
                                elide: Text.ElideRight
                                text: arow.modelData.name
                                color: sc.th.bright
                                font.family: sc.th.font
                                font.pixelSize: 12
                                font.bold: true
                            }
                            Text {
                                width: parent.width
                                elide: Text.ElideRight
                                text: arow.modelData.cmd
                                color: sc.th.dim
                                font.family: sc.th.font
                                font.pixelSize: 10
                            }
                        }
                        IconBtn {
                            id: adel
                            anchors.right: parent.right
                            anchors.rightMargin: 4
                            anchors.verticalCenter: parent.verticalCenter
                            box: 24
                            size: 10
                            glyph: "\u2715"
                            idle: sc.th.dim
                            hot: sc.th.accent
                            family: sc.th.font
                            onClicked: sc.cfg.removeApp(arow.index)
                        }
                    }
                }
                Field {
                    id: appName
                    width: parent.width
                    th: sc.th
                    label: "Name"
                    placeholder: "e.g. Firefox"
                }
                Field {
                    id: appCmd
                    width: parent.width
                    th: sc.th
                    label: "Command"
                    placeholder: "e.g. firefox"
                }
                Text {
                    text: "Add button"
                    color: addMouse.containsMouse ? sc.th.bright : sc.th.accent
                    font.family: sc.th.font
                    font.pixelSize: 12
                    font.bold: true
                    MouseArea {
                        id: addMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            sc.cfg.addApp(appName.live, appCmd.live);
                            appName.clear();
                            appCmd.clear();
                        }
                    }
                }
            }

            // ───────── Special ─────────
            Column {
                id: pSpecial
                width: parent.width
                visible: sc.section === "Special" && sc.special && sc.special.specialVisible
                spacing: 10

                Label2 {
                    th: sc.th
                    width: parent.width
                    text: "An encrypted vault for the two of you: photos, quotes, sealed letters, a bucket list and moods. Everything sits in ONE gpg archive; the passphrase is never stored."
                }
                Label2 {
                    th: sc.th
                    width: parent.width
                    visible: !sc.special.unlocked
                    text: "Unlock the vault in the Special tab to edit your names, birthdays, the banner, or the passphrase."
                    color: sc.th.accent
                }

                Field {
                    width: parent.width
                    th: sc.th
                    label: "Your name"
                    placeholder: "you"
                    text: sc.special.profile.me.name
                    enabled: sc.special.unlocked
                    opacity: enabled ? 1 : 0.45
                    onCommitted: function (v) { sc.special.setPerson("me", "name", v.trim()); }
                }
                Field {
                    width: parent.width
                    th: sc.th
                    label: "Partner's name"
                    placeholder: "them"
                    text: sc.special.profile.partner.name
                    enabled: sc.special.unlocked
                    opacity: enabled ? 1 : 0.45
                    onCommitted: function (v) { sc.special.setPerson("partner", "name", v.trim()); }
                }
                Row {
                    width: parent.width
                    spacing: 8
                    Field {
                        width: (parent.width - 8) / 2
                        th: sc.th
                        label: "Your birthday"
                        placeholder: "YYYY-MM-DD"
                        text: sc.special.profile.birthdayMe
                        enabled: sc.special.unlocked
                        opacity: enabled ? 1 : 0.45
                        onCommitted: function (v) { sc.special.setMeta("birthdayMe", v.trim()); }
                    }
                    Field {
                        width: (parent.width - 8) / 2
                        th: sc.th
                        label: "Partner's birthday"
                        placeholder: "YYYY-MM-DD"
                        text: sc.special.profile.birthdayPartner
                        enabled: sc.special.unlocked
                        opacity: enabled ? 1 : 0.45
                        onCommitted: function (v) { sc.special.setMeta("birthdayPartner", v.trim()); }
                    }
                }

                Field {
                    width: parent.width
                    th: sc.th
                    label: "Vault folder"
                    placeholder: sc.cfg.home + "/Pictures/special"
                    text: sc.special.vaultPath
                    browse: true
                    onCommitted: function (v) { sc.special.setVaultPath(v); }
                    onBrowseRequested: sc.chooser.openDir("sp:vaultPath")
                }
                Label2 {
                    th: sc.th
                    width: parent.width
                    text: sc.special.vaultExists
                        ? "vault.gpg found in that folder."
                        : "No vault.gpg there yet: open the Special tab and create one."
                }

                Label2 {
                    th: sc.th
                    width: parent.width
                    text: "Banner. The wide picture at the top of Us; PNG, JPG or GIF. You can also click the banner itself."
                }
                Row {
                    spacing: 8
                    Btn {
                        th: sc.th
                        label: "Choose banner"
                        enabled: sc.special.unlocked
                        opacity: enabled ? 1 : 0.4
                        onClicked: sc.chooser.open("sp:banner")
                    }
                    Btn {
                        th: sc.th
                        label: "Remove"
                        enabled: sc.special.unlocked
                        opacity: enabled ? 1 : 0.4
                        onClicked: sc.special.removeBanner()
                    }
                }
                Label2 {
                    th: sc.th
                    width: parent.width
                    text: !sc.special.unlocked
                        ? "Unlock the vault to see or change the banner."
                        : (sc.special.profile.banner !== "" ? "A banner is saved inside the vault." : "No banner yet.")
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: sc.a(sc.th.dim, 0.25)
                }

                Label2 {
                    th: sc.th
                    width: parent.width
                    text: "Change passphrase (needs the vault unlocked). 12+ characters, not digits only."
                }
                Field {
                    id: spPass1
                    width: parent.width
                    th: sc.th
                    label: "New passphrase"
                    placeholder: "at least 12 characters"
                    secret: true
                }
                Field {
                    id: spPass2
                    width: parent.width
                    th: sc.th
                    label: "Repeat"
                    placeholder: "same again"
                    secret: true
                }
                Row {
                    spacing: 8
                    Btn {
                        th: sc.th
                        label: "Set passphrase"
                        primary: true
                        onClicked: {
                            if (spPass1.live !== spPass2.live) {
                                sc.special.error = "The two passphrases don't match.";
                                return;
                            }
                            sc.special.changePass(spPass1.live);
                            spPass1.clear();
                            spPass2.clear();
                        }
                    }
                    Btn {
                        th: sc.th
                        label: "Lock now"
                        onClicked: sc.special.lock()
                    }
                }
                Label2 {
                    th: sc.th
                    width: parent.width
                    visible: sc.special.error !== ""
                    text: sc.special.error
                    color: sc.th.accent
                }
                Label2 {
                    th: sc.th
                    width: parent.width
                    visible: sc.special.info !== ""
                    text: sc.special.info
                    color: sc.th.accent
                }

                ChipRow {
                    th: sc.th
                    label: "Auto-lock after"
                    model: [
                        { label: "1 min", value: 1 },
                        { label: "5 min", value: 5 },
                        { label: "10 min", value: 10 },
                        { label: "15 min", value: 15 },
                        { label: "1 hour", value: 60 }
                    ]
                    current: sc.special.autoLockMinutes
                    onPicked: function (v) {
                        sc.special.autoLockMinutes = v;
                        sc.special.savePrefs();
                    }
                }
                TRow {
                    th: sc.th
                    label: "Lock when the panel closes"
                    on: sc.special.lockOnClose
                    onToggled: {
                        sc.special.lockOnClose = !sc.special.lockOnClose;
                        sc.special.savePrefs();
                    }
                }
                Label2 {
                    th: sc.th
                    width: parent.width
                    text: "Protects the files on disk and in backups. Not a screenshot, a screen share while unlocked, or someone who knows the passphrase."
                    color: sc.a(sc.th.dim, 0.8)
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: sc.a(sc.th.dim, 0.25)
                }

                Label2 {
                    th: sc.th
                    width: parent.width
                    text: "The tab is secret. To bring it back: Settings > Look, then tap About seven times."
                }
                TRow {
                    th: sc.th
                    label: "Hide the tab behind the knock"
                    on: sc.special.specialSecret
                    onToggled: sc.special.setSpecialSecret(!sc.special.specialSecret)
                }
                Btn {
                    th: sc.th
                    visible: sc.special.specialSecret && sc.special.specialRevealed
                    label: "Hide it now"
                    onClicked: sc.special.hideSpecial()
                }
                Label2 {
                    th: sc.th
                    width: parent.width
                    visible: !sc.special.specialSecret
                    text: "The tab is always visible while this is off."
                }
            }

            // ───────── Look ─────────
            Column {
                id: pLook
                width: parent.width
                visible: sc.section === "Look"
                spacing: 10

                SliderRow {
                    th: sc.th
                    label: "Panel opacity"
                    valueText: Math.round(sc.cfg.panelOpacity * 100) + "%"
                    from: 0.5
                    to: 1
                    value: sc.cfg.panelOpacity
                    onMoved: function (v) { sc.cfg.set("panelOpacity", Math.round(v * 20) / 20); }
                }
                ChipRow {
                    th: sc.th
                    label: "Width"
                    model: [{ label: "Compact", value: 420 }, { label: "Normal", value: 460 }, { label: "Wide", value: 520 }]
                    current: sc.cfg.panelWidth
                    onPicked: function (v) { sc.cfg.set("panelWidth", v); }
                }
                ChipRow {
                    th: sc.th
                    label: "Corner radius"
                    model: [{ label: "Theme", value: -1 }, { label: "0", value: 0 }, { label: "6", value: 6 }, { label: "12", value: 12 }, { label: "18", value: 18 }]
                    current: sc.cfg.cornerRadius
                    onPicked: function (v) { sc.cfg.set("cornerRadius", v); }
                }
                Field {
                    width: parent.width
                    th: sc.th
                    label: "Accent colour (empty = Ryoku palette)"
                    placeholder: "#e8553a"
                    text: sc.cfg.accentOverride
                    onCommitted: function (v) { sc.cfg.set("accentOverride", v.trim()); }
                }
                Label2 {
                    th: sc.th
                    width: parent.width
                    visible: sc.cfg.accentOverride.trim() !== "" && !sc.cfg.accentValid
                    text: "Use the form #rrggbb."
                    color: sc.th.accent
                }
                Label2 {
                    th: sc.th
                    width: parent.width
                    text: "Blur behind the panel is a Hyprland layer rule for the namespace media-panel; it is not set here."
                }

                Item {
                    width: parent.width
                    height: 24
                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "About"
                        color: sc.th.dim
                        font.family: sc.th.font
                        font.pixelSize: 10
                    }
                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: "media panel"
                        color: sc.a(sc.th.dim, 0.6)
                        font.family: sc.th.font
                        font.pixelSize: 8
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: sc.knock()
                    }
                }
            }
        }
    }
}
