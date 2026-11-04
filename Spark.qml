import QtQuick

// A sparkline. values: array of numbers; maxValue: top of the scale (0 = auto).
Canvas {
    id: sp

    property var values: []
    property real maxValue: 100
    property color tint: "#e8553a"
    property color gridColor: "#888888"

    onValuesChanged: requestPaint()
    onMaxValueChanged: requestPaint()
    onTintChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
        var ctx = getContext("2d");
        ctx.reset();
        var W = width;
        var H = height;
        if (W < 4 || H < 4)
            return;
        var v = values;
        var top = maxValue;
        if (top <= 0) {
            top = 1;
            for (var i = 0; i < v.length; i++)
                top = Math.max(top, v[i]);
        }
        // baseline
        ctx.globalAlpha = 0.25;
        ctx.strokeStyle = gridColor.toString();
        ctx.lineWidth = 1;
        ctx.beginPath();
        ctx.moveTo(0, H - 0.5);
        ctx.lineTo(W, H - 0.5);
        ctx.stroke();
        ctx.globalAlpha = 1;
        if (v.length < 2)
            return;
        var step = W / (60 - 1);
        var x0 = W - (v.length - 1) * step;
        function py(val) { return H - 2 - Math.max(0, Math.min(1, val / top)) * (H - 4); }
        ctx.beginPath();
        ctx.moveTo(x0, py(v[0]));
        for (var k = 1; k < v.length; k++)
            ctx.lineTo(x0 + k * step, py(v[k]));
        ctx.strokeStyle = tint.toString();
        ctx.lineWidth = 1.5;
        ctx.stroke();
        ctx.lineTo(x0 + (v.length - 1) * step, H);
        ctx.lineTo(x0, H);
        ctx.closePath();
        ctx.globalAlpha = 0.16;
        ctx.fillStyle = tint.toString();
        ctx.fill();
    }
}
