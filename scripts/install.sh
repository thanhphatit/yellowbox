#!/bin/bash
OS_TYPE=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH_TYPE=$(uname -m)

if [[ "$OS_TYPE" == "darwin" && "$ARCH_TYPE" == "arm64" ]]; then
    TARGET="darwin-arm64"
elif [[ "$OS_TYPE" == "linux" ]]; then
    TARGET="linux-amd64"
else
    echo "Hệ điều hành chưa được hỗ trợ."
    exit 1
fi

# Trỏ về tên miền xịn của bạn
URL="https://yellowbox.itblognote.com/bin/cicd-manager/$TARGET/cicd-manager"
curl -L $URL -o /usr/local/bin/cicd-manager
chmod +x /usr/local/bin/cicd-manager
echo "Cài đặt thành công cicd-manager!"