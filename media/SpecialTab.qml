import QtQuick

// SpecialTab.qml: the 4th tab. While the vault is locked this is just the gate;
// after unlocking it becomes Us / Memories / Words / Together / Data.
Item {
    id: tab

    property var th
    property var sp
    property var frames
    property var chooser
    property var host
    property bool active: false

    // The Special page was drawn at 7-10 px for a dense 460 px panel. Scale
    // the whole page up while shrinking its logical box, so the visual width
    // still matches the tab and every font/control grows together.
    readonly property real uiScale: 1.35

    property string section: sp.lastSection
    property int viewerIndex: -1

    onSectionChanged: {
        tab.sp.lastSection = tab.section;
        tab.sp.savePrefs();
        tab.sp.touch();
    }
    onActiveChanged: if (active) tab.sp.touch()


    function a(c, v) { return Qt.rgba(c.r, c.g, c.b, v); }

    Item {
        id: page
        width: tab.width / tab.uiScale
        height: tab.height / tab.uiScale
        scale: tab.uiScale
        transformOrigin: Item.TopLeft

        LockGate {
            anchors.fill: parent
            visible: !tab.sp.unlocked
            th: tab.th
            sp: tab.sp
            active: tab.active && !tab.sp.unlocked
        }

        Item {
            anchors.fill: parent
            visible: tab.sp.unlocked

            Column {
                id: outer
                anchors.fill: parent
                spacing: 8

                Item {
                    width: parent.width
                    height: 20
                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Special"
                        color: tab.th.bright
                        font.family: tab.th.font
                        font.pixelSize: 13
                        font.bold: true
                    }
                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 10
                        Rectangle {
                            width: 5
                            height: 5
                            radius: 2.5
                            anchors.verticalCenter: parent.verticalCenter
                            color: tab.th.accent
                            visible: tab.sp.dirty
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "lock"
                            color: lockMa.containsMouse ? tab.th.accent : tab.a(tab.th.dim, 0.75)
                            font.family: tab.th.font
                            font.pixelSize: 8
                            MouseArea {
                                id: lockMa
                                anchors.fill: parent
                                anchors.margins: -6
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: tab.sp.lock()
                            }
                        }
                    }
                }

                Row {
                    width: parent.width
                    height: 22
                    spacing: 15
                    Repeater {
                        model: ["Us", "Memories", "Words", "Together", "Data"]
                        delegate: Item {
                            required property string modelData
                            readonly property bool on: tab.section === modelData
                            width: navLabel.implicitWidth
                            height: 22
                            Text {
                                id: navLabel
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.top: parent.top
                                anchors.topMargin: 2
                                text: parent.modelData
                                color: parent.on ? tab.th.bright : tab.a(tab.th.dim, 0.8)
                                font.family: tab.th.font
                                font.pixelSize: 10
                                font.bold: parent.on
                            }
                            Rectangle {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                height: 1
                                color: tab.th.accent
                                visible: parent.on
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: tab.section = parent.modelData
                            }
                        }
                    }
                }

                Flickable {
                    id: flick
                    width: parent.width
                    height: outer.height - 20 - 22 - 16
                    contentWidth: width
                    contentHeight: content.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    Column {
                        id: content
                        width: flick.width
                        spacing: 0

                        SpecialUs {
                            width: parent.width
                            visible: tab.section === "Us"
                            th: tab.th
                            sp: tab.sp
                            frames: tab.frames
                            chooser: tab.chooser
                            onViewMemory: function (i) { if (i >= 0) tab.viewerIndex = i; }
                        }
                        SpecialMemories {
                            width: parent.width
                            visible: tab.section === "Memories"
                            th: tab.th
                            sp: tab.sp
                            chooser: tab.chooser
                            onOpenMemory: function (i) { if (i >= 0) tab.viewerIndex = i; }
                        }
                        SpecialWords {
                            width: parent.width
                            visible: tab.section === "Words"
                            th: tab.th
                            sp: tab.sp
                            chooser: tab.chooser
                        }
                        SpecialTogether {
                            width: parent.width
                            visible: tab.section === "Together"
                            th: tab.th
                            sp: tab.sp
                            chooser: tab.chooser
                        }
                        SpecialData {
                            width: parent.width
                            visible: tab.section === "Data"
                            th: tab.th
                            sp: tab.sp
                            chooser: tab.chooser
                        }
                    }

                    Rectangle {
                        parent: flick
                        visible: flick.visibleArea.heightRatio < 0.999
                        x: flick.width - width - 2
                        y: flick.visibleArea.yPosition * flick.height
                        width: 3
                        height: Math.max(24, flick.visibleArea.heightRatio * flick.height)
                        radius: 1.5
                        color: tab.a(tab.th.accent, 0.35)
                    }
                }
            }
        }

        MemoryViewer {
            anchors.fill: parent
            th: tab.th
            sp: tab.sp
            index: tab.viewerIndex
            onClosed: tab.viewerIndex = -1
        }
    }

}
