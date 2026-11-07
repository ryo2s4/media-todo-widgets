#!/usr/bin/env bash
set -e

# One-shot installer for the media, todo and calendar Quickshell widgets.
# Works either from a local clone (bash install.sh) or by piping the raw file.

REPO="https://github.com/ryo2s4/media-todo-widgets.git"
INSTALL_DIR="$HOME/.config/quickshell"
BIN_DIR="$HOME/.local/bin"
HYPR_USER="$HOME/.config/hypr/user.lua"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

echo "=== media + todo + calendar widgets ==="
echo ""

# ── dependencies ─────────────────────────────────────────────────────────────
echo "[*] Checking dependencies..."
need=()
for c in qs git curl; do
    command -v "$c" >/dev/null 2>&1 || need+=("$c")
done
if [ ${#need[@]} -gt 0 ]; then
    echo "[*] Missing: ${need[*]} (trying to install)"
    if command -v pacman >/dev/null 2>&1; then
        sudo pacman -S --needed --noconfirm quickshell-git curl gpg zenity yad kdialog wmctrl 2>/dev/null \
            || sudo pacman -S --needed --noconfirm quickshell curl gpg zenity yad kdialog wmctrl 2>/dev/null \
            || true
    elif command -v apt >/dev/null 2>&1; then
        sudo apt update 2>/dev/null || true
        sudo apt install -y quickshell curl gnupg zenity yad kdialog wmctrl 2>/dev/null || true
    elif command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y quickshell curl gnupg2 zenity yad kdialog wmctrl 2>/dev/null || true
    fi
fi
if ! command -v qs >/dev/null 2>&1; then
    echo "[!] quickshell (qs) is still missing. Install it, then run this again."
    exit 1
fi

mkdir -p "$INSTALL_DIR" "$BIN_DIR"

# ── source tree ──────────────────────────────────────────────────────────────
SRC_DIR=""
if [ -n "${BASH_SOURCE[0]:-}" ]; then
    HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || true)"
    if [ -n "$HERE" ] && [ -d "$HERE/todo" ] && [ -d "$HERE/media" ] && [ -d "$HERE/calendar" ]; then
        SRC_DIR="$HERE"
    fi
fi
if [ -z "$SRC_DIR" ]; then
    echo "[*] Downloading from $REPO..."
    if git clone --depth 1 "$REPO" "$TMP_DIR/repo" 2>/dev/null; then
        SRC_DIR="$TMP_DIR/repo"
    else
        echo "[!] Could not clone the repo."
        exit 1
    fi
fi
echo "[*] Using files from $SRC_DIR"

# ── install one widget without touching its data ─────────────────────────────
install_widget() {
    local name="$1"
    local src="$SRC_DIR/$name"
    local dst="$INSTALL_DIR/$name"
    [ -d "$src" ] || return 0

    echo "[*] Installing $name..."
    mkdir -p "$dst"
    local keep="$TMP_DIR/keep-$name"
    mkdir -p "$keep"

    # preserve anything the widget has written for this user
    local f
    for f in tasks.json state.json status.json settings.json special.json \
             library.json favorites.json notifs.json notifications.json \
             note.txt cava.conf weather.json; do
        [ -f "$dst/$f" ] && cp -a "$dst/$f" "$keep/$f"
    done
    [ -d "$dst/backups" ] && cp -a "$dst/backups" "$keep/backups"

    cp -a "$src/." "$dst/"

    for f in tasks.json state.json status.json settings.json special.json \
             library.json favorites.json notifs.json notifications.json \
             note.txt cava.conf weather.json; do
        [ -f "$keep/$f" ] && cp -a "$keep/$f" "$dst/$f"
    done
    if [ -d "$keep/backups" ]; then
        mkdir -p "$dst/backups"
        cp -a "$keep/backups/." "$dst/backups/"
    fi
}

install_widget todo
install_widget media
install_widget calendar

# ── launchers ────────────────────────────────────────────────────────────────
echo "[*] Installing launchers..."
cat > "$BIN_DIR/media-toggle" << 'EOF'
#!/usr/bin/env bash
# Toggle the media panel in place. Killing it here made every shortcut press
# pay the full Quickshell startup cost.
if pgrep -f '^qs -c media$' >/dev/null 2>&1; then
    qs -c media ipc call media toggle >/dev/null 2>&1
    exit 0
fi

# Cold start (login or crash): start detached and wait for the IPC socket.
setsid qs -c media >/dev/null 2>&1 < /dev/null &
for _ in $(seq 1 50); do
    if qs -c media ipc show >/dev/null 2>&1; then
        qs -c media ipc call media toggle >/dev/null 2>&1
        exit 0
    fi
    sleep 0.1
done
exit 1
EOF
cat > "$BIN_DIR/calendar-toggle" << 'EOF'
#!/usr/bin/env bash
if ! pgrep -f '^qs -c calendar' >/dev/null 2>&1; then
    qs -c calendar >/dev/null 2>&1 &
    sleep 0.8
fi
qs -c calendar ipc call calendar toggle >/dev/null 2>&1
EOF
chmod +x "$BIN_DIR/media-toggle" "$BIN_DIR/calendar-toggle"

# ── Hyprland startup + keybinds ──────────────────────────────────────────────
echo "[*] Setting up Hyprland startup and keybinds..."
mkdir -p "$(dirname "$HYPR_USER")"
if [ ! -f "$HYPR_USER" ]; then
    cat > "$HYPR_USER" << 'EOF'
-- Ryoku user overrides (loaded last). Edit freely; survives updates.
local hl = require("hyprland")

-- media + todo + calendar
hl.on("hyprland.start", function()
    hl.exec_cmd("qs -c todo &")
    hl.exec_cmd("qs -c media &")
    hl.exec_cmd("qs -c calendar &")
end)
hl.bind("SUPER + S", hl.dsp.exec_cmd("qs -c todo ipc call todo toggle"))
hl.bind("SUPER + M", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.local/bin/media-toggle"))
hl.bind("SUPER + G", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.local/bin/media-toggle"))
hl.bind("SUPER + C", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.local/bin/calendar-toggle"))
EOF
else
    add_block=0
    startup_lines=""
    for w in todo media calendar; do
        if ! grep -q "qs -c $w &" "$HYPR_USER"; then
            startup_lines="${startup_lines}    hl.exec_cmd(\"qs -c $w &\")\n"
        fi
    done
    if [ -n "$startup_lines" ]; then
        {
            echo ""
            echo "-- widget startup (added by the installer)"
            echo 'local hl = require("hyprland")'
            echo 'hl.on("hyprland.start", function()'
            printf '%b' "$startup_lines"
            echo 'end)'
        } >> "$HYPR_USER"
        add_block=1
    fi
    if ! grep -q 'SUPER + S' "$HYPR_USER"; then
        cat >> "$HYPR_USER" << 'EOF'
hl.bind("SUPER + S", hl.dsp.exec_cmd("qs -c todo ipc call todo toggle"))
EOF
        add_block=1
    fi
    if ! grep -q 'SUPER + M' "$HYPR_USER"; then
        cat >> "$HYPR_USER" << 'EOF'
hl.bind("SUPER + M", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.local/bin/media-toggle"))
EOF
        add_block=1
    fi
    if ! grep -q 'SUPER + G' "$HYPR_USER"; then
        cat >> "$HYPR_USER" << 'EOF'
hl.bind("SUPER + G", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.local/bin/media-toggle"))
EOF
        add_block=1
    fi
    # Older installs used SUPER + ALT + C for the calendar. Move that one
    # calendar line to the new shortcut without touching other ALT+C binds.
    if grep -q 'SUPER + ALT + C.*calendar-toggle' "$HYPR_USER"; then
        sed -i 's/SUPER + ALT + C\(.*calendar-toggle\)/SUPER + C\1/' "$HYPR_USER"
        add_block=1
    fi
    if ! grep -q 'SUPER + C.*calendar-toggle' "$HYPR_USER"; then
        cat >> "$HYPR_USER" << 'EOF'
hl.bind("SUPER + C", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.local/bin/calendar-toggle"))
EOF
        add_block=1
    fi
    if [ "$add_block" = 1 ]; then
        echo "[*] Added the missing startup/keybinds to $HYPR_USER"
    else
        echo "[*] Startup and keybinds already present"
    fi
fi

# On Ryoku, SUPER + C also opens the center window. Move that single stock
# chord out of the calendar's way. Leave a user's existing remap alone.
if command -v ryoku-hub >/dev/null 2>&1 \
    && ! grep -q '\["SUPER + C"\]' "$HOME/.config/hypr/rebinds.lua" 2>/dev/null; then
    ryoku-hub desktop set-rebind "SUPER + C" "SUPER + ALT + C" >/dev/null 2>&1 || true
fi

# ── start fresh ──────────────────────────────────────────────────────────────
echo "[*] Starting services..."
pkill -f '^qs -c todo' 2>/dev/null || true
pkill -f '^qs -c media' 2>/dev/null || true
pkill -f '^qs -c calendar' 2>/dev/null || true
sleep 1
nohup qs -c todo >/dev/null 2>&1 &
nohup qs -c media >/dev/null 2>&1 &
nohup qs -c calendar >/dev/null 2>&1 &
sleep 1

echo ""
echo "=== Done ==="
echo ""
echo "  SUPER + S        todo"
echo "  SUPER + M / G    media"
echo "  SUPER + C        calendar"
echo ""
echo "Configs: $INSTALL_DIR/{todo,media,calendar}"
echo "Launchers: $BIN_DIR/{media,calendar}-toggle"
echo ""
echo "If Hyprland does not see the new binds yet, run: hyprctl reload"
