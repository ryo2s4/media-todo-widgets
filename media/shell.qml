import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

// ~/.config/quickshell/media/shell.qml
//   run:     qs -c media
//   toggle:  qs -c media ipc call media toggle      (also: show, hide, home, games, music, settings)
// The panel emerges from the bottom-left corner.
// Keys (click the panel once first):
//   1 / 2 / 3 or Tab    switch tabs            Esc  close (or leave a text field / settings)
//   N  fold/unfold notifications               C    clear notifications
//   Home:  S Steam, D Discord, V VPN
//   Games: arrows move, Enter play/install, F favorite, S sort, A category, R surprise me, / search
//   Music: Space play/pause, Left/Right previous/next, Up/Down volume, L lyrics
ShellRoot {
    PanelWindow {
        id: root

        // ───────── window ─────────
        readonly property int panelW: cfg.panelWidth
        readonly property int panelMaxH: 800
        readonly property real panelAlpha: cfg.panelOpacity
        // true = the panel takes the keyboard as soon as it opens (blocks other apps while open)
        property bool grabKeyboard: false
        property bool open: false
        property bool settingsOpen: false
        property int tab: 0   // 0 Home, 1 Games, 2 Music, 3 Special (when revealed)
        readonly property var tabNames: special.specialVisible
            ? ["Home", "Games", "Music", "Special"] : ["Home", "Games", "Music"]
        readonly property int tabCount: tabNames.length

        // from Ryoku's own files (see applyColors / applyMetrics)
        property color paletteAccent: "#e8553a"
        property int ryokuRadius: 10
        property int ryokuGap: 12

        anchors { left: true; top: true; bottom: true }
        implicitWidth: panelW + th.gap * 2
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        visible: open || panel.opacity > 0.01
        mask: Region { item: panel }

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "media-panel"
        WlrLayershell.keyboardFocus: open ? (grabKeyboard ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand) : WlrKeyboardFocus.None

        onOpenChanged: {
            if (open) {
                Qt.callLater(root.focusKb);
            } else if (special.lockOnClose) {
                special.lock();
            }
        }

        Connections {
            target: special
            function onSpecialVisibleChanged() {
                if (!special.specialVisible && root.tab === 3)
                    root.tab = 0;
            }
        }

        function focusMonitor() {
            var m = Hyprland.focusedMonitor;
            if (!m)
                return;
            for (var i = 0; i < Quickshell.screens.length; i++) {
                if (Quickshell.screens[i].name === m.name) {
                    root.screen = Quickshell.screens[i];
                    break;
                }
            }
        }
        function openPanel() {
            if (!open)
                focusMonitor();
            open = true;
        }

        IpcHandler {
            target: "media"
            function toggle(): void { if (root.open) root.open = false; else root.openPanel(); }
            function show(): void { root.openPanel(); }
            function hide(): void { root.open = false; }
            function home(): void { root.tab = 0; root.openPanel(); }
            function games(): void { root.tab = 1; root.openPanel(); }
            function music(): void { root.tab = 2; root.openPanel(); }
            function special(): void { root.tab = special.specialVisible ? 3 : 0; root.openPanel(); }
            function settings(): void { root.settingsOpen = true; root.openPanel(); }
        }

        // ───────── data objects ─────────
        Settings { id: cfg }

        Special {
            id: special
            cfg: cfg
            chooser: chooser
            panelOpen: root.open
        }

        Cava {
            id: cava
            bars: cfg.cavaBars
            method: cfg.cavaMethod
            enabled: root.open && root.tab === 2 && cfg.cavaEnabled && music.isPlaying
        }

        Frames {
            id: framesData
            cfg: root.cfgObj
        }

        Chooser {
            id: chooser
            onPicked: function (target, path) {
                if (target.indexOf("sp:") === 0)
                    special.handlePick(target.substring(3), path);
                else
                    cfg.set(target, path);
            }
        }

        // notification history (listens on the session bus, so it works with any daemon)
        Notifs { id: notifs }

        // handed to the tabs (named differently so the bindings below are unambiguous)
        readonly property var cfgObj: cfg
        readonly property var cavaObj: cava
        readonly property var chooserObj: chooser
        readonly property var framesObj: framesData

        // ───────── theme: Ryoku palette + metrics, with your overrides ─────────
        QtObject {
            id: th
            property color accent: cfg.accentValid ? cfg.accentOverride.trim() : root.paletteAccent
            property color bright: "#ece7e2"
            property color dim: "#8f8882"
            property color cardBot: "#171211"
            property int radius: cfg.cornerRadius >= 0 ? cfg.cornerRadius : root.ryokuRadius
            property int gap: root.ryokuGap
            readonly property string font: "JetBrainsMono Nerd Font"
        }
        readonly property var themeObj: th

        function a(c, v) { return Qt.rgba(c.r, c.g, c.b, v); }

        function applyColors(raw) {
            var map = {};
            function walk(o) {
                for (var k in o) {
                    var v = o[k];
                    if (typeof v === "string")
                        map[k.toLowerCase()] = v;
                    else if (v && typeof v === "object")
                        walk(v);
                }
            }
            try {
                walk(JSON.parse(raw));
            } catch (e) {
                console.log("media: colors.json unreadable:", e);
                return;
            }
            function pick(names, fallback) {
                for (var i = 0; i < names.length; i++) {
                    var v = map[names[i]];
                    if (v === undefined)
                        continue;
                    if (/^[0-9a-f]{6}([0-9a-f]{2})?$/i.test(v))
                        v = "#" + v;
                    if (/^#[0-9a-f]{6}([0-9a-f]{2})?$/i.test(v))
                        return v;
                }
                return fallback;
            }
            root.paletteAccent = pick(["accent", "primary", "vermilion", "verm", "primary_color"], root.paletteAccent);
            th.bright = pick(["on_surface", "foreground", "fg", "text", "bright", "on_background"], th.bright);
            th.dim = pick(["on_surface_variant", "dim", "muted", "outline", "subtext", "comment"], th.dim);
            th.cardBot = pick(["surface_container", "surface", "background", "bg", "card_bot", "cardbot", "base"], th.cardBot);
        }

        function applyMetrics(raw) {
            var map = {};
            function walk(o) {
                for (var k in o) {
                    var v = o[k];
                    if (typeof v === "number")
                        map[k.toLowerCase()] = v;
                    else if (v && typeof v === "object")
                        walk(v);
                }
            }
            try {
                walk(JSON.parse(raw));
            } catch (e) {
                return;
            }
            function num(names, lo, hi) {
                for (var i = 0; i < names.length; i++) {
                    var v = map[names[i]];
                    if (v !== undefined && v >= lo && v <= hi)
                        return v;
                }
                return -1;
            }
            var r = num(["radius", "corner_radius", "rounding", "border_radius"], 0, 30);
            if (r >= 0)
                root.ryokuRadius = r;
            var g = num(["gaps_out", "gap", "gaps", "outer_gap"], 0, 40);
            if (g >= 0)
                root.ryokuGap = g;
        }

        FileView {
            id: colorsFile
            path: Quickshell.env("HOME") + "/.cache/ryoku/colors.json"
            watchChanges: true
            onFileChanged: colorsFile.reload()
            onLoaded: root.applyColors(colorsFile.text())
        }
        FileView {
            id: themeFile
            path: Quickshell.env("HOME") + "/.config/ryoku/theme.json"
            onLoaded: root.applyMetrics(themeFile.text())
        }
        FileView {
            id: desktopFile
            path: Quickshell.env("HOME") + "/.config/ryoku/desktop.json"
            onLoaded: root.applyMetrics(desktopFile.text())
        }

        function focusKb() { kb.forceActiveFocus(); }

        // ───────── the panel (bottom-left corner) ─────────
        Rectangle {
            id: panel
            width: root.panelW
            height: Math.min(parent.height - th.gap * 2, root.panelMaxH)
            x: root.open ? th.gap : -(root.panelW + th.gap)
            y: parent.height - height - th.gap + (root.open ? 0 : 60)
            opacity: root.open ? 1 : 0
            scale: root.open ? 1 : 0.88
            transformOrigin: Item.BottomLeft
            Behavior on x { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Behavior on y { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: 240 } }
            Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

            radius: th.radius + 2
            color: root.a(th.cardBot, root.panelAlpha)
            border.width: 1
            border.color: root.a(th.dim, 0.28)

            Item {
                id: kb
                anchors.fill: parent
                focus: true

                Keys.onPressed: function (event) {
                    var k = event.key;
                    var typing = !kb.activeFocus;
                    if (k === Qt.Key_Escape) {
                        if (typing)
                            kb.forceActiveFocus();
                        else if (root.settingsOpen)
                            root.settingsOpen = false;
                        else
                            root.open = false;
                        event.accepted = true;
                        return;
                    }
                    if (typing || root.settingsOpen)
                        return;
                    if (k === Qt.Key_1) {
                        root.tab = 0;
                    } else if (k === Qt.Key_2) {
                        root.tab = 1;
                    } else if (k === Qt.Key_3) {
                        root.tab = 2;
                    } else if (k === Qt.Key_4) {
                        if (special.specialVisible)
                            root.tab = 3;
                    } else if (k === Qt.Key_Tab) {
                        root.tab = (root.tab + 1) % root.tabCount;
                    } else if (k === Qt.Key_N) {
                        drawer.expanded = !drawer.expanded;
                    } else if (k === Qt.Key_C) {
                        notifs.clear();
                    } else if (root.tab === 0) {
                        if (k === Qt.Key_S) home.tileClicked(0);
                        else if (k === Qt.Key_D) home.tileClicked(1);
                        else if (k === Qt.Key_V) home.tileClicked(2);
                        else return;
                    } else if (root.tab === 1) {
                        if (k === Qt.Key_Slash) games.focusSearch();
                        else if (k === Qt.Key_Left) games.moveGrid(-1, 0);
                        else if (k === Qt.Key_Right) games.moveGrid(1, 0);
                        else if (k === Qt.Key_Up) games.moveGrid(0, -1);
                        else if (k === Qt.Key_Down) games.moveGrid(0, 1);
                        else if (k === Qt.Key_Return || k === Qt.Key_Enter) games.launchSel();
                        else if (k === Qt.Key_F) games.toggleFavSel();
                        else if (k === Qt.Key_S) games.cycleSort();
                        else if (k === Qt.Key_A) games.cycleFilter();
                        else if (k === Qt.Key_R) games.surprise();
                        else return;
                    } else {
                        if (k === Qt.Key_Space) music.toggle();
                        else if (k === Qt.Key_Right) music.next();
                        else if (k === Qt.Key_Left) music.prev();
                        else if (k === Qt.Key_Up) music.volumeBy(0.05);
                        else if (k === Qt.Key_Down) music.volumeBy(-0.05);
                        else if (k === Qt.Key_L) music.showLyrics = !music.showLyrics;
                        else return;
                    }
                    event.accepted = true;
                }

                Item {
                    id: content
                    anchors.fill: parent
                    anchors.margins: 16

                    // header: tabs, settings, close
                    Item {
                        id: header
                        width: parent.width
                        height: 26

                        Row {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 20
                            Repeater {
                                model: root.tabNames
                                delegate: Item {
                                    id: tabItem
                                    required property int index
                                    required property string modelData
                                    readonly property bool on: root.tab === index
                                    width: tabLabel.implicitWidth
                                    height: 24
                                    Text {
                                        id: tabLabel
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: tabItem.modelData
                                        color: tabItem.on ? th.bright : th.dim
                                        font.family: th.font
                                        font.pixelSize: 15
                                        font.bold: tabItem.on
                                    }
                                    Rectangle {
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.bottom: parent.bottom
                                        height: 1
                                        color: th.accent
                                        visible: tabItem.on
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.tab = tabItem.index;
                                            root.focusKb();
                                        }
                                    }
                                }
                            }
                        }

                        Row {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2
                            IconBtn {
                                size: 14
                                glyph: "\u2699"
                                on: root.settingsOpen
                                idle: th.dim
                                hot: th.accent
                                family: th.font
                                onClicked: root.settingsOpen = !root.settingsOpen
                            }
                            IconBtn {
                                size: 12
                                glyph: "\u2715"
                                idle: th.dim
                                hot: th.accent
                                family: th.font
                                onClicked: root.open = false
                            }
                        }
                    }

                    // notifications under every tab
                    NotifDrawer {
                        id: drawer
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        th: root.themeObj
                        nf: notifs
                    }

                    Item {
                        id: body
                        anchors.top: header.bottom
                        anchors.topMargin: 14
                        anchors.bottom: drawer.top
                        anchors.bottomMargin: 10
                        anchors.left: parent.left
                        anchors.right: parent.right

                        HomeTab {
                            id: home
                            anchors.fill: parent
                            visible: root.tab === 0
                            th: root.themeObj
                            cfg: root.cfgObj
                            chooser: root.chooserObj
                            frames: root.framesObj
                            gamesRef: games
                            host: root
                            active: root.open && root.tab === 0
                        }
                        GamesTab {
                            id: games
                            anchors.fill: parent
                            visible: root.tab === 1
                            th: root.themeObj
                            cfg: root.cfgObj
                            host: root
                            active: root.open && root.tab === 1
                        }
                        MusicTab {
                            id: music
                            anchors.fill: parent
                            visible: root.tab === 2
                            th: root.themeObj
                            cfg: root.cfgObj
                            cava: root.cavaObj
                            active: root.open && root.tab === 2
                        }
                        SpecialTab {
                            id: specialTab
                            anchors.fill: parent
                            visible: root.tab === 3
                            th: root.themeObj
                            sp: special
                            frames: root.framesObj
                            chooser: root.chooserObj
                            host: root
                            active: root.open && root.tab === 3
                        }
                    }
                }
            }

            // settings overlay
            SettingsCard {
                id: settingsCard
                z: 50
                anchors.fill: parent
                anchors.margins: 10
                visible: root.settingsOpen
                th: root.themeObj
                cfg: root.cfgObj
                cava: root.cavaObj
                chooser: root.chooserObj
                frames: root.framesObj
                special: special
                onClosed: root.settingsOpen = false
            }
        }
    }
}
