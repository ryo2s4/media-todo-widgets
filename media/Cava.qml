import QtQuick
import Quickshell
import Quickshell.Io

// Cava.qml: audio visualizer data. Runs `cava` with a generated config that
// prints one line of ";"-separated 0..100 values per frame.
Scope {
    id: cv

    property bool enabled: false      // set by the panel (music tab open and playing)
    property int bars: 32
    property string method: "pipewire"
    property var levels: []           // 0..1 per bar
    property real bass: 0             // 0..1, average of the lowest bars
    property bool available: true     // false when `cava` is not installed
    property bool confReady: false

    readonly property string confPath: Quickshell.env("HOME") + "/.config/quickshell/media/cava.conf"

    function _conf() {
        return [
            "[general]",
            "bars = " + bars,
            "framerate = 30",
            "[input]",
            "method = " + method,
            "source = auto",
            "[output]",
            "method = raw",
            "raw_target = /dev/stdout",
            "data_format = ascii",
            "ascii_max_range = 100",
            "bar_delimiter = 59",
            "frame_delimiter = 10",
            "[smoothing]",
            "noise_reduction = 60",
            ""
        ].join("\n");
    }

    function writeConf() {
        confReady = false;
        confFile.setText(_conf());
        readyTimer.restart();
    }

    onBarsChanged: writeConf()
    onMethodChanged: writeConf()
    Component.onCompleted: writeConf()

    Timer {
        id: readyTimer
        interval: 400
        onTriggered: cv.confReady = true
    }

    FileView {
        id: confFile
        path: cv.confPath
    }

    Process {
        command: ["sh", "-c", "command -v cava >/dev/null 2>&1 && echo yes || echo no"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: cv.available = (text.trim() === "yes")
        }
    }

    Process {
        id: proc
        command: ["cava", "-p", cv.confPath]
        running: cv.enabled && cv.available && cv.confReady
        stdout: SplitParser {
            onRead: function (line) { cv._frame(line); }
        }
        onRunningChanged: {
            if (!running) {
                cv.levels = [];
                cv.bass = 0;
            }
        }
    }

    function _frame(line) {
        var parts = String(line).split(";");
        var out = [];
        for (var i = 0; i < parts.length; i++) {
            if (parts[i] === "")
                continue;
            out.push(Math.max(0, Math.min(1, Number(parts[i]) / 100)));
        }
        if (out.length === 0)
            return;
        var n = Math.max(1, Math.round(out.length * 0.18));
        var sum = 0;
        for (var j = 0; j < n; j++)
            sum += out[j];
        bass = sum / n;
        levels = out;
    }
}
