#!/bin/bash

APP_NAME=$1
SPECIFIC_FILE=$2 # Tham số tùy chọn để tải file lẻ

if [ -z "$APP_NAME" ]; then
    echo "❌ Please provide an app name."
    echo "Usage: curl -sSL https://yellowbox.itblognote.com/scripts/install.sh | bash -s -- <app_name> [specific_file]"
    exit 1
fi

# Detect OS and Arch
OS_TYPE=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH_TYPE=$(uname -m)

if [[ "$OS_TYPE" == "darwin" && "$ARCH_TYPE" == "arm64" ]]; then
    TARGET="darwin-arm64"
elif [[ "$OS_TYPE" == "linux" ]]; then
    TARGET="linux-amd64"
else
    echo "❌ Unsupported OS/Architecture: $OS_TYPE $ARCH_TYPE"
    exit 1
fi

BASE_URL="https://yellowbox.itblognote.com/bin"
MANIFEST_URL="$BASE_URL/manifest.json"

echo "🔍 Fetching repository manifest..."

# Tải file manifest.json về bộ nhớ (không lưu ra đĩa)
export MANIFEST_JSON=$(curl -sSL "$MANIFEST_URL")
export REQ_APP="$APP_NAME"
export REQ_TARGET="$TARGET"
export REQ_FILE="$SPECIFIC_FILE"

if [ -z "$MANIFEST_JSON" ] || [ "$MANIFEST_JSON" == "404: Not Found" ]; then
    echo "❌ Failed to download manifest.json. Please ensure GitHub Actions has generated it."
    exit 1
fi

# Dùng Python để phân tích JSON và lấy danh sách file cần cài
# Python được sử dụng vì nó luôn có sẵn trên Linux/macOS thay vì jq
FILES=$(python3 -c '
import os, json, sys
try:
    data = json.loads(os.environ["MANIFEST_JSON"])
    app_name = os.environ["REQ_APP"]
    target = os.environ["REQ_TARGET"]
    req_file = os.environ.get("REQ_FILE", "")
    
    for tool in data.get("tools", []):
        if tool.get("name") == app_name:
            files = tool.get("platforms", {}).get(target, [])
            if req_file:
                if req_file in files:
                    print(req_file)
                    sys.exit(0)
                else:
                    sys.exit(2) # Lỗi: Có tool nhưng không có file yêu cầu
            else:
                for f in files:
                    print(f)
                sys.exit(0)
    sys.exit(1) # Lỗi: Không tìm thấy tool
except Exception as e:
    sys.exit(3) # Lỗi parsing
' 2>/dev/null)

RET_CODE=$?

if [ $RET_CODE -eq 1 ]; then
    echo "❌ App '$APP_NAME' not found in the repository."
    exit 1
elif [ $RET_CODE -eq 2 ]; then
    echo "❌ File '$SPECIFIC_FILE' not found in app '$APP_NAME' for $TARGET."
    exit 1
elif [ $RET_CODE -eq 3 ]; then
    echo "❌ Error parsing manifest data."
    exit 1
elif [ -z "$FILES" ]; then
    echo "❌ No binaries found for $APP_NAME on $TARGET."
    exit 1
fi

# Thực hiện vòng lặp tải từng file có trong danh sách
echo "📦 Installing '$APP_NAME' for $TARGET..."

for FILE in $FILES; do
    DOWNLOAD_URL="$BASE_URL/$APP_NAME/$TARGET/$FILE"
    echo "⏬ Downloading $FILE..."
    
    # Kiểm tra quyền root, nếu cần sudo thì thêm vào
    if [ -w "/usr/local/bin" ]; then
        curl -sSL "$DOWNLOAD_URL" -o "/usr/local/bin/$FILE"
        chmod +x "/usr/local/bin/$FILE"
    else
        echo "   (Requesting root permissions to write to /usr/local/bin)"
        sudo curl -sSL "$DOWNLOAD_URL" -o "/usr/local/bin/$FILE"
        sudo chmod +x "/usr/local/bin/$FILE"
    fi
done

echo ""
echo "✅ Successfully installed!"