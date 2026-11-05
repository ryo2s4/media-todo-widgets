import QtQuick
import QtQuick.Effects
import Quickshell.Services.Mpris

// Music tab: a "stage". The background is your own image / GIF (Settings > Music)
// or the blurred album cover; it zooms with the bass when Cava is running. The
// cover spins like a record while a song plays, Cava bars run along the bottom,
// and the "Lyrics" switch shows time-synced lyrics from LRCLIB.
Item {
    id: tab

    property var th
    property var cfg
    property var cava
    property bool active: false

    // -1 = automatic (the player that is playing), otherwise the player index
    property int pick: -1
    readonly property var list: Mpris.players.values
    readonly property var player: {
        var l = list;
        if (!l || l.length === 0)
            return null;
        if (pick >= 0 && pick < l.length)
            return l[pick];
        for (var i = 0; i < l.length; i++)
            if (l[i].isPlaying)
                return l[i];
        return l[0];
    }
    readonly property bool isPlaying: player !== null && player.isPlaying
    readonly property real progress: (player && player.lengthSupported && player.length > 0) ? Math.min(1, player.position / player.length) : 0
    readonly property string artUrl: player ? player.trackArtUrl : ""
    readonly property real bass: (cava && cfg && cfg.bgReact) ? cava.bass : 0

    readonly property string bgPath: cfg ? cfg.musicBg : ""
    readonly property bool bgIsAnim: /\.(gif|webp|apng)$/i.test(bgPath)
    readonly property string bgUrl: bgPath !== "" ? "file://" + bgPath : ""

    property bool showLyrics: false

    function a(c, v) { return Qt.rgba(c.r, c.g, c.b, v); }
    function fmt(sec) {
        sec = Math.max(0, Math.floor(sec));
        var m = Math.floor(sec / 60);
        var s = sec % 60;
        return m + ":" + (s < 10 ? "0" : "") + s;
    }

    // used by the panel's keyboard shortcuts
    function toggle() { if (player && player.canTogglePlaying) player.togglePlaying(); }
    function next() { if (player && player.canGoNext) player.next(); }
    function prev() { if (player && player.canGoPrevious) player.previous(); }
    function volumeBy(d) {
        if (player && player.volumeSupported)
            player.volume = Math.max(0, Math.min(1, player.volume + d));
    }

    // MPRIS does not push position updates, so ask for them (faster while lyrics show)
    Timer {
        interval: tab.showLyrics ? 250 : 1000
        repeat: true
        running: tab.active && tab.isPlaying
        onTriggered: tab.player.positionChanged()
    }

    // ───────── lyrics ─────────
    Lyrics {
        id: lyr
        enabled: tab.cfg ? (tab.cfg.lyricsEnabled && tab.active) : false
        artist: tab.player ? tab.player.trackArtist : ""
        title: tab.player ? tab.player.trackTitle : ""
        album: tab.player ? tab.player.trackAlbum : ""
        duration: (tab.player && tab.player.lengthSupported) ? tab.player.length : 0
    }

    // index of the line being sung (-1 before the first line)
    readonly property int curIdx: {
        var ls = lyr.lines;
        if (!player || ls.length === 0)
            return -1;
        var p = player.position - (cfg ? cfg.lyricsOffset : 0) / 1000;
        var lo = 0;
        var hi = ls.length - 1;
        var ans = -1;
        while (lo <= hi) {
            var mid = (lo + hi) >> 1;
            if (ls[mid].t <= p) {
                ans = mid;
                lo = mid + 1;
            } else {
                hi = mid - 1;
            }
        }
        return ans;
    }

    // ───────── the stage ─────────
    Rectangle {
        id: stage
        anchors.fill: parent
        radius: tab.th.radius
        color: tab.th.cardBot
        border.width: 1
        border.color: tab.a(tab.th.accent, 0.3)
        clip: true

        // background layer (zooms slightly with the bass)
        Item {
            id: bg
            anchors.fill: parent
            scale: 1.04 + tab.bass * 0.07
            Behavior on scale { NumberAnimation { duration: 90 } }

            AnimatedImage {
                anchors.fill: parent
                visible: tab.bgPath !== "" && tab.bgIsAnim
                source: (tab.bgPath !== "" && tab.bgIsAnim) ? tab.bgUrl : ""
                playing: tab.isPlaying
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }
            Image {
                anchors.fill: parent
                visible: tab.bgPath !== "" && !tab.bgIsAnim
                source: (tab.bgPath !== "" && !tab.bgIsAnim) ? tab.bgUrl : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }

            // no custom background: the album cover, blurred
            Image {
                id: blurSrc
                anchors.fill: parent
                visible: false
                source: tab.bgPath === "" ? tab.artUrl : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }
            MultiEffect {
                anchors.fill: parent
                source: blurSrc
                visible: tab.bgPath === "" && blurSrc.status === Image.Ready
                blurEnabled: true
                blur: 1.0
                blurMax: 64
                brightness: -0.05
                saturation: 0.3
            }
        }

        // dark scrim so text stays readable
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: tab.a(tab.th.cardBot, 0.45) }
                GradientStop { position: 0.6; color: tab.a(tab.th.cardBot, 0.72) }
                GradientStop { position: 1.0; color: tab.a(tab.th.cardBot, 0.92) }
            }
        }
        Rectangle {
            anchors.fill: parent
            color: tab.th.accent
            opacity: tab.bass * 0.18
        }

        // ── nothing playing ──
        Column {
            anchors.centerIn: parent
            visible: tab.player === null
            spacing: 8
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "\u266A"
                color: tab.th.dim
                font.family: tab.th.font
                font.pixelSize: 44
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "No player running"
                color: tab.th.bright
                font.family: tab.th.font
                font.pixelSize: 13
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Start Spotify, mpv or a browser tab"
                color: tab.th.dim
                font.family: tab.th.font
                font.pixelSize: 11
            }
        }

        // lyrics switch
        Text {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 12
            z: 5
            visible: tab.player !== null && !!tab.cfg && tab.cfg.lyricsEnabled
            text: "Lyrics"
            color: tab.showLyrics ? tab.th.accent : (lyrMouse.containsMouse ? tab.th.bright : tab.th.dim)
            font.family: tab.th.font
            font.pixelSize: 11
            font.bold: tab.showLyrics
            MouseArea {
                id: lyrMouse
                anchors.fill: parent
                anchors.margins: -6
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: tab.showLyrics = !tab.showLyrics
            }
        }

        // ── now playing ──
        Column {
            id: view
            visible: tab.player !== null
            anchors.top: parent.top
            anchors.topMargin: 18
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - 36
            spacing: 12

            // cover (a record) or lyrics
            Item {
                id: coverArea
                width: parent.width
                readonly property real coverSize: Math.min(parent.width - 40, 210, Math.max(110, tab.height - 380))
                height: tab.showLyrics ? Math.max(coverSize, 170) : coverSize

                Item {
                    id: coverBox
                    anchors.centerIn: parent
                    width: coverArea.coverSize
                    height: width
                    visible: !tab.showLyrics

                    // glow ring that breathes with the bass
                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width + 18
                        height: width
                        radius: width / 2
                        color: "transparent"
                        border.width: 3
                        border.color: tab.th.accent
                        opacity: 0.25 + tab.bass * 0.6
                        scale: 1 + tab.bass * 0.06
                        Behavior on scale { NumberAnimation { duration: 90 } }
                    }

                    Item {
                        id: disc
                        anchors.fill: parent

                        RotationAnimator on rotation {
                            from: 0
                            to: 360
                            duration: 16000
                            loops: Animation.Infinite
                            running: tab.isPlaying && !tab.showLyrics
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                            color: "#0b0b0e"
                            border.width: 1
                            border.color: tab.a(tab.th.dim, 0.5)
                        }
                        RoundImage {
                            id: coverImg
                            anchors.centerIn: parent
                            width: parent.width - 14
                            height: width
                            source: tab.artUrl
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: coverImg.status !== Image.Ready
                            text: "\u266A"
                            color: tab.th.dim
                            font.family: tab.th.font
                            font.pixelSize: 70
                        }
                        Rectangle {
                            anchors.centerIn: parent
                            width: 26
                            height: 26
                            radius: 13
                            color: tab.th.cardBot
                            border.width: 2
                            border.color: tab.a(tab.th.accent, 0.8)
                        }
                    }
                }

                // synced lyrics
                ListView {
                    id: lyricList
                    anchors.fill: parent
                    visible: tab.showLyrics && lyr.lines.length > 0
                    clip: true
                    interactive: false
                    model: lyr.lines
                    currentIndex: tab.curIdx
                    highlightRangeMode: ListView.StrictlyEnforceRange
                    preferredHighlightBegin: height / 2 - 18
                    preferredHighlightEnd: height / 2 + 18
                    highlightMoveDuration: 350
                    delegate: Text {
                        required property int index
                        required property var modelData
                        width: lyricList.width
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                        topPadding: 3
                        bottomPadding: 3
                        text: modelData.text !== "" ? modelData.text : "\u00B7"
                        color: index === tab.curIdx ? tab.th.bright : tab.a(tab.th.dim, 0.9)
                        font.family: tab.th.font
                        font.pixelSize: index === tab.curIdx ? 15 : 12
                        font.bold: index === tab.curIdx
                    }
                }

                // plain (not timed) lyrics
                Flickable {
                    anchors.fill: parent
                    visible: tab.showLyrics && lyr.lines.length === 0 && lyr.plain !== ""
                    contentWidth: width
                    contentHeight: plainText.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    Text {
                        id: plainText
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                        text: lyr.plain
                        color: tab.th.bright
                        font.family: tab.th.font
                        font.pixelSize: 12
                        lineHeight: 1.2
                    }
                }

                Text {
                    anchors.centerIn: parent
                    width: parent.width - 20
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    visible: tab.showLyrics && lyr.lines.length === 0 && lyr.plain === ""
                    text: lyr.status === "loading" ? "Looking for lyrics..." : "No lyrics found for this track"
                    color: tab.th.dim
                    font.family: tab.th.font
                    font.pixelSize: 12
                }
            }

            Column {
                width: parent.width
                spacing: 3
                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: tab.player && tab.player.trackTitle !== "" ? tab.player.trackTitle : "Unknown title"
                    color: tab.th.bright
                    font.family: tab.th.font
                    font.pixelSize: 16
                    font.bold: true
                }
                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: tab.player ? tab.player.trackArtist : ""
                    color: tab.th.accent
                    font.family: tab.th.font
                    font.pixelSize: 12
                }
                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    visible: tab.player !== null && tab.player.trackAlbum !== ""
                    text: tab.player ? tab.player.trackAlbum : ""
                    color: tab.th.dim
                    font.family: tab.th.font
                    font.pixelSize: 11
                }
            }

            // seek bar
            Column {
                width: parent.width
                spacing: 5
                Rectangle {
                    id: seek
                    width: parent.width
                    height: 4
                    radius: 2
                    color: tab.a(tab.th.dim, 0.3)
                    Rectangle {
                        height: parent.height
                        radius: 2
                        color: tab.th.accent
                        width: parent.width * tab.progress
                    }
                    MouseArea {
                        anchors.fill: parent
                        anchors.topMargin: -8
                        anchors.bottomMargin: -8
                        enabled: tab.player !== null && tab.player.canSeek && tab.player.lengthSupported
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: function (mouse) {
                            tab.player.position = Math.max(0, Math.min(1, mouse.x / seek.width)) * tab.player.length;
                        }
                    }
                }
                Item {
                    width: parent.width
                    height: 14
                    Text {
                        anchors.left: parent.left
                        text: tab.player ? tab.fmt(tab.player.position) : ""
                        color: tab.th.dim
                        font.family: tab.th.font
                        font.pixelSize: 10
                    }
                    Text {
                        anchors.right: parent.right
                        text: (tab.player && tab.player.lengthSupported) ? tab.fmt(tab.player.length) : ""
                        color: tab.th.dim
                        font.family: tab.th.font
                        font.pixelSize: 10
                    }
                }
            }

            // controls
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 18
                IconBtn {
                    box: 38
                    size: 20
                    glyph: "\u23EE"
                    opacity: (tab.player && tab.player.canGoPrevious) ? 1 : 0.35
                    idle: tab.th.bright
                    hot: tab.th.accent
                    family: tab.th.font
                    onClicked: tab.prev()
                }
                IconBtn {
                    box: 46
                    size: 28
                    glyph: tab.isPlaying ? "\u275A\u275A" : "\u25B6"
                    on: tab.isPlaying
                    idle: tab.th.bright
                    hot: tab.th.accent
                    family: tab.th.font
                    onClicked: tab.toggle()
                }
                IconBtn {
                    box: 38
                    size: 20
                    glyph: "\u23ED"
                    opacity: (tab.player && tab.player.canGoNext) ? 1 : 0.35
                    idle: tab.th.bright
                    hot: tab.th.accent
                    family: tab.th.font
                    onClicked: tab.next()
                }
            }

            // volume
            Row {
                visible: tab.player !== null && tab.player.volumeSupported
                width: parent.width
                spacing: 10
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "vol"
                    color: tab.th.dim
                    font.family: tab.th.font
                    font.pixelSize: 10
                }
                Slider {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 70
                    th: tab.th
                    from: 0
                    to: 1
                    value: tab.player ? tab.player.volume : 0
                    onMoved: function (v) { tab.player.volume = v; }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: tab.player ? Math.round(tab.player.volume * 100) + "%" : ""
                    color: tab.th.dim
                    font.family: tab.th.font
                    font.pixelSize: 10
                }
            }
        }

        // ── Cava bars along the bottom ──
        Item {
            id: bars
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            anchors.bottomMargin: 26
            height: 64
            visible: tab.player !== null && tab.cava !== undefined && tab.cava.available && tab.cfg.cavaEnabled

            Row {
                anchors.fill: parent
                spacing: 3
                Repeater {
                    model: tab.cava ? tab.cava.bars : 0
                    delegate: Item {
                        id: barSlot
                        required property int index
                        width: (bars.width - 3 * (tab.cava.bars - 1)) / tab.cava.bars
                        height: bars.height
                        readonly property real lvl: (tab.cava.levels.length > index) ? tab.cava.levels[index] : 0
                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: parent.width
                            height: Math.max(3, barSlot.lvl * bars.height)
                            radius: Math.min(width / 2, 3)
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: tab.th.accent }
                                GradientStop { position: 1.0; color: tab.a(tab.th.accent, 0.35) }
                            }
                        }
                    }
                }
            }
        }

        // hints under the stage
        Text {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 8
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: {
                if (!tab.player)
                    return "";
                var s = tab.player.identity;
                if (tab.list.length > 1)
                    s += "   \u00B7   click to switch player";
                if (tab.cava !== undefined && !tab.cava.available && tab.cfg.cavaEnabled)
                    s += "   \u00B7   install cava for the visualizer";
                return s;
            }
            color: tab.a(tab.th.dim, 0.95)
            font.family: tab.th.font
            font.pixelSize: 10
            MouseArea {
                anchors.fill: parent
                enabled: tab.list.length > 1
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: tab.pick = (tab.pick + 2) % (tab.list.length + 1) - 1
            }
        }
    }
}
