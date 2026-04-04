#!/usr/bin/env bash
# build_narrative.sh — Markdown本文をPandocでdocxに変換する
#
# Usage:
#   bash main/step02_docx/build_narrative.sh [--docker|--local]
#
# 環境変数:
#   USE_DOCKER=1  Docker経由で実行（デフォルト）
#   USE_DOCKER=0  ローカルpandocで実行

set -euo pipefail

# --- プロジェクトルートに移動 ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_ROOT"

# --- 設定 ---
REFERENCE_DOC="templates/reference.docx"
OUTPUT_DIR="main/step02_docx/output"

declare -A SOURCES=(
    ["main/step01_narrative/youshiki1_2.md"]="$OUTPUT_DIR/youshiki1_2_narrative.docx"
    ["main/step01_narrative/youshiki1_3.md"]="$OUTPUT_DIR/youshiki1_3_narrative.docx"
)

PANDOC_OPTS=(
    --from markdown+east_asian_line_breaks
    --to docx
    "--reference-doc=$REFERENCE_DOC"
)

# --- 実行モード判定 ---
resolve_mode() {
    # 引数での指定
    if [[ "${1:-}" == "--docker" ]]; then
        echo "docker"; return
    elif [[ "${1:-}" == "--local" ]]; then
        echo "local"; return
    fi
    # 環境変数での指定
    if [[ "${USE_DOCKER:-}" == "0" ]]; then
        echo "local"; return
    fi
    # デフォルト: Docker
    echo "docker"
}

MODE=$(resolve_mode "${1:-}")

# --- pandoc実行関数 ---
run_pandoc() {
    if [[ "$MODE" == "docker" ]]; then
        docker compose -f docker/docker-compose.yml run --rm \
            -u "$(id -u):$(id -g)" python \
            pandoc "$@"
    else
        if ! command -v pandoc &>/dev/null; then
            echo "ERROR: pandoc がインストールされていません" >&2
            echo "  --docker オプションでDocker経由の実行を試してください" >&2
            exit 1
        fi
        pandoc "$@"
    fi
}

# --- Python実行関数 ---
run_python() {
    if [[ "$MODE" == "docker" ]]; then
        docker compose -f docker/docker-compose.yml run --rm \
            -u "$(id -u):$(id -g)" python \
            python3 "$@"
    else
        python3 "$@"
    fi
}

# --- reference.docx の確認・生成・スタイル設定 ---
if [[ ! -f "$REFERENCE_DOC" ]]; then
    echo "reference.docx を生成・スタイル設定します..."
    mkdir -p templates
    run_pandoc --print-default-data-file reference.docx > "$REFERENCE_DOC"
    echo "  デフォルト reference.docx を生成"
fi

# スタイル設定（毎回実行して最新の設定を反映）
echo "reference.docx スタイル設定:"
run_python main/step02_docx/fix_reference_styles.py "$REFERENCE_DOC"
echo ""

# --- 出力ディレクトリ作成 ---
mkdir -p "$OUTPUT_DIR"

# --- 変換実行 ---
echo "Mode: $MODE"
echo ""

FAILED=0
for src in "${!SOURCES[@]}"; do
    out="${SOURCES[$src]}"
    if [[ ! -f "$src" ]]; then
        echo "SKIP: $src が見つかりません"
        continue
    fi
    echo "Converting: $src → $out"
    if run_pandoc "$src" "${PANDOC_OPTS[@]}" --output="$out"; then
        echo "  OK: $out ($(du -h "$out" | cut -f1))"
    else
        echo "  FAIL: $src の変換に失敗しました" >&2
        FAILED=1
    fi
done

echo ""

# --- 出力確認 ---
if [[ "$FAILED" -eq 0 ]]; then
    echo "=== 完了 ==="
    for out in "${SOURCES[@]}"; do
        if [[ -f "$out" ]]; then
            echo "  $out ($(du -h "$out" | cut -f1))"
        fi
    done
else
    echo "ERROR: 一部の変換に失敗しました" >&2
    exit 1
fi
