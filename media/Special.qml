import QtQuick
import Quickshell
import Quickshell.Io

// Special.qml: the encrypted couples vault behind the "Special" tab.
// Everything personal (the two profiles, memories, quotes, sealed letters,
// the bucket list, moods) lives in ONE gpg-symmetric archive (AES-256) inside a
// folder you pick. While unlocked it is decrypted into a 0700 tmpfs dir and
// wiped again on lock, so a killed panel never leaves plaintext on disk.
//
// The passphrase only ever travels through the environment of a short-lived
// bash process; it is never part of a command line.
Scope {
    id: sp

    property var cfg: null
    property var chooser: null
    property bool panelOpen: false

    readonly property string home: Quickshell.env("HOME")
    // the desktop account picture, used for "me" instead of a copy in the vault
    readonly property string facePath: home + "/.face"
    property bool faceExists: false

    // the tab is hidden behind a seven-tap knock in Settings > Look unless
    // specialSecret is turned off (then it is always visible)
    property bool specialSecret: true
    property bool specialRevealed: false
    readonly property bool specialVisible: !specialSecret || specialRevealed

    readonly property string runtimeDir: Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"
    readonly property string prefsFile: home + "/.config/quickshell/media/special.json"

    // ── preferences (never secret: no names, no dates, no passphrase) ──
    property string vaultPath: home + "/Pictures/special"
    property int autoLockMinutes: 10
    property bool lockOnClose: true
    property string lastSection: "Us"

    readonly property string vaultFile: vaultPath.replace(/\/+$/, "") + "/vault.gpg"

    // ── vault state ──
    property bool vaultExists: false
    property bool unlocked: false
    property bool busy: false
    property bool packing: false
    property bool dirty: false
    property string error: ""
    property string info: ""
    property string tmpDir: ""
    property int fails: 0
    property real cooldownUntil: 0

    property string _pw: ""
    property string _pending: ""
    property string _pendingVault: ""
    property var _pendingMemory: null
    property string _pendingBanner: ""
    property bool _creating: false
    property bool _lockAfterPack: false
    property bool _needPack: false
    property int _gen: 0
    property int _packGen: 0

    // ── data (meaningful while unlocked) ──
    property var profile: sp._emptyProfile()
    property var memories: []
    property var quotes: []
    property var notes: []
    property var bucket: []
    property var moods: []

    Component.onCompleted: {
        sp.sweep();
        sp.probe();
        faceProbe.environment = { SP_FACE: sp.facePath };
        faceProbe.running = true;
    }
    Process {
        id: faceProbe
        command: ["bash", "-c", "[ -f \"$SP_FACE\" ] && printf YES || printf NO"]
        stdout: StdioCollector {
            onStreamFinished: sp.faceExists = text.trim() === "YES"
        }
    }

    // ───────── dates ─────────
    function pad(n) { return (n < 10 ? "0" : "") + n; }
    function todayStr() {
        var d = new Date();
        return d.getFullYear() + "-" + pad(d.getMonth() + 1) + "-" + pad(d.getDate());
    }
    function parseDate(s) {
        if (!s)
            return null;
        var p = String(s).split("-");
        if (p.length !== 3)
            return null;
        var d = new Date(Number(p[0]), Number(p[1]) - 1, Number(p[2]));
        return isNaN(d.getTime()) ? null : d;
    }
    function fmtDate(d) { return d.getFullYear() + "-" + pad(d.getMonth() + 1) + "-" + pad(d.getDate()); }
    function dayDiff(a, b) {
        var A = new Date(a.getFullYear(), a.getMonth(), a.getDate());
        var B = new Date(b.getFullYear(), b.getMonth(), b.getDate());
        return Math.round((B - A) / 86400000);
    }
    function daysSince(s) {
        var d = parseDate(s);
        return d ? dayDiff(d, new Date()) : null;
    }
    function daysUntil(s) {
        var d = parseDate(s);
        return d ? dayDiff(new Date(), d) : null;
    }
    function nextOccurrence(s) {
        var d = parseDate(s);
        if (!d)
            return null;
        var t = new Date();
        var n = new Date(t.getFullYear(), d.getMonth(), d.getDate());
        if (dayDiff(t, n) < 0)
            n = new Date(t.getFullYear() + 1, d.getMonth(), d.getDate());
        return n;
    }

    function countdowns() {
        var out = [];
        var who1 = (profile.me && profile.me.name) ? profile.me.name : "Me";
        var who2 = (profile.partner && profile.partner.name) ? profile.partner.name : "Partner";
        if (profile.since) {
            var n = nextOccurrence(profile.since);
            var yrs = n ? (n.getFullYear() - parseDate(profile.since).getFullYear()) : 0;
            if (n)
                out.push({ label: yrs > 0 ? yrs + (yrs === 1 ? " year together" : " years together") : "Together", days: dayDiff(new Date(), n), date: fmtDate(n), glyph: "\u2665" });
        }
        if (profile.birthdayMe) {
            var b = nextOccurrence(profile.birthdayMe);
            if (b)
                out.push({ label: who1 + "'s birthday", days: dayDiff(new Date(), b), date: fmtDate(b), glyph: "\u2726" });
        }
        if (profile.birthdayPartner) {
            var c = nextOccurrence(profile.birthdayPartner);
            if (c)
                out.push({ label: who2 + "'s birthday", days: dayDiff(new Date(), c), date: fmtDate(c), glyph: "\u2726" });
        }
        if (profile.nextMeet) {
            var m = parseDate(profile.nextMeet);
            if (m)
                out.push({ label: "Next meet", days: dayDiff(new Date(), m), date: fmtDate(m), glyph: "\u2708" });
        }
        out.sort(function (a, b) { return a.days - b.days; });
        return out;
    }

    // ─── memory of the day ───
    function thisDayMemory() {
        if (memories.length === 0)
            return null;
        var t = new Date();
        for (var i = 0; i < memories.length; i++) {
            var d = parseDate(memories[i].date);
            if (d && d.getMonth() === t.getMonth() && d.getDate() === t.getDate())
                return memories[i];
        }
        var start = new Date(t.getFullYear(), 0, 0);
        var doy = Math.floor((t - start) / 86400000);
        return memories[doy % memories.length];
    }
    function yearsAgo(m) {
        var d = m ? parseDate(m.date) : null;
        return d ? (new Date().getFullYear() - d.getFullYear()) : 0;
    }

    // ───────── urls ─────────
    function url(rel) { return rel ? "file://" + tmpDir + "/" + rel : ""; }
    function memoryUrl(m) { return m ? url(m.file) : ""; }
    function avatarUrl(who) {
        if (who === "me" && sp.faceExists)
            return "file://" + sp.facePath;
        return (profile[who] && profile[who].avatar) ? url(profile[who].avatar) : "";
    }
    function avatarEditable(who) { return !(who === "me" && sp.faceExists); }

    // ───────── passphrase rules ─────────
    function passIssue(p) {
        p = String(p || "");
        if (p.length < 12)
            return "Use at least 12 characters.";
        if (/^\d+$/.test(p))
            return "Digits only isn't a passphrase. Add words.";
        return "";
    }

    // ───────── preferences ─────────
    function savePrefs() {
        prefsTimer.restart();
    }
    Timer {
        id: prefsTimer
        interval: 350
        onTriggered: {
            prefsStore.setText(JSON.stringify({
                vaultPath: sp.vaultPath,
                autoLockMinutes: sp.autoLockMinutes,
                lockOnClose: sp.lockOnClose,
                lastSection: sp.lastSection,
                specialSecret: sp.specialSecret,
                specialRevealed: sp.specialRevealed
            }, null, 1));
            chmodProc.environment = { SP_FILE: sp.prefsFile };
            chmodProc.running = true;
        }
    }
    Process {
        id: chmodProc
        command: ["bash", "-c", "for i in 1 2 3 4 5 6; do [ -f \"$SP_FILE\" ] && chmod 600 \"$SP_FILE\" && break; sleep 0.05; done; true"]
    }
    FileView {
        id: prefsStore
        path: sp.prefsFile
        onLoaded: {
            try {
                var s = JSON.parse(prefsStore.text());
                if (typeof s.vaultPath === "string" && s.vaultPath !== "")
                    sp.vaultPath = s.vaultPath;
                if (typeof s.autoLockMinutes === "number")
                    sp.autoLockMinutes = s.autoLockMinutes;
                if (typeof s.lockOnClose === "boolean")
                    sp.lockOnClose = s.lockOnClose;
                if (typeof s.lastSection === "string" && s.lastSection !== "")
                    sp.lastSection = s.lastSection;
                if (typeof s.specialSecret === "boolean")
                    sp.specialSecret = s.specialSecret;
                if (typeof s.specialRevealed === "boolean")
                    sp.specialRevealed = s.specialRevealed;
            } catch (e) {
                console.log("media: special.json:", e);
            }
            sp.probe();
        }
    }

    // ───────── vault plumbing ─────────
    function revealSpecial() {
        sp.specialRevealed = true;
        sp.savePrefs();
    }
    function setSpecialSecret(v) {
        sp.specialSecret = !!v;
        if (sp.specialSecret)
            sp.specialRevealed = false;
        sp.savePrefs();
        // hiding the tab is also a lock: never leave decrypted files behind it
        if (sp.specialSecret)
            sp.lock();
    }
    function hideSpecial() {
        sp.specialRevealed = false;
        sp.savePrefs();
        sp.lock();
    }

    function probe() {
        probeProc.environment = { SP_VAULT: sp.vaultFile };
        probeProc.running = true;
    }
    Process {
        id: probeProc
        command: ["bash", "-c", "[ -f \"$SP_VAULT\" ] && printf YES || printf NO"]
        stdout: StdioCollector {
            onStreamFinished: sp.vaultExists = text.trim() === "YES"
        }
    }

    function sweep() {
        sweepProc.environment = { SP_DIR: sp.runtimeDir };
        sweepProc.running = true;
    }
    Process {
        id: sweepProc
        command: ["bash", "-c", "rm -rf \"$SP_DIR\"/ryoku-special-* 2>/dev/null; true"]
    }

    function setVaultPath(p) {
        p = String(p || "").trim();
        if (p === "")
            return;
        if (sp.unlocked) {
            sp._pendingVault = p;
            sp.lock();
            return;
        }
        sp.vaultPath = p;
        sp.savePrefs();
        sp.probe();
    }

    function mkTmp() {
        mkdirProc.running = true;
    }
    Process {
        id: mkdirProc
        command: ["bash", "-c", "d=$(mktemp -d \"${XDG_RUNTIME_DIR:-/tmp}/ryoku-special-XXXXXX\") && chmod 700 \"$d\" && printf %s \"$d\""]
        stdout: StdioCollector {
            onStreamFinished: {
                sp.tmpDir = text.trim();
                if (sp.tmpDir === "") {
                    sp.busy = false;
                    sp.error = "Could not create a private temp dir.";
                    return;
                }
                if (sp._creating)
                    sp._startCreate();
                else
                    sp._startUnlock();
            }
        }
    }

    function unlock(p) {
        if (sp.busy)
            return;
        if (Date.now() < sp.cooldownUntil) {
            sp.error = "Too many attempts. Wait a moment.";
            return;
        }
        var issue = sp.passIssue(p);
        if (issue !== "") {
            sp.error = issue;
            return;
        }
        sp.error = "";
        sp.info = "";
        sp.busy = true;
        sp._creating = false;
        sp._pending = p;
        sp.tmpDir = "";
        sp.mkTmp();
    }

    function create(p) {
        if (sp.busy)
            return;
        var issue = sp.passIssue(p);
        if (issue !== "") {
            sp.error = issue;
            return;
        }
        sp.error = "";
        sp.busy = true;
        sp._creating = true;
        sp._pending = p;
        sp.tmpDir = "";
        sp.mkTmp();
    }

    function _startCreate() {
        sp._pw = sp._pending;
        sp.profile = sp._emptyProfile();
        sp.memories = [];
        sp.quotes = [];
        sp.notes = [];
        sp.bucket = [];
        sp.moods = [];
        sp._writeData();
        sp._needPack = true;
        sp._lockAfterPack = false;
    }

    function _startUnlock() {
        unlockProc.environment = { SP_PW: sp._pending, SP_VAULT: sp.vaultFile, SP_TMP: sp.tmpDir };
        unlockProc.running = true;
    }
    Process {
        id: unlockProc
        command: ["bash", "-c",
            "set -o pipefail; " +
            "printf '%s' \"$SP_PW\" | gpg --batch --quiet --pinentry-mode loopback --passphrase-fd 0 " +
            "--decrypt \"$SP_VAULT\" 2>/dev/null | tar --zstd -xf - -C \"$SP_TMP\" 2>/dev/null; " +
            "rc=${PIPESTATUS[1]}; if [ \"$rc\" -eq 0 ]; then printf OK; else printf BAD; fi"]
        stdout: StdioCollector {
            onStreamFinished: {
                var ok = text.trim() === "OK";
                if (ok) {
                    // stay locked/busy until data.json has actually been read, so a
                    // close in this window can never repack the vault with empty data
                    if (!sp._creating)
                        sp.fails = 0;
                    sp.loadData();
                } else {
                    sp.busy = false;
                    sp._pending = "";
                    sp._creating = false;
                    sp.fails++;
                    sp.error = "Wrong passphrase.";
                    if (sp.fails >= 5) {
                        sp.cooldownUntil = Date.now() + 30000;
                        sp.fails = 0;
                    }
                    sp.wipeTmp();
                }
            }
        }
    }

    function loadData() {
        if (sp.tmpDir === "")
            return;
        readProc.environment = { SP_TARGET: sp.tmpDir + "/data.json" };
        readProc.running = true;
    }
    Process {
        id: readProc
        command: ["bash", "-c", "[ -f \"$SP_TARGET\" ] && cat \"$SP_TARGET\" || printf '{}'"]
        stdout: StdioCollector {
            onStreamFinished: sp._load(text)
        }
    }

    function _emptyProfile() {
        return {
            me: { name: "", avatar: "", frame: "" },
            partner: { name: "", avatar: "", frame: "" },
            since: "", nextMeet: "", birthdayMe: "", birthdayPartner: "", banner: ""
        };
    }

    function _obj() {
        return {
            profile: sp.profile,
            memories: sp.memories,
            quotes: sp.quotes,
            notes: sp.notes,
            bucket: sp.bucket,
            moods: sp.moods
        };
    }

    function _load(raw) {
        var s = {};
        try {
            s = JSON.parse(String(raw || "{}"));
        } catch (e) {
            s = {};
            sp.error = "data.json inside the vault is unreadable.";
        }
        var d = sp._emptyProfile();
        var p = s.profile || {};
        for (var who of ["me", "partner"]) {
            if (p[who] && typeof p[who] === "object") {
                d[who] = {
                    name: String(p[who].name || ""),
                    avatar: String(p[who].avatar || ""),
                    frame: String(p[who].frame || "")
                };
            }
        }
        for (var k of ["since", "nextMeet", "birthdayMe", "birthdayPartner", "banner"])
            d[k] = String(p[k] || "");
        sp.profile = d;

        sp.memories = Array.isArray(s.memories) ? s.memories.filter(function (m) {
            return m && typeof m.file === "string" && m.file !== "";
        }).map(function (m) {
            return {
                file: String(m.file), caption: String(m.caption || ""), date: String(m.date || ""),
                city: String(m.city || ""), fav: !!m.fav
            };
        }) : [];
        sp.quotes = Array.isArray(s.quotes) ? s.quotes.filter(function (q) { return q && q.text; }).map(function (q) {
            return { text: String(q.text), who: String(q.who || "me"), date: String(q.date || "") };
        }) : [];
        sp.notes = Array.isArray(s.notes) ? s.notes.filter(function (n) { return n && n.text; }).map(function (n) {
            return { text: String(n.text), createdAt: String(n.createdAt || ""), unlockAt: String(n.unlockAt || ""), opened: !!n.opened };
        }) : [];
        sp.bucket = Array.isArray(s.bucket) ? s.bucket.filter(function (b) { return b && b.text; }).map(function (b) {
            return { text: String(b.text), done: !!b.done, doneAt: String(b.doneAt || "") };
        }) : [];
        sp.moods = Array.isArray(s.moods) ? s.moods.filter(function (m) { return m && m.date; }).map(function (m) {
            return { date: String(m.date), me: Number(m.me || 0), partner: Number(m.partner || 0) };
        }) : [];

        var created = sp._creating;
        sp._creating = false;
        sp.unlocked = true;
        sp._pw = sp._pending;
        sp._pending = "";
        sp.busy = false;
        if (created) {
            sp.vaultExists = true;
            sp.info = "Vault created.";
        }
        lockTimer.restart();
        // closed while we were still reading: never leave a vault unlocked in memory
        if (!sp.panelOpen)
            sp.lock();
    }

    function save() {
        if (!sp.unlocked)
            return;
        sp.dirty = true;
        sp._writeData();
        packTimer.restart();
    }

    function _writeData() {
        if (sp.tmpDir === "")
            return;
        sp._gen++;
        writeProc.environment = { SP_TARGET: sp.tmpDir + "/data.json", SP_DATA: JSON.stringify(sp._obj()) };
        writeProc.running = true;
    }
    Process {
        id: writeProc
        command: ["bash", "-c", "printf '%s' \"$SP_DATA\" > \"$SP_TARGET\""]
        onRunningChanged: {
            if (!running && (sp._lockAfterPack || sp._needPack)) {
                sp._needPack = false;
                sp.packNow();
            }
        }
    }

    Timer {
        id: packTimer
        interval: 8000
        onTriggered: {
            if (sp.packing) {
                restart();
                return;
            }
            sp.packNow();
        }
    }

    function requestLock() {
        if (!sp.unlocked)
            return;
        sp._lockAfterPack = true;
        sp._writeData();
    }

    function packNow() {
        if (sp.tmpDir === "")
            return;
        if (!sp.unlocked && !sp._creating)
            return;
        if (sp.packing || writeProc.running) {
            sp._needPack = true;
            return;
        }
        sp.packing = true;
        sp._packGen = sp._gen;
        packProc.environment = { SP_PW: sp._pw, SP_TMP: sp.tmpDir, SP_VAULT: sp.vaultFile };
        packProc.running = true;
    }
    Process {
        id: packProc
        command: ["bash", "-c",
            "mkdir -p \"$(dirname \"$SP_VAULT\")\"; set -o pipefail; " +
            "tar --zstd -cf - -C \"$SP_TMP\" . | gpg --batch --yes --quiet --pinentry-mode loopback " +
            "--passphrase-fd 3 --symmetric --cipher-algo AES256 --s2k-mode 3 --s2k-digest-algo SHA512 " +
            "--s2k-count 65011712 -o \"$SP_VAULT.tmp\" 3<<<\"$SP_PW\" 2>/dev/null; " +
            "rc=${PIPESTATUS[1]}; if [ \"$rc\" -eq 0 ]; then " +
            "[ -f \"$SP_VAULT\" ] && cp -f \"$SP_VAULT\" \"$SP_VAULT.bak\"; " +
            "mv -f \"$SP_VAULT.tmp\" \"$SP_VAULT\"; printf OK; else rm -f \"$SP_VAULT.tmp\"; printf FAIL; fi"]
        stdout: StdioCollector {
            onStreamFinished: {
                sp.packing = false;
                if (text.trim() === "OK") {
                    sp.vaultExists = true;
                    sp.dirty = false;
                    if (sp._needPack || sp._gen !== sp._packGen) {
                        sp._needPack = false;
                        sp.packNow();
                        return;
                    }
                    if (sp._creating) {
                        // keep _creating set: _load uses it to show "Vault created"
                        sp.vaultExists = true;
                        sp.loadData();
                    }
                    if (sp._lockAfterPack) {
                        sp._lockAfterPack = false;
                        sp.wipeTmp();
                    }
                } else {
                    sp.error = "Could not write the vault. Check the folder and its free space.";
                    sp._lockAfterPack = false;
                    sp._creating = false;
                    sp.busy = false;
                }
            }
        }
    }

    function lock() {
        if (!sp.unlocked)
            return;
        sp.requestLock();
    }

    function wipeTmp() {
        if (sp.tmpDir === "")
            return;
        rmProc.environment = { SP_TMP: sp.tmpDir };
        rmProc.running = true;
        var d = sp.tmpDir;
        sp.tmpDir = "";
        sp.unlocked = false;
        sp._pw = "";
        sp.profile = sp._emptyProfile();
        sp.memories = [];
        sp.quotes = [];
        sp.notes = [];
        sp.bucket = [];
        sp.moods = [];
        sp.busy = false;
        if (sp._pendingVault !== "") {
            sp.vaultPath = sp._pendingVault;
            sp._pendingVault = "";
            sp.savePrefs();
            sp.probe();
        }
        console.log("media: special vault locked, wiped", d);
    }
    Process {
        id: rmProc
        command: ["bash", "-c", "rm -rf \"$SP_TMP\" 2>/dev/null; true"]
    }

    Timer {
        id: lockTimer
        interval: Math.max(1, sp.autoLockMinutes) * 60000
        running: sp.unlocked
        onTriggered: sp.lock()
    }
    function touch() {
        if (sp.unlocked)
            lockTimer.restart();
    }

    // ───────── passphrase change (re-encrypts with the new key) ─────────
    function changePass(p) {
        var issue = sp.passIssue(p);
        if (issue !== "") {
            sp.error = issue;
            return;
        }
        if (!sp.unlocked) {
            sp.error = "Unlock the tab first, then change the passphrase.";
            return;
        }
        sp._pw = p;
        sp.error = "";
        sp.info = "Passphrase changed.";
        sp._writeData();
        sp._needPack = true;
        packTimer.restart();
    }

    // ───────── profile editing ─────────
    function setPerson(who, key, value) {        var p = JSON.parse(JSON.stringify(sp.profile));
        if (!p[who])
            p[who] = {};
        p[who][key] = value;
        sp.profile = p;
        sp.save();
    }
    function setMeta(key, value) {
        var p = JSON.parse(JSON.stringify(sp.profile));
        p[key] = value;
        sp.profile = p;
        sp.save();
    }

    // ───────── chooser bridge ─────────
    function handlePick(kind, path) {
        if (!path)
            return;
        if (kind === "vaultPath")
            sp.setVaultPath(path);
        else if (kind === "me" || kind === "partner")
            sp.setAvatar(kind, path);
        else if (kind === "banner")
            sp.setBanner(path);
        else if (kind === "memories")
            sp.addMemory(path);
        else if (kind === "importDir")
            sp.importFolder(path);
        else if (kind === "exportDir")
            sp.exportBook(path);
        else if (kind === "backupDir")
            sp.backupTo(path);
    }

    function setBanner(src) {
        if (!sp.unlocked)
            return;
        var m = String(src).match(/\.[a-z0-9]+$/i);
        var ext = m ? m[0].toLowerCase() : ".jpg";
        var rel = "banner-" + Date.now() + ext;
        sp._pendingBanner = rel;
        bannerProc.environment = { SP_SRC: src, SP_DST: sp.tmpDir + "/" + rel, SP_TMP: sp.tmpDir };
        bannerProc.running = true;
    }
    Process {
        id: bannerProc
        command: ["bash", "-c",
            "cp -f -- \"$SP_SRC\" \"$SP_DST\" 2>/dev/null || { printf FAIL; exit 0; }; " +
            "b=${SP_DST##*/}; find \"$SP_TMP\" -maxdepth 1 -type f -name 'banner-*' ! -name \"$b\" -delete 2>/dev/null; printf OK"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim() === "OK") {
                    sp.setMeta("banner", sp._pendingBanner);
                    sp._pendingBanner = "";
                } else {
                    sp.error = "Could not copy that banner.";
                }
            }
        }
    }
    function removeBanner() {
        var rel = sp.profile.banner;
        sp.setMeta("banner", "");
        if (rel !== "" && sp.tmpDir !== "") {
            delProc.environment = { SP_TARGET: sp.tmpDir + "/" + rel };
            delProc.running = true;
        }
    }

    function setAvatar(who, src) {
        if (!sp.unlocked)
            return;
        var m = String(src).match(/\.[a-z0-9]+$/i);
        var ext = m ? m[0].toLowerCase() : ".jpg";
        var rel = "avatars/" + who + ext;
        copyProc.environment = { SP_SRC: src, SP_DST: sp.tmpDir + "/" + rel, SP_MKDIR: sp.tmpDir + "/avatars" };
        copyProc.running = true;
        sp.setPerson(who, "avatar", rel);
    }
    Process {
        id: copyProc
        command: ["bash", "-c", "[ -n \"$SP_MKDIR\" ] && mkdir -p \"$SP_MKDIR\"; cp -f -- \"$SP_SRC\" \"$SP_DST\" 2>/dev/null && printf OK || printf FAIL"]
        stdout: StdioCollector {
            onStreamFinished: if (text.trim() !== "OK") sp.error = "Could not copy that file."
        }
    }

    // ───────── memories ─────────
    function addMemory(src) {
        if (!sp.unlocked)
            return;
        var m = String(src).match(/\.[a-z0-9]+$/i);
        var ext = m ? m[0].toLowerCase() : ".jpg";
        var name = "m" + Date.now() + ext;
        sp._pendingMemory = { file: "memories/" + name, caption: "", date: sp.todayStr(), city: "", fav: false };
        copyProc.environment = { SP_SRC: src, SP_DST: sp.tmpDir + "/memories/" + name, SP_MKDIR: sp.tmpDir + "/memories" };
        copyProc.running = true;
        memPoll.restart();
    }
    Timer {
        id: memPoll
        interval: 900
        onTriggered: {
            if (copyProc.running) {
                restart();
                return;
            }
            if (sp._pendingMemory) {
                sp.memories = sp.memories.concat([sp._pendingMemory]);
                sp._pendingMemory = null;
                sp.save();
            }
        }
    }
    function setMemory(i, key, value) {
        var arr = sp.memories.slice();
        if (i < 0 || i >= arr.length)
            return;
        var o = JSON.parse(JSON.stringify(arr[i]));
        o[key] = value;
        arr[i] = o;
        sp.memories = arr;
        sp.save();
    }
    function toggleFav(i) {
        var arr = sp.memories.slice();
        if (i < 0 || i >= arr.length)
            return;
        arr[i] = JSON.parse(JSON.stringify(arr[i]));
        arr[i].fav = !arr[i].fav;
        sp.memories = arr;
        sp.save();
    }
    function removeMemory(i) {
        var arr = sp.memories.slice();
        if (i < 0 || i >= arr.length)
            return;
        var rel = arr[i].file;
        arr.splice(i, 1);
        sp.memories = arr;
        sp.save();
        delProc.environment = { SP_TARGET: sp.tmpDir + "/" + rel };
        delProc.running = true;
    }
    Process {
        id: delProc
        command: ["bash", "-c", "rm -f -- \"$SP_TARGET\""]
    }

    // ───────── quotes ─────────
    function addQuote(text, who) {
        text = String(text || "").trim();
        if (text === "")
            return;
        sp.quotes = sp.quotes.concat([{ text: text, who: who || "me", date: sp.todayStr() }]);
        sp.save();
    }
    function removeQuote(i) {
        var arr = sp.quotes.slice();
        if (i >= 0 && i < arr.length)
            arr.splice(i, 1);
        sp.quotes = arr;
        sp.save();
    }

    // ───────── sealed letters ─────────
    function addNote(text, unlockAt) {
        text = String(text || "").trim();
        if (text === "")
            return;
        sp.notes = sp.notes.concat([{
            text: text, createdAt: sp.todayStr(), unlockAt: String(unlockAt || ""), opened: false
        }]);
        sp.save();
    }
    function openNote(i) {
        var arr = sp.notes.slice();
        if (i < 0 || i >= arr.length)
            return;
        var o = JSON.parse(JSON.stringify(arr[i]));
        o.opened = true;
        arr[i] = o;
        sp.notes = arr;
        sp.save();
    }
    function noteReady(n) {
        return !n.unlockAt || String(n.unlockAt) <= sp.todayStr();
    }
    function noteDays(n) {
        return sp.daysUntil(n.unlockAt);
    }
    function removeNote(i) {
        var arr = sp.notes.slice();
        if (i >= 0 && i < arr.length)
            arr.splice(i, 1);
        sp.notes = arr;
        sp.save();
    }

    // ───────── bucket list ─────────
    function addBucket(text) {
        text = String(text || "").trim();
        if (text === "")
            return;
        sp.bucket = sp.bucket.concat([{ text: text, done: false, doneAt: "" }]);
        sp.save();
    }
    function toggleBucket(i) {
        var arr = sp.bucket.slice();
        if (i < 0 || i >= arr.length)
            return;
        var o = JSON.parse(JSON.stringify(arr[i]));
        o.done = !o.done;
        o.doneAt = o.done ? sp.todayStr() : "";
        arr[i] = o;
        sp.bucket = arr;
        sp.save();
    }
    function removeBucket(i) {
        var arr = sp.bucket.slice();
        if (i >= 0 && i < arr.length)
            arr.splice(i, 1);
        sp.bucket = arr;
        sp.save();
    }

    // ───────── moods ─────────
    function todayMood() {
        var t = sp.todayStr();
        for (var i = 0; i < sp.moods.length; i++)
            if (sp.moods[i].date === t)
                return sp.moods[i];
        return { date: t, me: 0, partner: 0 };
    }
    function setMood(who, level) {
        var t = sp.todayStr();
        var arr = sp.moods.slice();
        var at = -1;
        for (var i = 0; i < arr.length; i++)
            if (arr[i].date === t) {
                at = i;
                break;
            }
        if (at < 0) {
            arr.push({ date: t, me: 0, partner: 0 });
            at = arr.length - 1;
        }
        var o = JSON.parse(JSON.stringify(arr[at]));
        o[who] = level;
        arr[at] = o;
        sp.moods = arr;
        sp.save();
    }
    function recentMoods(n) {
        var out = sp.moods.slice();
        out.sort(function (a, b) { return a.date < b.date ? 1 : -1; });
        return out.slice(0, n || 14);
    }

    // ───────── import a whole folder ─────────
    function importFolder(dir) {
        if (!sp.unlocked)
            return;
        importProc.environment = { SP_SRC: dir, SP_MEM: sp.tmpDir + "/memories" };
        importProc.running = true;
    }
    Process {
        id: importProc
        command: ["python3", "-c",
            "import json,os,shutil,sys,time\n" +
            "src,mem=os.environ['SP_SRC'],os.environ['SP_MEM']\n" +
            "os.makedirs(mem,exist_ok=True)\n" +
            "exts=('.jpg','.jpeg','.png','.webp','.gif','.bmp','.avif')\n" +
            "out=[]\n" +
            "for n in sorted(os.listdir(src)):\n" +
            "    p=os.path.join(src,n)\n" +
            "    if not os.path.isfile(p) or os.path.splitext(n)[1].lower() not in exts: continue\n" +
            "    name='i%d_%s' % (int(time.time()*1000)+len(out), n.replace(' ','_'))\n" +
            "    shutil.copy2(p,os.path.join(mem,name))\n" +
            "    out.append({'file':'memories/'+name,'date':time.strftime('%Y-%m-%d',time.localtime(os.path.getmtime(p)))})\n" +
            "print(json.dumps(out))"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var arr = JSON.parse(text.trim() || "[]");
                    if (Array.isArray(arr) && arr.length > 0) {
                        var add = arr.map(function (m) {
                            return { file: String(m.file), caption: "", date: String(m.date || ""), city: "", fav: false };
                        });
                        sp.memories = sp.memories.concat(add);
                        sp.save();
                        sp.info = "Imported " + add.length + " memories.";
                    } else {
                        sp.info = "No images found in that folder.";
                    }
                } catch (e) {
                    sp.error = "Could not import that folder.";
                }
            }
        }
    }

    // ───────── export ─────────
    function exportBook(dir) {
        if (!sp.unlocked)
            return;
        exportProc.environment = { SP_SRC: sp.tmpDir, SP_OUT: dir };
        exportProc.running = true;
    }
    Process {
        id: exportProc
        command: ["python3", "-c",
            "import base64,json,os,shutil,sys,html\n" +
            "src,out=os.environ['SP_SRC'],os.environ['SP_OUT']\n" +
            "d=json.load(open(os.path.join(src,'data.json')))\n" +
            "os.makedirs(out,exist_ok=True)\n" +
            "img=os.path.join(out,'images'); os.makedirs(img,exist_ok=True)\n" +
            "def enc(p):\n" +
            "    with open(os.path.join(src,p),'rb') as f: return base64.b64encode(f.read()).decode()\n" +
            "prof=d.get('profile',{})\n" +
            "me=prof.get('me',{}).get('name') or 'Me'\n" +
            "her=prof.get('partner',{}).get('name') or 'Partner'\n" +
            "h=['<html><head><meta charset=\"utf-8\"><title>Our memory book</title>',\n" +
            "   '<style>body{background:#141010;color:#ece7e2;font-family:monospace;max-width:860px;margin:40px auto;padding:0 20px}',\n" +
            "   'img{max-width:100%;border-radius:10px;margin:8px 0}h1,h2{color:#e8553a}',\n" +
            "   '.q{border-left:3px solid #e8553a;padding-left:12px;margin:10px 0;color:#c9c2bc}',\n" +
            "   '.m{margin:26px 0;border-bottom:1px solid #2a2320;padding-bottom:20px}.c{color:#8f8882;font-size:13px}</style></head><body>']\n" +
            "h.append('<h1>%s &amp; %s</h1>' % (html.escape(me),html.escape(her)))\n" +
            "if prof.get('since'): h.append('<p class=\"c\">together since %s</p>' % html.escape(prof['since']))\n" +
            "h.append('<h2>Memories</h2>')\n" +
            "md=['# Our memory book','']\n" +
            "if prof.get('since'): md.append('Together since %s' % prof['since']); md.append('')\n" +
            "for m in d.get('memories',[]):\n" +
            "    p=m.get('file','')\n" +
            "    if not p or not os.path.exists(os.path.join(src,p)): continue\n" +
            "    cap=html.escape(m.get('caption') or '')\n" +
            "    meta=' &middot; '.join([x for x in [html.escape(m.get('date') or ''),html.escape(m.get('city') or '')] if x])\n" +
            "    mt='png' if p.lower().endswith('.png') else ('webp' if p.lower().endswith('.webp') else ('gif' if p.lower().endswith('.gif') else 'jpeg'))
    h.append('<div class=\"m\"><img src=\"data:image/%s;base64,%s\"><div class=\"c\">%s</div><p>%s</p></div>' % (mt,enc(p),meta,cap))\n" +
            "    shutil.copy2(os.path.join(src,p),os.path.join(img,os.path.basename(p)))\n" +
            "    md.append('![%s](images/%s)' % (cap,os.path.basename(p))); md.append(''); md.append('*%s*' % meta.replace(' &middot; ',' \u00b7 ')); md.append(''); md.append(cap); md.append('')\n" +
            "h.append('<h2>Our quotes</h2>')\n" +
            "md.append('## Our quotes'); md.append('')\n" +
            "for q in d.get('quotes',[]):\n" +
            "    h.append('<div class=\"q\">%s</div>' % html.escape(q.get('text','')))\n" +
            "    md.append('> %s' % q.get('text','')); md.append('')\n" +
            "h.append('<h2>Letters</h2>')\n" +
            "md.append('## Letters'); md.append('')\n" +
            "for n in d.get('notes',[]):\n" +
            "    h.append('<div class=\"q\"><div class=\"c\">sealed until %s</div>%s</div>' % (html.escape(n.get('unlockAt') or 'always'),html.escape(n.get('text',''))))\n" +
            "    md.append('**Sealed until %s**' % (n.get('unlockAt') or 'always')); md.append(''); md.append(n.get('text','')); md.append('')\n" +
            "h.append('<h2>Bucket list</h2><ul>')\n" +
            "md.append('## Bucket list'); md.append('')\n" +
            "for b in d.get('bucket',[]):\n" +
            "    mark='x' if b.get('done') else ' '\n" +
            "    h.append('<li>[%s] %s</li>' % (mark,html.escape(b.get('text',''))))\n" +
            "    md.append('- [%s] %s' % (mark,b.get('text','')))\n" +
            "h.append('</ul></body></html>')\n" +
            "open(os.path.join(out,'memory-book.html'),'w').write('\\n'.join(h))\n" +
            "open(os.path.join(out,'memory-book.md'),'w').write('\\n'.join(md))\n" +
            "print('OK')"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim() === "OK") {
                    sp.info = "Memory book written. It is NOT encrypted.";
                    sp.error = "";
                } else {
                    sp.error = "Export failed.";
                }
            }
        }
    }

    function backupTo(dir) {
        if (!sp.unlocked)
            return;
        backupProc.environment = { SP_SRC: sp.vaultFile, SP_DIR: dir };
        backupProc.running = true;
    }
    Process {
        id: backupProc
        command: ["bash", "-c", "mkdir -p \"$SP_DIR\" && cp -f \"$SP_SRC\" \"$SP_DIR/vault-$(date +%Y%m%d-%H%M).gpg\" && printf OK || printf FAIL"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim() === "OK") {
                    sp.info = "Encrypted vault copied.";
                    sp.error = "";
                } else {
                    sp.error = "Backup failed.";
                }
            }
        }
    }

    function deleteVault() {
        if (sp.unlocked)
            sp.lock();
        delVaultProc.environment = { SP_DIR: sp.vaultPath };
        delVaultProc.running = true;
    }
    Process {
        id: delVaultProc
        command: ["bash", "-c", "rm -f \"$SP_DIR/vault.gpg\" \"$SP_DIR/vault.gpg.bak\"; true"]
        onRunningChanged: if (!running) sp.probe()
    }
}
