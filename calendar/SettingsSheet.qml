import QtQuick

// SettingsSheet.qml: the calendar's settings in one inset sheet.
// The sheet scrolls so the small 520 px card can still reach every option.
// Writes go through Settings.qml, which remains the only owner of the file.
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
            cfg.set("skinImage", skinIn.text.trim());
        }
        sheet.closed();
    }

    function loadFields() {
        if (!cfg)
            return;
        gifIn.text = cfg.gif;
        cityIn.text = cfg.city;
        accentIn.text = cfg.accentOverride;
        skinIn.text = cfg.skinImage;
        gifIn.cursorPosition = 0;
        cityIn.cursorPosition = 0;
        accentIn.cursorPosition = 0;
        skinIn.cursorPosition = 0;
        flick.contentY = 0;
    }

    onOpenChanged: {
        if (open) {
            loadFields();
            Qt.callLater(function () { flick.contentY = 0; });
        }
    }
    Component.onCompleted: if (open) loadFields()

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: sheet.a(sheet.cardBg, 0.70) }
            GradientStop { position: 1.0; color: sheet.a(sheet.cardBg, 0.84) }
        }

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
        color: "transparent"
        clip: true
        border.width: 1
        border.color: sheet.a(sheet.dim, sheet.highContrast ? 0.55 : 0.32)

        gradient: Gradient {
            GradientStop { position: 0.0; color: sheet.cardBg }
            GradientStop { position: 0.70; color: sheet.cardBg }
            GradientStop { position: 1.0; color: sheet.a(sheet.cardBg, 0.99) }
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: parent.height * 0.22
            gradient: Gradient {
                GradientStop { position: 0.0; color: sheet.a(sheet.accent, 0.10) }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 1
            height: 1
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.5; color: sheet.a(sheet.accent, 0.72) }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        // Keep empty-card clicks from reaching the closing scrim.
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
        }

        Item {
            id: head
            x: 18
            y: 14
            width: parent.width - 36
            height: 28

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
                anchors.topMargin: 21
                text: "changes save automatically  \u00B7  scroll for more"
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
                    Accessible.name: "Close settings"
                    onClicked: sheet.close()
                }
            }
        }

        Rectangle {
            x: 18
            y: 50
            width: parent.width - 36
            height: 1
            color: sheet.a(sheet.dim, sheet.highContrast ? 0.32 : 0.14)
        }

        Flickable {
            id: flick
            x: 18
            y: 62
            width: parent.width - 36
            height: parent.height - 78
            contentWidth: width
            contentHeight: columns.height
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.VerticalFlick

            Row {
                id: columns
                width: flick.width
                spacing: 14
                height: Math.max(leftCol.height, rightCol.height)

                Column {
                    id: leftCol
                    width: (columns.width - columns.spacing) / 2
                    spacing: 9

                    Text {
                        text: "PANEL"
                        color: sheet.a(sheet.accent, 0.9)
                        font.family: sheet.font
                        font.pixelSize: 8
                        font.letterSpacing: 1.1
                        font.bold: true
                    }

                    SettingSlider {
                        id: sizeSlider
                        width: parent.width
                        label: "Size"
                        valueText: Math.round(sizeSlider.value) + " px"
                        from: 520
                        to: 900
                        step: 10
                        value: sheet.cfg ? sheet.cfg.panelWidth : 700
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
                                { label: "M", size: 700 },
                                { label: "L", size: 800 }
                            ]
                            delegate: Rectangle {
                                id: preset
                                required property var modelData
                                width: (parent.width - 12) / 3
                                height: 22
                                radius: 5
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

                    SettingSlider {
                        id: auraSlider
                        width: parent.width
                        label: "Glow"
                        valueText: Math.round(auraSlider.value * 100) + "%"
                        from: 0
                        to: 1
                        step: 0.01
                        value: sheet.cfg ? sheet.cfg.aura : 0.7
                        accent: sheet.accent
                        dim: sheet.dim
                        font: sheet.font
                        onMoved: function (v) { if (sheet.cfg) sheet.cfg.set("aura", v); }
                    }

                    SettingToggle {
                        width: parent.width
                        label: "Fit layout to panel size"
                        hint: "compact, comfortable or roomy"
                        on: sheet.cfg ? sheet.cfg.autoLayout : true
                        accent: sheet.accent
                        bright: sheet.bright
                        dim: sheet.dim
                        font: sheet.font
                        duration: sheet.motionFast
                        onToggled: if (sheet.cfg) sheet.cfg.set("autoLayout", !sheet.cfg.autoLayout)
                    }

                    SettingToggle {
                        width: parent.width
                        label: "Reduce motion"
                        hint: "stop slides and the gif while open"
                        on: sheet.cfg ? sheet.cfg.reducedMotion : false
                        accent: sheet.accent
                        bright: sheet.bright
                        dim: sheet.dim
                        font: sheet.font
                        duration: 0
                        onToggled: if (sheet.cfg) sheet.cfg.set("reducedMotion", !sheet.cfg.reducedMotion)
                    }

                    SettingToggle {
                        width: parent.width
                        label: "High contrast"
                        hint: "stronger borders and brighter secondary text"
                        on: sheet.cfg ? sheet.cfg.highContrast : false
                        accent: sheet.accent
                        bright: sheet.bright
                        dim: sheet.dim
                        font: sheet.font
                        duration: sheet.motionFast
                        onToggled: if (sheet.cfg) sheet.cfg.set("highContrast", !sheet.cfg.highContrast)
                    }

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: sheet.a(sheet.dim, sheet.highContrast ? 0.30 : 0.12)
                    }

                    Text {
                        text: "SKIN STAGE"
                        color: sheet.a(sheet.accent, 0.9)
                        font.family: sheet.font
                        font.pixelSize: 8
                        font.letterSpacing: 1.1
                        font.bold: true
                    }

                    SettingToggle {
                        width: parent.width
                        label: "Show skin stage"
                        hint: "the card under the month; space stays reserved"
                        on: sheet.cfg ? sheet.cfg.showSkinStage : true
                        accent: sheet.accent
                        bright: sheet.bright
                        dim: sheet.dim
                        font: sheet.font
                        duration: sheet.motionFast
                        onToggled: if (sheet.cfg) sheet.cfg.set("showSkinStage", !sheet.cfg.showSkinStage)
                    }

                    SettingField {
                        id: skinIn
                        width: parent.width
                        label: "Skin image"
                        placeholder: "~/Pictures/skin.png  (optional)"
                        accent: sheet.accent
                        bright: sheet.bright
                        dim: sheet.dim
                        font: sheet.font
                        onCommitted: function (value) { if (sheet.cfg) sheet.cfg.set("skinImage", value.trim()); }
                    }

                    Row {
                        width: parent.width
                        spacing: 8
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "FIT"
                            color: sheet.a(sheet.dim, 0.9)
                            font.family: sheet.font
                            font.pixelSize: 8
                            font.letterSpacing: 0.8
                        }
                        Repeater {
                            model: ["cover", "contain"]
                            delegate: Rectangle {
                                required property string modelData
                                width: 58
                                height: 21
                                radius: 5
                                color: sheet.cfg && sheet.cfg.skinFit === modelData
                                    ? sheet.a(sheet.accent, 0.18) : sheet.a(sheet.dim, 0.06)
                                border.width: 1
                                border.color: sheet.cfg && sheet.cfg.skinFit === modelData
                                    ? sheet.accent : sheet.a(sheet.dim, 0.2)
                                Text {
                                    anchors.centerIn: parent
                                    text: modelData
                                    color: sheet.cfg && sheet.cfg.skinFit === modelData
                                        ? sheet.accent : sheet.a(sheet.dim, 0.9)
                                    font.family: sheet.font
                                    font.pixelSize: 8
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: if (sheet.cfg) sheet.cfg.set("skinFit", modelData)
                                }
                            }
                        }
                    }

                    SettingToggle {
                        width: parent.width
                        label: "Show stage hints"
                        hint: "the small label when no skin image is set"
                        on: sheet.cfg ? sheet.cfg.skinHints : true
                        accent: sheet.accent
                        bright: sheet.bright
                        dim: sheet.dim
                        font: sheet.font
                        duration: sheet.motionFast
                        onToggled: if (sheet.cfg) sheet.cfg.set("skinHints", !sheet.cfg.skinHints)
                    }
                }

                Column {
                    id: rightCol
                    width: (columns.width - columns.spacing) / 2
                    spacing: 9

                    Text {
                        text: "CLOCK & CALENDAR"
                        color: sheet.a(sheet.accent, 0.9)
                        font.family: sheet.font
                        font.pixelSize: 8
                        font.letterSpacing: 1.1
                        font.bold: true
                    }

                    SettingToggle {
                        width: parent.width
                        label: "24-hour clock"
                        hint: "turn off for a 12-hour clock"
                        on: sheet.cfg ? sheet.cfg.clock24h : true
                        accent: sheet.accent
                        bright: sheet.bright
                        dim: sheet.dim
                        font: sheet.font
                        duration: sheet.motionFast
                        onToggled: if (sheet.cfg) sheet.cfg.set("clock24h", !sheet.cfg.clock24h)
                    }

                    SettingToggle {
                        width: parent.width
                        label: "Show seconds"
                        hint: "the small accent seconds beside the clock"
                        on: sheet.cfg ? sheet.cfg.showSeconds : true
                        accent: sheet.accent
                        bright: sheet.bright
                        dim: sheet.dim
                        font: sheet.font
                        duration: sheet.motionFast
                        onToggled: if (sheet.cfg) sheet.cfg.set("showSeconds", !sheet.cfg.showSeconds)
                    }

                    SettingToggle {
                        width: parent.width
                        label: "Start week on Monday"
                        hint: "Monday first, instead of Sunday"
                        on: sheet.cfg ? sheet.cfg.weekStartsMonday : false
                        accent: sheet.accent
                        bright: sheet.bright
                        dim: sheet.dim
                        font: sheet.font
                        duration: sheet.motionFast
                        onToggled: if (sheet.cfg) sheet.cfg.set("weekStartsMonday", !sheet.cfg.weekStartsMonday)
                    }

                    SettingToggle {
                        width: parent.width
                        label: "Show lunar line"
                        hint: "phase marker and moon detail link"
                        on: sheet.cfg ? sheet.cfg.showMoonLine : true
                        accent: sheet.accent
                        bright: sheet.bright
                        dim: sheet.dim
                        font: sheet.font
                        duration: sheet.motionFast
                        onToggled: if (sheet.cfg) sheet.cfg.set("showMoonLine", !sheet.cfg.showMoonLine)
                    }

                    SettingToggle {
                        width: parent.width
                        label: "Show weather"
                        hint: "the compact strip under the moon"
                        on: sheet.cfg ? sheet.cfg.showWeatherStrip : true
                        accent: sheet.accent
                        bright: sheet.bright
                        dim: sheet.dim
                        font: sheet.font
                        duration: sheet.motionFast
                        onToggled: if (sheet.cfg) sheet.cfg.set("showWeatherStrip", !sheet.cfg.showWeatherStrip)
                    }

                    SettingToggle {
                        width: parent.width
                        label: "Show next task"
                        hint: "the upcoming-task shortcut in the task card"
                        on: sheet.cfg ? sheet.cfg.showTaskNext : true
                        accent: sheet.accent
                        bright: sheet.bright
                        dim: sheet.dim
                        font: sheet.font
                        duration: sheet.motionFast
                        onToggled: if (sheet.cfg) sheet.cfg.set("showTaskNext", !sheet.cfg.showTaskNext)
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

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: sheet.a(sheet.dim, sheet.highContrast ? 0.30 : 0.12)
                    }

                    Text {
                        text: "GIF"
                        color: sheet.a(sheet.accent, 0.9)
                        font.family: sheet.font
                        font.pixelSize: 8
                        font.letterSpacing: 1.1
                        font.bold: true
                    }

                    SettingToggle {
                        width: parent.width
                        label: "Show gif"
                        hint: "the tile under the task card"
                        on: sheet.cfg ? sheet.cfg.showGif : true
                        accent: sheet.accent
                        bright: sheet.bright
                        dim: sheet.dim
                        font: sheet.font
                        duration: sheet.motionFast
                        onToggled: if (sheet.cfg) sheet.cfg.set("showGif", !sheet.cfg.showGif)
                    }

                    SettingField {
                        id: gifIn
                        width: parent.width
                        label: "GIF path"
                        placeholder: "~/Pictures/your.gif"
                        accent: sheet.accent
                        bright: sheet.bright
                        dim: sheet.dim
                        font: sheet.font
                        onCommitted: function (value) { if (sheet.cfg) sheet.cfg.set("gif", value.trim()); }
                    }

                    Row {
                        width: parent.width
                        spacing: 8
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "FIT"
                            color: sheet.a(sheet.dim, 0.9)
                            font.family: sheet.font
                            font.pixelSize: 8
                            font.letterSpacing: 0.8
                        }
                        Repeater {
                            model: ["cover", "contain"]
                            delegate: Rectangle {
                                required property string modelData
                                width: 58
                                height: 21
                                radius: 5
                                color: sheet.cfg && sheet.cfg.gifFit === modelData
                                    ? sheet.a(sheet.accent, 0.18) : sheet.a(sheet.dim, 0.06)
                                border.width: 1
                                border.color: sheet.cfg && sheet.cfg.gifFit === modelData
                                    ? sheet.accent : sheet.a(sheet.dim, 0.2)
                                Text {
                                    anchors.centerIn: parent
                                    text: modelData
                                    color: sheet.cfg && sheet.cfg.gifFit === modelData
                                        ? sheet.accent : sheet.a(sheet.dim, 0.9)
                                    font.family: sheet.font
                                    font.pixelSize: 8
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: if (sheet.cfg) sheet.cfg.set("gifFit", modelData)
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: sheet.a(sheet.dim, sheet.highContrast ? 0.30 : 0.12)
                    }

                    Text {
                        text: "WEATHER"
                        color: sheet.a(sheet.accent, 0.9)
                        font.family: sheet.font
                        font.pixelSize: 8
                        font.letterSpacing: 1.1
                        font.bold: true
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
                                required property string modelData
                                width: 38
                                height: 21
                                radius: 5
                                color: sheet.cfg && sheet.cfg.units === modelData
                                    ? sheet.a(sheet.accent, 0.18) : sheet.a(sheet.dim, 0.06)
                                border.width: 1
                                border.color: sheet.cfg && sheet.cfg.units === modelData
                                    ? sheet.accent : sheet.a(sheet.dim, 0.2)
                                Text {
                                    anchors.centerIn: parent
                                    text: modelData === "c" ? "\u00B0C" : "\u00B0F"
                                    color: sheet.cfg && sheet.cfg.units === modelData
                                        ? sheet.accent : sheet.a(sheet.dim, 0.9)
                                    font.family: sheet.font
                                    font.pixelSize: 9
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: if (sheet.cfg) sheet.cfg.set("units", modelData)
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

                    Text {
                        width: parent.width
                        text: "The calendar reads your todo list live and only displays it. Adding, completing and rescheduling stay in the todo panel. Nothing here writes tasks.json."
                        color: sheet.a(sheet.dim, 0.62)
                        font.family: sheet.font
                        font.pixelSize: 8
                        wrapMode: Text.WordWrap
                        lineHeight: 1.25
                    }
                }
            }
        }

        // A quiet scrollbar; it appears only when the sheet actually needs it.
        Item {
            visible: flick.contentHeight > flick.height
            x: card.width - 10
            y: flick.y
            width: 3
            height: flick.height

            Rectangle {
                anchors.fill: parent
                radius: 2
                color: sheet.a(sheet.dim, 0.10)
            }
            Rectangle {
                width: parent.width
                radius: 2
                color: sheet.a(sheet.accent, 0.65)
                height: Math.max(24, flick.height * flick.height / Math.max(1, flick.contentHeight))
                y: (flick.contentY / Math.max(1, flick.contentHeight - flick.height)) * (parent.height - height)
            }
        }
    }
}
