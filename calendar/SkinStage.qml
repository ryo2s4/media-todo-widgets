import QtQuick
import QtQuick.Effects

// SkinStage.qml: the reserved area below the month. It is intentionally a
// quiet card until the user points Settings > Skin image at a picture, which
// gives future skins a stable, already-styled home.
Item {
    id: stage

    property url source: ""
    property string fit: "cover"
    property bool hints: true
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

    Rectangle {
        anchors.fill: parent
        radius: stage.radius
        gradient: Gradient {
            GradientStop { position: 0.0; color: stage.a(stage.bright, stage.highContrast ? 0.07 : 0.045) }
            GradientStop { position: 1.0; color: stage.a(stage.cardBg, 0.42) }
        }
        border.width: stage.highContrast ? 2 : 1
        border.color: skinHover.hovered ? stage.a(stage.accent, 0.55)
            : stage.a(stage.dim, stage.highContrast ? 0.38 : 0.14)

        Behavior on border.color { ColorAnimation { duration: 130 } }
    }

    // A soft top edge, matching the month and task cards.
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 1
        height: 1
        radius: 1
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 0.5; color: stage.a(stage.accent, 0.28 + stage.aura * 0.22) }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }

    Item {
        id: imageFrame
        anchors.fill: parent
        anchors.margins: 1
        visible: false

        Image {
            anchors.fill: parent
            source: stage.source
            sourceSize.width: imageFrame.width * 2
            sourceSize.height: imageFrame.height * 2
            fillMode: stage.fit === "contain" ? Image.PreserveAspectFit : Image.PreserveAspectCrop
            asynchronous: true
            smooth: true
            cache: false
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
            radius: Math.max(4, stage.radius - 1)
            color: "black"
        }
    }

    MultiEffect {
        anchors.fill: parent
        anchors.margins: 1
        source: imageFrame
        maskEnabled: true
        maskSource: imageMask
        visible: stage.source.toString() !== ""
        opacity: 0.94
    }

    // A gentle bottom shade keeps text readable over bright skin images.
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: Math.round(parent.height * 0.48)
        radius: stage.radius
        visible: stage.source.toString() !== ""
        gradient: Gradient {
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 1.0; color: stage.a(stage.cardBg, 0.75) }
        }
    }

    Row {
        visible: stage.source.toString() === "" && stage.hints
        anchors.centerIn: parent
        spacing: 10

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "\u2726"
            color: stage.a(stage.accent, 0.30 + stage.aura * 0.18)
            font.family: stage.font
            font.pixelSize: 22
        }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            Text {
                text: "SKIN STAGE"
                color: stage.a(stage.accent, 0.78)
                font.family: stage.font
                font.pixelSize: 8
                font.bold: true
                font.letterSpacing: 1.3
            }
            Text {
                text: "reserved for later"
                color: stage.a(stage.dim, 0.55)
                font.family: stage.font
                font.pixelSize: 7
            }
        }
    }

    Text {
        visible: stage.source.toString() !== "" && stage.hints
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: 9
        text: "SKIN"
        color: stage.a(stage.bright, 0.68)
        font.family: stage.font
        font.pixelSize: 6
        font.letterSpacing: 1.2
    }

    HoverHandler { id: skinHover }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        Accessible.name: "Skin stage settings"
        onClicked: stage.clicked()
    }
}
