#!/usr/bin/env bash
# roundtrip.sh — ビルド → Google Drive push → PDF変換待ち → pull の一括実行
#
# Usage:
#   ./scripts/roundtrip.sh [OPTIONS]
#
# Options:
#   --skip-build    ビルドをスキップ（push以降のみ実行）
#   --skip-push     push をスキップ（pull待ちのみ実行）
#   --timeout MIN   PDF待ちタイムアウト（デフォルト: 5分）
#   --poll SEC      ポーリング間隔（デフォルト: 10秒）
#   --dry-run       実際の転送を行わない
#   -h, --help      ヘルプ表示
#
# ディレクトリ:
#   data/output/    ビルド成果物の集約先（docx/xlsx）
#   data/products/  Windows変換済みPDFのダウンロード先

set -euo pipefail

# --- プロジェクトルート ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

# --- 設定 ---
GDRIVE_REMOTE="${GDRIVE_REMOTE:-gdrive:}"
GDRIVE_PATH="${GDRIVE_PATH:-tmp/med-resist-grant}"
GDRIVE_DEST="${GDRIVE_REMOTE}${GDRIVE_PATH}"

OUTPUT_DIR="data/output"
PRODUCTS_DIR="data/products"

# ビルド成果物のソースディレクトリ
BUILD_OUTPUT_DIRS=(
    "main/step02_docx/output"
    "main/step03_excel/output"
)

# --- フラグ ---
SKIP_BUILD=false
SKIP_PUSH=false
TIMEOUT_MIN=5
POLL_SEC=10
DRY_RUN=""

# --- ヘルパー ---
log_info()  { echo "[INFO]  $(date '+%H:%M:%S') $1"; }
log_warn()  { echo "[WARN]  $(date '+%H:%M:%S') $1"; }
log_error() { echo "[ERROR] $(date '+%H:%M:%S') $1" >&2; }
log_ok()    { echo "[OK]    $(date '+%H:%M:%S') $1"; }

separator() { echo "========================================"; }

# M14-05: rclone 呼び出しを retry 付きで実行するヘルパー。
# Google Drive の応答遅延で 1 回の timeout が起きても即中断せず、最大
# $RCLONE_MAX_RETRIES 回まで間隔 $RCLONE_RETRY_SLEEP 秒を置いて再試行する。
# 使用例: rclone_with_retry 60 rclone lsf "${GDRIVE_DEST}/" --max-depth 1
RCLONE_MAX_RETRIES="${RCLONE_MAX_RETRIES:-3}"
RCLONE_RETRY_SLEEP="${RCLONE_RETRY_SLEEP:-5}"
rclone_with_retry() {
    local to="$1"; shift
    local attempt=1
    while :; do
        if timeout "$to" "$@"; then
            return 0
        fi
        local rc=$?
        if [[ $attempt -ge $RCLONE_MAX_RETRIES ]]; then
            return $rc
        fi
        log_warn "rclone 実行失敗 (exit $rc, try $attempt/$RCLONE_MAX_RETRIES)。${RCLONE_RETRY_SLEEP}秒後に再試行します"
        sleep "$RCLONE_RETRY_SLEEP"
        attempt=$((attempt + 1))
    done
}

# --- 引数解析 ---
while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-build)  SKIP_BUILD=true; shift ;;
        --skip-push)   SKIP_PUSH=true; shift ;;
        --timeout)     TIMEOUT_MIN="$2"; shift 2 ;;
        --poll)        POLL_SEC="$2"; shift 2 ;;
        --dry-run)     DRY_RUN="--dry-run"; shift ;;
        -h|--help)
            head -17 "$0" | tail -16
            exit 0
            ;;
        *)
            log_error "不明なオプション: $1"
            exit 1
            ;;
    esac
done

# --- ディレクトリ準備 ---
mkdir -p "$OUTPUT_DIR" "$PRODUCTS_DIR"

# ============================================================
# Phase 1: ビルド
# ============================================================
phase_build() {
    separator
    log_info "Phase 1: ビルド"
    separator
    echo ""

    bash "$SCRIPT_DIR/build.sh"

    echo ""
}

