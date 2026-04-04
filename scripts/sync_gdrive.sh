#!/usr/bin/env bash
# sync_gdrive.sh — Google Driveとの出力ファイル同期
#
# Usage:
#   ./scripts/sync_gdrive.sh [OPTIONS]
#
# Options:
#   --push      docx/xlsxをGoogle Driveにアップロード（デフォルト）
#   --pull      PDFをGoogle Driveからダウンロード
#   --dry-run   転送内容の確認のみ（実際には転送しない）
#   -h, --help  ヘルプ表示
#
# 環境変数:
#   GDRIVE_REMOTE  rcloneリモート名 (default: gdrive:)
#   GDRIVE_PATH    Google Drive上のパス (default: tmp/med-resist-grant)

set -euo pipefail

# --- プロジェクトルート ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

# --- 設定 ---
GDRIVE_REMOTE="${GDRIVE_REMOTE:-gdrive:}"
GDRIVE_PATH="${GDRIVE_PATH:-tmp/med-resist-grant}"
GDRIVE_DEST="${GDRIVE_REMOTE}${GDRIVE_PATH}"

OUTPUT_DIRS=(
    "main/step02_docx/output"
    "main/step03_excel/output"
)
PDF_LOCAL_DIR="data/products"

# --- フラグ ---
ACTION="push"
DRY_RUN=""

# --- ヘルパー ---
log_info()  { echo "[INFO]  $(date '+%H:%M:%S') $1"; }
log_error() { echo "[ERROR] $(date '+%H:%M:%S') $1" >&2; }
log_ok()    { echo "[OK]    $(date '+%H:%M:%S') $1"; }

# --- 引数解析 ---
while [[ $# -gt 0 ]]; do
    case $1 in
        --push)    ACTION="push"; shift ;;
        --pull)    ACTION="pull"; shift ;;
        --dry-run) DRY_RUN="--dry-run"; shift ;;
        -h|--help)
            head -16 "$0" | tail -15
            exit 0
            ;;
        *)
            log_error "不明なオプション: $1"
            exit 1
            ;;
    esac
done

# --- rclone 確認 ---
if ! command -v rclone &>/dev/null; then
    log_error "rclone がインストールされていません"
    exit 1
fi

# リモート接続テスト（aboutで認証のみ確認、ファイルリストなし）
if ! timeout 10 rclone about "$GDRIVE_REMOTE" &>/dev/null; then
    log_error "rclone リモート '$GDRIVE_REMOTE' に接続できません"
    log_error "  rclone config reconnect ${GDRIVE_REMOTE} を実行してください"
    exit 1
fi

# --- Push ---
push_files() {
    log_info "Push: 出力ファイルを $GDRIVE_DEST にアップロード"
    [[ -n "$DRY_RUN" ]] && log_info "(dry-run モード)"
    echo ""

    local count=0
    rclone mkdir "$GDRIVE_DEST" 2>/dev/null || true

    for dir in "${OUTPUT_DIRS[@]}"; do
        if [[ ! -d "$dir" ]]; then
            log_info "SKIP: $dir が存在しません"
            continue
        fi

        # docx と xlsx を転送
        local has_files=false
        for ext in docx xlsx; do
            for f in "$dir"/*."$ext"; do
                [[ -f "$f" ]] && has_files=true && break
            done
        done

        if [[ "$has_files" == false ]]; then
            log_info "SKIP: $dir に対象ファイルがありません"
            continue
        fi

        log_info "Uploading from $dir ..."
        rclone copy "$dir" "$GDRIVE_DEST" \
            --include "*.docx" \
            --include "*.xlsx" \
            --stats-one-line -v \
            $DRY_RUN

        count=$((count + 1))
    done

    echo ""
    if [[ -n "$DRY_RUN" ]]; then
        log_info "dry-run 完了（実際の転送は行われていません）"
    else
        log_ok "Push 完了 → $GDRIVE_DEST"
        # リモート側のファイル一覧
        echo ""
        log_info "Google Drive ファイル一覧:"
        timeout 15 rclone ls "$GDRIVE_DEST" 2>/dev/null | while read -r size name; do
            printf "  %8s  %s\n" "$(numfmt --to=iec "$size" 2>/dev/null || echo "${size}B")" "$name"
        done || log_info "(ファイルなし)"
    fi
}

# --- Pull ---
pull_pdfs() {
    log_info "Pull: PDFを $GDRIVE_DEST/products からダウンロード"
    [[ -n "$DRY_RUN" ]] && log_info "(dry-run モード)"
    echo ""

    mkdir -p "$PDF_LOCAL_DIR"

    # リモート側のPDF確認
    local pdf_count
    pdf_count=$(timeout 15 rclone lsf "$GDRIVE_DEST/products" --include "*.pdf" --max-depth 1 --files-only 2>/dev/null | wc -l || echo 0)
    if [[ "$pdf_count" -eq 0 ]]; then
        log_info "Google Drive にPDFファイルがありません"
        log_info "Windows側でのPDF変換が完了していることを確認してください"
        return
    fi

    log_info "$pdf_count 個のPDFを検出"
    rclone copy "$GDRIVE_DEST/products" "$PDF_LOCAL_DIR" \
        --max-depth 1 \
        --filter "+ *.pdf" \
        --filter "- *" \
        --stats-one-line -v \
        $DRY_RUN

    echo ""
    if [[ -n "$DRY_RUN" ]]; then
        log_info "dry-run 完了"
    else
        log_ok "Pull 完了 → $PDF_LOCAL_DIR/"
        echo ""
        log_info "ダウンロードしたPDF:"
        for f in "$PDF_LOCAL_DIR"/*.pdf; do
            [[ -f "$f" ]] && printf "  %-50s %s\n" "$f" "$(du -h "$f" | cut -f1)"
        done

        # Google Drive上のPDFを__archives/にタイムスタンプ付きで移動
        echo ""
        local archive_ts
        archive_ts="$(date '+%Y%m%d_%H%M%S')"
        local gdrive_archive="$GDRIVE_DEST/products/__archives"

        log_info "Google Drive上のPDFを __archives/ に退避..."
        rclone mkdir "$gdrive_archive" 2>/dev/null || true

        local pdf_list
        pdf_list=$(timeout 15 rclone lsf "$GDRIVE_DEST/products" --include "*.pdf" --max-depth 1 --files-only 2>/dev/null || true)
        for pdf_name in $pdf_list; do
            local base="${pdf_name%.pdf}"
            local archived_name="${base}_${archive_ts}.pdf"
            timeout 30 rclone moveto \
                "$GDRIVE_DEST/products/$pdf_name" \
                "$gdrive_archive/$archived_name" \
                -v 2>&1 || true
            log_info "  $pdf_name → __archives/$archived_name"
        done
    fi
}

# --- メイン ---
case "$ACTION" in
    push) push_files ;;
    pull) pull_pdfs ;;
esac
