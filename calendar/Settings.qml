import QtQuick
import Quickshell
import Quickshell.Io

// Settings.qml: the handful of things the calendar lets you change.
// Saved in ~/.config/quickshell/calendar/settings.json
Scope {
    id: cfg

    readonly property string home: Quickshell.env("HOME")

    property string gif: ""              // absolute path, ~/path, or file:// URL
    property string city: ""             // empty = guess from the IP address
    property string units: "c"           // "c" | "f"
    property int panelWidth: 560
    property real panelOpacity: 1.0
    property string accentOverride: ""   // "#rrggbb", empty = Ryoku palette

    readonly property var strKeys: ["gif", "city", "units", "accentOverride"]
    readonly property var numKeys: ["panelWidth", "panelOpacity"]

    readonly property bool accentValid: /^#[0-9a-f]{6}$/i.test(accentOverride.trim())

    function _obj() {
        var o = {};
        var all = strKeys.concat(numKeys);
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
