#!/bin/bash
# scripts/uninstall.sh

APP_NAME=$1
SPECIFIC_FILE=$2

if [ -z "$APP_NAME" ]; then
    echo "❌ Usage: curl -sSL https://yellowbox.itblognote.com/scripts/uninstall.sh | bash -s -- <app_name> [specific_file]"
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

# Phân tích JSON để biết chính xác cần xóa những file nào
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
    echo "❌ Tool '$APP_NAME' (or file '$SPECIFIC_FILE') not found in repository."
    exit 1
fi

echo "🧹 Uninstalling $APP_NAME..."
REMOVED_COUNT=0

for FILE in $FILES; do
    # 1. Kiểm tra và xóa ở thư mục Local (~/.local/bin)
    LOCAL_PATH="$HOME/.local/bin/$FILE"
    if [ -f "$LOCAL_PATH" ]; then
        rm "$LOCAL_PATH"
        echo "   🗑️  Removed: $LOCAL_PATH"
        REMOVED_COUNT=$((REMOVED_COUNT + 1))
    fi

    # 2. Kiểm tra và xóa ở thư mục System (/usr/local/bin)
    SYSTEM_PATH="/usr/local/bin/$FILE"
    if [ -f "$SYSTEM_PATH" ]; then
        if [ -w "/usr/local/bin" ]; then
            rm "$SYSTEM_PATH"
        else
            echo "   (Sudo required to remove $SYSTEM_PATH)"
            sudo rm "$SYSTEM_PATH"
        fi
        echo "   🗑️  Removed: $SYSTEM_PATH"
        REMOVED_COUNT=$((REMOVED_COUNT + 1))
    fi
done

if [ $REMOVED_COUNT -eq 0 ]; then
    echo "⚠️  Could not find any installed files for '$APP_NAME' on this system."
else
    echo "✅ $APP_NAME uninstalled successfully!"
fi