# ============================================================
# Phase 2: 成果物を data/output/ に集約
# ============================================================
phase_collect() {
    separator
    log_info "Phase 2: 成果物集約 → $OUTPUT_DIR/"
    separator
    echo ""

    local count=0
    for dir in "${BUILD_OUTPUT_DIRS[@]}"; do
        if [[ ! -d "$dir" ]]; then continue; fi
        for f in "$dir"/*.docx "$dir"/*.xlsx; do
            if [[ -f "$f" ]]; then
                cp "$f" "$OUTPUT_DIR/"
                count=$((count + 1))
            fi
        done
    done

    log_info "$count ファイルを $OUTPUT_DIR/ に集約"
    for f in "$OUTPUT_DIR"/*.docx "$OUTPUT_DIR"/*.xlsx; do
        [[ -f "$f" ]] && printf "  %-45s %s\n" "$(basename "$f")" "$(du -h "$f" | cut -f1)"
    done
    echo ""
}

# ============================================================
# Phase 3: Google Drive にアップロード
# ============================================================
phase_push() {
    separator
    log_info "Phase 3: Google Drive push → $GDRIVE_DEST"
    separator
    echo ""

    # rclone確認
    if ! command -v rclone &>/dev/null; then
        log_error "rclone がインストールされていません"
        return 1
    fi
    # M14-05: timeout を 15s → 60s に緩和し retry を追加。Google Drive の
    # 応答遅延で一時的に失敗しても自動復帰する。
    if ! rclone_with_retry 60 rclone lsf "${GDRIVE_DEST}/" --max-depth 1 --dirs-only &>/dev/null; then
        log_error "rclone リモート '$GDRIVE_DEST' に接続できません"
        log_error "  rclone config reconnect ${GDRIVE_REMOTE} を実行してください"
        exit 1
    fi

    rclone mkdir "$GDRIVE_DEST" 2>/dev/null || true

    rclone copy "$OUTPUT_DIR" "$GDRIVE_DEST" \
        --include "*.docx" \
        --include "*.xlsx" \
        --stats-one-line -v \
        $DRY_RUN

    if [[ -n "$DRY_RUN" ]]; then
        log_info "(dry-run: 実際のアップロードは行われていません)"
    else
        log_ok "Push 完了"
    fi
    echo ""
}

# ============================================================
# Phase 4: PDF変換待ち → ダウンロード
# ============================================================
phase_wait_and_pull() {
    separator
    log_info "Phase 4: PDF変換待ち（最大 ${TIMEOUT_MIN}分、${POLL_SEC}秒間隔）"
    separator
    echo ""

    if [[ -n "$DRY_RUN" ]]; then
        log_info "(dry-run: PDF待ちをスキップします)"
        echo ""
        return
    fi

    # pushしたdocxの数をカウント（期待されるPDF数）
    local expected_pdfs=0
    for f in "$OUTPUT_DIR"/*.docx; do
        [[ -f "$f" ]] && expected_pdfs=$((expected_pdfs + 1))
    done

    if [[ "$expected_pdfs" -eq 0 ]]; then
        log_warn "docxファイルがありません。PDF待ちをスキップします"
        return
    fi

    log_info "docx $expected_pdfs 個 → PDF $expected_pdfs 個 を待機中..."
    echo ""

    local deadline=$((SECONDS + TIMEOUT_MIN * 60))
    local found_pdfs=0
    local prev_found=0

    while [[ $SECONDS -lt $deadline ]]; do
        # N14-05: timeout を 15s → 60s に緩和。watch-and-convert が一方向に
        # PDF を produce する性質を活用し、found_pdfs を単調増加とする
        # （一時的な空応答で値が drop することによる振動を防ぐ）。
        local _pdf_lines
        _pdf_lines=$(timeout 60 rclone lsf "$GDRIVE_DEST/products" --include "*.pdf" --max-depth 1 --files-only 2>/dev/null) || true
        local _count
        _count=$(echo "$_pdf_lines" | grep -c . || true)
        if [[ "$_count" -gt "$found_pdfs" ]]; then
            found_pdfs=$_count
        fi

        if [[ "$found_pdfs" -ne "$prev_found" ]]; then
            log_info "PDF検出: $found_pdfs / $expected_pdfs"
            prev_found=$found_pdfs
        fi

        if [[ "$found_pdfs" -ge "$expected_pdfs" ]]; then
            log_ok "全PDF変換完了"
            echo ""
            break
        fi

        local remaining=$(( (deadline - SECONDS) / 60 ))
        printf "\r  待機中... (PDF: %d/%d, 残り約%d分)  " "$found_pdfs" "$expected_pdfs" "$remaining"
        sleep "$POLL_SEC"
    done

    # 改行（\rの後）
    echo ""

    if [[ "$found_pdfs" -lt "$expected_pdfs" ]]; then
        log_warn "タイムアウト: $found_pdfs / $expected_pdfs PDFのみ検出"
        log_warn "変換済みのPDFのみダウンロードします"
    fi

    if [[ "$found_pdfs" -eq 0 ]]; then
        log_error "PDFが見つかりません。Windows側の watch-and-convert.ps1 を確認してください"
        exit 1
    fi

    # ダウンロード（__archives/ は除外、products/ 直下のPDFのみ）
    log_info "PDFダウンロード → $PRODUCTS_DIR/"
    rclone copy "$GDRIVE_DEST/products" "$PRODUCTS_DIR" \
        --max-depth 1 \
        --filter "+ *.pdf" \
        --filter "- *" \
        --stats-one-line -v

    echo ""
    log_ok "Pull 完了"
    echo ""

    log_info "ダウンロードしたPDF:"
    for f in "$PRODUCTS_DIR"/*.pdf; do
        [[ -f "$f" ]] && printf "  %-45s %s\n" "$(basename "$f")" "$(du -h "$f" | cut -f1)"
    done
    echo ""

    # Google Drive上のPDFを__archives/にタイムスタンプ付きで移動
    local archive_ts
    archive_ts="$(date '+%Y%m%d_%H%M%S')"
    local gdrive_archive="$GDRIVE_DEST/products/__archives"

    log_info "Google Drive上のPDFを __archives/ に退避..."
    rclone mkdir "$gdrive_archive" 2>/dev/null || true

    local pdf_list
    # M14-05: 退避前の一覧取得も 60s + retry に緩和。
    pdf_list=$(rclone_with_retry 60 rclone lsf "$GDRIVE_DEST/products" --include "*.pdf" --max-depth 1 --files-only 2>/dev/null || true)
    for pdf_name in $pdf_list; do
        local base="${pdf_name%.pdf}"
        local archived_name="${base}_${archive_ts}.pdf"
        timeout 30 rclone moveto \
            "$GDRIVE_DEST/products/$pdf_name" \
            "$gdrive_archive/$archived_name" \
            -v 2>&1 || true
        log_info "  $pdf_name → __archives/$archived_name"
    done
    echo ""
}

# ============================================================
# メイン
# ============================================================
echo ""
separator
log_info "roundtrip: ビルド → push → PDF待ち → pull"
[[ -n "$DRY_RUN" ]] && log_info "(dry-run モード)"
separator
echo ""

# Phase 1
if [[ "$SKIP_BUILD" == false && "$SKIP_PUSH" == false ]]; then
    phase_build
else
    log_info "Phase 1: ビルド → スキップ"
    echo ""
fi

# Phase 2
if [[ "$SKIP_PUSH" == false ]]; then
    phase_collect
else
    log_info "Phase 2: 集約 → スキップ"
    echo ""
fi

# Phase 3
if [[ "$SKIP_PUSH" == false ]]; then
    phase_push
else
    log_info "Phase 3: Push → スキップ"
    echo ""
fi

# Phase 4
phase_wait_and_pull

# --- 完了サマリー ---
separator
log_ok "roundtrip 完了"
separator
echo ""
echo "成果物 (docx/xlsx): $OUTPUT_DIR/"
echo "PDF:                $PRODUCTS_DIR/"
echo ""
