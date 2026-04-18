#!/usr/bin/env bash
# collab_watcher.sh — 共同執筆トリガー監視 & 自動ビルド
#
# Google Drive上の trigger.txt を定期ポーリングし、"build" トリガーで
# ドラフト同期 → ソースバックアップ → ビルド → roundtrip → 成果物配信 を実行。
# 各フェーズの進捗は Google Chat Webhook で通知する。
#
# Usage:
#   ./scripts/collab_watcher.sh              # フォアグラウンド実行
#   nohup ./scripts/collab_watcher.sh &      # バックグラウンド実行
#
# 停止:
#   Ctrl+C (フォアグラウンド) / kill (バックグラウンド)
#
# 環境変数 (.env):
#   GCHAT_WEBHOOK_URL   Google Chat Webhook URL
#   COLLAB_REMOTE       rclone リモート名 (default: gdrive:)
#   COLLAB_PATH         共有フォルダパス (default: share_temp/med-resist-collab)
#   RUNNER              実行環境 (docker/uv/direct, default: docker)
#   COLLAB_POLL_SEC     ポーリング間隔 (default: 15)
#   COLLAB_COOLDOWN_SEC クールダウン秒数 (default: 120)

set -euo pipefail

# --- プロジェクトルート ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

# --- .env 読み込み ---
# N15-09: .env が無い場合は .env.example を fallback として読み込み警告で続行。
# 提出当日のリカバリ運用や予備機での起動失敗を避ける。GCHAT_WEBHOOK_URL 等の
# 機微変数は空のままになるため、Webhook 通知は内部で skip 動作となる。
if [[ -f "$PROJECT_ROOT/.env" ]]; then
    set -a
    # shellcheck disable=SC1091
    source "$PROJECT_ROOT/.env"
    set +a
elif [[ -f "$PROJECT_ROOT/.env.example" ]]; then
    echo "WARN: .env が見つかりません。.env.example を fallback として読み込みます。" >&2
    echo "      → 機微変数 (GCHAT_WEBHOOK_URL 等) は空のままで動作します。" >&2
    set -a
    # shellcheck disable=SC1091
    source "$PROJECT_ROOT/.env.example"
    set +a
else
    echo "ERROR: .env も .env.example も見つかりません。.env.example を作成してください。" >&2
    exit 1
fi

# --- デフォルト値 ---
GCHAT_WEBHOOK_URL="${GCHAT_WEBHOOK_URL:-}"
COLLAB_REMOTE="${COLLAB_REMOTE:-gdrive:}"
COLLAB_PATH="${COLLAB_PATH:-share_temp/med-resist-collab}"
RUNNER="${RUNNER:-docker}"
COLLAB_POLL_SEC="${COLLAB_POLL_SEC:-15}"
COLLAB_COOLDOWN_SEC="${COLLAB_COOLDOWN_SEC:-120}"

COLLAB_DEST="${COLLAB_REMOTE}${COLLAB_PATH}"
LOCKFILE="/tmp/collab_watcher.lock"
LAST_BUILD_TS=0

