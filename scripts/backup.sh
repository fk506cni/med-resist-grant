#!/bin/bash
#
# バックアップスクリプト
# - 指定フォルダをGoogle Drive（rclone経由）にアップロード
# - 同じ内容をzipにしてローカルの__archivesに保存
#

set -euo pipefail

# ============================================
# 設定
# ============================================

# バックアップ対象フォルダ（プロジェクトルートからの相対パス）
# 複数指定可能
BACKUP_TARGETS=(
    # "Docker"
    "icdo3-to-ci5-mapper"
    "jp-cancer-code-mapping"
    "main"
    "scripts"
    # "dat"
    "docker"
)

# rcloneリモート名
RCLONE_REMOTE="gdrive:"

# Google Drive上の保存先ベースパス（マイドライブからの相対パス）
GDRIVE_BASE_PATH="tmp"

# ============================================
# 変数設定
# ============================================

# スクリプトのディレクトリを取得
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# プロジェクトルート（scriptsフォルダの親ディレクトリ）
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# プロジェクト名（ディレクトリ名）
PROJECT_NAME="$(basename "$PROJECT_ROOT")"

# ローカルアーカイブ保存先
LOCAL_ARCHIVE_DIR="${PROJECT_ROOT}/__archives"

# タイムスタンプ（YYYYMMDD_HHMMSS形式）
TIMESTAMP="$(date '+%Y%m%d_%H%M%S')"

# Google Drive上の保存先フォルダ
GDRIVE_DEST="${RCLONE_REMOTE}${GDRIVE_BASE_PATH}/${PROJECT_NAME}"

# ============================================
# 関数
# ============================================

log_info() {
    echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') $1"
}

log_error() {
    echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') $1" >&2
}

# Google Drive上にフォルダが存在するか確認し、なければ作成
ensure_gdrive_folder() {
    local folder_path="$1"

    log_info "Google Driveフォルダを確認中: ${folder_path}"

    # rclone mkdirはフォルダが存在しても問題なく動作する
    if rclone mkdir "${folder_path}"; then
        log_info "フォルダ準備完了: ${folder_path}"
    else
        log_error "フォルダの作成に失敗: ${folder_path}"
        return 1
    fi
}

# フォルダをGoogle Driveにアップロード
upload_folder() {
    local target_name="$1"
    local source_path="${PROJECT_ROOT}/${target_name}"
    local backup_name="${target_name}_${TIMESTAMP}"
    local gdrive_dest_folder="${GDRIVE_DEST}/${backup_name}"

    # ソースフォルダの存在確認
    if [[ ! -d "$source_path" ]]; then
        log_error "バックアップ対象が存在しません: ${source_path}"
        return 1
    fi

    log_info "=== アップロード開始: ${target_name} ==="

    log_info "Google Driveにアップロード中: ${gdrive_dest_folder}"
    rclone copy "$source_path" "$gdrive_dest_folder" --progress
    log_info "Google Driveアップロード完了: ${gdrive_dest_folder}"

    log_info "=== アップロード完了: ${target_name} ==="
}

# ============================================
# メイン処理
# ============================================

main() {
    log_info "バックアップ処理を開始します"
    log_info "プロジェクト: ${PROJECT_NAME}"
    log_info "タイムスタンプ: ${TIMESTAMP}"

    # ローカルアーカイブディレクトリの作成
    if [[ ! -d "$LOCAL_ARCHIVE_DIR" ]]; then
        log_info "ローカルアーカイブディレクトリを作成: ${LOCAL_ARCHIVE_DIR}"
        mkdir -p "$LOCAL_ARCHIVE_DIR"
    fi

    # Google Driveの保存先フォルダを確認・作成
    ensure_gdrive_folder "$GDRIVE_DEST"

    # バックアップ成功/失敗カウント
    local success_count=0
    local fail_count=0

    # アップロード成功したフォルダを記録
    local uploaded_targets=()

    # 各対象フォルダをアップロード
    for target in "${BACKUP_TARGETS[@]}"; do
        if upload_folder "$target"; then
            ((++success_count))
            uploaded_targets+=("$target")
        else
            ((++fail_count))
        fi
    done

    # アップロード成功したフォルダをまとめてzip化
    if [[ ${#uploaded_targets[@]} -gt 0 ]]; then
        local zip_file="${LOCAL_ARCHIVE_DIR}/${PROJECT_NAME}_${TIMESTAMP}.zip"
        log_info "=== ローカルアーカイブ作成 ==="
        log_info "zipアーカイブを作成中: ${zip_file}"
        (cd "$PROJECT_ROOT" && zip -r "$zip_file" "${uploaded_targets[@]}" -x "*.DS_Store" -x "*__pycache__*")
        log_info "zipアーカイブ作成完了: ${zip_file}"
    fi

    # 結果サマリー
    log_info "========================================"
    log_info "バックアップ処理完了"
    log_info "成功: ${success_count} / 失敗: ${fail_count}"
    log_info "========================================"

    if [[ $fail_count -gt 0 ]]; then
        return 1
    fi
}

# スクリプト実行
main "$@"
