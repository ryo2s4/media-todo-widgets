import QtQuick
import Quickshell.Io

// Volume (wpctl), brightness (brightnessctl) and the power buttons.
// Restart, shut down and log out need a second click within three seconds.
Column {
    id: qc

    property var th
    property var cfg
    property var stats

    spacing: 12

    function a(c, v) { return Qt.rgba(c.r, c.g, c.b, v); }

    // ───────── volume ─────────
    property int volLocal: 0
    property bool volTouched: false
    readonly property int volShown: volTouched ? volLocal : (stats ? stats.volume : -1)

    Process { id: volProc }
    Timer {
        id: volSend
        interval: 100
        onTriggered: {
            if (!volProc.running) {
                volProc.command = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", (qc.volLocal / 100).toFixed(2)];
                volProc.running = true;
            } else {
                volSend.restart();
            }
        }
    }
    Timer {
        id: volRelease
        interval: 1500
        onTriggered: {
            qc.volTouched = false;
            if (qc.stats)
                qc.stats.refresh();
        }
    }
    function setVolume(v) {
        volLocal = Math.round(v);
        volTouched = true;
        if (!volSend.running)
            volSend.start();
        volRelease.restart();
    }
    function toggleMute() {
        volProc.command = ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"];
        volProc.running = true;
        volRelease.restart();
    }

    // ───────── brightness ─────────
    property int briLocal: 0
    property bool briTouched: false
    readonly property int briShown: briTouched ? briLocal : (stats ? stats.brightness : -1)

    Process { id: briProc }
    Timer {
        id: briSend
        interval: 100
        onTriggered: {
            if (!briProc.running) {
                briProc.command = ["brightnessctl", "set", Math.max(1, qc.briLocal) + "%"];
                briProc.running = true;
            } else {
                briSend.restart();
            }
        }
    }
    Timer {
        id: briRelease
        interval: 1500
        onTriggered: {
            qc.briTouched = false;
            if (qc.stats)
                qc.stats.refresh();
        }
    }
    function setBrightness(v) {
        briLocal = Math.round(v);
        briTouched = true;
        if (!briSend.running)
            briSend.start();
        briRelease.restart();
    }

    // ───────── power ─────────
    property int armed: -1
    Process { id: powerProc }
    Timer {
        id: disarm
        interval: 3000
        onTriggered: qc.armed = -1
    }

    readonly property var actions: [
        { label: "Lock", confirm: false },
        { label: "Sleep", confirm: false },
        { label: "Restart", confirm: true },
        { label: "Shut down", confirm: true },
        { label: "Log out", confirm: true }
    ]

    function runAction(i) {
        var cmd;
        if (i === 0)
            cmd = ["sh", "-c", cfg ? cfg.lockCmd : "loginctl lock-session"];
        else if (i === 1)
            cmd = ["systemctl", "suspend"];
        else if (i === 2)
            cmd = ["systemctl", "reboot"];
        else if (i === 3)
            cmd = ["systemctl", "poweroff"];
        else
            cmd = ["hyprctl", "dispatch", "exit"];
        powerProc.command = cmd;
        powerProc.running = true;
    }

    function pressed(i) {
        if (actions[i].confirm && armed !== i) {
            armed = i;
            disarm.restart();
            return;
        }
        armed = -1;
        disarm.stop();
        runAction(i);
    }

    // ───────── layout ─────────
    Item {
        width: parent.width
        height: 24
        Text {
            id: volLabel
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 92
            text: qc.stats && qc.stats.muted ? "Volume  muted" : "Volume  " + (qc.volShown >= 0 ? qc.volShown + "%" : "--")
            color: volMouse.containsMouse ? qc.th.accent : (qc.stats && qc.stats.muted ? qc.th.dim : qc.th.bright)
            font.family: qc.th.font
            font.pixelSize: 11
            MouseArea {
                id: volMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: qc.toggleMute()
            }
        }
        Slider {
            anchors.left: volLabel.right
            anchors.leftMargin: 10
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            th: qc.th
            from: 0
            to: 100
            value: Math.max(0, qc.volShown)
            enabled: qc.volShown >= 0
            onMoved: function (v) { qc.setVolume(v); }
        }
    }

    Item {
        width: parent.width
        height: 24
        visible: qc.briShown >= 0
        Text {
            id: briLabel
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 92
            text: "Brightness  " + qc.briShown + "%"
            color: qc.th.bright
            font.family: qc.th.font
            font.pixelSize: 11
        }
        Slider {
            anchors.left: briLabel.right
            anchors.leftMargin: 10
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            th: qc.th
            from: 1
            to: 100
            value: Math.max(1, qc.briShown)
            onMoved: function (v) { qc.setBrightness(v); }
        }
    }

    Row {
        width: parent.width
        spacing: 6
        Repeater {
            model: qc.actions
            delegate: Rectangle {
                id: btn
                required property int index
                required property var modelData
                readonly property bool isArmed: qc.armed === index
                width: (parent.width - 24) / 5
                height: 30
                radius: qc.th.radius
                color: isArmed ? qc.a(qc.th.accent, 0.22) : (btnMouse.containsMouse ? qc.a(qc.th.dim, 0.16) : qc.a(qc.th.dim, 0.07))
                border.width: 1
                border.color: isArmed ? qc.th.accent : qc.a(qc.th.dim, 0.22)
                Text {
                    anchors.centerIn: parent
                    text: btn.isArmed ? "Confirm?" : btn.modelData.label
                    color: btn.isArmed ? qc.th.accent : qc.th.bright
                    font.family: qc.th.font
                    font.pixelSize: 10
                    font.bold: btn.isArmed
                }
                MouseArea {
                    id: btnMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: qc.pressed(btn.index)
                }
            }
        }
    }
}
