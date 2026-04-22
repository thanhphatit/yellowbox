#!/bin/bash

APP_NAME=$1

if [ -z "$APP_NAME" ]; then
    echo "❌ Please provide an app name. Usage: curl ... | bash -s -- <app_name>"
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

# Define URLs
BASE_URL="https://yellowbox.itblognote.com/bin"
# Lưu ý: Với cicd-manager có nhiều controller, ta mặc định cài k8s-controller hoặc bạn có thể logic thêm
# Ở đây tôi làm logic đơn giản: nếu là folder, tải file trùng tên folder
BINARY_URL="$BASE_URL/$APP_NAME/$TARGET/$APP_NAME"

# Đặc cách cho cicd-manager (vì bạn có nhiều file bên trong)
if [ "$APP_NAME" == "cicd-manager" ]; then
    echo "📦 cicd-manager detected. Installing the full suite..."
    CONTROLLERS=("config-controller" "docker-controller" "helm-controller" "k8s-controller" "release-controller" "terraform-controller")
    for ctrl in "${CONTROLLERS[@]}"; do
        echo "⏬ Downloading $ctrl..."
        curl -L "$BASE_URL/cicd-manager/$TARGET/$ctrl" -o "/usr/local/bin/$ctrl"
        chmod +x "/usr/local/bin/$ctrl"
    done
    echo "✅ cicd-manager suite installed successfully!"
else
    echo "⏬ Downloading $APP_NAME for $TARGET..."
    curl -L "$BINARY_URL" -o "/usr/local/bin/$APP_NAME"
    chmod +x "/usr/local/bin/$APP_NAME"
    echo "✅ $APP_NAME installed successfully to /usr/local/bin/$APP_NAME"
fi