pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// Reads ~/.config/quickshell/todo/status.json (written by the todo panel) and
// opens the panel with `qs -c todo ipc call todo toggle`.
Item {
    id: svc

    property var pluginApi
    readonly property var settings: pluginApi ? pluginApi.pluginSettings : null

    property bool available: false
    property int urgent: 0
    property int pending: 0
    property bool running: false
    property double endAt: 0
    property int idleRemaining: 0
    property int remaining: 0
    property string task: ""
    property string mode: ""
    property int doneToday: 0
    property int goal: 5
    property int streak: 0

    function fmt(sec) {
        var m = Math.floor(sec / 60);
        var s = sec % 60;
        return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s;
    }

    function _tick() {
        remaining = running ? Math.max(0, Math.round((endAt - Date.now()) / 1000)) : idleRemaining;
    }

    function _read(raw) {
        try {
            var s = JSON.parse(raw);
            urgent = s.urgent || 0;
            pending = s.pending || 0;
            running = !!s.running;
            endAt = s.endAt || 0;
            idleRemaining = s.remaining || 0;
            task = s.task || "";
            mode = s.mode || "";
            doneToday = s.doneToday || 0;
            goal = s.goal || 5;
            streak = s.streak || 0;
            available = true;
            _tick();
        } catch (e) {
            console.log("todostatus: could not read status.json:", e);
        }
    }

    FileView {
        id: statusFile
        path: Quickshell.env("HOME") + "/.config/quickshell/todo/status.json"
        watchChanges: true
        onFileChanged: statusFile.reload()
        onLoaded: svc._read(statusFile.text())
        onLoadFailed: svc.available = false
    }

    Timer {
        interval: 1000
        repeat: true
        running: svc.running
        onTriggered: svc._tick()
    }

    Process {
        id: toggler
        command: ["qs", "-c", "todo", "ipc", "call", "todo", "toggle"]
    }

    function toggleBoard() {
        toggler.running = true;
    }
}
