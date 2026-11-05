import QtQuick
import Quickshell
import Quickshell.Io

// Stats.qml: system numbers for the Home tab. One small shell script runs every
// few seconds while `active` is true and prints key=value lines. The last
// three minutes of CPU, temperature and network speed are kept for the graphs.
Scope {
    id: st

    property bool active: false

    property real cpu: 0          // percent
    property real memPct: 0
    property real memUsed: 0      // GB
    property real memTotal: 0     // GB
    property int temp: -1         // degrees C, -1 = unknown
    property real diskPct: 0
    property real diskUsed: 0     // GB
    property real diskTotal: 0    // GB
    property string uptime: ""
    property int battery: -1      // percent, -1 = no battery
    property string batState: ""
    property string net: ""
    property bool vpn: false
    property string vpnName: ""
    property real rx: 0           // bytes per second
    property real tx: 0
    property int volume: -1       // percent, -1 = unknown
    property bool muted: false
    property int brightness: -1   // percent, -1 = no backlight

    property var cpuHist: []
    property var tempHist: []
    property var rxHist: []
    property var txHist: []

    property real _prevTotal: 0
    property real _prevIdle: 0
    property real _prevRx: -1
    property real _prevTx: -1
    property double _prevTime: 0

    readonly property var scriptLines: [
        "head -n1 /proc/stat | sed 's/^/cpu=/'",
        "awk '/MemTotal/{t=$2} /MemAvailable/{a=$2} END{print \"mem=\" t \" \" a}' /proc/meminfo",
        "for h in /sys/class/hwmon/hwmon*; do n=$(cat \"$h/name\" 2>/dev/null); case \"$n\" in coretemp|k10temp|zenpower|cpu_thermal) t=$(cat \"$h/temp1_input\" 2>/dev/null); if [ -n \"$t\" ]; then echo \"temp=$((t/1000))\"; break; fi;; esac; done",
        "df -B1 --output=size,used / 2>/dev/null | tail -n1 | awk '{print \"disk=\" $1 \" \" $2}'",
        "echo \"uptime=$(cut -d' ' -f1 /proc/uptime)\"",
        "for b in /sys/class/power_supply/BAT*; do if [ -d \"$b\" ]; then echo \"bat=$(cat \"$b/capacity\") $(cat \"$b/status\")\"; break; fi; done",
        "awk 'NR>2 && $1 !~ /^lo:/ {rx+=$2; tx+=$10} END{print \"netb=\" rx \" \" tx}' /proc/net/dev",
        "v=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null); [ -n \"$v\" ] && echo \"vol=$v\"",
        "brightnessctl -m 2>/dev/null | head -n1 | awk -F, '{print \"bri=\" $4}'",
        "nmcli -t -f NAME,TYPE connection show --active 2>/dev/null | grep -E ':(802-11-wireless|ethernet)$' | head -n1 | cut -d: -f1 | sed 's/^/net=/'",
        "nmcli -t -f NAME,TYPE connection show --active 2>/dev/null | grep -i -E 'proton|wireguard|vpn' | head -n1 | cut -d: -f1 | sed 's/^/vpn=/'"
    ]

    Process {
        id: proc
        command: ["sh", "-c", st.scriptLines.join("\n")]
        stdout: StdioCollector {
            onStreamFinished: st._parse(text)
        }
    }

    Timer {
        interval: 3000
        repeat: true
        running: st.active
        triggeredOnStart: true
        onTriggered: st.refresh()
    }

    function refresh() {
        if (!proc.running)
            proc.running = true;
    }

    function _push(arr, v) {
        var out = arr.length >= 60 ? arr.slice(arr.length - 59) : arr.slice();
        out.push(v);
        return out;
    }

    function _fmtUptime(sec) {
        var d = Math.floor(sec / 86400);
        var h = Math.floor((sec % 86400) / 3600);
        var m = Math.floor((sec % 3600) / 60);
        if (d > 0)
            return d + "d " + h + "h";
        if (h > 0)
            return h + "h " + m + "m";
        return m + "m";
    }

    function fmtRate(bps) {
        if (bps >= 1048576)
            return (bps / 1048576).toFixed(1) + " MB/s";
        if (bps >= 1024)
            return Math.round(bps / 1024) + " KB/s";
        return Math.round(bps) + " B/s";
    }

    function _parse(out) {
        var lines = String(out).split("\n");
        var vpnFound = false;
        var netFound = "";
        var batFound = -1;
        var tempFound = -1;
        var volFound = -1;
        var mutedFound = false;
        var briFound = -1;
        var now = Date.now();
        for (var i = 0; i < lines.length; i++) {
            var l = lines[i];
            var eq = l.indexOf("=");
            if (eq < 0)
                continue;
            var k = l.substring(0, eq);
            var v = l.substring(eq + 1).trim();
            if (k === "cpu") {
                var p = v.split(/\s+/).slice(1).map(Number);
                if (p.length >= 5) {
                    var idle = p[3] + (p[4] || 0);
                    var total = 0;
                    for (var j = 0; j < Math.min(8, p.length); j++)
                        total += p[j];
                    if (_prevTotal > 0 && total > _prevTotal) {
                        cpu = Math.max(0, Math.min(100, 100 * (1 - (idle - _prevIdle) / (total - _prevTotal))));
                        cpuHist = _push(cpuHist, cpu);
                    }
                    _prevTotal = total;
                    _prevIdle = idle;
                }
            } else if (k === "mem") {
                var m = v.split(" ").map(Number);
                if (m[0] > 0) {
                    memTotal = m[0] / 1048576;
                    memUsed = (m[0] - m[1]) / 1048576;
                    memPct = 100 * (m[0] - m[1]) / m[0];
                }
            } else if (k === "temp") {
                tempFound = Number(v);
            } else if (k === "disk") {
                var d = v.split(" ").map(Number);
                if (d[0] > 0) {
                    diskTotal = d[0] / 1e9;
                    diskUsed = d[1] / 1e9;
                    diskPct = 100 * d[1] / d[0];
                }
            } else if (k === "uptime") {
                uptime = _fmtUptime(Number(v));
            } else if (k === "bat") {
                var b = v.split(" ");
                batFound = Number(b[0]);
                batState = b.slice(1).join(" ");
            } else if (k === "netb") {
                var nb = v.split(" ").map(Number);
                if (_prevRx >= 0 && now > _prevTime) {
                    var dt = (now - _prevTime) / 1000;
                    rx = Math.max(0, (nb[0] - _prevRx) / dt);
                    tx = Math.max(0, (nb[1] - _prevTx) / dt);
                    rxHist = _push(rxHist, rx);
                    txHist = _push(txHist, tx);
                }
                _prevRx = nb[0];
                _prevTx = nb[1];
                _prevTime = now;
            } else if (k === "vol") {
                var vp = v.split(" ");
                volFound = Math.round(Number(vp[1]) * 100);
                mutedFound = v.indexOf("MUTED") >= 0;
            } else if (k === "bri") {
                briFound = Math.round(parseFloat(v));
            } else if (k === "net") {
                netFound = v;
            } else if (k === "vpn" && v !== "") {
                vpnFound = true;
                vpnName = v;
            }
        }
        temp = tempFound;
        if (tempFound >= 0)
            tempHist = _push(tempHist, tempFound);
        battery = batFound;
        net = netFound;
        vpn = vpnFound;
        volume = volFound;
        muted = mutedFound;
        brightness = isNaN(briFound) ? -1 : briFound;
        if (!vpnFound)
            vpnName = "";
    }
}
