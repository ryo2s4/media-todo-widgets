import QtQuick
import Quickshell
import Quickshell.Io

// Settings.qml: everything the settings card edits.
// Saved in ~/.config/quickshell/media/settings.json
Scope {
    id: cfg

    readonly property string user: Quickshell.env("USER")
    readonly property string home: Quickshell.env("HOME")

    // ── Profile ──
    property string name: ""              // empty = the system username
    property string subtitle: ""
    property string lang: "ar"            // "ar" | "en"
    property string greetMorning: ""      // empty = default for the language
    property string greetDay: ""
    property string greetEvening: ""
    property string greetNight: ""
    property string avatarPath: ""        // empty = ~/.face
    property string bannerPath: ""        // image or GIF behind the profile
    property real bannerDim: 0.45
    property string avatarFrame: ""      // frame id from frames.json, "custom", or empty for none
    property string customFramePath: ""  // your own frame: PNG with a transparent middle
    property real customFrameHole: 0.7     // the middle's diameter as a fraction of the image width

    // ── Weather ──
    property bool weatherEnabled: true
    property string city: ""              // empty = guess from the IP address
    property string units: "c"            // "c" | "f"
    property bool weatherFx: true         // rain, snow and clouds over the banner

    // ── Home sections ──
    property bool showQuote: true
    property bool showSystem: true
    property bool showQuick: true
    property bool showLaunchers: true
    property bool showContinue: true
    property bool showShots: true
    property bool showCalendar: true
    property bool showNote: true
    property string systemView: "gauges"  // "gauges" | "graphs"
    property string shotsDir: ""          // empty = ~/Pictures/Screenshots
    property string lockCmd: "loginctl lock-session"
    property var customApps: []           // [{ name, cmd }]

    // ── Quotes ──
    property string quoteMode: "daily"    // "daily" | "random"
    property bool useBuiltinQuotes: true
    property var customQuotes: []

    // ── Music ──
    property string musicBg: ""           // image or GIF
    property bool cavaEnabled: true
    property int cavaBars: 32
    property string cavaMethod: "pipewire"
    property bool bgReact: true
    property bool lyricsEnabled: true
    property int lyricsOffset: 0          // milliseconds, positive = lyrics appear later

    // ── Games ──
    property string steamKey: ""
    property string steamId: ""           // empty = detected from Steam
    property bool closeOnLaunch: true

    // ── Appearance ──
    property real panelOpacity: 0.9
    property int panelWidth: 460
    property int cornerRadius: -1         // -1 = follow the Ryoku theme
    property string accentOverride: ""    // "#rrggbb", empty = Ryoku palette

    readonly property var strKeys: ["name", "subtitle", "lang", "greetMorning", "greetDay", "greetEvening", "greetNight",
        "avatarPath", "bannerPath", "avatarFrame", "customFramePath", "city", "units", "systemView", "shotsDir", "lockCmd", "quoteMode",
        "musicBg", "cavaMethod", "steamKey", "steamId", "accentOverride"]
    readonly property var boolKeys: ["weatherEnabled", "weatherFx", "showQuote", "showSystem", "showQuick", "showLaunchers",
        "showContinue", "showShots", "showCalendar", "showNote", "useBuiltinQuotes", "cavaEnabled", "bgReact",
        "lyricsEnabled", "closeOnLaunch"]
    readonly property var numKeys: ["bannerDim", "customFrameHole", "cavaBars", "lyricsOffset", "panelOpacity", "panelWidth", "cornerRadius"]

    readonly property string displayName: name.trim() !== "" ? name.trim() : user
    readonly property string avatarFile: avatarPath.trim() !== "" ? avatarPath.trim() : home + "/.face"
    readonly property string shotsFolder: shotsDir.trim() !== "" ? shotsDir.trim() : home + "/Pictures/Screenshots"
    readonly property bool accentValid: /^#[0-9a-f]{6}$/i.test(accentOverride.trim())

    readonly property var builtinQuotes: [
        "ابدأ من حيث أنت، بما عندك، وكمّل.",
        "الخطوة الصغيرة كل يوم تغلب القفزة الكبيرة مرة في السنة.",
        "الكود اللي ما يشتغل اليوم، يشتغل بعد استراحة قصيرة.",
        "ركّز على شي واحد، وسوّه زين.",
        "كل خطأ تحله اليوم هو درس ما راح تنساه.",
        "لا تقارن بدايتك بنهاية غيرك.",
        "قسّم المهمة الكبيرة لمهام صغيرة، وبتخلص.",
        "الانضباط يسوي اللي ما تسويه الحماسة.",
        "الراحة جزء من الشغل مو عكسه.",
        "السرعة تجي مع التكرار، والإتقان مع الصبر.",
        "اكتب الخطة، ونفّذ أول بند.",
        "كل مشروع كبير بدأ بملف فاضي.",
        "الحل غالباً أبسط مما تتخيل.",
        "جرّب وافشل وعدّل، هذا الطريق.",
        "إنجاز اليوم أحسن من كمال بكرة.",
        "خذ نفس عميق، وارجع للمهمة."
    ]

    function allQuotes() {
        var out = useBuiltinQuotes ? builtinQuotes.slice() : [];
        out = out.concat(customQuotes);
        return out.length > 0 ? out : builtinQuotes;
    }

    function defaultGreeting(period) {
        var ar = ["صباح الخير", "نهارك سعيد", "مساء الخير", "ليلة سعيدة"];
        var en = ["Good morning", "Good afternoon", "Good evening", "Good night"];
        return (lang === "ar" ? ar : en)[period];
    }

    function greeting(hour) {
        var p = (hour >= 5 && hour < 12) ? 0 : (hour >= 12 && hour < 16) ? 1 : (hour >= 16 && hour < 21) ? 2 : 3;
        var custom = [greetMorning, greetDay, greetEvening, greetNight][p];
        return custom.trim() !== "" ? custom : defaultGreeting(p);
    }

    function addQuote(text) {
        text = String(text).trim();
        if (text === "")
            return;
        customQuotes = customQuotes.concat([text]);
        save();
    }

    function removeQuote(i) {
        var arr = customQuotes.slice();
        if (i >= 0 && i < arr.length)
            arr.splice(i, 1);
        customQuotes = arr;
        save();
    }

    function addApp(appName, cmd) {
        appName = String(appName).trim();
        cmd = String(cmd).trim();
        if (appName === "" || cmd === "")
            return;
        customApps = customApps.concat([{ name: appName, cmd: cmd }]);
        save();
    }

    function removeApp(i) {
        var arr = customApps.slice();
        if (i >= 0 && i < arr.length)
            arr.splice(i, 1);
        customApps = arr;
        save();
    }

    // set a plain setting by name and save
    function set(key, value) {
        cfg[key] = value;
        save();
    }

    // ── persistence ──
    function _obj() {
        var o = { customQuotes: customQuotes, customApps: customApps };
        var all = strKeys.concat(boolKeys, numKeys);
        for (var i = 0; i < all.length; i++)
            o[all[i]] = cfg[all[i]];
        return o;
    }

    function _load(raw) {
        try {
            var s = JSON.parse(raw);
            for (var i = 0; i < strKeys.length; i++)
                if (s[strKeys[i]] !== undefined)
                    cfg[strKeys[i]] = String(s[strKeys[i]]);
            for (var j = 0; j < boolKeys.length; j++)
                if (s[boolKeys[j]] !== undefined)
                    cfg[boolKeys[j]] = !!s[boolKeys[j]];
            for (var k = 0; k < numKeys.length; k++)
                if (s[numKeys[k]] !== undefined && !isNaN(Number(s[numKeys[k]])))
                    cfg[numKeys[k]] = Number(s[numKeys[k]]);
            if (Array.isArray(s.customQuotes))
                customQuotes = s.customQuotes.map(String);
            if (Array.isArray(s.customApps))
                customApps = s.customApps.filter(function (a) { return a && a.name && a.cmd; })
                    .map(function (a) { return { name: String(a.name), cmd: String(a.cmd) }; });
        } catch (e) {
            console.log("media: could not read settings.json:", e);
        }
    }

    function save() { saveTimer.restart(); }

    Timer {
        id: saveTimer
        interval: 400
        onTriggered: store.setText(JSON.stringify(cfg._obj(), null, 1))
    }

    FileView {
        id: store
        path: Quickshell.env("HOME") + "/.config/quickshell/media/settings.json"
        onLoaded: cfg._load(store.text())
    }
}
