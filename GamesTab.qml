import QtQuick
import Quickshell
import Quickshell.Io

// Games tab: a hero card for the selected game on top, a cover grid below.
// Categories: All / Recent / Favorites / Not installed. "Not installed" lists the
// games you own but don't have (needs a Steam Web API key, see Settings);
// INSTALL opens Steam's install dialog and the download shows up here with progress.
Item {
    id: tab

    property var th
    property var host
    property var cfg
    property bool active: false

    // Games that are not on Steam. Each entry: { name: "Minecraft", cmd: ["sh", "-c", "..."] }
    readonly property var extraGames: []

    readonly property string base: Quickshell.env("HOME") + "/.config/quickshell/media"
    readonly property int cols: 3
    readonly property var filterNames: ["All", "Recent", "Favorites", "Not installed"]
    readonly property var sortNames: ["Recent", "A-Z", "Size", "Playtime"]
    readonly property bool closeOnLaunch: cfg ? cfg.closeOnLaunch : true
    readonly property string steamKey: cfg ? cfg.steamKey : ""
    readonly property string steamId: (cfg && cfg.steamId !== "") ? cfg.steamId : steamIdAuto

    property string steamRoot: ""
    property string steamIdAuto: ""
    property var games: []        // games with an appmanifest: installed, installing or updating
    property var artMap: ({})     // appid -> { cover, hero, header } (absolute paths)
    property var playMap: ({})    // appid -> minutes played
    property var owned: []        // from the Steam Web API: { id, name, playtime, last }
    property double libTime: 0
    property bool libLoaded: false
    property bool libBusy: false
    property string libStatus: ""
    property string note: ""
    property bool waitInstall: false
    property var favs: []         // keys
    property string query: ""
    property int filterMode: 0
    property int sortMode: 0
    property int selIdx: 0
    property var tools: ({})       // which of prime-run, gamemoderun, mangohud are installed
    property var launchOpts: ({})  // appid -> Steam launch options string
    property bool newOnly: false
    property var rPath: []
    property int rStep: 0

    function a(c, v) { return Qt.rgba(c.r, c.g, c.b, v); }

    // ───────── derived lists ─────────
    readonly property var notInstalled: {
        var have = {};
        for (var i = 0; i < games.length; i++)
            have[games[i].id] = true;
        var out = [];
        for (var j = 0; j < owned.length; j++) {
            var o = owned[j];
            if (have[o.id])
                continue;
            out.push({ key: o.id, id: o.id, name: o.name, lastPlayed: o.last, size: 0, extra: -1,
                       installed: false, state: 0, btd: 0, bdl: 0, playtime: o.playtime });
        }
        return out;
    }

    readonly property bool anyDownloading: {
        for (var i = 0; i < games.length; i++)
            if (downloading(games[i]))
                return true;
        return false;
    }

    function downloading(g) { return !!g && g.btd > 0 && g.bdl < g.btd; }
    function progressOf(g) { return (g && g.btd > 0) ? Math.max(0, Math.min(1, g.bdl / g.btd)) : 0; }
    function playedOf(g) { return g ? (playMap[g.id] || g.playtime || 0) : 0; }

    readonly property var shown: {
        var q = query.trim().toLowerCase();
        var src = (filterMode === 3) ? notInstalled : games;
        var out = [];
        for (var i = 0; i < src.length; i++) {
            var g = src[i];
            if (filterMode === 2 && favs.indexOf(g.key) < 0)
                continue;
            if (filterMode === 1 && !(g.lastPlayed > 0))
                continue;
            if (q !== "" && g.name.toLowerCase().indexOf(q) < 0)
                continue;
            out.push(g);
        }
        var mode = (filterMode === 1) ? 0 : sortMode;
        var pm = playMap;
        out.sort(function (x, y) {
            if (mode === 1)
                return x.name.localeCompare(y.name);
            if (mode === 2 && y.size !== x.size)
                return y.size - x.size;
            if (mode === 3) {
                var d = (pm[y.id] || y.playtime || 0) - (pm[x.id] || x.playtime || 0);
                if (d !== 0)
                    return d;
            }
            if (y.lastPlayed !== x.lastPlayed)
                return y.lastPlayed - x.lastPlayed;
            return x.name.localeCompare(y.name);
        });
        if (filterMode === 1 && out.length > 15)
            out = out.slice(0, 15);
        return out;
    }
    readonly property var sel: (selIdx >= 0 && selIdx < shown.length) ? shown[selIdx] : null

    // ───────── artwork (local Steam cache first, then Steam's CDN) ─────────
    function fileUrl(p) { return (p && p !== "") ? "file://" + p : ""; }
    function cdn(id, file) { return "https://cdn.cloudflare.steamstatic.com/steam/apps/" + id + "/" + file; }
    function coverChain(g) {
        var out = [];
        if (!g || g.extra >= 0)
            return out;
        var e = artMap[g.id];
        if (e) {
            if (e.cover) out.push(fileUrl(e.cover));
            if (e.header) out.push(fileUrl(e.header));
        }
        out.push(cdn(g.id, "library_600x900.jpg"));
        out.push(cdn(g.id, "header.jpg"));
        return out;
    }
    function heroChain(g) {
        var out = [];
        if (!g || g.extra >= 0)
            return out;
        var e = artMap[g.id];
        if (e) {
            if (e.hero) out.push(fileUrl(e.hero));
            if (e.header) out.push(fileUrl(e.header));
            if (e.cover) out.push(fileUrl(e.cover));
        }
        out.push(cdn(g.id, "library_hero.jpg"));
        out.push(cdn(g.id, "header.jpg"));
        return out;
    }

    // ───────── formatting ─────────
    function ago(ts, extra) {
        if (extra >= 0)
            return "custom";
        if (!ts)
            return "never played";
        var d = Math.floor((Date.now() / 1000 - ts) / 86400);
        if (d <= 0)
            return "played today";
        if (d === 1)
            return "played yesterday";
        if (d < 30)
            return "played " + d + " days ago";
        if (d < 365)
            return "played " + Math.floor(d / 30) + " months ago";
        return "played " + Math.floor(d / 365) + " years ago";
    }
    function fmtSize(b) {
        if (!b)
            return "";
        return b >= 1e9 ? (b / 1e9).toFixed(1) + " GB" : Math.round(b / 1e6) + " MB";
    }
    function fmtPlay(m) {
        if (!m)
            return "";
        return m >= 60 ? Math.floor(m / 60) + "h " + (m % 60) + "m played" : m + "m played";
    }

    // ───────── scanning Steam ─────────
    // Prints ROOT / SID / GAME / PT / ART lines. The layout of Steam's cover cache differs
    // between client versions, so art files are found with `find` instead of guessed.
    readonly property var scanLines: [
        "root=\"$HOME/.local/share/Steam\"; [ -d \"$root/steamapps\" ] || root=\"$HOME/.steam/steam\"",
        "printf 'ROOT\\t%s\\n' \"$root\"",
        "lu=\"$root/config/loginusers.vdf\"",
        "[ -f \"$lu\" ] && awk -F'\"' '/^[ \\t]*\"[0-9]+\"[ \\t]*$/ {if (length($2)==17) id=$2} /\"MostRecent\"/ && $4==\"1\" {print \"SID\\t\" id}' \"$lu\"",
        "{ echo \"$root\"; grep '\"path\"' \"$root/steamapps/libraryfolders.vdf\" 2>/dev/null | awk -F'\"' '{print $4}'; } | sort -u | while read -r lib; do",
        "  for f in \"$lib\"/steamapps/appmanifest_*.acf; do",
        "    [ -f \"$f\" ] || continue",
        "    id=$(grep -m1 '\"appid\"' \"$f\" | awk -F'\"' '{print $4}')",
        "    name=$(grep -m1 '\"name\"' \"$f\" | awk -F'\"' '{print $4}')",
        "    lp=$(grep -m1 '\"LastPlayed\"' \"$f\" | awk -F'\"' '{print $4}')",
        "    sz=$(grep -m1 '\"SizeOnDisk\"' \"$f\" | awk -F'\"' '{print $4}')",
        "    st=$(grep -m1 '\"StateFlags\"' \"$f\" | awk -F'\"' '{print $4}')",
        "    btd=$(grep -m1 '\"BytesToDownload\"' \"$f\" | awk -F'\"' '{print $4}')",
        "    bdl=$(grep -m1 '\"BytesDownloaded\"' \"$f\" | awk -F'\"' '{print $4}')",
        "    printf 'GAME\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\n' \"$id\" \"${lp:-0}\" \"${sz:-0}\" \"${st:-0}\" \"${btd:-0}\" \"${bdl:-0}\" \"$name\"",
        "  done",
        "done",
        "for lc in \"$root\"/userdata/*/config/localconfig.vdf; do",
        "  [ -f \"$lc\" ] || continue",
        "  awk -F'\"' '/^[ \\t]*\"[0-9]+\"[ \\t]*$/ {c=$2} /\"Playtime\"/ {if (c != \"\") print \"PT\\t\" c \"\\t\" $4} /\"LaunchOptions\"/ {if (c != \"\") print \"LO\\t\" c \"\\t\" $4}' \"$lc\"",
        "done",
        "for t in prime-run gamemoderun mangohud; do command -v \"$t\" >/dev/null 2>&1 && printf 'TOOL\\t%s\\n' \"$t\"; done",
        "find \"$root/appcache/librarycache\" -type f \\( -name '*library_600x900*' -o -name '*library_hero*' -o -name '*header*' \\) 2>/dev/null | sed 's/^/ART\\t/'"
    ]

    Process {
        id: scan
        command: ["sh", "-c", tab.scanLines.join("\n")]
        stdout: StdioCollector {
            onStreamFinished: tab.parseScan(text)
        }
    }

    function refresh() {
        if (!scan.running)
            scan.running = true;
    }

    function parseScan(out) {
        var lines = String(out).split("\n");
        var arr = [];
        var art = {};
        var pt = {};
        var tl = {};
        var lo = {};
        var seen = {};
        for (var i = 0; i < lines.length; i++) {
            var l = lines[i];
            if (l.indexOf("ROOT\t") === 0) {
                tab.steamRoot = l.substring(5);
            } else if (l.indexOf("SID\t") === 0) {
                tab.steamIdAuto = l.substring(4).trim();
            } else if (l.indexOf("GAME\t") === 0) {
                var p = l.split("\t");
                var id = p[1];
                var name = p.slice(7).join("\t");
                if (!id || seen[id] || name === "")
                    continue;
                if (/^(Proton|Steam Linux Runtime|Steamworks Common)/.test(name))
                    continue;
                seen[id] = true;
                var st = Number(p[4]) || 0;
                arr.push({ key: id, id: id, name: name, lastPlayed: Number(p[2]) || 0, size: Number(p[3]) || 0,
                           extra: -1, installed: (st & 4) !== 0, state: st, btd: Number(p[5]) || 0, bdl: Number(p[6]) || 0,
                           playtime: 0 });
            } else if (l.indexOf("PT\t") === 0) {
                var q = l.split("\t");
                pt[q[1]] = Math.max(pt[q[1]] || 0, Number(q[2]) || 0);
            } else if (l.indexOf("TOOL\t") === 0) {
                tl[l.substring(5).trim()] = true;
            } else if (l.indexOf("LO\t") === 0) {
                var lq = l.split("\t");
                lo[lq[1]] = lq.slice(2).join("\t");
            } else if (l.indexOf("ART\t") === 0) {
                var path = l.substring(4);
                var m = /\/librarycache\/(\d+)[_\/]/.exec(path);
                if (!m)
                    continue;
                var e = art[m[1]];
                if (!e) {
                    e = {};
                    art[m[1]] = e;
                }
                var fn = path.substring(path.lastIndexOf("/") + 1);
                if (/library_600x900/.test(fn)) {
                    if (!e.cover || fn.indexOf("2x") < 0)
                        e.cover = path;
                } else if (/library_hero_blur/.test(fn)) {
                    continue;
                } else if (/library_hero/.test(fn)) {
                    if (!e.hero)
                        e.hero = path;
                } else if (/header/.test(fn)) {
                    if (!e.header)
                        e.header = path;
                }
            }
        }
        for (var x = 0; x < extraGames.length; x++)
            arr.push({ key: "x" + x, id: "", name: extraGames[x].name, lastPlayed: 0, size: 0, extra: x,
                       installed: true, state: 4, btd: 0, bdl: 0, playtime: 0 });
        games = arr;
        artMap = art;
        playMap = pt;
        tools = tl;
        launchOpts = lo;
        if (selIdx >= shown.length)
            selIdx = 0;
        maybeFetch();
    }

    // ───────── owned games from the Steam Web API ─────────
    FileView {
        id: libFile
        path: tab.base + "/library.json"
        onLoaded: {
            try {
                var s = JSON.parse(libFile.text());
                if (Array.isArray(s.games)) {
                    tab.owned = s.games;
                    tab.libTime = Number(s.time) || 0;
                }
            } catch (e) {
                console.log("media: could not read library.json:", e);
            }
            tab.libLoaded = true;
            tab.maybeFetch();
        }
        onLoadFailed: {
            tab.libLoaded = true;
            tab.maybeFetch();
        }
    }

    // fetch at most once a day on its own
    function maybeFetch() {
        if (!libLoaded || libBusy || steamKey === "" || steamId === "")
            return;
        if (Date.now() - libTime > 86400000)
            fetchLibrary();
    }

    function fetchLibrary() {
        if (steamKey === "") {
            libStatus = "Add your Steam Web API key in Settings (the gear icon) to list the games you own.";
            return;
        }
        if (steamId === "") {
            libStatus = "Could not detect your SteamID. Set it in Settings.";
            return;
        }
        if (libBusy)
            return;
        libBusy = true;
        libStatus = "Fetching your Steam library...";
        fetchProc.command = ["curl", "-s", "-m", "25",
            "https://api.steampowered.com/IPlayerService/GetOwnedGames/v1/?key=" + encodeURIComponent(steamKey)
            + "&steamid=" + encodeURIComponent(steamId)
            + "&include_appinfo=1&include_played_free_games=1&format=json"];
        fetchProc.running = true;
    }

    Process {
        id: fetchProc
        stdout: StdioCollector {
            onStreamFinished: tab.libFetched(text)
        }
        onRunningChanged: if (!running) tab.libBusy = false
    }

    function libFetched(txt) {
        libBusy = false;
        try {
            var r = JSON.parse(txt);
            var g = r.response ? r.response.games : undefined;
            if (!g || g.length === 0) {
                libStatus = "Steam returned no games. Check the API key and that your profile's game details are public.";
                return;
            }
            var arr = g.map(function (x) {
                return { id: String(x.appid), name: String(x.name || ("App " + x.appid)),
                         playtime: Number(x.playtime_forever) || 0, last: Number(x.rtime_last_played) || 0 };
            });
            owned = arr;
            libTime = Date.now();
            libStatus = "";
            libFile.setText(JSON.stringify({ time: libTime, games: arr }));
        } catch (e) {
            libStatus = "Could not read Steam's answer (is the API key right?).";
        }
    }

    // refresh the list now: rescan Steam and refetch the library
    function refreshAll() {
        refresh();
        if (steamKey !== "")
            fetchLibrary();
    }

    Component.onCompleted: refresh()
    onActiveChanged: {
        if (active) {
            refresh();
            maybeFetch();
        }
    }
    onSteamIdChanged: maybeFetch()
    onSteamKeyChanged: {
        libStatus = "";
        maybeFetch();
    }

    // while something downloads (or an install was just requested) keep the list fresh
    Timer {
        interval: 4000
        repeat: true
        running: tab.active
        onTriggered: if (tab.anyDownloading || tab.waitInstall) tab.refresh()
    }
    Timer {
        id: waitTimer
        interval: 120000
        onTriggered: tab.waitInstall = false
    }
    Timer {
        id: noteTimer
        interval: 9000
        onTriggered: tab.note = ""
    }

    // ───────── favorites ─────────
    FileView {
        id: favFile
        path: tab.base + "/favorites.json"
        onLoaded: {
            try {
                var arr = JSON.parse(favFile.text());
                if (Array.isArray(arr))
                    tab.favs = arr;
            } catch (e) {
                console.log("media: could not read favorites.json:", e);
            }
        }
    }

    function isFav(key) { return favs.indexOf(key) >= 0; }
    function toggleFav(key) {
        var arr = favs.slice();
        var at = arr.indexOf(key);
        if (at >= 0)
            arr.splice(at, 1);
        else
            arr.push(key);
        favs = arr;
        favFile.setText(JSON.stringify(arr));
    }
    function toggleFavSel() { if (sel) toggleFav(sel.key); }

    // ───────── launching and installing ─────────
    Process { id: launcher }

    readonly property string steamUrlScript: 'command -v steam >/dev/null 2>&1 && setsid -f steam "$1" >/dev/null 2>&1 || xdg-open "$1"'

    function launch(g) {
        if (!g)
            return;
        if (!g.installed) {
            install(g);
            return;
        }
        if (downloading(g))
            return;
        if (g.extra >= 0)
            launcher.command = extraGames[g.extra].cmd;
        else
            launcher.command = ["sh", "-c", steamUrlScript, "sh", "steam://rungameid/" + g.id];
        launcher.running = true;
        if (closeOnLaunch && host)
            host.open = false;
    }

    function install(g) {
        if (!g || downloading(g))
            return;
        launcher.command = ["sh", "-c", steamUrlScript, "sh", "steam://install/" + g.id];
        launcher.running = true;
        note = "Steam opened its install dialog for " + g.name + ". Confirm it there to start the download.";
        noteTimer.restart();
        waitInstall = true;
        waitTimer.restart();
    }

    function launchSel() { launch(sel); }

    function openKeyPage() {
        launcher.command = ["xdg-open", "https://steamcommunity.com/dev/apikey"];
        launcher.running = true;
    }

    // ───────── used by the panel's keyboard shortcuts ─────────
    function moveGrid(dx, dy) {
        if (shown.length === 0)
            return;
        selIdx = Math.max(0, Math.min(shown.length - 1, selIdx + dx + dy * cols));
        grid.positionViewAtIndex(selIdx, GridView.Contain);
    }
    function cycleSort() { sortMode = (sortMode + 1) % sortNames.length; selIdx = 0; }
    function cycleFilter() { filterMode = (filterMode + 1) % filterNames.length; selIdx = 0; }
    function focusSearch() { search.forceActiveFocus(); }

    // ───────── "Surprise me": a short roulette over the current list ─────────
    function surprise() {
        if (rTimer.running || shown.length === 0)
            return;
        var pool = [];
        for (var i = 0; i < shown.length; i++) {
            var g = shown[i];
            if (filterMode !== 3 && !g.installed)
                continue;
            if (newOnly && (g.lastPlayed > 0 || playedOf(g) > 0))
                continue;
            pool.push(i);
        }
        if (pool.length === 0) {
            note = newOnly ? "No unplayed games in this list" : "Nothing to pick from";
            noteTimer.restart();
            return;
        }
        var target = pool[Math.floor(Math.random() * pool.length)];
        var path = [];
        var idx = selIdx;
        for (var st = 0; st < 80; st++) {
            idx = (idx + 1) % shown.length;
            path.push(idx);
            if (st >= 13 && idx === target)
                break;
        }
        if (path[path.length - 1] !== target)
            path.push(target);
        rPath = path;
        rStep = 0;
        rTimer.interval = 45;
        rTimer.start();
    }

    Timer {
        id: rTimer
        repeat: true
        onTriggered: {
            tab.selIdx = tab.rPath[tab.rStep];
            grid.positionViewAtIndex(tab.selIdx, GridView.Contain);
            tab.rStep += 1;
            interval = Math.min(300, interval * 1.12);
            if (tab.rStep >= tab.rPath.length)
                stop();
        }
    }

    // ───────── UI ─────────
    Column {
        anchors.fill: parent
        spacing: 8

        // hero card for the selected game
        Rectangle {
            id: hero
            width: parent.width
            height: 168
            radius: tab.th.radius
            color: tab.a(tab.th.dim, 0.10)
            border.width: 1
            border.color: tab.a(tab.th.accent, 0.35)
            clip: true

            Image {
                id: heroImg
                property var srcs: tab.heroChain(tab.sel)
                property int tryIdx: 0
                anchors.fill: parent
                source: tryIdx < srcs.length ? srcs[tryIdx] : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize.width: 920
                visible: status === Image.Ready
                onSrcsChanged: tryIdx = 0
                onStatusChanged: {
                    if (status === Image.Error && tryIdx < srcs.length - 1)
                        tryIdx += 1;
                }
            }
            Text {
                anchors.centerIn: parent
                visible: heroImg.status !== Image.Ready && tab.sel !== null
                text: tab.sel ? tab.sel.name.charAt(0).toUpperCase() : ""
                color: tab.a(tab.th.accent, 0.35)
                font.family: tab.th.font
                font.pixelSize: 80
                font.bold: true
            }
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0.0; color: tab.a(tab.th.cardBot, 0.10) }
                    GradientStop { position: 0.55; color: tab.a(tab.th.cardBot, 0.55) }
                    GradientStop { position: 1.0; color: tab.a(tab.th.cardBot, 0.97) }
                }
            }

            Text {
                anchors.centerIn: parent
                width: parent.width - 40
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                visible: tab.sel === null
                text: {
                    if (tab.filterMode === 3)
                        return tab.libBusy ? "Fetching your library..." : "Nothing here yet";
                    return tab.games.length === 0 ? "No Steam games found" : "No match";
                }
                color: tab.th.dim
                font.family: tab.th.font
                font.pixelSize: 12
            }

            Text {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.margins: 10
                visible: tab.sel !== null && !tab.sel.installed && !tab.downloading(tab.sel)
                text: "NOT INSTALLED"
                color: tab.th.bright
                font.family: tab.th.font
                font.pixelSize: 10
                font.bold: true
                font.letterSpacing: 1
            }

            IconBtn {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 6
                visible: tab.sel !== null
                size: 18
                glyph: (tab.sel && tab.isFav(tab.sel.key)) ? "\u2605" : "\u2606"
                on: tab.sel ? tab.isFav(tab.sel.key) : false
                idle: tab.th.bright
                hot: tab.th.accent
                family: tab.th.font
                onClicked: tab.toggleFavSel()
            }

            IconBtn {
                anchors.right: parent.right
                anchors.rightMargin: 34
                anchors.top: parent.top
                anchors.topMargin: 6
                visible: tab.sel !== null && tab.sel.extra < 0
                size: 15
                glyph: "\u2699"
                idle: tab.th.bright
                hot: tab.th.accent
                family: tab.th.font
                onClicked: optsCard.open(tab.sel)
            }

            Column {
                visible: tab.sel !== null
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.margins: 14
                anchors.right: actionBtn.left
                anchors.rightMargin: 10
                spacing: 3
                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: tab.sel ? tab.sel.name : ""
                    color: tab.th.bright
                    font.family: tab.th.font
                    font.pixelSize: 17
                    font.bold: true
                }
                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: {
                        if (!tab.sel)
                            return "";
                        var parts = [tab.ago(tab.sel.lastPlayed, tab.sel.extra)];
                        var pl = tab.fmtPlay(tab.playedOf(tab.sel));
                        if (pl !== "")
                            parts.push(pl);
                        var sz = tab.fmtSize(tab.sel.size);
                        if (sz !== "")
                            parts.push(sz);
                        return parts.join("  \u00B7  ");
                    }
                    color: tab.th.dim
                    font.family: tab.th.font
                    font.pixelSize: 11
                }
                // download progress
                Rectangle {
                    visible: tab.downloading(tab.sel)
                    width: parent.width
                    height: 4
                    radius: 2
                    color: tab.a(tab.th.dim, 0.3)
                    Rectangle {
                        height: parent.height
                        radius: 2
                        color: tab.th.accent
                        width: parent.width * tab.progressOf(tab.sel)
                    }
                }
            }

            Rectangle {
                id: actionBtn
                visible: tab.sel !== null
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 14
                width: 112
                height: 34
                radius: tab.th.radius
                readonly property bool busy: tab.downloading(tab.sel)
                readonly property bool inst: tab.sel !== null && !tab.sel.installed
                color: busy ? tab.a(tab.th.dim, 0.3) : (actionMouse.containsMouse ? tab.th.bright : tab.th.accent)
                Text {
                    anchors.centerIn: parent
                    text: actionBtn.busy ? (Math.round(tab.progressOf(tab.sel) * 100) + "%  " + (tab.sel && tab.sel.installed ? "UPDATING" : "INSTALLING")) : (actionBtn.inst ? "\u2193  INSTALL" : "\u25B6  PLAY")
                    color: actionBtn.busy ? tab.th.bright : tab.th.cardBot
                    font.family: tab.th.font
                    font.pixelSize: actionBtn.busy ? 9 : 12
                    font.bold: true
                }
                MouseArea {
                    id: actionMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: !actionBtn.busy
                    cursorShape: Qt.PointingHandCursor
                    onClicked: tab.launchSel()
                }
            }
        }

        // search + sort + refresh
        Rectangle {
            width: parent.width
            height: 34
            radius: tab.th.radius
            color: tab.a(tab.th.dim, 0.07)
            border.width: 1
            border.color: search.activeFocus ? tab.a(tab.th.accent, 0.6) : tab.a(tab.th.dim, 0.14)

            IconBtn {
                id: refreshBtn
                anchors.right: parent.right
                anchors.rightMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                size: 14
                glyph: "\u21BB"
                on: tab.libBusy
                idle: tab.th.dim
                hot: tab.th.accent
                family: tab.th.font
                onClicked: tab.refreshAll()
            }
            Text {
                id: sortText
                anchors.right: refreshBtn.left
                anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                text: "Sort: " + tab.sortNames[tab.sortMode] + " \u25BE"
                color: sortMouse.containsMouse ? tab.th.accent : tab.th.dim
                opacity: tab.filterMode === 1 ? 0.4 : 1
                font.family: tab.th.font
                font.pixelSize: 10
                MouseArea {
                    id: sortMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: tab.cycleSort()
                }
            }
            Text {
                id: newOnlyText
                anchors.right: sortText.left
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: "new only"
                color: tab.newOnly ? tab.th.accent : tab.a(tab.th.dim, 0.8)
                font.family: tab.th.font
                font.pixelSize: 10
                font.bold: tab.newOnly
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -3
                    cursorShape: Qt.PointingHandCursor
                    onClicked: tab.newOnly = !tab.newOnly
                }
            }
            Text {
                id: surpriseText
                anchors.right: newOnlyText.left
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                text: "Surprise me"
                color: surpriseMouse.containsMouse ? tab.th.bright : tab.th.accent
                font.family: tab.th.font
                font.pixelSize: 10
                font.bold: true
                MouseArea {
                    id: surpriseMouse
                    anchors.fill: parent
                    anchors.margins: -3
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: tab.surprise()
                }
            }
            TextInput {
                id: search
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.right: surpriseText.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                clip: true
                color: tab.th.bright
                selectByMouse: true
                font.family: tab.th.font
                font.pixelSize: 13
                onTextChanged: {
                    tab.query = text;
                    tab.selIdx = 0;
                }
                onAccepted: tab.launchSel()
            }
            Text {
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                visible: search.text === ""
                text: "Search games  ( / )"
                color: tab.a(tab.th.dim, 0.8)
                font.family: tab.th.font
                font.pixelSize: 12
            }
        }

        // category chips
        Row {
            spacing: 6
            Repeater {
                model: tab.filterNames
                delegate: Rectangle {
                    id: chip
                    required property int index
                    required property string modelData
                    readonly property bool on: tab.filterMode === index
                    width: chipText.implicitWidth + 18
                    height: 24
                    radius: 12
                    color: on ? tab.a(tab.th.accent, 0.20) : "transparent"
                    border.width: 1
                    border.color: on ? tab.th.accent : tab.a(tab.th.dim, 0.3)
                    Text {
                        id: chipText
                        anchors.centerIn: parent
                        text: chip.modelData + (chip.index === 3 && tab.notInstalled.length > 0 ? " " + tab.notInstalled.length : "")
                        color: chip.on ? tab.th.accent : tab.th.dim
                        font.family: tab.th.font
                        font.pixelSize: 11
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            tab.filterMode = chip.index;
                            tab.selIdx = 0;
                            if (chip.index === 3)
                                tab.maybeFetch();
                        }
                    }
                }
            }
        }

        // cover grid
        Item {
            width: parent.width
            height: tab.height - 168 - 34 - 24 - 16 - 4 * 8

            GridView {
                id: grid
                anchors.fill: parent
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                cellWidth: Math.floor(width / tab.cols)
                cellHeight: Math.round(cellWidth * 1.46)
                model: tab.shown

                delegate: Item {
                    id: cell
                    required property int index
                    required property var modelData
                    readonly property bool selected: tab.selIdx === index
                    readonly property bool busy: tab.downloading(modelData)

                    width: grid.cellWidth
                    height: grid.cellHeight

                    HoverHandler { id: hover }

                    Rectangle {
                        id: tile
                        anchors.fill: parent
                        anchors.margins: 5
                        radius: tab.th.radius
                        color: tab.a(tab.th.dim, 0.12)
                        border.width: cell.selected ? 2 : (hover.hovered ? 1 : 0)
                        border.color: cell.selected ? tab.th.accent : tab.a(tab.th.dim, 0.6)
                        scale: cell.selected ? 1.03 : 1
                        clip: true
                        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

                        Image {
                            id: coverImg
                            property var srcs: tab.coverChain(cell.modelData)
                            property int tryIdx: 0
                            anchors.fill: parent
                            source: tryIdx < srcs.length ? srcs[tryIdx] : ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            sourceSize: Qt.size(260, 380)
                            opacity: cell.modelData.installed ? 1 : 0.62
                            visible: status === Image.Ready
                            onSrcsChanged: tryIdx = 0
                            onStatusChanged: {
                                if (status === Image.Error && tryIdx < srcs.length - 1)
                                    tryIdx += 1;
                            }
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: coverImg.status !== Image.Ready
                            text: cell.modelData.name.charAt(0).toUpperCase()
                            color: tab.a(tab.th.accent, 0.5)
                            font.family: tab.th.font
                            font.pixelSize: 38
                            font.bold: true
                        }
                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: 40
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: "transparent" }
                                GradientStop { position: 1.0; color: tab.a(tab.th.cardBot, 0.92) }
                            }
                        }
                        Text {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.margins: 6
                            anchors.bottomMargin: cell.busy ? 10 : 6
                            elide: Text.ElideRight
                            text: cell.modelData.name
                            color: tab.th.bright
                            font.family: tab.th.font
                            font.pixelSize: 10
                        }
                        // download progress along the bottom edge
                        Rectangle {
                            visible: cell.busy
                            anchors.left: parent.left
                            anchors.bottom: parent.bottom
                            height: 4
                            width: parent.width * tab.progressOf(cell.modelData)
                            color: tab.th.accent
                        }
                        Text {
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 5
                            visible: tab.isFav(cell.modelData.key)
                            text: "\u2605"
                            color: tab.th.accent
                            font.family: tab.th.font
                            font.pixelSize: 14
                        }
                        // "not installed" badge
                        Rectangle {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.margins: 5
                            visible: !cell.modelData.installed && !cell.busy
                            width: 20
                            height: 20
                            radius: 10
                            color: tab.a(tab.th.cardBot, 0.85)
                            border.width: 1
                            border.color: tab.th.accent
                            Text {
                                anchors.centerIn: parent
                                text: "\u2193"
                                color: tab.th.accent
                                font.family: tab.th.font
                                font.pixelSize: 11
                                font.bold: true
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            tab.selIdx = cell.index;
                            if (tab.host)
                                tab.host.focusKb();
                        }
                        onDoubleClicked: tab.launch(cell.modelData)
                    }
                }
            }

            // help card for the "Not installed" category when the library is not loaded
            Rectangle {
                anchors.centerIn: parent
                width: parent.width - 30
                height: helpCol.implicitHeight + 28
                visible: tab.filterMode === 3 && tab.notInstalled.length === 0 && tab.query === ""
                radius: tab.th.radius
                color: tab.a(tab.th.accent, 0.06)
                border.width: 1
                border.color: tab.a(tab.th.accent, 0.35)

                Column {
                    id: helpCol
                    x: 14
                    y: 14
                    width: parent.width - 28
                    spacing: 8
                    Text {
                        width: parent.width
                        wrapMode: Text.Wrap
                        text: tab.libBusy ? "Fetching your Steam library..." : "Games you own but have not installed"
                        color: tab.th.bright
                        font.family: tab.th.font
                        font.pixelSize: 13
                        font.bold: true
                    }
                    Text {
                        width: parent.width
                        wrapMode: Text.Wrap
                        text: tab.libStatus !== "" ? tab.libStatus
                            : (tab.steamKey === "" ? "Add a free Steam Web API key in Settings (the gear icon), then press the refresh button. Your profile's game details must be public."
                                                   : "Press the refresh button to load your library.")
                        color: tab.th.dim
                        font.family: tab.th.font
                        font.pixelSize: 11
                    }
                    Row {
                        spacing: 16
                        Text {
                            text: "Get an API key"
                            color: keyMouse.containsMouse ? tab.th.bright : tab.th.accent
                            font.family: tab.th.font
                            font.pixelSize: 11
                            font.bold: true
                            MouseArea {
                                id: keyMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: tab.openKeyPage()
                            }
                        }
                        Text {
                            text: "Load library"
                            color: loadMouse.containsMouse ? tab.th.bright : tab.th.accent
                            font.family: tab.th.font
                            font.pixelSize: 11
                            font.bold: true
                            MouseArea {
                                id: loadMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: tab.fetchLibrary()
                            }
                        }
                    }
                }
            }
        }

        Text {
            width: parent.width
            height: 16
            elide: Text.ElideRight
            text: tab.note !== "" ? tab.note
                : (tab.shown.length + (tab.shown.length === 1 ? " game" : " games") + "  \u00B7  Enter play/install  \u00B7  F favorite  \u00B7  S sort  \u00B7  A category")
            color: tab.note !== "" ? tab.th.accent : tab.a(tab.th.dim, 0.8)
            font.family: tab.th.font
            font.pixelSize: 10
        }
    }

    LaunchOptions {
        id: optsCard
        z: 20
        anchors.fill: parent
        visible: false
        th: tab.th
        gt: tab
        onClosed: visible = false
    }
}
