import QtQuick

// The top of the Home tab.
//  - Your picture sits in the bottom-left corner of the banner: large, no frame.
//  - The arc to its right shows the current period. By day it runs from sunrise to
//    sunset with the sun on it; at night from sunset to the next sunrise with the
//    moon on it, drawn with its real phase. A dotted line drops from the marker to the
//    horizon, and the part already travelled is drawn solid.
//  - The background is your banner image, or a plain sky for the time of day with a
//    warm glow at dawn and dusk and stars at night.
Item {
    id: dl

    property var th
    property var cfg
    property var weather
    property date now: new Date()
    property bool active: false
    property url avatar
    property string greeting: ""
    property string userName: ""
    property string subtitle: ""
    property var frames
    property bool animGif: false
    property string frameToast: ""
    signal avatarClicked()

    implicitHeight: 210
    height: implicitHeight

    // ───────── time ─────────
    readonly property real hour: now.getHours() + now.getMinutes() / 60
    readonly property bool wxOn: !!weather && !!cfg && cfg.weatherEnabled && weather.ready
    readonly property real sr: wxOn ? weather.sunrise : 6
    readonly property real ss: wxOn ? weather.sunset : 18
    readonly property bool day: hour >= sr && hour < ss
    readonly property string kind: wxOn ? weather.kind : "clear"

    // progress through the current period (day: sunrise to sunset, night: sunset to sunrise)
    readonly property real startH: day ? sr : ss
    readonly property real endH: day ? ss : sr + 24
    readonly property real hAdj: (!day && hour < sr) ? hour + 24 : hour
    readonly property real prog: Math.max(0, Math.min(1, (hAdj - startH) / Math.max(0.1, endH - startH)))
    readonly property real untilEnd: Math.max(0, endH - hAdj)

    readonly property real sinceSet: hour >= ss ? hour - ss : hour + 24 - ss
    readonly property real untilRise: hour < sr ? sr - hour : sr + 24 - hour
    readonly property real nightAmt: day ? 0 : Math.min(1, Math.min(sinceSet, untilRise))
    readonly property real twilight: Math.max(0, 1 - Math.min(Math.abs(hour - sr), Math.abs(hour - ss)) / 1.6)

    readonly property real moonP: {
        var days = (now.getTime() - Date.UTC(2000, 0, 6, 18, 14)) / 86400000;
        var p = (days % 29.530588853) / 29.530588853;
        return p < 0 ? p + 1 : p;
    }

    readonly property color sunTone: "#f6c453"
    readonly property color moonTone: "#dfe6ff"
    readonly property color tone: day ? sunTone : moonTone

    readonly property string bannerPath: cfg ? cfg.bannerPath : ""
    readonly property bool hasBanner: bannerPath !== ""
    readonly property bool bannerAnim: /\.(gif|webp|apng)$/i.test(bannerPath)
    readonly property real dim: cfg ? cfg.bannerDim : 0.45

    // layout
    readonly property real avatarSize: 98
    // profile frame: a ring (static or animated) goes around the picture, a sticker sits on its edge
    readonly property var frameDef: (frames && cfg && cfg.avatarFrame !== "") ? frames.get(cfg.avatarFrame) : null
    readonly property bool ringFrame: frameDef !== null && frameDef.kind !== "sticker"
    readonly property bool stickerFrame: frameDef !== null && frameDef.kind === "sticker"
    readonly property bool frameAnim: frameDef !== null && frameDef.kind === "anim"
    readonly property real boxSize: ringFrame ? 136 : avatarSize
    readonly property real picD: ringFrame ? boxSize * frameDef.hole * 0.97 : avatarSize
    onFrameDefChanged: animGif = false
    readonly property real arcL: 10 + boxSize + 20
    readonly property real arcR: width - 22
    readonly property real arcW: arcR - arcL
    readonly property real hy: 104          // horizon line
    readonly property real arcH: 46         // height of the arc above the horizon

    function a(c, v) { return Qt.rgba(c.r, c.g, c.b, v); }
    function pad(n) { return (n < 10 ? "0" : "") + n; }
    function hhmm(h) {
        var m = Math.round(h * 60);
        return pad(Math.floor(m / 60) % 24) + ":" + pad(m % 60);
    }
    function hm(h) {
        var m = Math.round(h * 60);
        return Math.floor(m / 60) + "h " + pad(m % 60) + "m";
    }
    function mix(c1, c2, t) { return [c1[0] + (c2[0] - c1[0]) * t, c1[1] + (c2[1] - c1[1]) * t, c1[2] + (c2[2] - c1[2]) * t]; }
    function col(c) { return Qt.rgba(c[0] / 255, c[1] / 255, c[2] / 255, 1); }
    function rnd(n) { var x = Math.sin(n * 12.9898) * 43758.5453; return x - Math.floor(x); }

    // sky colours for the current hour, shifted by the real sunrise and sunset
    readonly property var skyPair: {
        var h = hour;
        var r = sr;
        var s = ss;
        var N1 = [9, 13, 30];
        var N2 = [26, 34, 68];
        var keys = [
            [0, N1, N2],
            [r - 1.2, [22, 26, 60], [64, 52, 92]],
            [r + 0.6, [62, 74, 136], [236, 164, 112]],
            [r + 3.5, [72, 132, 208], [172, 214, 246]],
            [s - 3.5, [72, 126, 204], [166, 206, 244]],
            [s - 0.4, [72, 54, 114], [244, 128, 90]],
            [s + 1.6, [20, 24, 54], [62, 44, 84]],
            [24, N1, N2]
        ];
        var top = keys[0][1];
        var bot = keys[0][2];
        for (var i = 0; i < keys.length - 1; i++) {
            if (h >= keys[i][0] && h <= keys[i + 1][0]) {
                var span = keys[i + 1][0] - keys[i][0];
                var t = span > 0 ? (h - keys[i][0]) / span : 0;
                top = mix(keys[i][1], keys[i + 1][1], t);
                bot = mix(keys[i][2], keys[i + 1][2], t);
                break;
            }
        }
        var g = (kind === "clear") ? 0 : (kind === "fog" ? 0.55 : 0.4);
        if (g > 0) {
            top = mix(top, [96, 102, 114], g);
            bot = mix(bot, [120, 126, 136], g);
        }
        return [top, bot];
    }

    function cycleFrame() {
        if (!frames || !cfg)
            return;
        var id = frames.nextId(cfg.avatarFrame);
        cfg.set("avatarFrame", id);
        var d = frames.get(id);
        frameToast = d ? d.name : "No frame";
        toastTimer.restart();
    }

    Timer {
        id: toastTimer
        interval: 1800
    }

    function moonName() {
        var names = ["New moon", "Waxing crescent", "First quarter", "Waxing gibbous", "Full moon", "Waning gibbous", "Last quarter", "Waning crescent"];
        var illum = (1 - Math.cos(2 * Math.PI * moonP)) / 2;
        return names[Math.floor(moonP * 8 + 0.5) % 8] + "  " + Math.round(illum * 100) + "%";
    }

    // ───────── the banner ─────────
    Rectangle {
        id: frame
        anchors.fill: parent
        radius: dl.th.radius
        color: dl.th.cardBot
        border.width: 1
        border.color: dl.a(dl.th.dim, 0.3)
        clip: true

        // sky
        Rectangle {
            anchors.fill: parent
            visible: !dl.hasBanner
            gradient: Gradient {
                GradientStop { position: 0.0; color: dl.col(dl.skyPair[0]) }
                GradientStop { position: 1.0; color: dl.col(dl.skyPair[1]) }
            }
        }
        // warm glow along the horizon at dawn and dusk
        Rectangle {
            visible: !dl.hasBanner
            x: 0
            y: dl.hy - 70
            width: parent.width
            height: 110
            opacity: dl.twilight * 0.55
            gradient: Gradient {
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.75; color: "#ff9a5a" }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }
        // stars
        Repeater {
            model: (!dl.hasBanner && dl.nightAmt > 0.02) ? 38 : 0
            delegate: Rectangle {
                required property int index
                x: dl.rnd(index + 1) * (frame.width - 4)
                y: dl.rnd(index + 101) * (dl.hy - 14)
                width: index % 9 === 0 ? 2 : 1
                height: width
                color: "#ffffff"
                opacity: dl.nightAmt * (0.35 + 0.5 * dl.rnd(index + 7))
            }
        }

        // your own banner
        AnimatedImage {
            anchors.fill: parent
            visible: dl.hasBanner && dl.bannerAnim
            source: (dl.hasBanner && dl.bannerAnim) ? "file://" + dl.bannerPath : ""
            playing: dl.active
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }
        Image {
            anchors.fill: parent
            visible: dl.hasBanner && !dl.bannerAnim
            source: (dl.hasBanner && !dl.bannerAnim) ? "file://" + dl.bannerPath : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }
        // keeps text readable on any background
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, dl.hasBanner ? dl.dim * 0.6 : 0.06) }
                GradientStop { position: 0.55; color: Qt.rgba(0, 0, 0, dl.hasBanner ? dl.dim * 0.5 : 0.0) }
                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, dl.hasBanner ? Math.min(0.88, dl.dim + 0.35) : 0.50) }
            }
        }

        WeatherFx {
            anchors.fill: parent
            kind: dl.kind
            running: dl.active
            visible: dl.wxOn && !!dl.cfg && dl.cfg.weatherFx
        }

        // ── clock and date ──
        Column {
            x: 16
            y: 12
            spacing: 0
            Text {
                text: Qt.formatDateTime(dl.now, "hh:mm")
                color: "#ffffff"
                style: Text.Outline
                styleColor: "#44000000"
                font.family: dl.th.font
                font.pixelSize: 32
                font.bold: true
            }
            Text {
                text: Qt.formatDateTime(dl.now, "dddd, d MMMM")
                color: "#f2f2f2"
                style: Text.Outline
                styleColor: "#44000000"
                font.family: dl.th.font
                font.pixelSize: 11
            }
        }

        // ── weather ──
        Column {
            anchors.right: parent.right
            anchors.rightMargin: 16
            y: 12
            spacing: 0
            visible: dl.wxOn
            Text {
                anchors.right: parent.right
                text: dl.wxOn ? Math.round(dl.weather.temp) + dl.weather.unitSym : ""
                color: "#ffffff"
                style: Text.Outline
                styleColor: "#44000000"
                font.family: dl.th.font
                font.pixelSize: 22
                font.bold: true
            }
            Text {
                anchors.right: parent.right
                text: dl.wxOn ? dl.weather.desc : ""
                color: "#f2f2f2"
                style: Text.Outline
                styleColor: "#44000000"
                font.family: dl.th.font
                font.pixelSize: 11
            }
            Text {
                anchors.right: parent.right
                text: dl.wxOn ? dl.weather.place : ""
                color: "#dcdcdc"
                style: Text.Outline
                styleColor: "#44000000"
                font.family: dl.th.font
                font.pixelSize: 9
            }
        }

        // ── the arc: sun by day, moon by night ──
        Canvas {
            id: arc
            x: dl.arcL
            y: 0
            width: dl.arcW
            height: dl.hy + 16

            property real prog: dl.prog
            property bool isDay: dl.day
            property real moon: dl.moonP
            property string toneKey: dl.tone.toString()
            onProgChanged: requestPaint()
            onIsDayChanged: requestPaint()
            onMoonChanged: requestPaint()
            onToneKeyChanged: requestPaint()
            onWidthChanged: requestPaint()
            Component.onCompleted: requestPaint()

            onPaint: {
                var ctx = getContext("2d");
                ctx.reset();
                var W = width;
                var hy = dl.hy;
                var A = dl.arcH;
                function pt(t) { return [t * W, hy - A * Math.sin(Math.PI * t)]; }

                // horizon
                ctx.strokeStyle = "rgba(255,255,255,0.30)";
                ctx.lineWidth = 1;
                ctx.beginPath();
                ctx.moveTo(0, hy + 0.5);
                ctx.lineTo(W, hy + 0.5);
                ctx.stroke();

                // the whole path as dots
                ctx.fillStyle = "rgba(255,255,255,0.42)";
                for (var t = 0; t <= 1.0001; t += 0.02) {
                    var d = pt(t);
                    ctx.fillRect(d[0] - 0.75, d[1] - 0.75, 1.5, 1.5);
                }

                // the part already travelled, solid
                ctx.strokeStyle = toneKey;
                ctx.lineWidth = 2;
                ctx.lineCap = "round";
                ctx.beginPath();
                for (var k = 0; k <= 40; k++) {
                    var q = pt(prog * k / 40);
                    if (k === 0)
                        ctx.moveTo(q[0], q[1]);
                    else
                        ctx.lineTo(q[0], q[1]);
                }
                ctx.stroke();

                // both ends on the horizon
                ctx.fillStyle = toneKey;
                ctx.beginPath();
                ctx.arc(0, hy, 3, 0, Math.PI * 2);
                ctx.fill();
                ctx.beginPath();
                ctx.arc(W, hy, 3, 0, Math.PI * 2);
                ctx.fill();

                var m = pt(prog);
                var cx = m[0];
                var cy = m[1];

                // line down to the horizon
                ctx.strokeStyle = "rgba(255,255,255,0.25)";
                ctx.lineWidth = 1;
                ctx.beginPath();
                ctx.moveTo(cx + 0.5, cy + 16);
                ctx.lineTo(cx + 0.5, hy);
                ctx.stroke();

                if (isDay) {
                    var g = ctx.createRadialGradient(cx, cy, 2, cx, cy, 32);
                    g.addColorStop(0, "rgba(255,214,120,0.55)");
                    g.addColorStop(1, "rgba(255,214,120,0)");
                    ctx.fillStyle = g;
                    ctx.fillRect(cx - 34, cy - 34, 68, 68);
                    ctx.strokeStyle = "rgba(255,226,150,0.9)";
                    ctx.lineWidth = 1.6;
                    for (var r = 0; r < 10; r++) {
                        var an = r * Math.PI / 5;
                        ctx.beginPath();
                        ctx.moveTo(cx + Math.cos(an) * 13, cy + Math.sin(an) * 13);
                        ctx.lineTo(cx + Math.cos(an) * 18, cy + Math.sin(an) * 18);
                        ctx.stroke();
                    }
                    ctx.fillStyle = "rgba(255,240,196,1)";
                    ctx.beginPath();
                    ctx.arc(cx, cy, 9, 0, Math.PI * 2);
                    ctx.fill();
                } else {
                    var mg = ctx.createRadialGradient(cx, cy, 2, cx, cy, 28);
                    mg.addColorStop(0, "rgba(210,222,255,0.40)");
                    mg.addColorStop(1, "rgba(210,222,255,0)");
                    ctx.fillStyle = mg;
                    ctx.fillRect(cx - 30, cy - 30, 60, 60);

                    // the moon with its real phase
                    var R = 11;
                    ctx.fillStyle = "rgba(223,230,255,0.22)";
                    ctx.beginPath();
                    ctx.arc(cx, cy, R, 0, Math.PI * 2);
                    ctx.fill();
                    var kk = Math.cos(2 * Math.PI * moon);
                    var waxing = moon < 0.5;
                    var N = 24;
                    ctx.fillStyle = "rgba(240,244,255,1)";
                    ctx.beginPath();
                    for (var i = 0; i <= N; i++) {
                        var y = -R + (2 * R * i / N);
                        var s = Math.sqrt(Math.max(0, R * R - y * y));
                        var x = waxing ? cx + s : cx - s;
                        if (i === 0)
                            ctx.moveTo(x, cy + y);
                        else
                            ctx.lineTo(x, cy + y);
                    }
                    for (var j = N; j >= 0; j--) {
                        var y2 = -R + (2 * R * j / N);
                        var s2 = Math.sqrt(Math.max(0, R * R - y2 * y2));
                        ctx.lineTo(waxing ? cx + kk * s2 : cx - kk * s2, cy + y2);
                    }
                    ctx.closePath();
                    ctx.fill();
                }
            }
        }

        // end labels and captions under the horizon
        Text {
            x: dl.arcL - width / 2
            y: dl.hy + 8
            text: dl.hhmm(dl.startH)
            color: "#ffffff"
            opacity: 0.75
            font.family: dl.th.font
            font.pixelSize: 9
        }
        Text {
            x: dl.arcR - width / 2
            y: dl.hy + 8
            text: dl.hhmm(dl.endH)
            color: "#ffffff"
            opacity: 0.75
            font.family: dl.th.font
            font.pixelSize: 9
        }
        Column {
            x: dl.arcL + dl.arcW / 2 - width / 2
            y: dl.hy + 8
            spacing: 2
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: (dl.day ? "Sunset in " : "Sunrise in ") + dl.hm(dl.untilEnd)
                color: "#ffffff"
                opacity: 0.85
                font.family: dl.th.font
                font.pixelSize: 10
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: dl.day ? dl.hm(dl.ss - dl.sr) + " of daylight" : dl.moonName()
                color: "#ffffff"
                opacity: 0.6
                font.family: dl.th.font
                font.pixelSize: 9
            }
        }

        // ── greeting, to the right of the picture ──
        Column {
            x: dl.arcL - 4
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 16
            width: parent.width - x - 14
            spacing: 1
            Text {
                width: parent.width
                elide: Text.ElideRight
                text: dl.greeting
                color: "#ffffff"
                style: Text.Outline
                styleColor: "#55000000"
                font.family: dl.th.font
                font.pixelSize: 19
                font.bold: true
            }
            Text {
                width: parent.width
                elide: Text.ElideRight
                text: dl.userName + (dl.subtitle !== "" ? "   \u00B7   " + dl.subtitle : "")
                color: "#ffffff"
                opacity: 0.85
                style: Text.Outline
                styleColor: "#55000000"
                font.family: dl.th.font
                font.pixelSize: 12
            }
        }

        // ── your picture: bottom-left corner, large, no frame of its own ──
        Item {
            id: pic
            x: 10
            y: parent.height - dl.boxSize - 10
            width: dl.boxSize
            height: dl.boxSize
            readonly property real acx: width * (dl.ringFrame ? dl.frameDef.cx : 0.5)
            readonly property real acy: height * (dl.ringFrame ? dl.frameDef.cy : 0.5)
            scale: picMouse.containsMouse ? 1.02 : 1
            Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

            // soft shadow instead of a border
            Rectangle {
                x: pic.acx - width / 2
                y: pic.acy - height / 2 + 4
                width: dl.picD + 10
                height: width
                radius: width / 2
                color: "#000000"
                opacity: 0.14
            }
            Rectangle {
                x: pic.acx - width / 2
                y: pic.acy - height / 2 + 3
                width: dl.picD + 4
                height: width
                radius: width / 2
                color: "#000000"
                opacity: 0.22
            }
            RoundImage {
                id: avatarImg
                x: pic.acx - dl.picD / 2
                y: pic.acy - dl.picD / 2
                width: dl.picD
                height: dl.picD
                source: dl.avatar
            }
            Rectangle {
                x: pic.acx - dl.picD / 2
                y: pic.acy - dl.picD / 2
                width: dl.picD
                height: dl.picD
                radius: width / 2
                visible: avatarImg.status !== Image.Ready
                color: dl.a(dl.th.accent, 0.35)
                Text {
                    anchors.centerIn: parent
                    text: dl.userName !== "" ? dl.userName.charAt(0).toUpperCase() : "?"
                    color: "#ffffff"
                    font.family: dl.th.font
                    font.pixelSize: 38
                    font.bold: true
                }
            }

            // ring frames go over the picture
            Image {
                anchors.fill: parent
                visible: dl.ringFrame && !dl.frameAnim
                source: (dl.ringFrame && !dl.frameAnim) ? dl.frames.fileUrl(dl.frameDef) : ""
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                smooth: true
                mipmap: true
            }
            AnimatedImage {
                anchors.fill: parent
                visible: dl.ringFrame && dl.frameAnim
                source: (dl.ringFrame && dl.frameAnim) ? (dl.animGif ? dl.frames.gifUrl(dl.frameDef) : dl.frames.fileUrl(dl.frameDef)) : ""
                playing: dl.active
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                smooth: true
                onStatusChanged: {
                    if (status === Image.Error && !dl.animGif && dl.frameDef && dl.frameDef.gif)
                        dl.animGif = true;
                }
            }

            // a sticker sits on the top-right edge of the picture
            Image {
                visible: dl.stickerFrame
                source: dl.stickerFrame ? dl.frames.fileUrl(dl.frameDef) : ""
                width: dl.picD * 0.55
                height: width
                x: pic.acx + dl.picD * 0.28
                y: pic.acy - dl.picD * 0.70
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                smooth: true
            }

            MouseArea {
                id: picMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: dl.avatarClicked()
            }

            // on hover: change the picture, or step through the frames
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: dl.ringFrame ? 4 : 8
                spacing: 4
                visible: picMouse.containsMouse || pillA.containsMouse || pillB.containsMouse
                Rectangle {
                    width: tA.implicitWidth + 12
                    height: 18
                    radius: 9
                    color: Qt.rgba(0, 0, 0, 0.66)
                    Text {
                        id: tA
                        anchors.centerIn: parent
                        text: "Picture"
                        color: "#ffffff"
                        font.family: dl.th.font
                        font.pixelSize: 9
                    }
                    MouseArea {
                        id: pillA
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: dl.avatarClicked()
                    }
                }
                Rectangle {
                    width: tB.implicitWidth + 12
                    height: 18
                    radius: 9
                    color: Qt.rgba(0, 0, 0, 0.66)
                    Text {
                        id: tB
                        anchors.centerIn: parent
                        text: "Frame"
                        color: "#ffffff"
                        font.family: dl.th.font
                        font.pixelSize: 9
                    }
                    MouseArea {
                        id: pillB
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: dl.cycleFrame()
                    }
                }
            }
        }

        // the frame's name, shown for a moment after switching
        Rectangle {
            visible: toastTimer.running
            x: 14
            y: parent.height - dl.boxSize - 10 - 26
            width: toastText.implicitWidth + 16
            height: 20
            radius: 10
            color: Qt.rgba(0, 0, 0, 0.66)
            Text {
                id: toastText
                anchors.centerIn: parent
                text: dl.frameToast
                color: "#ffffff"
                font.family: dl.th.font
                font.pixelSize: 10
            }
        }
    }
}
