import QtQuick
import QtQuick.Effects

// GifTile.qml: the small framed animation below the task card.
// It is intentionally a sibling of the task card so shortening the task list
// gives the gif its own breathing room.
Item {
    id: tile

    property url source: ""
    property string fit: "cover"
    property bool open: false
    property bool reducedMotion: false
    property real aura: 0.7
    property color accent: "#90cef4"
    property color bright: "#dfe3e7"
    property color dim: "#8b9297"
    property color cardBg: "#0f1417"
    property string font: "JetBrainsMono Nerd Font"
    property real radius: 10
    property bool highContrast: false

    signal clicked()

    function a(c, v) { return Qt.rgba(c.r, c.g, c.b, v); }

    readonly property bool hasSource: source.toString() !== ""
    readonly property bool hovering: hover.hovered

    Rectangle {
        id: frame
        anchors.fill: parent
        radius: tile.radius
        color: "transparent"
        clip: true
        gradient: Gradient {
            GradientStop { position: 0.0; color: tile.a(tile.bright, tile.highContrast ? 0.09 : 0.045) }
            GradientStop { position: 1.0; color: tile.a(tile.cardBg, 0.55) }
        }
        border.width: tile.highContrast ? 2 : 1
        border.color: tile.hovering ? tile.a(tile.accent, 0.58) : tile.a(tile.dim, tile.highContrast ? 0.38 : 0.16)
        scale: tile.hovering && !tile.reducedMotion ? 1.018 : 1.0

        Behavior on scale { NumberAnimation { duration: tile.reducedMotion ? 0 : 150; easing.type: Easing.OutCubic } }
        Behavior on border.color { ColorAnimation { duration: 130 } }

        Item {
            id: imageFrame
            anchors.fill: parent
            anchors.margins: 1
            visible: false

            AnimatedImage {
                anchors.fill: parent
                source: tile.source
                fillMode: tile.fit === "contain" ? Image.PreserveAspectFit : Image.PreserveAspectCrop
                asynchronous: true
                smooth: true
                playing: tile.open && !tile.reducedMotion
                cache: false
                sourceSize.width: imageFrame.width * 2
                sourceSize.height: imageFrame.height * 2
            }
        }

        Item {
            id: imageMask
            anchors.fill: parent
            anchors.margins: 1
            layer.enabled: true
            visible: false
            Rectangle {
                anchors.fill: parent
                radius: Math.max(4, tile.radius - 1)
                color: "black"
            }
        }

        MultiEffect {
            anchors.fill: parent
            anchors.margins: 1
            source: imageFrame
            maskEnabled: true
            maskSource: imageMask
            visible: tile.hasSource
            opacity: 0.96
        }

        // A small glassy edge so the tile reads as a framed object, not a
        // floating rectangle.
        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: Math.max(1, tile.radius - 1)
            color: "transparent"
            border.width: 1
            border.color: tile.a(tile.bright, 0.08)
        }

        Rectangle {
            visible: tile.hasSource
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 7
            width: 22
            height: 13
            radius: 4
            color: tile.a(tile.cardBg, 0.58)
            border.width: 1
            border.color: tile.a(tile.bright, 0.12)
            Text {
                anchors.centerIn: parent
                text: "GIF"
                color: tile.a(tile.bright, 0.78)
                font.family: tile.font
                font.pixelSize: 6
                font.letterSpacing: 0.6
            }
        }

        Column {
            visible: !tile.hasSource
            anchors.centerIn: parent
            spacing: 4
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "\u2727"
                color: tile.a(tile.accent, 0.62)
                font.family: tile.font
                font.pixelSize: Math.max(18, Math.min(28, tile.height * 0.22))
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "gif"
                color: tile.a(tile.dim, 0.75)
                font.family: tile.font
                font.pixelSize: 8
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "click to set"
                color: tile.a(tile.dim, 0.48)
                font.family: tile.font
                font.pixelSize: 7
            }
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 1
            height: Math.round(parent.height * 0.30)
            radius: tile.radius
            visible: tile.hasSource && tile.hovering
            gradient: Gradient {
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 1.0; color: tile.a(tile.cardBg, 0.78) }
            }
            Text {
                anchors.centerIn: parent
                text: "change gif"
                color: tile.a(tile.bright, 0.9)
                font.family: tile.font
                font.pixelSize: 7
            }
        }
    }

    HoverHandler { id: hover }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        Accessible.name: "GIF settings"
        onClicked: tile.clicked()
    }
}