# --- ログヘルパー ---
log_info()  { echo "[INFO]  $(date '+%Y-%m-%d %H:%M:%S') $1"; }
log_warn()  { echo "[WARN]  $(date '+%Y-%m-%d %H:%M:%S') $1"; }
log_error() { echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') $1" >&2; }
log_ok()    { echo "[OK]    $(date '+%Y-%m-%d %H:%M:%S') $1"; }

# --- Google Chat Webhook 通知 ---
notify_gchat() {
    local message="$1"
    log_info "通知: $message"
    if [[ -z "$GCHAT_WEBHOOK_URL" ]]; then
        log_warn "GCHAT_WEBHOOK_URL が未設定のため通知をスキップ"
        return 0
    fi
    curl -s -X POST "$GCHAT_WEBHOOK_URL" \
        -H "Content-Type: application/json" \
        -d "$(jq -n --arg text "$message" '{text: $text}')" \
        >/dev/null 2>&1 || log_warn "Webhook 送信失敗"
}

# --- status.txt 更新 ---
update_status() {
    local status_text="$1"
    echo "$status_text" | rclone rcat "${COLLAB_DEST}/status.txt" 2>/dev/null \
        || log_warn "status.txt の更新に失敗"
}

# --- trigger.txt を IDLE にリセット ---
reset_trigger() {
    echo "IDLE" | rclone rcat "${COLLAB_DEST}/trigger.txt" 2>/dev/null \
        || log_warn "trigger.txt のリセットに失敗"
}

# --- ロック管理 ---
acquire_lock() {
    if [[ -f "$LOCKFILE" ]]; then
        return 1
    fi
    echo $$ > "$LOCKFILE"
    return 0
}

release_lock() {
    rm -f "$LOCKFILE"
}

# --- クリーンアップ（EXIT trap） ---
cleanup() {
    log_info "Watcher を停止します..."
    release_lock
    notify_gchat "$(printf '\xf0\x9f\x94\xb4') Watcher停止"
    exit 0
}
trap cleanup EXIT INT TERM

# --- 前提チェック ---
for cmd in rclone jq curl; do
    if ! command -v "$cmd" &>/dev/null; then
        log_error "$cmd がインストールされていません"
        exit 1
    fi
done

# rclone 接続チェック
if ! timeout 15 rclone cat "${COLLAB_DEST}/trigger.txt" &>/dev/null; then
    log_error "rclone リモート '$COLLAB_DEST' に接続できません"
    log_error "  rclone config reconnect ${COLLAB_REMOTE} を実行してください"
    exit 1
fi

# ============================================================
# Phase 1: 双方向ドラフト同期
# ============================================================
phase_sync_drafts() {
    log_info "Phase 1: 双方向ドラフト同期"

    local narrative_dir="main/step01_narrative"
    local drafts_remote="${COLLAB_DEST}/drafts"

    # Linux → Drive（ローカルの最新原稿を共有フォルダに反映）
    rclone copy "$narrative_dir/" "$drafts_remote/" \
        --include "*.md" \
        --update \
        -v 2>&1 | head -20 || true

    # figs: Linux → Drive
    if [[ -d "$narrative_dir/figs" ]]; then
        rclone copy "$narrative_dir/figs/" "$drafts_remote/figs/" \
            --update \
            -v 2>&1 | head -20 || true
    fi

    # Drive → Linux（共同研究者の編集を取り込み）
    rclone copy "$drafts_remote/" "$narrative_dir/" \
        --include "*.md" \
        --update \
        -v 2>&1 | head -20 || true

    # figs: Drive → Linux
    rclone copy "$drafts_remote/figs/" "$narrative_dir/figs/" \
        --update \
        -v 2>&1 | head -20 || true
    mkdir -p "$narrative_dir/figs"

    notify_gchat "$(printf '\xf0\x9f\x93\xa5') ドラフトを同期しました"
}

# ============================================================
# Phase 1.5: ソースコードバックアップ
# ============================================================
phase_backup_source() {
    log_info "Phase 1.5: ソースコードバックアップ"

    local ts
    ts="$(date '+%Y%m%d_%H%M%S')"
    local zip_name="src_${ts}.zip"
    local zip_path="/tmp/${zip_name}"

    # git管理ファイルのみをzip化
    git -C "$PROJECT_ROOT" archive --format=zip HEAD -o "$zip_path"

    # Google Drive にアップロード
    rclone copy "$zip_path" "${COLLAB_REMOTE}tmp/med-resist-grant/src/" \
        -v 2>&1 | head -10 || true

    rm -f "$zip_path"

    notify_gchat "$(printf '\xf0\x9f\x92\xbe') ソースコードをバックアップしました"
}

# ============================================================
# Phase 2: ビルド
# ============================================================
phase_build() {
    log_info "Phase 2: ビルド"

    update_status "$(printf '\xf0\x9f\x94\xa8') ビルド中..."

    local build_output
    if build_output=$(bash "$SCRIPT_DIR/build.sh" 2>&1); then
        # ビルド結果サマリーを抽出
        local summary=""
        for step in validate forms narrative security excel; do
            if echo "$build_output" | grep -q "${step}.*OK"; then
                summary="${summary} ${step} $(printf '\xe2\x9c\x93') /"
            elif echo "$build_output" | grep -q "${step}.*SKIP"; then
                summary="${summary} ${step} - /"
            elif echo "$build_output" | grep -q "${step}.*FAIL"; then
                summary="${summary} ${step} $(printf '\xe2\x9c\x97') /"
            fi
        done
        summary="${summary% /}"
        notify_gchat "$(printf '\xf0\x9f\x94\xa8') ビルド完了（${summary} ）"
        return 0
    else
        local error_tail
        error_tail=$(echo "$build_output" | tail -5 | tr '\n' ' ')
        notify_gchat "$(printf '\xe2\x9d\x8c') ビルド失敗: ${error_tail}"
        update_status "$(printf '\xe2\x9d\x8c') エラー: ビルド失敗 ($(date '+%Y-%m-%d %H:%M'))"
        return 1
    fi
}

# ============================================================
# Phase 3: roundtrip（push → PDF待ち → pull）
# ============================================================
phase_roundtrip() {
    log_info "Phase 3: roundtrip（push → PDF待ち → pull）"

    notify_gchat "$(printf '\xf0\x9f\x93\xa4') Google Driveにアップロード中..."

    local rt_output
    if rt_output=$(bash "$SCRIPT_DIR/roundtrip.sh" --skip-build 2>&1); then
        # PDF数をカウント
        local pdf_count=0
        for f in data/products/*.pdf; do
            [[ -f "$f" ]] && pdf_count=$((pdf_count + 1))
        done
        notify_gchat "$(printf '\xe2\x9c\x85') PDF変換完了（${pdf_count}個）"
        return 0
    else
        local error_tail
        error_tail=$(echo "$rt_output" | tail -5 | tr '\n' ' ')
        notify_gchat "$(printf '\xe2\x9d\x8c') roundtrip失敗: ${error_tail}"
        update_status "$(printf '\xe2\x9d\x8c') エラー: roundtrip失敗 ($(date '+%Y-%m-%d %H:%M'))"
        return 1
    fi
}

# ============================================================
# Phase 4: 成果物配信
# ============================================================
phase_deliver() {
    log_info "Phase 4: 成果物配信"

    local products_remote="${COLLAB_DEST}/products"

    # PDF
    if [[ -d "data/products" ]]; then
        rclone copy "data/products/" "$products_remote/" \
            --include "*.pdf" \
            -v 2>&1 | head -10 || true
    fi

    # docx / xlsx
    if [[ -d "data/output" ]]; then
        rclone copy "data/output/" "$products_remote/" \
            --include "*.docx" \
            --include "*.xlsx" \
            -v 2>&1 | head -10 || true
    fi

    notify_gchat "$(printf '\xf0\x9f\x93\xa6') 成果物を共有フォルダに配信しました"
}

# ============================================================
# Phase 5: 完了
# ============================================================
phase_complete() {
    local completed_at
    completed_at="$(date '+%Y-%m-%d %H:%M')"
    update_status "$(printf '\xe2\x9c\x85') 完了 (${completed_at})"
    notify_gchat "$(printf '\xf0\x9f\x8e\x89') 全工程完了。products/ フォルダを確認してください"
}

# ============================================================
# ビルドパイプライン全体
# ============================================================
run_build_pipeline() {
    log_info "=== ビルドパイプライン開始 ==="

    # Phase 1: ドラフト同期
    if ! phase_sync_drafts; then
        notify_gchat "$(printf '\xe2\x9d\x8c') ドラフト同期でエラーが発生しました"
        update_status "$(printf '\xe2\x9d\x8c') エラー: ドラフト同期 ($(date '+%Y-%m-%d %H:%M'))"
        return 1
    fi

    # Phase 1.5: ソースバックアップ
    if ! phase_backup_source; then
        notify_gchat "$(printf '\xe2\x9d\x8c') ソースバックアップでエラーが発生しました"
        update_status "$(printf '\xe2\x9d\x8c') エラー: バックアップ ($(date '+%Y-%m-%d %H:%M'))"
        return 1
    fi

    # Phase 2: ビルド
    if ! phase_build; then
        return 1
    fi

    # Phase 3: roundtrip
    if ! phase_roundtrip; then
        return 1
    fi

    # Phase 4: 成果物配信
    if ! phase_deliver; then
        notify_gchat "$(printf '\xe2\x9d\x8c') 成果物配信でエラーが発生しました"
        update_status "$(printf '\xe2\x9d\x8c') エラー: 成果物配信 ($(date '+%Y-%m-%d %H:%M'))"
        return 1
    fi

    # Phase 5: 完了
    phase_complete

    log_ok "=== ビルドパイプライン完了 ==="
}

# ============================================================
# メインループ
# ============================================================
log_info "========================================"
log_info "collab_watcher 起動"
log_info "  リモート: ${COLLAB_DEST}"
log_info "  ポーリング間隔: ${COLLAB_POLL_SEC}秒"
log_info "  クールダウン: ${COLLAB_COOLDOWN_SEC}秒"
log_info "  Runner: ${RUNNER}"
log_info "========================================"

notify_gchat "$(printf '\xf0\x9f\x9f\xa2') Watcher起動（ポーリング: ${COLLAB_POLL_SEC}秒間隔）"

while true; do
    # trigger.txt を読み取り
    trigger_content=""
    trigger_content=$(timeout 15 rclone cat "${COLLAB_DEST}/trigger.txt" 2>/dev/null || true)
    # 先頭行のみ、前後空白を除去
    trigger_content=$(echo "$trigger_content" | head -1 | tr -d '[:space:]')

    if [[ "$trigger_content" == build* ]]; then
        log_info "トリガー検出: '$trigger_content'"

        # ロックチェック
        if ! acquire_lock; then
            log_warn "ビルド中のためスキップ（ロックファイル: $LOCKFILE）"
            sleep "$COLLAB_POLL_SEC"
            continue
        fi

        # クールダウンチェック
        now=$(date +%s)
        elapsed=$((now - LAST_BUILD_TS))
        if [[ "$LAST_BUILD_TS" -gt 0 && "$elapsed" -lt "$COLLAB_COOLDOWN_SEC" ]]; then
            remaining=$((COLLAB_COOLDOWN_SEC - elapsed))
            log_warn "クールダウン中（残り ${remaining}秒）"
            notify_gchat "$(printf '\xe2\x8f\xb3') クールダウン中です（残り ${remaining}秒）。しばらくお待ちください"
            reset_trigger
            release_lock
            sleep "$COLLAB_POLL_SEC"
            continue
        fi

        # trigger.txt を IDLE にリセット
        reset_trigger

        # status.txt を更新
        update_status "$(printf '\xf0\x9f\x94\x84') ビルドパイプライン実行中..."

        # パイプライン実行
        if run_build_pipeline; then
            LAST_BUILD_TS=$(date +%s)
        else
            log_error "ビルドパイプラインが失敗しました"
            # status.txt は各フェーズ内で更新済み
        fi

        release_lock
    fi

    sleep "$COLLAB_POLL_SEC"
done
