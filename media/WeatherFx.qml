import QtQuick

// Weather overlay for the banner. kind: clear, clouds, fog, rain, snow, storm.
// Everything is plain rectangles with looping animations; `running` stops them.
Item {
    id: fx

    property string kind: "clear"
    property bool running: true
    clip: true

    readonly property bool rainy: kind === "rain" || kind === "storm"
    readonly property bool cloudy: kind === "clouds" || kind === "rain" || kind === "storm" || kind === "snow"

    // slow drifting clouds
    Repeater {
        model: fx.cloudy ? 3 : 0
        delegate: Rectangle {
            required property int index
            y: 6 + index * 26
            width: 150 + index * 40
            height: 34 + index * 6
            radius: height / 2
            color: "#ffffff"
            opacity: fx.kind === "clouds" ? 0.10 : 0.07
            NumberAnimation on x {
                from: -260
                to: fx.width + 40
                duration: 70000 + index * 28000
                loops: Animation.Infinite
                running: fx.running
            }
        }
    }

    // fog bands
    Repeater {
        model: fx.kind === "fog" ? 2 : 0
        delegate: Rectangle {
            required property int index
            y: 40 + index * 44
            width: fx.width * 1.6
            height: 46
            opacity: 0.16
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.5; color: "#ffffff" }
                GradientStop { position: 1.0; color: "transparent" }
            }
            NumberAnimation on x {
                from: -fx.width * 0.6
                to: 0
                duration: 22000 + index * 9000
                loops: Animation.Infinite
                running: fx.running
            }
        }
    }

    // rain
    Repeater {
        model: fx.rainy ? 28 : 0
        delegate: Rectangle {
            required property int index
            x: ((index * 37) % 101) / 101 * fx.width
            width: 1
            height: 10 + (index % 4) * 3
            rotation: 14
            color: "#b8d4ff"
            opacity: 0.35
            NumberAnimation on y {
                from: -24 - (index % 9) * 14
                to: fx.height + 24
                duration: 620 + (index % 7) * 90
                loops: Animation.Infinite
                running: fx.running
            }
        }
    }

    // snow
    Repeater {
        model: fx.kind === "snow" ? 24 : 0
        delegate: Rectangle {
            id: flake
            required property int index
            readonly property real baseX: ((index * 53) % 103) / 103 * fx.width
            width: 2 + index % 3
            height: width
            radius: width / 2
            color: "#ffffff"
            opacity: 0.7
            NumberAnimation on y {
                from: -10 - (index % 8) * 16
                to: fx.height + 10
                duration: 5200 + (index % 6) * 800
                loops: Animation.Infinite
                running: fx.running
            }
            SequentialAnimation on x {
                loops: Animation.Infinite
                running: fx.running
                NumberAnimation { from: flake.baseX - 9; to: flake.baseX + 9; duration: 1900 + (flake.index % 5) * 300; easing.type: Easing.InOutSine }
                NumberAnimation { from: flake.baseX + 9; to: flake.baseX - 9; duration: 1900 + (flake.index % 5) * 300; easing.type: Easing.InOutSine }
            }
        }
    }

    // lightning
    Rectangle {
        anchors.fill: parent
        visible: fx.kind === "storm"
        color: "#ffffff"
        opacity: 0
        SequentialAnimation on opacity {
            loops: Animation.Infinite
            running: fx.running && fx.kind === "storm"
            PauseAnimation { duration: 5200 }
            NumberAnimation { to: 0.5; duration: 60 }
            NumberAnimation { to: 0; duration: 150 }
            NumberAnimation { to: 0.3; duration: 50 }
            NumberAnimation { to: 0; duration: 320 }
            PauseAnimation { duration: 3100 }
        }
    }
}
