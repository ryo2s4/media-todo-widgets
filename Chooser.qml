import QtQuick
import Quickshell
import Quickshell.Io

// Chooser.qml: "Browse..." for image paths. Uses whichever of zenity, kdialog or
// yad is installed. Call open("avatarPath") and listen for picked(target, path).
Scope {
    id: ch

    property string target: ""
    property string error: ""
    property string mode: "image"          // "image" | "dir"
    signal picked(string target, string path)

    readonly property string imageScript: "f=$(zenity --file-selection --title='Choose an image' --filename=\"$HOME/Pictures/\" --file-filter='Images | *.png *.jpg *.jpeg *.webp *.gif *.bmp *.apng' 2>/dev/null) || f=$(kdialog --getopenfilename \"$HOME/Pictures\" 'image/*' 2>/dev/null) || f=$(yad --file --title='Choose an image' 2>/dev/null); if [ -n \"$f\" ]; then echo \"$f\"; elif ! command -v zenity >/dev/null 2>&1 && ! command -v kdialog >/dev/null 2>&1 && ! command -v yad >/dev/null 2>&1; then echo NOCHOOSER; fi"

    readonly property string dirScript: "f=$(zenity --file-selection --directory --title='Choose a folder' --filename=\"$HOME/\" 2>/dev/null) || f=$(kdialog --getexistingdirectory \"$HOME\" 2>/dev/null) || f=$(yad --file --directory --title='Choose a folder' 2>/dev/null); if [ -n \"$f\" ]; then echo \"$f\"; elif ! command -v zenity >/dev/null 2>&1 && ! command -v kdialog >/dev/null 2>&1 && ! command -v yad >/dev/null 2>&1; then echo NOCHOOSER; fi"

    readonly property string script: mode === "dir" ? dirScript : imageScript

    Process {
        id: proc
        command: ["sh", "-c", ch.script]
        stdout: StdioCollector {
            onStreamFinished: {
                var out = text.trim();
                if (out === "NOCHOOSER")
                    ch.error = "No file chooser found. Install zenity, or paste the path by hand.";
                else if (out !== "")
                    ch.picked(ch.target, out);
            }
        }
    }

    function open(t) {
        if (proc.running)
            return;
        target = t;
        mode = "image";
        error = "";
        proc.running = true;
    }

    function openDir(t) {
        if (proc.running)
            return;
        target = t;
        mode = "dir";
        error = "";
        proc.running = true;
    }
}
