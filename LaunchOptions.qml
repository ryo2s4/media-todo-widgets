import QtQuick
import Quickshell
import Quickshell.Io

// Launch options for one Steam game. The options are saved into Steam's own
// per-game "launch options" (localconfig.vdf), so they apply however the game is
// started. Steam must be closed while saving; "Close Steam and apply" does that.
Rectangle {
    id: lo

    property var th
    property var gt           // the GamesTab
    property var game: null
    signal closed()

    property bool prime: false
    property bool gm: false
    property bool mh: false
    property string prefix: ""
    property string extra: ""
    property string status: ""
    property bool busy: false

    readonly property string appId: game ? game.id : ""
    readonly property bool havePrime: !!gt && !!gt.tools["prime-run"]
    readonly property bool haveGm: !!gt && !!gt.tools["gamemoderun"]
    readonly property bool haveMh: !!gt && !!gt.tools["mangohud"]

    radius: th.radius
    color: th.cardBot
    border.width: 1
    border.color: Qt.rgba(th.accent.r, th.accent.g, th.accent.b, 0.5)

    function a(c, v) { return Qt.rgba(c.r, c.g, c.b, v); }

    function compose() {
        var parts = [];
        if (prefix.trim() !== "")
            parts.push(prefix.trim());
        if (prime)
            parts.push("prime-run");
        if (gm)
            parts.push("gamemoderun");
        if (mh)
            parts.push("mangohud");
        var pre = parts.join(" ");
        var ex = extra.trim();
        if (pre === "" && ex === "")
            return "";
        return (pre !== "" ? pre + " " : "") + "%command%" + (ex !== "" ? " " + ex : "");
    }
    readonly property string composed: {
        var dep = prime + "" + gm + mh + prefix + extra;
        return compose();
    }

    function parse(opts) {
        var s = opts || "";
        prime = /(^|\s)prime-run(\s|$)/.test(s);
        gm = /(^|\s)gamemoderun(\s|$)/.test(s);
        mh = /(^|\s)mangohud(\s|$)/.test(s);
        var idx = s.indexOf("%command%");
        var before = idx >= 0 ? s.substring(0, idx) : "";
        var after = idx >= 0 ? s.substring(idx + 9) : s;
        before = before.replace(/(^|\s)(prime-run|gamemoderun|mangohud)(?=\s|$)/g, " ").replace(/\s+/g, " ").trim();
        prefix = before;
        extra = after.trim();
    }

    function open(g) {
        game = g;
        status = "";
        parse(gt && g ? (gt.launchOpts[g.id] || "") : "");
        visible = true;
    }

    function apply(closeSteam) {
        if (!game || busy)
            return;
        busy = true;
        status = closeSteam ? "Closing Steam and saving..." : "Saving...";
        var cmd = ["python3", Quickshell.env("HOME") + "/.config/quickshell/media/set-launch-options.py"];
        if (closeSteam)
            cmd.push("--close");
        cmd.push(appId);
        cmd.push(compose());
        proc.command = cmd;
        proc.running = true;
    }

    function result(out) {
        busy = false;
        var t = String(out).trim();
        if (t.indexOf("OK") === 0) {
            var m = Object.assign({}, gt.launchOpts);
            m[appId] = compose();
            gt.launchOpts = m;
            status = "Saved. Start the game from here or from Steam.";
        } else if (t === "STEAM_RUNNING") {
            status = "Steam is running. Close it first, or use \"Close Steam and apply\".";
        } else if (t === "NOFILES") {
            status = "Could not find Steam's localconfig.vdf.";
        } else {
            status = t !== "" ? t : "Nothing was saved.";
        }
    }

    Process {
        id: proc
        stdout: StdioCollector {
            onStreamFinished: lo.result(text)
        }
        onRunningChanged: if (!running) lo.busy = false
    }

    component Row2: Item {
        id: r2
        property string label: ""
        property string note: ""
        property bool on: false
        property bool avail: true
        signal toggled()
        width: parent ? parent.width : 200
        height: 34
        Column {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1
            Text {
                text: r2.label
                color: r2.avail ? lo.th.bright : lo.th.dim
                font.family: lo.th.font
                font.pixelSize: 12
            }
            Text {
                text: r2.avail ? r2.note : r2.note + " (not installed)"
                color: lo.th.dim
                font.family: lo.th.font
                font.pixelSize: 9
            }
        }
        Toggle {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            on: r2.on
            accent: lo.th.accent
            dim: lo.th.dim
            onToggled: r2.toggled()
        }
    }

    MouseArea { anchors.fill: parent }   // swallow clicks behind the card

    Item {
        id: bar
        x: 16
        y: 12
        width: parent.width - 32
        height: 24
        Text {
            anchors.left: parent.left
            anchors.right: closeBtn.left
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            text: "Launch options  \u00B7  " + (lo.game ? lo.game.name : "")
            color: lo.th.bright
            font.family: lo.th.font
            font.pixelSize: 13
            font.bold: true
        }
        IconBtn {
            id: closeBtn
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            size: 12
            glyph: "\u2715"
            idle: lo.th.dim
            hot: lo.th.accent
            family: lo.th.font
            onClicked: lo.closed()
        }
    }

    Column {
        x: 16
        y: bar.y + bar.height + 12
        width: parent.width - 32
        spacing: 8

        Row2 {
            label: "Run on the NVIDIA GPU"
            note: "prime-run"
            avail: lo.havePrime
            on: lo.prime
            onToggled: lo.prime = !lo.prime
        }
        Row2 {
            label: "GameMode"
            note: "gamemoderun, CPU and GPU tweaks while playing"
            avail: lo.haveGm
            on: lo.gm
            onToggled: lo.gm = !lo.gm
        }
        Row2 {
            label: "MangoHud overlay"
            note: "mangohud, shows FPS and temperatures"
            avail: lo.haveMh
            on: lo.mh
            onToggled: lo.mh = !lo.mh
        }
        Field {
            width: parent.width
            th: lo.th
            label: "Environment variables (before the game)"
            placeholder: "e.g. __GL_SHADER_DISK_CACHE=1"
            text: lo.prefix
            onCommitted: function (v) { lo.prefix = v; }
        }
        Field {
            width: parent.width
            th: lo.th
            label: "Game arguments (after the game)"
            placeholder: "e.g. -windowed -novid"
            text: lo.extra
            onCommitted: function (v) { lo.extra = v; }
        }

        Rectangle {
            width: parent.width
            height: prev.implicitHeight + 16
            radius: 5
            color: lo.a(lo.th.dim, 0.08)
            border.width: 1
            border.color: lo.a(lo.th.dim, 0.2)
            Text {
                id: prev
                x: 8
                y: 8
                width: parent.width - 16
                wrapMode: Text.WrapAnywhere
                text: lo.composed !== "" ? lo.composed : "(no launch options)"
                color: lo.composed !== "" ? lo.th.bright : lo.th.dim
                font.family: "monospace"
                font.pixelSize: 11
            }
        }

        Row {
            spacing: 18
            Text {
                text: "Apply"
                color: lo.busy ? lo.th.dim : (applyMouse.containsMouse ? lo.th.bright : lo.th.accent)
                font.family: lo.th.font
                font.pixelSize: 12
                font.bold: true
                MouseArea {
                    id: applyMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: !lo.busy
                    cursorShape: Qt.PointingHandCursor
                    onClicked: lo.apply(false)
                }
            }
            Text {
                text: "Close Steam and apply"
                color: lo.busy ? lo.th.dim : (closeApplyMouse.containsMouse ? lo.th.bright : lo.th.accent)
                font.family: lo.th.font
                font.pixelSize: 12
                font.bold: true
                MouseArea {
                    id: closeApplyMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: !lo.busy
                    cursorShape: Qt.PointingHandCursor
                    onClicked: lo.apply(true)
                }
            }
        }

        Text {
            width: parent.width
            visible: lo.status !== ""
            wrapMode: Text.Wrap
            text: lo.status
            color: lo.th.dim
            font.family: lo.th.font
            font.pixelSize: 10
        }
        Text {
            width: parent.width
            wrapMode: Text.Wrap
            text: "Saved into Steam's own launch options for this game (a backup of localconfig.vdf is kept next to it). Steam rewrites that file on exit, so it must be closed while saving."
            color: lo.a(lo.th.dim, 0.85)
            font.family: lo.th.font
            font.pixelSize: 9
        }
    }
}
