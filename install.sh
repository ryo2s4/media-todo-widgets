#!/usr/bin/env bash
set -e

REPO="https://github.com/ryo2s4/media-todo-widgets.git"
INSTALL_DIR="$HOME/.config/quickshell"
BIN_DIR="$HOME/.local/bin"
HYPR_USER="$HOME/.config/hypr/user.lua"

echo "=== Media + Todo Installer ==="
echo ""

# Install dependencies
echo "[*] Installing dependencies..."
if command -v pacman >/dev/null 2>&1; then
    sudo pacman -S --needed --noconfirm quickshell-git gpg zenity yad kdialog wmctrl 2>/dev/null || sudo pacman -S --needed --noconfirm quickshell gpg zenity yad kdialog wmctrl 2>/dev/null || true
elif command -v apt >/dev/null 2>&1; then
    sudo apt install -y quickshell gnupg zenity yad kdialog wmctrl 2>/dev/null || true
elif command -v dnf >/dev/null 2>&1; then
    sudo dnf install -y quickshell gnupg2 zenity yad kdialog wmctrl 2>/dev/null || true
fi

# Create dirs
mkdir -p "$INSTALL_DIR" "$BIN_DIR"

# Clone or update repo
TMP_DIR=$(mktemp -d)
echo "[*] Downloading from $REPO..."
if git clone --depth 1 "$REPO" "$TMP_DIR/repo" 2>/dev/null; then
    echo "[*] Cloned successfully"
else
    echo "[!] Failed to clone repo, trying to use local copy..."
    cp -r "$HOME/.config/quickshell/todo" "$TMP_DIR/repo/todo" 2>/dev/null || true
    cp -r "$HOME/.config/quickshell/media" "$TMP_DIR/repo/media" 2>/dev/null || true
fi

# Install todo
if [ -d "$TMP_DIR/repo/todo" ]; then
    echo "[*] Installing todo..."
    rm -rf "$INSTALL_DIR/todo"
    cp -r "$TMP_DIR/repo/todo" "$INSTALL_DIR/todo"
fi

# Install media
if [ -d "$TMP_DIR/repo/media" ]; then
    echo "[*] Installing media..."
    rm -rf "$INSTALL_DIR/media"
    cp -r "$TMP_DIR/repo/media" "$INSTALL_DIR/media"
    # Remove git history
    rm -rf "$INSTALL_DIR/media/.git"
fi

rm -rf "$TMP_DIR"

# Install media-toggle script
echo "[*] Installing media-toggle..."
cat > "$BIN_DIR/media-toggle" << 'EOF'
#!/usr/bin/env bash
# kill any stuck instances
pkill -f "qs -c media" 2>/dev/null
sleep 0.3
# start fresh if not running
if ! pgrep -f "qs -c media" >/dev/null 2>&1; then
  qs -c media >/dev/null 2>&1 &
  sleep 1
fi
# toggle
qs -c media ipc call media toggle >/dev/null 2>&1
EOF
chmod +x "$BIN_DIR/media-toggle"

# Add to PATH if not present
if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.zshrc" 2>/dev/null || true
fi

# Setup Hyprland keybinds
echo "[*] Setting up Hyprland keybinds..."
mkdir -p "$(dirname "$HYPR_USER")"

# Create or append to user.lua
if [ ! -f "$HYPR_USER" ]; then
    cat > "$HYPR_USER" << 'EOF'
local hl = require("hyprland")

-- Auto-start todo and media
hl.on("hyprland.start", function()
    hl.exec_cmd("qs -c todo &")
    hl.exec_cmd("qs -c media &")
end)

-- Keybinds
hl.bind("SUPER + S", hl.dsp.exec_cmd("qs -c todo ipc call todo toggle"))
hl.bind("SUPER + M", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.local/bin/media-toggle"))
hl.bind("SUPER + G", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.local/bin/media-toggle"))
EOF
    echo "[*] Created $HYPR_USER with keybinds"
else
    # Check if keybinds already exist
    if ! grep -q "qs -c todo ipc call todo toggle" "$HYPR_USER"; then
        cat >> "$HYPR_USER" << 'EOF'

-- Media + Todo keybinds (added by installer)
local hl = require("hyprland")
hl.bind("SUPER + S", hl.dsp.exec_cmd("qs -c todo ipc call todo toggle"))
hl.bind("SUPER + M", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.local/bin/media-toggle"))
hl.bind("SUPER + G", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.local/bin/media-toggle"))
EOF
        echo "[*] Added keybinds to existing $HYPR_USER"
    else
        echo "[*] Keybinds already present"
    fi
fi

# Start services
echo "[*] Starting services..."
pkill -f "qs -c todo" 2>/dev/null || true
pkill -f "qs -c media" 2>/dev/null || true
sleep 1
qs -c todo >/dev/null 2>&1 &
qs -c media >/dev/null 2>&1 &

echo ""
echo "=== Installation Complete ==="
echo ""
echo "Keybinds:"
echo "  SUPER + S  -> Toggle Todo"
echo "  SUPER + M  -> Toggle Media"
echo "  SUPER + G  -> Toggle Media"
echo ""
echo "Configs installed to:"
echo "  $INSTALL_DIR/todo"
echo "  $INSTALL_DIR/media"
echo ""
echo "Media toggle script: $BIN_DIR/media-toggle"
echo ""
