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

    # M15-01: 集約前に既存の docx/xlsx を削除し、ステイル成果物の累積を防ぐ。
    # 過去ビルドの研究者構成・命名規約変更時の旧ファイル（例: 旧 placeholder
    # 名の betten_XX_○○.docx）が gdrive 経由で Windows へ転送され、提出物に
    # 混入する事故を根本的に塞ぐ。.gitkeep は保持。
    local stale=0
    for f in "$OUTPUT_DIR"/*.docx "$OUTPUT_DIR"/*.xlsx; do
        if [[ -f "$f" ]]; then
            rm -f "$f"
            stale=$((stale + 1))
        fi
    done
    if [[ "$stale" -gt 0 ]]; then
        log_info "既存の $stale ファイルをクリアしました（ステイル混入防止）"
    fi

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

    # N15-01: 前回 roundtrip の PDF が products/ に残ったままだと、
    #   (a) Phase 4 の polling が「旧 PDF + 新 PDF」で count を誤判定し
    #       Windows 変換完了前に premature break する
    #   (b) Windows 側に旧 PDF が visible のまま残り誤認識の原因になる
    # 以前は Phase 4 末尾で「download 後に __archives へ move」していたが、
    # それでは Windows 側 products/ が空になり PDF を確認できなかった。
    # ⇒ push 直前にアーカイブすることで:
    #   - Windows 側 products/ には常に「最新 roundtrip の PDF」が可視
    #   - __archives/ には時系列で蓄積
    if [[ -z "$DRY_RUN" ]]; then
        archive_old_gdrive_pdfs
    fi

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
# phase_push が呼び出す pre-push cleanup: 旧 PDF を __archives/ へ退避
# ============================================================
archive_old_gdrive_pdfs() {
    local archive_ts
    archive_ts="$(date '+%Y%m%d_%H%M%S')"
    local gdrive_archive="$GDRIVE_DEST/products/__archives"

    local pdf_list
    pdf_list=$(rclone_with_retry 60 rclone lsf \
        "$GDRIVE_DEST/products" \
        --include "*.pdf" --max-depth 1 --files-only 2>/dev/null || true)

    if [[ -z "$pdf_list" ]]; then
        return 0  # 旧 PDF 無し — cleanup 不要
    fi

    log_info "旧 PDF を __archives/ に退避..."
    rclone mkdir "$gdrive_archive" 2>/dev/null || true

    for pdf_name in $pdf_list; do
        local base="${pdf_name%.pdf}"
        local archived_name="${base}_${archive_ts}.pdf"
        timeout 30 rclone moveto \
            "$GDRIVE_DEST/products/$pdf_name" \
            "$gdrive_archive/$archived_name" \
            -v 2>&1 | tail -1 || true
        log_info "  旧 $pdf_name → __archives/$archived_name"
    done
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

    # N15-01: PDF を Google Drive 側 products/ に残すことで Windows でも可視化。
    # 次回 Phase 3 冒頭の archive_old_gdrive_pdfs() で __archives/ へ退避される。
    log_info "Google Drive products/ は保持（Windows での閲覧用）"
    log_info "次回 Phase 3 冒頭で __archives/ に自動退避します"
    echo ""
}

# ============================================================
# Phase 5: PDF 結合（pypdf）→ Windows gdrive に push back
# ============================================================
phase_merge() {
    separator
    log_info "Phase 5: PDF結合 → Windows gdrive へ push back"
    separator
    echo ""

    if [[ -n "$DRY_RUN" ]]; then
        log_info "(dry-run: 結合・push back をスキップします)"
        echo ""
        return
    fi

    local merge_script="main/step04_package/merge_pdfs.py"
    if [[ ! -f "$merge_script" ]]; then
        log_warn "$merge_script が見つかりません。結合をスキップします"
        echo ""
        return
    fi

    # build.sh merge サブコマンドを使って RUNNER 切替・SETUP_DIR 継承を統一
    # （docker / uv / direct は build.sh の RUNNER 環境変数に従う）
    if ! bash "$SCRIPT_DIR/build.sh" merge; then
        log_warn "merge_pdfs.py の実行に失敗しました。結合 PDF 無しで続行します"
        echo ""
        return
    fi

    local merged="$PRODUCTS_DIR/submission_merged.pdf"
    if [[ ! -f "$merged" ]]; then
        log_warn "結合 PDF が生成されていません: $merged"
        echo ""
        return
    fi

    log_ok "結合PDF: $merged ($(du -h "$merged" | cut -f1))"
    echo ""

    # Windows 側 gdrive の merged/ フォルダへ戻す。watch-and-convert.ps1 は
    # *.docx のみ監視するため、結合 PDF を配置しても変換ループは発生しない。
    # merged/ は Phase 4 の products/__archives 退避対象外なので提出当日まで残る。
    log_info "結合PDFを $GDRIVE_DEST/merged/ に push..."
    rclone mkdir "$GDRIVE_DEST/merged" 2>/dev/null || true
    if rclone copy "$merged" "$GDRIVE_DEST/merged/" \
            --stats-one-line -v; then
        log_ok "結合PDF push 完了 → Windows 側 gdrive に同期待ち"
    else
        log_warn "結合PDF の push に失敗しました（Linux 側 data/products/ には生成済）"
    fi
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

# Phase 5
phase_merge

# --- 完了サマリー ---
separator
log_ok "roundtrip 完了"
separator
echo ""
echo "成果物 (docx/xlsx): $OUTPUT_DIR/"
echo "PDF:                $PRODUCTS_DIR/"
echo ""
