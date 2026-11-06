import QtQuick

// TaskSection.qml: a small labelled group in the selected-day task column.
// The sections are Overdue / Open / Done; the parent only shows non-empty ones.
Item {
    id: section

    property string title: ""
    property var tasks: []
    property var store
    property double nowMs: Date.now()
    property color accent: "#90cef4"
    property color warn: "#e8a15a"
    property color bright: "#dfe3e7"
    property color dim: "#8b9297"
    property color cardBg: "#0f1417"
    property color tone: accent
    property string font: "JetBrainsMono Nerd Font"

    signal openRequested()

    visible: tasks && tasks.length > 0
    width: parent ? parent.width : 0
    height: visible ? col.implicitHeight : 0

    Column {
        id: col
        width: parent.width
        spacing: 2

        Item {
            width: parent.width
            height: 13

            Text {
                x: 2
                anchors.verticalCenter: parent.verticalCenter
                text: section.title
                color: section.tone
                font.family: section.font
                font.pixelSize: 7
                font.bold: true
                font.letterSpacing: 0.7
            }
            Text {
                anchors.right: parent.right
                anchors.rightMargin: 2
                anchors.verticalCenter: parent.verticalCenter
                text: section.tasks ? section.tasks.length : 0
                color: Qt.rgba(section.tone.r, section.tone.g, section.tone.b, 0.75)
                font.family: section.font
                font.pixelSize: 7
            }
        }

        Repeater {
            model: section.tasks

            delegate: TaskRow {
                required property var modelData

                task: modelData
                store: section.store
                nowMs: section.nowMs
                accent: section.accent
                warn: section.warn
                bright: section.bright
                dim: section.dim
                cardBg: section.cardBg
                font: section.font
                width: section.width

                onOpenRequested: section.openRequested()
            }
        }
    }
}
