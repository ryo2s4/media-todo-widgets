import QtQuick
import QtQuick.Effects

// An image clipped to a rounded shape (radius = width / 2 gives a circle).
Item {
    id: ri

    property url source
    property real radius: width / 2
    property int fillMode: Image.PreserveAspectCrop
    property bool blurred: false
    readonly property alias status: img.status

    Image {
        id: img
        anchors.fill: parent
        source: ri.source
        fillMode: ri.fillMode
        asynchronous: true
        visible: false
    }

    Item {
        id: maskItem
        anchors.fill: parent
        layer.enabled: true
        visible: false
        Rectangle {
            anchors.fill: parent
            radius: ri.radius
            color: "black"
        }
    }

    MultiEffect {
        anchors.fill: parent
        source: img
        maskEnabled: true
        maskSource: maskItem
        blurEnabled: ri.blurred
        blur: 1.0
        blurMax: 48
        visible: img.status === Image.Ready
    }
}
