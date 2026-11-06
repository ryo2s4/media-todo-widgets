import QtQuick
import Quickshell
import Quickshell.Io

// Settings.qml: the things the calendar lets you change.
// Saved in ~/.config/quickshell/calendar/settings.json
Scope {
    id: cfg

    readonly property string home: Quickshell.env("HOME")

    property string gif: ""              // absolute path, ~/path, or file:// URL
    property string city: ""             // empty = guess from the IP address
    property string units: "c"           // "c" | "f"
    property int panelWidth: 700
    property real panelOpacity: 1.0
    property real aura: 0.7              // 0..1 accent glow strength
    property string accentOverride: ""   // "#rrggbb", empty = Ryoku palette
    property bool autoLayout: true       // compact / comfortable / roomy by size
    property bool reducedMotion: false
    property bool highContrast: false

    // Clock and calendar
    property bool clock24h: true
    property bool showSeconds: true
    property bool weekStartsMonday: false
    property bool showMoonLine: true
    property bool showWeatherStrip: true
    property bool showTaskNext: true

    // Gif and the reserved skin stage
    property bool showGif: true
    property string gifFit: "cover"       // "cover" | "contain"
    property bool showSkinStage: true
    property string skinImage: ""         // optional image for the reserved stage
    property string skinFit: "cover"      // "cover" | "contain"
    property bool skinHints: true         // show the "skin stage" placeholder text

    readonly property var strKeys: ["gif", "city", "units", "accentOverride", "gifFit", "skinImage", "skinFit"]
    readonly property var numKeys: ["panelWidth", "panelOpacity", "aura"]
    readonly property var boolKeys: [
        "autoLayout", "reducedMotion", "highContrast",
        "clock24h", "showSeconds", "weekStartsMonday", "showMoonLine",
        "showWeatherStrip", "showTaskNext", "showGif", "showSkinStage", "skinHints"
    ]

    readonly property bool accentValid: /^#[0-9a-f]{6}$/i.test(accentOverride.trim())

    function _obj() {
        var o = {};
        var all = strKeys.concat(numKeys).concat(boolKeys);
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
            for (var j = 0; j < numKeys.length; j++)
                if (s[numKeys[j]] !== undefined && !isNaN(Number(s[numKeys[j]])))
                    cfg[numKeys[j]] = Number(s[numKeys[j]]);
            for (var k = 0; k < boolKeys.length; k++) {
                var key = boolKeys[k];
                if (s[key] !== undefined) {
                    var v = s[key];
                    cfg[key] = v === true || v === 1 || v === "1" || v === "true";
                }
            }
            // Keep the visual controls inside sane bounds.
            cfg.panelOpacity = Math.max(0.5, Math.min(1, cfg.panelOpacity));
            cfg.aura = Math.max(0, Math.min(1, cfg.aura));
            if (cfg.gifFit !== "contain")
                cfg.gifFit = "cover";
            if (cfg.skinFit !== "contain")
                cfg.skinFit = "cover";
        } catch (e) {
            console.log("calendar: could not read settings.json:", e);
        }
    }

    function set(key, value) {
        cfg[key] = value;
        save();
    }

    function save() { saveTimer.restart(); }

    Timer {
        id: saveTimer
        interval: 400
        onTriggered: store.setText(JSON.stringify(cfg._obj(), null, 1))
    }

    FileView {
        id: store
        path: Quickshell.env("HOME") + "/.config/quickshell/calendar/settings.json"
        onLoaded: cfg._load(store.text())
    }
}
