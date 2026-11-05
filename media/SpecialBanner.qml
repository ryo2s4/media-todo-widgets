import QtQuick
import QtQuick.Effects

// SpecialBanner.qml: the wide picture at the top of Us.
// Still images get a slow Ken Burns drift; animated GIF/WebP banners play.
// The rounded mask is done with MultiEffect so the picture can move inside it.
Item {
    id: root

    property url source
    property real radius: 10
    readonly property bool animated: /\.(gif|webp|apng)$/i.test(String(source))
    readonly property bool ready: animated
        ? anim.status === Image.Ready
        : still.status === Image.Ready
    visible: source != "" && ready

    property real drift: 1.03
    SequentialAnimation on drift {
        loops: Animation.Infinite
        running: root.visible
        NumberAnimation { from: 1.03; to: 1.10; duration: 18000; easing.type: Easing.InOutSine }
        NumberAnimation { from: 1.10; to: 1.03; duration: 18000; easing.type: Easing.InOutSine }
    }

    Item {
        id: frame
        anchors.fill: parent
        visible: false
        Item {
            anchors.fill: parent
            scale: root.drift
            Image {
                id: still
                anchors.fill: parent
                source: root.animated ? "" : root.source
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                smooth: true
                cache: false
                sourceSize.width: parent.width * 2
                sourceSize.height: parent.height * 2
            }
            AnimatedImage {
                id: anim
                anchors.fill: parent
                source: root.animated ? root.source : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                smooth: true
                playing: true
                cache: false
                sourceSize.width: parent.width * 2
                sourceSize.height: parent.height * 2
            }
        }
    }

    Item {
        id: maskItem
        anchors.fill: parent
        layer.enabled: true
        visible: false
        Rectangle {
            anchors.fill: parent
            radius: root.radius
            color: "black"
        }
    }

    MultiEffect {
        anchors.fill: parent
        source: frame
        maskEnabled: true
        maskSource: maskItem
        opacity: root.ready ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 500 } }
    }
}
