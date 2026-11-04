import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io

// Home tab. Every card can be switched off in Settings > Home.
Item {
    id: tab

    property var th
    property var host
    property var cfg
    property var chooser
    property var gamesRef
    property var frames
    property bool active: false

    readonly property string home: Quickshell.env("HOME")
    readonly property string base: home + "/.config/quickshell/media"

    function a(c, v) { return Qt.rgba(c.r, c.g, c.b, v); }

    // ───────── small building blocks ─────────
    component Card: Rectangle {
        property var th
        property color edge: Qt.rgba(th.dim.r, th.dim.g, th.dim.b, 0.18)
        property color fill: Qt.rgba(th.dim.r, th.dim.g, th.dim.b, 0.07)
        radius: th.radius
        color: fill
        border.width: 1
        border.color: edge
    }
    component Cap: Text {
        property var th
        color: th.accent
        font.family: th.font
        font.pixelSize: 10
        font.bold: true
        font.letterSpacing: 1.5
    }

    // ───────── clock ─────────
    property date now: new Date()
    Timer {
        interval: 1000
        repeat: true
        running: tab.active
        triggeredOnStart: true
        onTriggered: tab.now = new Date()
    }

    // ───────── quote ─────────
    property int shuffle: 0
    property int rnd: Math.floor(Math.random() * 1000)
    readonly property var quotes: cfg ? cfg.allQuotes() : []
    readonly property int dayOfYear: Math.floor((new Date(now.getFullYear(), now.getMonth(), now.getDate()) - new Date(now.getFullYear(), 0, 0)) / 86400000)
    readonly property string quote: {
        var q = quotes;
        if (q.length === 0)
            return "";
        var base = (cfg && cfg.quoteMode === "random") ? rnd : dayOfYear;
        return q[(base + shuffle) % q.length];
    }

    // ───────── data sources ─────────
    Stats {
        id: sys
        active: tab.active
    }
    Weather {
        id: wxData
        active: tab.active
        enabled: tab.cfg ? tab.cfg.weatherEnabled : false
        city: tab.cfg ? tab.cfg.city : ""
        units: tab.cfg ? tab.cfg.units : "c"
    }

    // Todo summary (written by the Todo panel)
    property var todo: ({ urgent: 0, pending: 0, running: false, endAt: 0, remaining: 0, task: "", doneToday: 0, goal: 5, mode: "" })
    property bool todoSeen: false
    FileView {
        id: todoFile
        path: tab.home + "/.config/quickshell/todo/status.json"
        watchChanges: true
        onFileChanged: todoFile.reload()
        onLoaded: {
            try {
                tab.todo = JSON.parse(todoFile.text());
                tab.todoSeen = true;
            } catch (e) {
                tab.todoSeen = false;
            }
        }
    }
    readonly property int todoRemain: (todo.running && todo.endAt > 0) ? Math.max(0, Math.round((todo.endAt - now.getTime()) / 1000)) : (todo.remaining || 0)
    function mmss(sec) {
        var m = Math.floor(sec / 60);
        var s = sec % 60;
        return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s;
    }

    // recently played Steam games, from the Games tab's scan
    readonly property var recent: {
        if (!gamesRef)
            return [];
        var g = gamesRef.games;
        var out = [];
        for (var i = 0; i < g.length; i++)
            if (g[i].installed && g[i].lastPlayed > 0 && g[i].extra < 0)
                out.push(g[i]);
        out.sort(function (x, y) { return y.lastPlayed - x.lastPlayed; });
        return out.slice(0, 3);
    }

    // newest screenshots
    FolderListModel {
        id: shots
        folder: tab.cfg ? "file://" + tab.cfg.shotsFolder : ""
        nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp", "*.PNG", "*.JPG"]
        sortField: FolderListModel.Time
        sortReversed: true
        showDirs: false
    }

    // ───────── launchers and VPN ─────────
    Process { id: launcher }
    function launchApp(cmd) {
        launcher.command = cmd;
        launcher.running = true;
        if (cfg && cfg.closeOnLaunch && host)
            host.open = false;
    }
    function openFile(path) {
        launcher.command = ["xdg-open", path];
        launcher.running = true;
    }

    property bool vpnCli: false
    property string vpnMsg: ""
    Process {
        id: vpnProbe
        command: ["sh", "-c", "command -v protonvpn >/dev/null 2>&1 && echo yes || echo no"]
        stdout: StdioCollector {
            onStreamFinished: tab.vpnCli = (text.trim() === "yes")
        }
    }
    Process {
        id: vpnProc
        onExited: function (exitCode, exitStatus) {
            if (exitCode !== 0 && tab.vpnCli)
                tab.vpnMsg = "Failed. Sign in once: protonvpn signin <username>";
            else if (tab.vpnCli)
                tab.vpnMsg = "";
            vpnRefresh.restart();
        }
    }
    Timer {
        id: vpnRefresh
        interval: 1500
        onTriggered: sys.refresh()
    }
    onActiveChanged: {
        if (active) {
            rnd = Math.floor(Math.random() * 1000);
            if (!vpnProbe.running)
                vpnProbe.running = true;
        }
    }
    Component.onCompleted: vpnProbe.running = true

    function toggleVpn() {
        if (vpnProc.running)
            return;
        if (vpnCli) {
            vpnMsg = sys.vpn ? "Disconnecting..." : "Connecting to the fastest server...";
            vpnProc.command = ["protonvpn", sys.vpn ? "disconnect" : "connect"];
        } else {
            vpnMsg = "Opened the Proton VPN app (install proton-vpn-cli for one-click connect)";
            vpnProc.command = ["sh", "-c", "setsid -f protonvpn-app >/dev/null 2>&1"];
        }
        vpnProc.running = true;
    }

    readonly property var tiles: {
        var out = [
            { name: "Steam", sub: "open the client", icons: ["steam"], kind: "steam", cmd: "" },
            { name: "Discord", sub: "open Discord", icons: ["discord"], kind: "discord", cmd: "" },
            { name: "Proton VPN", sub: "", icons: ["proton-vpn", "protonvpn", "network-vpn"], kind: "vpn", cmd: "" }
        ];
        var apps = cfg ? cfg.customApps : [];
        for (var i = 0; i < apps.length; i++)
            out.push({ name: apps[i].name, sub: "", icons: [apps[i].name.toLowerCase(), apps[i].cmd.split(" ")[0]], kind: "custom", cmd: apps[i].cmd });
        return out;
    }

    // used by the panel's keyboard shortcuts and by the tiles
    function tileClicked(i) {
        var t = tiles[i];
        if (!t)
            return;
        if (t.kind === "steam")
            launchApp(["sh", "-c", "setsid -f steam >/dev/null 2>&1"]);
        else if (t.kind === "discord")
            launchApp(["sh", "-c", "setsid -f discord >/dev/null 2>&1"]);
        else if (t.kind === "vpn")
            toggleVpn();
        else
            launchApp(["sh", "-c", "setsid -f " + t.cmd + " >/dev/null 2>&1"]);
    }

    function iconSrc(names) {
        for (var i = 0; i < names.length; i++) {
            if (!names[i])
                continue;
            var p = Quickshell.iconPath(names[i], true);
            if (p !== "")
                return p;
        }
        return "";
    }

    // ───────── calendar ─────────
    property int monthOffset: 0
    readonly property date viewDate: new Date(now.getFullYear(), now.getMonth() + monthOffset, 1)
    readonly property int startDay: viewDate.getDay()
    readonly property int daysInMonth: new Date(viewDate.getFullYear(), viewDate.getMonth() + 1, 0).getDate()

    // ───────── layout ─────────
    Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: width
        contentHeight: col.implicitHeight + 4
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: col
            width: flick.width
            spacing: 12

            // ── day line and greeting ──
            DayLine {
                width: parent.width
                th: tab.th
                cfg: tab.cfg
                weather: wxData
                frames: tab.frames
                now: tab.now
                active: tab.active
                avatar: tab.cfg ? "file://" + tab.cfg.avatarFile : ""
                greeting: tab.cfg ? tab.cfg.greeting(tab.now.getHours()) : ""
                userName: tab.cfg ? tab.cfg.displayName : ""
                subtitle: tab.cfg ? tab.cfg.subtitle : ""
                onAvatarClicked: {
                    if (tab.chooser)
                        tab.chooser.open("avatarPath");
                }
            }

            Text {
                width: parent.width
                visible: !!tab.chooser && tab.chooser.error !== ""
                wrapMode: Text.Wrap
                text: tab.chooser ? tab.chooser.error : ""
                color: tab.th.accent
                font.family: tab.th.font
                font.pixelSize: 10
            }

            // ── weather ──
            Card {
                th: tab.th
                width: parent.width
                height: 82
                visible: !!tab.cfg && tab.cfg.weatherEnabled && wxData.ready

                Column {
                    x: 14
                    y: 12
                    width: parent.width - 28 - 3 * 66
                    spacing: 4
                    Cap { th: tab.th; text: "WEATHER" }
                    Text {
                        width: parent.width
                        elide: Text.ElideRight
                        text: "Feels " + Math.round(wxData.feels) + "\u00B0   High " + Math.round(wxData.hi) + "\u00B0   Low " + Math.round(wxData.lo) + "\u00B0"
                        color: tab.th.bright
                        font.family: tab.th.font
                        font.pixelSize: 11
                    }
                    Text {
                        width: parent.width
                        elide: Text.ElideRight
                        text: "Wind " + Math.round(wxData.wind) + " km/h   Humidity " + wxData.humidity + "%"
                        color: tab.th.dim
                        font.family: tab.th.font
                        font.pixelSize: 10
                    }
                }
                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    y: 10
                    Repeater {
                        model: wxData.days
                        delegate: Column {
                            required property var modelData
                            width: 66
                            spacing: 3
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.label
                                color: tab.th.dim
                                font.family: tab.th.font
                                font.pixelSize: 10
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: Math.round(modelData.hi) + "\u00B0 / " + Math.round(modelData.lo) + "\u00B0"
                                color: tab.th.bright
                                font.family: tab.th.font
                                font.pixelSize: 11
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 62
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                                text: modelData.desc
                                color: tab.th.dim
                                font.family: tab.th.font
                                font.pixelSize: 9
                            }
                        }
                    }
                }
            }

            // ── quote ──
            Card {
                th: tab.th
                width: parent.width
                height: qtext.implicitHeight + 40
                visible: !!tab.cfg && tab.cfg.showQuote
                edge: tab.a(tab.th.accent, 0.28)
                fill: tab.a(tab.th.accent, 0.05)

                Rectangle {
                    x: 0
                    y: 14
                    width: 3
                    height: parent.height - 28
                    color: tab.th.accent
                }
                Text {
                    id: qtext
                    x: 20
                    y: 16
                    width: parent.width - 40
                    wrapMode: Text.Wrap
                    text: tab.quote
                    color: tab.th.bright
                    font.family: tab.th.font
                    font.pixelSize: 14
                    lineHeight: 1.25
                }
                IconBtn {
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: 4
                    box: 22
                    size: 12
                    glyph: "\u21BB"
                    idle: tab.a(tab.th.dim, 0.9)
                    hot: tab.th.accent
                    family: tab.th.font
                    onClicked: tab.shuffle += 1
                }
            }

            // ── system ──
            Card {
                th: tab.th
                width: parent.width
                height: sysBody.implicitHeight + 44
                visible: !!tab.cfg && tab.cfg.showSystem

                Cap { th: tab.th; x: 14; y: 12; text: "SYSTEM" }
                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    y: 10
                    spacing: 12
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: sys.uptime !== "" ? "up " + sys.uptime : ""
                        color: tab.th.dim
                        font.family: tab.th.font
                        font.pixelSize: 10
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: (tab.cfg && tab.cfg.systemView === "gauges") ? "Graphs" : "Gauges"
                        color: viewMouse.containsMouse ? tab.th.bright : tab.th.accent
                        font.family: tab.th.font
                        font.pixelSize: 10
                        font.bold: true
                        MouseArea {
                            id: viewMouse
                            anchors.fill: parent
                            anchors.margins: -4
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: tab.cfg.set("systemView", tab.cfg.systemView === "gauges" ? "graphs" : "gauges")
                        }
                    }
                }

                Column {
                    id: sysBody
                    x: 14
                    y: 34
                    width: parent.width - 28
                    spacing: 8

                    // gauges
                    Row {
                        visible: !!tab.cfg && tab.cfg.systemView === "gauges"
                        width: parent.width
                        spacing: (width - 4 * 70) / 3
                        Gauge {
                            th: tab.th
                            tint: tab.th.accent
                            value: sys.cpu / 100
                            text: Math.round(sys.cpu) + "%"
                            label: "CPU"
                        }
                        Gauge {
                            th: tab.th
                            tint: tab.th.accent
                            value: sys.memPct / 100
                            text: sys.memUsed.toFixed(1)
                            label: "RAM GB"
                        }
                        Gauge {
                            th: tab.th
                            tint: (sys.temp >= 80) ? "#ff5a4a" : tab.th.accent
                            value: sys.temp < 0 ? 0 : Math.min(1, sys.temp / 100)
                            text: sys.temp < 0 ? "--" : sys.temp + "\u00B0"
                            label: "TEMP"
                        }
                        Gauge {
                            th: tab.th
                            tint: tab.th.accent
                            value: sys.diskPct / 100
                            text: Math.round(sys.diskPct) + "%"
                            label: "DISK"
                        }
                    }

                    // graphs
                    Column {
                        visible: !!tab.cfg && tab.cfg.systemView === "graphs"
                        width: parent.width
                        spacing: 8
                        Item {
                            width: parent.width
                            height: 14
                            Text { text: "CPU"; color: tab.th.dim; font.family: tab.th.font; font.pixelSize: 10 }
                            Text { anchors.right: parent.right; text: Math.round(sys.cpu) + "%"; color: tab.th.bright; font.family: tab.th.font; font.pixelSize: 10 }
                        }
                        Spark { width: parent.width; height: 34; values: sys.cpuHist; maxValue: 100; tint: tab.th.accent; gridColor: tab.th.dim }
                        Item {
                            width: parent.width
                            height: 14
                            Text { text: "Temperature"; color: tab.th.dim; font.family: tab.th.font; font.pixelSize: 10 }
                            Text { anchors.right: parent.right; text: sys.temp < 0 ? "--" : sys.temp + "\u00B0C"; color: tab.th.bright; font.family: tab.th.font; font.pixelSize: 10 }
                        }
                        Spark { width: parent.width; height: 34; values: sys.tempHist; maxValue: 100; tint: tab.th.accent; gridColor: tab.th.dim }
                        Item {
                            width: parent.width
                            height: 14
                            Text { text: "Network  down"; color: tab.th.dim; font.family: tab.th.font; font.pixelSize: 10 }
                            Text { anchors.right: parent.right; text: sys.fmtRate(sys.rx) + "   up " + sys.fmtRate(sys.tx); color: tab.th.bright; font.family: tab.th.font; font.pixelSize: 10 }
                        }
                        Spark { width: parent.width; height: 34; values: sys.rxHist; maxValue: 0; tint: tab.th.accent; gridColor: tab.th.dim }
                    }

                    Flow {
                        width: parent.width
                        spacing: 14
                        Text {
                            visible: sys.net !== ""
                            text: sys.net
                            color: tab.th.dim
                            font.family: tab.th.font
                            font.pixelSize: 10
                        }
                        Text {
                            visible: sys.battery >= 0
                            text: "battery " + sys.battery + "%" + (sys.batState === "Charging" ? " charging" : "")
                            color: (sys.battery >= 0 && sys.battery <= 20 && sys.batState !== "Charging") ? "#ff5a4a" : tab.th.dim
                            font.family: tab.th.font
                            font.pixelSize: 10
                        }
                        Text {
                            text: "disk " + sys.diskUsed.toFixed(0) + " / " + sys.diskTotal.toFixed(0) + " GB"
                            color: tab.th.dim
                            font.family: tab.th.font
                            font.pixelSize: 10
                        }
                        Text {
                            text: "ram " + sys.memUsed.toFixed(1) + " / " + sys.memTotal.toFixed(1) + " GB"
                            color: tab.th.dim
                            font.family: tab.th.font
                            font.pixelSize: 10
                        }
                    }
                }
            }

            // ── volume, brightness, power ──
            Card {
                th: tab.th
                width: parent.width
                height: quick.implicitHeight + 24
                visible: !!tab.cfg && tab.cfg.showQuick

                QuickControls {
                    id: quick
                    x: 14
                    y: 12
                    width: parent.width - 28
                    th: tab.th
                    cfg: tab.cfg
                    stats: sys
                }
            }

            // ── app buttons ──
            Grid {
                width: parent.width
                columns: 3
                spacing: 8
                visible: !!tab.cfg && tab.cfg.showLaunchers

                Repeater {
                    model: tab.tiles
                    delegate: Rectangle {
                        id: tile
                        required property int index
                        required property var modelData
                        readonly property bool lit: modelData.kind === "vpn" && sys.vpn
                        readonly property string icon: tab.iconSrc(modelData.icons)

                        width: (parent.width - 16) / 3
                        height: 78
                        radius: tab.th.radius
                        color: lit ? tab.a(tab.th.accent, 0.16) : (tileMouse.containsMouse ? tab.a(tab.th.dim, 0.14) : tab.a(tab.th.dim, 0.07))
                        border.width: 1
                        border.color: lit ? tab.th.accent : tab.a(tab.th.dim, 0.22)

                        Image {
                            id: tileIcon
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: 9
                            width: 28
                            height: 28
                            source: tile.icon
                            sourceSize: Qt.size(56, 56)
                            fillMode: Image.PreserveAspectFit
                            visible: tile.icon !== "" && status === Image.Ready
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: 9
                            visible: !tileIcon.visible
                            text: tile.modelData.name.charAt(0).toUpperCase()
                            color: tile.lit ? tab.th.accent : tab.th.dim
                            font.family: tab.th.font
                            font.pixelSize: 24
                            font.bold: true
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: 43
                            width: parent.width - 10
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            text: tile.modelData.name
                            color: tab.th.bright
                            font.family: tab.th.font
                            font.pixelSize: 11
                            font.bold: true
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: 60
                            width: parent.width - 10
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            text: {
                                if (tile.modelData.kind === "vpn") {
                                    if (sys.vpn)
                                        return "connected";
                                    return tab.vpnCli ? "fastest server" : "opens the app";
                                }
                                return tile.modelData.sub;
                            }
                            color: tile.lit ? tab.th.accent : tab.th.dim
                            font.family: tab.th.font
                            font.pixelSize: 9
                        }
                        MouseArea {
                            id: tileMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: tab.tileClicked(tile.index)
                        }
                    }
                }
            }

            Text {
                width: parent.width
                visible: tab.vpnMsg !== ""
                wrapMode: Text.Wrap
                text: tab.vpnMsg
                color: tab.th.dim
                font.family: tab.th.font
                font.pixelSize: 10
            }

            // ── continue playing ──
            Column {
                width: parent.width
                spacing: 6
                visible: !!tab.cfg && tab.cfg.showContinue && tab.recent.length > 0
                Cap { th: tab.th; text: "CONTINUE PLAYING" }
                Row {
                    width: parent.width
                    spacing: 8
                    Repeater {
                        model: tab.recent
                        delegate: Rectangle {
                            id: rc
                            required property var modelData
                            width: (parent.width - 16) / 3
                            height: 84
                            radius: tab.th.radius
                            color: tab.a(tab.th.dim, 0.12)
                            border.width: rcMouse.containsMouse ? 1 : 0
                            border.color: tab.th.accent
                            clip: true

                            Image {
                                id: rcImg
                                property var srcs: tab.gamesRef ? tab.gamesRef.heroChain(rc.modelData) : []
                                property int tryIdx: 0
                                anchors.fill: parent
                                source: tryIdx < srcs.length ? srcs[tryIdx] : ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                sourceSize.width: 400
                                visible: status === Image.Ready
                                onSrcsChanged: tryIdx = 0
                                onStatusChanged: {
                                    if (status === Image.Error && tryIdx < srcs.length - 1)
                                        tryIdx += 1;
                                }
                            }
                            Rectangle {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                height: 34
                                gradient: Gradient {
                                    GradientStop { position: 0.0; color: "transparent" }
                                    GradientStop { position: 1.0; color: tab.a(tab.th.cardBot, 0.95) }
                                }
                            }
                            Text {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                anchors.margins: 6
                                elide: Text.ElideRight
                                text: rc.modelData.name
                                color: tab.th.bright
                                font.family: tab.th.font
                                font.pixelSize: 10
                            }
                            MouseArea {
                                id: rcMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: tab.gamesRef.launch(rc.modelData)
                            }
                        }
                    }
                }
            }

            // ── screenshots ──
            Column {
                width: parent.width
                spacing: 6
                visible: !!tab.cfg && tab.cfg.showShots && shots.count > 0
                Cap { th: tab.th; text: "SCREENSHOTS" }
                ListView {
                    width: parent.width
                    height: 66
                    orientation: ListView.Horizontal
                    spacing: 8
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    model: Math.min(8, shots.count)
                    delegate: Rectangle {
                        id: shot
                        required property int index
                        readonly property string fileUrl: shots.get(index, "fileUrl").toString()
                        width: 106
                        height: 64
                        radius: 6
                        color: tab.a(tab.th.dim, 0.12)
                        border.width: shotMouse.containsMouse ? 1 : 0
                        border.color: tab.th.accent
                        clip: true
                        Image {
                            anchors.fill: parent
                            source: shot.fileUrl
                            sourceSize: Qt.size(240, 150)
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                        }
                        MouseArea {
                            id: shotMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: tab.openFile(shot.fileUrl.replace("file://", ""))
                        }
                    }
                }
            }

            // ── calendar and Todo ──
            Row {
                width: parent.width
                spacing: 10
                visible: !!tab.cfg && tab.cfg.showCalendar

                Card {
                    id: calCard
                    th: tab.th
                    width: Math.floor((parent.width - 10) * 0.56)
                    height: 200

                    Item {
                        id: calHead
                        x: 10
                        y: 8
                        width: parent.width - 20
                        height: 24
                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: Qt.formatDate(tab.viewDate, "MMMM yyyy")
                            color: tab.th.bright
                            font.family: tab.th.font
                            font.pixelSize: 12
                            font.bold: true
                        }
                        Row {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            IconBtn {
                                box: 22
                                size: 13
                                glyph: "\u2039"
                                idle: tab.th.dim
                                hot: tab.th.accent
                                family: tab.th.font
                                onClicked: tab.monthOffset -= 1
                            }
                            IconBtn {
                                box: 22
                                size: 13
                                glyph: "\u203A"
                                idle: tab.th.dim
                                hot: tab.th.accent
                                family: tab.th.font
                                onClicked: tab.monthOffset += 1
                            }
                        }
                    }

                    Grid {
                        x: 10
                        y: calHead.y + calHead.height + 4
                        width: parent.width - 20
                        columns: 7
                        rowSpacing: 1

                        Repeater {
                            model: ["S", "M", "T", "W", "T", "F", "S"]
                            delegate: Item {
                                required property string modelData
                                width: calCard.width / 7 - 3
                                height: 18
                                Text {
                                    anchors.centerIn: parent
                                    text: modelData
                                    color: tab.a(tab.th.dim, 0.8)
                                    font.family: tab.th.font
                                    font.pixelSize: 9
                                }
                            }
                        }
                        Repeater {
                            model: 42
                            delegate: Item {
                                id: dayCell
                                required property int index
                                readonly property int day: index - tab.startDay + 1
                                readonly property bool valid: day >= 1 && day <= tab.daysInMonth
                                readonly property bool today: valid && tab.monthOffset === 0 && day === tab.now.getDate()
                                width: calCard.width / 7 - 3
                                height: 22
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 22
                                    height: 20
                                    radius: 10
                                    visible: dayCell.today
                                    color: tab.th.accent
                                }
                                Text {
                                    anchors.centerIn: parent
                                    visible: dayCell.valid
                                    text: dayCell.day
                                    color: dayCell.today ? tab.th.cardBot : tab.th.bright
                                    font.family: tab.th.font
                                    font.pixelSize: 10
                                    font.bold: dayCell.today
                                }
                            }
                        }
                    }
                }

                Card {
                    th: tab.th
                    width: parent.width - calCard.width - 10
                    height: 200
                    edge: tab.a(tab.th.accent, 0.28)
                    fill: tab.a(tab.th.accent, 0.05)

                    Column {
                        x: 12
                        y: 10
                        width: parent.width - 24
                        spacing: 4

                        Cap { th: tab.th; text: "TODO" }
                        Text {
                            visible: tab.todoSeen
                            text: tab.todo.urgent
                            color: tab.th.accent
                            font.family: tab.th.font
                            font.pixelSize: 38
                            font.bold: true
                        }
                        Text {
                            visible: tab.todoSeen
                            text: "urgent"
                            color: tab.th.dim
                            font.family: tab.th.font
                            font.pixelSize: 10
                        }
                        Text {
                            visible: tab.todoSeen
                            text: tab.todo.pending + " pending"
                            color: tab.th.bright
                            font.family: tab.th.font
                            font.pixelSize: 11
                        }
                        Text {
                            visible: tab.todoSeen
                            text: tab.todo.doneToday + " / " + tab.todo.goal + " done today"
                            color: tab.th.dim
                            font.family: tab.th.font
                            font.pixelSize: 10
                        }
                        Text {
                            visible: tab.todoSeen && tab.todo.running
                            width: parent.width
                            elide: Text.ElideRight
                            text: "\u25B6 " + tab.mmss(tab.todoRemain) + (tab.todo.task !== "" ? "  " + tab.todo.task : "")
                            color: tab.th.accent
                            font.family: tab.th.font
                            font.pixelSize: 10
                        }
                        Text {
                            visible: !tab.todoSeen
                            width: parent.width
                            wrapMode: Text.Wrap
                            text: "The Todo panel is not running yet."
                            color: tab.th.dim
                            font.family: tab.th.font
                            font.pixelSize: 10
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: tab.launchApp(["qs", "-c", "todo", "ipc", "call", "todo", "toggle"])
                    }
                }
            }

            // ── scratch note ──
            Card {
                th: tab.th
                width: parent.width
                height: 112
                visible: !!tab.cfg && tab.cfg.showNote

                Cap { th: tab.th; x: 14; y: 10; text: "NOTE" }
                TextEdit {
                    id: noteEdit
                    x: 14
                    y: 28
                    width: parent.width - 28
                    height: parent.height - 38
                    wrapMode: TextEdit.Wrap
                    color: tab.th.bright
                    selectByMouse: true
                    clip: true
                    font.family: tab.th.font
                    font.pixelSize: 12
                    onTextChanged: if (tab.noteLoaded) noteSave.restart()
                }
                Text {
                    x: 14
                    y: 28
                    visible: noteEdit.text === "" && !noteEdit.activeFocus
                    text: "Type anything. It saves by itself."
                    color: tab.a(tab.th.dim, 0.7)
                    font.family: tab.th.font
                    font.pixelSize: 12
                }
            }
        }
    }

    // scratch note storage
    property bool noteLoaded: false
    FileView {
        id: noteFile
        path: tab.base + "/note.txt"
        onLoaded: {
            noteEdit.text = noteFile.text();
            tab.noteLoaded = true;
        }
        onLoadFailed: tab.noteLoaded = true
    }
    Timer {
        id: noteSave
        interval: 700
        onTriggered: noteFile.setText(noteEdit.text)
    }
}
