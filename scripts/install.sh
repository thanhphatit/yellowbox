#!/bin/bash

APP_NAME=$1
SPECIFIC_FILE=$2

if [ -z "$APP_NAME" ]; then
    echo "❌ Usage: curl -sSL https://yellowbox.itblognote.com/scripts/install.sh | bash -s -- <app_name> [specific_file]"
    exit 1
fi

# Detect OS/Arch
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)
[ "$OS" == "darwin" ] && [ "$ARCH" == "arm64" ] && TARGET="darwin-arm64"
[ "$OS" == "linux" ] && TARGET="linux-amd64"

if [ -z "$TARGET" ]; then
    echo "❌ Unsupported platform: $OS-$ARCH"
    exit 1
fi

BASE_URL="https://yellowbox.itblognote.com/bin"
MANIFEST=$(curl -sSL "$BASE_URL/manifest.json")

# Phân tích JSON bằng Python
FILES=$(python3 -c "
import json, os
try:
    data = json.loads('''$MANIFEST''')
    app = '$APP_NAME'
    target = '$TARGET'
    req_file = '$SPECIFIC_FILE'
    for t in data.get('tools', []):
        if t['name'] == app:
            available = t['platforms'].get(target, [])
            if req_file:
                if req_file in available: print(req_file)
            else:
                for f in available: print(f)
except: pass
")

if [ -z "$FILES" ]; then
    echo "❌ Tool '$APP_NAME' (or file '$SPECIFIC_FILE') not found for $TARGET."
    exit 1
fi

# --- LOGIC CÀI ĐẶT THÔNG MINH (SUDO vs NORMAL) ---
if [ "$(id -u)" -eq 0 ]; then
    # Người dùng chạy bằng: sudo curl ... | sudo bash -s -- ...
    INSTALL_DIR="/usr/local/bin"
    echo "🛡️ Root privileges detected. Installing system-wide to $INSTALL_DIR..."
else
    # Người dùng chạy lệnh bình thường
    INSTALL_DIR="$HOME/.local/bin"
    echo "👤 Normal user detected. Installing locally to $INSTALL_DIR..."
    # Tạo thư mục nếu chưa có
    mkdir -p "$INSTALL_DIR"
fi

# Tải file
echo "📦 Installing $APP_NAME..."
for FILE in $FILES; do
    echo "⏬ Fetching $FILE..."
    URL="$BASE_URL/$APP_NAME/$TARGET/$FILE"
    
    curl -sSL "$URL" -o "$INSTALL_DIR/$FILE"
    chmod +x "$INSTALL_DIR/$FILE"
done

echo "✅ Done!"

# --- KIỂM TRA ĐƯỜNG DẪN MÔI TRƯỜNG ---
if [ "$(id -u)" -ne 0 ]; then
    if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
        echo ""
        echo "⚠️  WARNING: $INSTALL_DIR is not in your PATH."
        echo "   To run the tools from anywhere, please add this line to your ~/.bashrc or ~/.zshrc:"
        echo "   export PATH=\"\$HOME/.local/bin:\$PATH\""
    fi
fi