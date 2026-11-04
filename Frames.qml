import QtQuick
import Quickshell
import Quickshell.Io

// Frames.qml: the profile picture frames.
// Files live in ~/.config/quickshell/media/frames/ and are listed in frames.json:
//   { id, name, file, kind: "ring" | "anim" | "sticker", hole, cx, cy, gif? }
// hole = diameter of the empty middle as a fraction of the image width, cx / cy = where
// its centre is. "anim" frames are animated WebP files with a GIF as fallback.
// A frame of your own (Settings > Profile) is added as the id "custom".
Scope {
    id: fr

    property var cfg
    property var list: []

    readonly property string dir: Quickshell.env("HOME") + "/.config/quickshell/media/frames"

    FileView {
        id: listFile
        path: fr.dir + "/frames.json"
        onLoaded: {
            try {
                var s = JSON.parse(listFile.text());
                fr.list = s.frames || [];
            } catch (e) {
                console.log("media: could not read frames.json:", e);
            }
        }
    }

    // every choice, including your own frame
    readonly property var all: {
        var out = list.slice();
        if (cfg && cfg.customFramePath !== "")
            out.push({ id: "custom", name: "Your frame", abs: cfg.customFramePath, kind: "ring",
                       hole: cfg.customFrameHole, cx: 0.5, cy: 0.5 });
        return out;
    }

    function get(id) {
        for (var i = 0; i < all.length; i++)
            if (all[i].id === id)
                return all[i];
        return null;
    }

    function fileUrl(def) {
        if (!def)
            return "";
        return def.abs ? "file://" + def.abs : "file://" + dir + "/" + def.file;
    }

    function gifUrl(def) {
        return (def && def.gif) ? "file://" + dir + "/" + def.gif : "";
    }

    // none -> first frame -> ... -> last frame -> none
    function nextId(cur) {
        var ids = [""];
        for (var i = 0; i < all.length; i++)
            ids.push(all[i].id);
        var at = ids.indexOf(cur);
        return ids[(at + 1) % ids.length];
    }
}
