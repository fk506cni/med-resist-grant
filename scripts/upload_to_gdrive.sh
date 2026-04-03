#!/bin/bash

# Google Driveアップロードスクリプト
# rcloneを使用してcancer_claims_validation_package_*.zipをGoogle Driveにアップロード

# 設定
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
PROJECT_NAME="$(basename "$PROJECT_ROOT")"
GDRIVE_REMOTE="gdrive"  # rcloneで設定したリモート名
GDRIVE_FOLDER="tmp/${PROJECT_NAME}"  # アップロード先（マイドライブ/tmp/{project_name}/）
OUTPUT_DIR="/tmp/${PROJECT_NAME}"

# 最新のzipファイルを検索（/tmp/{project_name}/から）
LATEST_ZIP=$(ls -t "${OUTPUT_DIR}"/cancer_claims_validation_package_*.zip 2>/dev/null | head -n 1)

if [ -z "$LATEST_ZIP" ]; then
    echo "Error: cancer_claims_validation_package_*.zip ファイルが見つかりません"
    echo "先に create_package.sh を実行してください"
    exit 1
fi

echo "アップロード対象: $(basename "$LATEST_ZIP")"
echo "アップロード先: ${GDRIVE_REMOTE}:${GDRIVE_FOLDER}"

# rcloneでアップロード
rclone copy "$LATEST_ZIP" "${GDRIVE_REMOTE}:${GDRIVE_FOLDER}" --progress

if [ $? -eq 0 ]; then
    echo "✓ アップロード完了: $(basename "$LATEST_ZIP")"
else
    echo "✗ アップロード失敗"
    exit 1
fi
