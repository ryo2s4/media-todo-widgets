import QtQuick
import Quickshell
import Quickshell.Io

// Lyrics.qml: looks the current track up on LRCLIB (free, no key). Synced lyrics
// become `lines` ([{ t, text }], t in seconds); plain lyrics go to `plain`.
Scope {
    id: ly

    property bool enabled: true
    property string artist: ""
    property string title: ""
    property string album: ""
    property real duration: 0

    property var lines: []
    property string plain: ""
    property string status: ""          // "", "loading", "none"
    property string trackKey: ""
    property var cache: ({})

    readonly property string base: "https://lrclib.net/api/"
    readonly property string ua: "media-panel (quickshell, personal use)"

    function enc(s) { return encodeURIComponent(s); }
    function keyNow() { return artist.trim().toLowerCase() + "|" + title.trim().toLowerCase(); }

    onArtistChanged: schedule.restart()
    onTitleChanged: schedule.restart()
    onEnabledChanged: if (enabled) schedule.restart()

    Timer {
        id: schedule
        interval: 500
        onTriggered: ly.load()
    }

    function load() {
        if (!enabled || title.trim() === "") {
            lines = [];
            plain = "";
            status = "";
            trackKey = "";
            return;
        }
        var k = keyNow();
        if (k === trackKey && (status === "loading" || lines.length > 0 || plain !== ""))
            return;
        trackKey = k;
        if (cache[k]) {
            lines = cache[k].lines;
            plain = cache[k].plain;
            status = (lines.length > 0 || plain !== "") ? "" : "none";
            return;
        }
        lines = [];
        plain = "";
        status = "loading";
        var url = base + "get?artist_name=" + enc(artist) + "&track_name=" + enc(title)
            + (album !== "" ? "&album_name=" + enc(album) : "")
            + (duration > 0 ? "&duration=" + Math.round(duration) : "");
        getProc.command = ["curl", "-s", "-m", "15", "-A", ua, url];
        getProc.running = true;
    }

    function parseLrc(text) {
        var out = [];
        var re = /\[(\d+):(\d+(?:\.\d+)?)\]/g;
        var rows = String(text).split("\n");
        for (var i = 0; i < rows.length; i++) {
            var row = rows[i];
            var times = [];
            var m;
            re.lastIndex = 0;
            while ((m = re.exec(row)) !== null)
                times.push(Number(m[1]) * 60 + Number(m[2]));
            var txt = row.replace(/\[[^\]]*\]/g, "").trim();
            for (var j = 0; j < times.length; j++)
                out.push({ t: times[j], text: txt });
        }
        out.sort(function (a, b) { return a.t - b.t; });
        return out;
    }

    function finish(k, obj) {
        if (k !== keyNow())
            return;
        var l = (obj && obj.syncedLyrics) ? parseLrc(obj.syncedLyrics) : [];
        var p = (obj && obj.plainLyrics) ? String(obj.plainLyrics) : "";
        var c = cache;
        c[k] = { lines: l, plain: p };
        cache = c;
        lines = l;
        plain = p;
        status = (l.length > 0 || p !== "") ? "" : "none";
    }

    function getDone(txt) {
        var k = trackKey;
        try {
            var r = JSON.parse(txt);
            if (r && (r.syncedLyrics || r.plainLyrics)) {
                finish(k, r);
                return;
            }
        } catch (e) {
            // fall through to the search
        }
        if (k !== keyNow())
            return;
        searchProc.command = ["curl", "-s", "-m", "15", "-A", ua, base + "search?q=" + enc(artist + " " + title)];
        searchProc.running = true;
    }

    function searchDone(txt) {
        var k = trackKey;
        try {
            var arr = JSON.parse(txt);
            if (Array.isArray(arr)) {
                var best = null;
                for (var i = 0; i < arr.length; i++) {
                    if (arr[i].syncedLyrics) {
                        best = arr[i];
                        break;
                    }
                    if (!best && arr[i].plainLyrics)
                        best = arr[i];
                }
                finish(k, best);
                return;
            }
        } catch (e) {
            // no result
        }
        finish(k, null);
    }

    Process {
        id: getProc
        stdout: StdioCollector {
            onStreamFinished: ly.getDone(text)
        }
    }
    Process {
        id: searchProc
        stdout: StdioCollector {
            onStreamFinished: ly.searchDone(text)
        }
    }
}
