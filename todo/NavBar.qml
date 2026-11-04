import QtQuick

// Top view bar: one tab per board/extra view. This is the primary navigation;
// the header's ... menu keeps only the utility actions.
Item {
    id: nav

    property var host
    property var th
    property var st
    property real spacing: 2

    height: 40

    property var tabs: [
        { key: "board", glyph: "\uf00a", label: "Board" },
        { key: "stats", glyph: "\uf080", label: "Stats" },
        { key: "calendar", glyph: "\uf073", label: "Calendar" },
        { key: "tags", glyph: "\uf02c", label: "Tags" },
        { key: "templates", glyph: "\uf0c5", label: "Templates" },
        { key: "archive", glyph: "\uf187", label: "Archive" },
        { key: "plan", glyph: "\uf185", label: "Plan" },
        { key: "palette", glyph: "\uf120", label: "Palette" },
        { key: "focus", glyph: "\uf017", label: "Focus" }
    ]

    readonly property bool planDue: {
        var r = st ? st.nowTick : 0;
        return st ? st.lastPlanDay !== st.dayKey(Date.now()) : false;
    }

    function a(c, v) { return Qt.rgba(c.r, c.g, c.b, v); }

    function activeFor(k) {
        if (k === "board")
            return !host.statsOpen && !host.calOpen && !host.tagsOpen && !host.templatesOpen &&
                   !host.archiveOpen && !host.planOpen && !host.paletteOpen && !host.focusMode &&
                   !host.settingsOpen;
        if (k === "stats")
            return host.statsOpen;
        if (k === "calendar")
            return host.calOpen;
        if (k === "tags")
            return host.tagsOpen;
        if (k === "templates")
            return host.templatesOpen;
        if (k === "archive")
            return host.archiveOpen;
        if (k === "plan")
            return host.planOpen;
        if (k === "palette")
            return host.paletteOpen;
        if (k === "focus")
            return host.focusMode;
        return false;
    }

    function closeViews() {
        host.closeSheets();
        host.settingsOpen = false;
    }

    function choose(k) {
        if (k === "board") {
            closeViews();
            host.focusMode = false;
        } else if (k === "stats") {
            var was = host.statsOpen;
            closeViews();
            host.statsOpen = !was;
        } else if (k === "calendar") {
            var wasCal = host.calOpen;
            closeViews();
            host.calOpen = !wasCal;
        } else if (k === "tags") {
            var wasTags = host.tagsOpen;
            closeViews();
            host.tagsOpen = !wasTags;
        } else if (k === "templates") {
            var wasTpl = host.templatesOpen;
            closeViews();
            host.templatesOpen = !wasTpl;
        } else if (k === "archive") {
            var wasArc = host.archiveOpen;
            closeViews();
            host.archiveOpen = !wasArc;
        } else if (k === "plan") {
            var wasPlan = host.planOpen;
            closeViews();
            host.planOpen = !wasPlan;
        } else if (k === "palette") {
            var wasPal = host.paletteOpen;
            closeViews();
            if (wasPal)
                host.paletteOpen = false;
            else
                host.openPalette();
        } else if (k === "focus") {
            var wasFocus = host.focusMode;
            closeViews();
            host.focusMode = !wasFocus;
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: th.radius
        color: nav.a(th.dim, 0.05)
        border.width: 1
        border.color: nav.a(th.dim, 0.13)
        gradient: Gradient {
            GradientStop { position: 0.0; color: nav.a(th.bright, 0.04) }
            GradientStop { position: 0.5; color: "transparent" }
            GradientStop { position: 1.0; color: nav.a(th.cardBot, 0.18) }
        }
    }

    Row {
        anchors.fill: parent
        spacing: nav.spacing

        Repeater {
            model: nav.tabs
            delegate: Item {
                id: tab
                required property var modelData
                width: (nav.width - nav.spacing * (nav.tabs.length - 1)) / nav.tabs.length
                height: nav.height

                readonly property bool on: nav.activeFor(modelData.key)
                readonly property bool isPlan: modelData.key === "plan"

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 1
                    radius: 7
                    color: tab.on ? nav.a(nav.th.accent, 0.16)
                                  : (tabHover.hovered ? nav.a(nav.th.dim, 0.11) : "transparent")
                    border.width: tab.on ? 1 : 0
                    border.color: nav.a(nav.th.accent, 0.35)
                    Behavior on color { ColorAnimation { duration: 120 } }
                }

                HoverHandler { id: tabHover }

                Column {
                    anchors.centerIn: parent
                    spacing: 0
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: tab.modelData.glyph
                        color: tab.on ? nav.th.accent : (tabHover.hovered ? nav.th.bright : nav.th.dim)
                        font.family: nav.th.font
                        font.pixelSize: 13
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: tab.modelData.label
                        color: tab.on ? nav.th.accent : (tabHover.hovered ? nav.th.bright : nav.a(nav.th.dim, 0.9))
                        font.family: nav.th.font
                        font.pixelSize: 8
                    }
                }

                Rectangle {
                    visible: tab.on
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    width: 14
                    height: 2
                    radius: 1
                    color: nav.th.accent
                }

                Rectangle {
                    visible: tab.isPlan && nav.planDue
                    anchors.top: parent.top
                    anchors.topMargin: 4
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.horizontalCenterOffset: 9
                    width: 4
                    height: 4
                    radius: 2
                    color: nav.th.accent
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: nav.choose(tab.modelData.key)
                }
            }
        }
    }
}
