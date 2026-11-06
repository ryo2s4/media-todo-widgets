import QtQuick

// Moon.qml: a real phase drawing, not a picture set.
// The terminator is the projected edge of the lit half of the sphere, so the
// crescent thickness follows the actual age of the moon.
Item {
    id: moon

    property color litColor: "#f2ecdf"
    property color shadeColor: "#10141a"
    property color rimColor: "#dfe3e7"
    property color glowColor: "#90cef4"
    property real glowStrength: 0.22
    property real pad: 4
    property bool craters: true
    property bool live: true

    // 0 = new, 0.25 = first quarter, 0.5 = full, 0.75 = last quarter
    property real phase: 0
    property real ageDays: 0
    property real illumination: 0
    property int lunarDay: 1
    property string phaseName: "New moon"
    property date nextNew: new Date()
    property date nextFull: new Date()

    readonly property real synodic: 29.530588853
    readonly property double epoch: Date.UTC(2000, 0, 6, 18, 14, 0)

    function refresh() {
        var days = (Date.now() - epoch) / 86400000;
        var age = days % synodic;
        if (age < 0)
            age += synodic;
        ageDays = age;
        phase = age / synodic;
        illumination = (1 - Math.cos(phase * Math.PI * 2)) / 2;
        lunarDay = Math.floor(age) + 1;
        phaseName = nameFor(phase);
        nextNew = dateAtPhase(0);
        nextFull = dateAtPhase(0.5);
        canvas.requestPaint();
    }

    // Date of the next occurrence of a phase fraction. This is intentionally
    // approximate (the synodic month varies slightly), which is plenty for a
    // glanceable calendar card.
    function dateAtPhase(target) {
        var delta = target - phase;
        if (delta < 0)
            delta += 1;
        return new Date(Date.now() + delta * synodic * 86400000);
    }

    function nameFor(p) {
        if (p < 0.02 || p > 0.98)
            return "New moon";
        if (p < 0.23)
            return "Waxing crescent";
        if (p < 0.27)
            return "First quarter";
        if (p < 0.48)
            return "Waxing gibbous";
        if (p < 0.52)
            return "Full moon";
        if (p < 0.73)
            return "Waning gibbous";
        if (p < 0.77)
            return "Last quarter";
        return "Waning crescent";
    }

    function rgba(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a);
    }

    function crater(ctx, x, y, r, a) {
        ctx.beginPath();
        ctx.arc(x, y, r, 0, Math.PI * 2);
        ctx.fillStyle = Qt.rgba(0.42, 0.38, 0.32, a);
        ctx.fill();
    }

    function paint(ctx) {
        var w = canvas.width;
        var h = canvas.height;
        var cx = w / 2;
        var cy = h / 2;
        var r = Math.min(w, h) / 2 - pad;
        if (r <= 0)
            return;

        ctx.clearRect(0, 0, w, h);
        ctx.setTransform(1, 0, 0, 1, 0, 0);

        // soft halo
        if (glowStrength > 0) {
            var halo = ctx.createRadialGradient(cx, cy, r * 0.6, cx, cy, r * 1.55);
            halo.addColorStop(0, rgba(glowColor, glowStrength));
            halo.addColorStop(0.55, rgba(glowColor, glowStrength * 0.35));
            halo.addColorStop(1, rgba(glowColor, 0));
            ctx.fillStyle = halo;
            ctx.beginPath();
            ctx.arc(cx, cy, r * 1.55, 0, Math.PI * 2);
            ctx.fill();
        }

        // lit surface
        var body = ctx.createRadialGradient(cx - r * 0.35, cy - r * 0.35, r * 0.1, cx, cy, r);
        body.addColorStop(0, litColor);
        body.addColorStop(1, Qt.darker(litColor, 1.35));
        ctx.fillStyle = body;
        ctx.beginPath();
        ctx.arc(cx, cy, r, 0, Math.PI * 2);
        ctx.fill();

        // a few craters, clipped to the disc
        if (craters) {
            ctx.save();
            ctx.beginPath();
            ctx.arc(cx, cy, r, 0, Math.PI * 2);
            ctx.clip();
            crater(ctx, cx - r * 0.34, cy - r * 0.28, r * 0.19, 0.16);
            crater(ctx, cx + r * 0.22, cy - r * 0.38, r * 0.11, 0.13);
            crater(ctx, cx + r * 0.30, cy + r * 0.10, r * 0.15, 0.14);
            crater(ctx, cx - r * 0.10, cy + r * 0.36, r * 0.10, 0.12);
            crater(ctx, cx - r * 0.52, cy + r * 0.16, r * 0.07, 0.10);
            crater(ctx, cx + r * 0.50, cy + r * 0.42, r * 0.06, 0.10);
            ctx.restore();
        }

        // dark side: the outer left (or right) half plus the terminator ellipse.
        // cos(phase angle) gives the terminator's signed half-width; at new/full
        // it equals r, at the quarters it is 0 (a straight line).
        ctx.save();
        ctx.beginPath();
        ctx.arc(cx, cy, r, 0, Math.PI * 2);
        ctx.clip();
        var a = r * Math.cos(phase * Math.PI * 2);
        if (phase > 0.5) {
            ctx.translate(cx, cy);
            ctx.scale(-1, 1);
            ctx.translate(-cx, -cy);
        }
        var k = 0.5522847498;
        ctx.beginPath();
        ctx.moveTo(cx, cy - r);
        ctx.arc(cx, cy, r, -Math.PI / 2, Math.PI / 2, true);
        ctx.bezierCurveTo(cx + a * k, cy + r, cx + a, cy + r * k, cx + a, cy);
        ctx.bezierCurveTo(cx + a, cy - r * k, cx + a * k, cy - r, cx, cy - r);
        ctx.closePath();
        ctx.fillStyle = rgba(shadeColor, 0.93);
        ctx.fill();
        ctx.restore();

        // rim
        ctx.beginPath();
        ctx.arc(cx, cy, r, 0, Math.PI * 2);
        ctx.strokeStyle = rgba(rimColor, 0.20);
        ctx.lineWidth = 1;
        ctx.stroke();
    }

    onPhaseChanged: canvas.requestPaint()
    onLitColorChanged: canvas.requestPaint()
    onShadeColorChanged: canvas.requestPaint()
    onGlowColorChanged: canvas.requestPaint()
    onPadChanged: canvas.requestPaint()
    onCratersChanged: canvas.requestPaint()

    Component.onCompleted: if (live) refresh()

    Timer {
        interval: 600000
        repeat: true
        running: live
        onTriggered: moon.refresh()
    }

    Canvas {
        id: canvas
        anchors.fill: parent
        antialiasing: true
        onPaint: moon.paint(getContext("2d"))
    }
}
