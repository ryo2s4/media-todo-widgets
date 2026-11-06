import QtQuick

// SettingsSheet.qml: the calendar's settings in one compact inset sheet.
// Two columns keep everything visible without a scroll area, even on the
// 520 px card. Writes go through Settings.qml, so the panel remains the only
// place that owns the settings file.
Item {
    id: sheet

    property bool open: false
    property var cfg
    property var weather
    property color accent: "#90cef4"
    property color bright: "#dfe3e7"
    property color dim: "#8b9297"
    property color cardBg: "#0f1417"
    property string font: "JetBrainsMono Nerd Font"
    property real radius: 14
    property bool highContrast: false
    property int motionFast: 140

    signal closed()

    visible: open
    z: 100

    function a(c, v) { return Qt.rgba(c.r, c.g, c.b, v); }

    function close() {
        if (cfg) {
            cfg.set("gif", gifIn.text.trim());
            cfg.set("city", cityIn.text.trim());
            cfg.set("accentOverride", accentIn.text.trim());
        }
        sheet.closed();
    }

    function loadFields() {
        if (!cfg)
            return;
        gifIn.text = cfg.gif;
        cityIn.text = cfg.city;
        accentIn.text = cfg.accentOverride;
        gifIn.cursorPosition = 0;
        cityIn.cursorPosition = 0;
        accentIn.cursorPosition = 0;
    }

    onOpenChanged: {
        if (open)
            loadFields();
    }

    Component.onCompleted: if (open) loadFields()

    Rectangle {
        anchors.fill: parent
        color: sheet.a(sheet.cardBg, 0.74)

        MouseArea {
            anchors.fill: parent
            onClicked: sheet.close()
        }
    }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: Math.min(parent.width - 24, 520)
        height: parent.height - 24
        radius: sheet.radius
        color: sheet.cardBg
        border.width: 1
        border.color: sheet.a(sheet.dim, sheet.highContrast ? 0.55 : 0.35)
        clip: true

        // Keep empty-card clicks from reaching the closing scrim. This sits
        // behind the real controls, so blank space is swallowed and a click
        // outside the card still closes the sheet.
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
        }

        Item {
            id: head
            x: 18
            y: 14
            width: parent.width - 36
            height: 26

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "Settings"
                color: sheet.bright
                font.family: sheet.font
                font.pixelSize: 16
                font.bold: true
            }
            Text {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.topMargin: 20
                text: "changes save automatically"
                color: sheet.a(sheet.dim, 0.55)
                font.family: sheet.font
                font.pixelSize: 8
            }
            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: "close \u00D7"
                color: closeHover.hovered ? sheet.accent : sheet.a(sheet.dim, 0.9)
                font.family: sheet.font
                font.pixelSize: 10
                HoverHandler { id: closeHover }
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    cursorShape: Qt.PointingHandCursor
                    onClicked: sheet.close()
                }
            }
        }

        Rectangle {
            x: 18
            y: 48
            width: parent.width - 36
            height: 1
            color: sheet.a(sheet.dim, sheet.highContrast ? 0.32 : 0.14)
        }

        Row {
            id: cols
            x: 18
            y: 60
            width: parent.width - 36
            height: parent.height - 72
            spacing: 14

            // ── left: panel behaviour ─────────────────────────────────
            Column {
                width: (cols.width - cols.spacing) / 2
                spacing: 12

                Text {
                    text: "PANEL"
                    color: sheet.a(sheet.dim, 0.9)
                    font.family: sheet.font
                    font.pixelSize: 8
                    font.letterSpacing: 0.8
                }

                SettingSlider {
                    id: sizeSlider
                    width: parent.width
                    label: "Size"
                    valueText: Math.round(sizeSlider.value) + " px"
                    from: 520
                    to: 900
                    step: 10
                    value: sheet.cfg ? sheet.cfg.panelWidth : 640
                    accent: sheet.accent
                    dim: sheet.dim
                    font: sheet.font
                    onMoved: function (v) { if (sheet.cfg) sheet.cfg.set("panelWidth", v); }
                }

                Row {
                    width: parent.width
                    spacing: 6

                    Repeater {
                        model: [
                            { label: "S", size: 560 },
                            { label: "M", size: 640 },
                            { label: "L", size: 800 }
                        ]
                        delegate: Rectangle {
                            id: preset
                            required property var modelData
                            width: 52
                            height: 22
                            radius: 4
                            color: sheet.cfg && Math.round(sheet.cfg.panelWidth) === preset.modelData.size
                                ? sheet.a(sheet.accent, 0.18) : sheet.a(sheet.dim, 0.06)
                            border.width: 1
                            border.color: sheet.cfg && Math.round(sheet.cfg.panelWidth) === preset.modelData.size
                                ? sheet.accent : sheet.a(sheet.dim, 0.2)

                            Text {
                                anchors.centerIn: parent
                                text: preset.modelData.label + "  " + preset.modelData.size
                                color: sheet.cfg && Math.round(sheet.cfg.panelWidth) === preset.modelData.size
                                    ? sheet.accent : sheet.a(sheet.dim, 0.9)
                                font.family: sheet.font
                                font.pixelSize: 8
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: if (sheet.cfg) sheet.cfg.set("panelWidth", preset.modelData.size)
                            }
                        }
                    }
                }

                SettingSlider {
                    id: opacitySlider
                    width: parent.width
                    label: "Opacity"
                    valueText: Math.round(opacitySlider.value * 100) + "%"
                    from: 0.5
                    to: 1
                    step: 0.01
                    value: sheet.cfg ? sheet.cfg.panelOpacity : 1
                    accent: sheet.accent
                    dim: sheet.dim
                    font: sheet.font
                    onMoved: function (v) { if (sheet.cfg) sheet.cfg.set("panelOpacity", v); }
                }

                Item {
                    width: parent.width
                    height: 36

                    Column {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 44
                        spacing: 1
                        Text {
                            text: "Fit layout to panel size"
                            color: sheet.bright
                            font.family: sheet.font
                            font.pixelSize: 9
                        }
                        Text {
                            width: parent.width
                            text: "compact, comfortable or roomy"
                            color: sheet.a(sheet.dim, 0.65)
                            font.family: sheet.font
                            font.pixelSize: 7
                            elide: Text.ElideRight
                        }
                    }
                    Toggle {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        on: sheet.cfg ? sheet.cfg.autoLayout : true
                        accent: sheet.accent
                        dim: sheet.dim
                        duration: sheet.motionFast
                        onToggled: if (sheet.cfg) sheet.cfg.set("autoLayout", !sheet.cfg.autoLayout)
                    }
                    MouseArea {
                        anchors.fill: parent
                        z: 10
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (sheet.cfg) sheet.cfg.set("autoLayout", !sheet.cfg.autoLayout)
                    }
                }

                Item {
                    width: parent.width
                    height: 36

                    Column {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 44
                        spacing: 1
                        Text {
                            text: "Reduce motion"
                            color: sheet.bright
                            font.family: sheet.font
                            font.pixelSize: 9
                        }
                        Text {
                            width: parent.width
                            text: "stop slides and the gif while open"
                            color: sheet.a(sheet.dim, 0.65)
                            font.family: sheet.font
                            font.pixelSize: 7
                            elide: Text.ElideRight
                        }
                    }
                    Toggle {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        on: sheet.cfg ? sheet.cfg.reducedMotion : false
                        accent: sheet.accent
                        dim: sheet.dim
                        duration: 0
                        onToggled: if (sheet.cfg) sheet.cfg.set("reducedMotion", !sheet.cfg.reducedMotion)
                    }
                    MouseArea {
                        anchors.fill: parent
                        z: 10
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (sheet.cfg) sheet.cfg.set("reducedMotion", !sheet.cfg.reducedMotion)
                    }
                }

                Item {
                    width: parent.width
                    height: 36

                    Column {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 44
                        spacing: 1
                        Text {
                            text: "High contrast"
                            color: sheet.bright
                            font.family: sheet.font
                            font.pixelSize: 9
                        }
                        Text {
                            width: parent.width
                            text: "stronger borders and brighter secondary text"
                            color: sheet.a(sheet.dim, 0.65)
                            font.family: sheet.font
                            font.pixelSize: 7
                            elide: Text.ElideRight
                        }
                    }
                    Toggle {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        on: sheet.cfg ? sheet.cfg.highContrast : false
                        accent: sheet.accent
                        dim: sheet.dim
                        duration: sheet.motionFast
                        onToggled: if (sheet.cfg) sheet.cfg.set("highContrast", !sheet.cfg.highContrast)
                    }
                    MouseArea {
                        anchors.fill: parent
                        z: 10
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (sheet.cfg) sheet.cfg.set("highContrast", !sheet.cfg.highContrast)
                    }
                }
            }

            // ── right: calendar and weather ───────────────────────────
            Column {
                width: (cols.width - cols.spacing) / 2
                spacing: 12

                Text {
                    text: "CALENDAR"
                    color: sheet.a(sheet.dim, 0.9)
                    font.family: sheet.font
                    font.pixelSize: 8
                    font.letterSpacing: 0.8
                }

                SettingField {
                    id: accentIn
                    width: parent.width
                    label: "Accent override"
                    placeholder: "#90cef4  (empty = Ryoku palette)"
                    accent: sheet.accent
                    bright: sheet.bright
                    dim: sheet.dim
                    font: sheet.font
                    onCommitted: function (value) {
                        if (sheet.cfg)
                            sheet.cfg.set("accentOverride", value.trim());
                    }
                }

                Text {
                    text: "reset accent"
                    color: accentResetHover.hovered ? sheet.accent : sheet.a(sheet.dim, 0.7)
                    font.family: sheet.font
                    font.pixelSize: 8
                    HoverHandler { id: accentResetHover }
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -5
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            accentIn.text = "";
                            if (sheet.cfg)
                                sheet.cfg.set("accentOverride", "");
                        }
                    }
                }

                SettingField {
                    id: gifIn
                    width: parent.width
                    label: "GIF"
                    placeholder: "~/Pictures/your.gif"
                    accent: sheet.accent
                    bright: sheet.bright
                    dim: sheet.dim
                    font: sheet.font
                    onCommitted: function (value) { if (sheet.cfg) sheet.cfg.set("gif", value.trim()); }
                }

                Text {
                    text: "WEATHER"
                    color: sheet.a(sheet.dim, 0.9)
                    font.family: sheet.font
                    font.pixelSize: 8
                    font.letterSpacing: 0.8
                }

                SettingField {
                    id: cityIn
                    width: parent.width
                    label: "City"
                    placeholder: "empty = guess from the network"
                    accent: sheet.accent
                    bright: sheet.bright
                    dim: sheet.dim
                    font: sheet.font
                    onCommitted: function (value) { if (sheet.cfg) sheet.cfg.set("city", value.trim()); }
                }

                Row {
                    width: parent.width
                    spacing: 8

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "UNITS"
                        color: sheet.a(sheet.dim, 0.9)
                        font.family: sheet.font
                        font.pixelSize: 8
                        font.letterSpacing: 0.8
                    }

                    Repeater {
                        model: ["c", "f"]
                        delegate: Rectangle {
                            id: unit
                            required property string modelData
                            width: 38
                            height: 22
                            radius: 4
                            color: sheet.cfg && sheet.cfg.units === unit.modelData
                                ? sheet.a(sheet.accent, 0.18) : sheet.a(sheet.dim, 0.06)
                            border.width: 1
                            border.color: sheet.cfg && sheet.cfg.units === unit.modelData
                                ? sheet.accent : sheet.a(sheet.dim, 0.2)

                            Text {
                                anchors.centerIn: parent
                                text: unit.modelData === "c" ? "\u00B0C" : "\u00B0F"
                                color: sheet.cfg && sheet.cfg.units === unit.modelData
                                    ? sheet.accent : sheet.a(sheet.dim, 0.9)
                                font.family: sheet.font
                                font.pixelSize: 9
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: if (sheet.cfg) sheet.cfg.set("units", unit.modelData)
                            }
                        }
                    }

                    Item { width: 2; height: 1 }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "reload"
                        color: reloadHover.hovered ? sheet.accent : sheet.a(sheet.dim, 0.8)
                        font.family: sheet.font
                        font.pixelSize: 8
                        HoverHandler { id: reloadHover }
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -5
                            cursorShape: Qt.PointingHandCursor
                            onClicked: if (sheet.weather) sheet.weather.refresh(true)
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: sheet.a(sheet.dim, sheet.highContrast ? 0.3 : 0.12)
                }

                Text {
                    width: parent.width
                    text: "The calendar reads your todo list live. New tasks and checkmarks go through the todo panel, so both stay in sync. Nothing here writes tasks.json."
                    color: sheet.a(sheet.dim, 0.65)
                    font.family: sheet.font
                    font.pixelSize: 8
                    wrapMode: Text.WordWrap
                    lineHeight: 1.25
                }
            }
        }
    }
}
