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
    --lua-filter=filters/textbox-minimal.lua
)

FIGS_DIR="main/step01_narrative/figs"

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

# --- mermaid / rsvg-convert 実行関数 ---
# mmdc: $1=入力 .mmd, $2=出力 .svg
run_mermaid() {
    if [[ "$MODE" == "docker" ]]; then
        docker compose -f docker/docker-compose.yml run --rm \
            -u "$(id -u):$(id -g)" mermaid \
            mmdc -i "$1" -o "$2" \
            -p /etc/puppeteer-config.json \
            -c /etc/mermaid-config.json
    else
        if ! command -v mmdc &>/dev/null; then
            echo "  WARN: mmdc がホストに見つからないためスキップ: $1" >&2
            return 0
        fi
        mmdc -i "$1" -o "$2"
    fi
}

# rsvg-convert: $1=入力 .svg, $2=出力 .png (300dpi)
run_rsvg_convert() {
    if [[ "$MODE" == "docker" ]]; then
        docker compose -f docker/docker-compose.yml run --rm \
            -u "$(id -u):$(id -g)" python \
            rsvg-convert -d 300 -p 300 "$1" -o "$2"
    else
        if ! command -v rsvg-convert &>/dev/null; then
            echo "  WARN: rsvg-convert がホストに見つからないためスキップ: $1" >&2
            return 0
        fi
        rsvg-convert -d 300 -p 300 "$1" -o "$2"
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

# --- Phase A: mermaid → svg → svg.png ---
# md ループの外で 1 回だけ実行（複数 md 間で共有される figs/ を対象）
echo "Phase A: mermaid → svg → svg.png"

# .mmd → .svg
shopt -s nullglob
mmd_files=( "$FIGS_DIR"/*.mmd )
shopt -u nullglob

for mmd in "${mmd_files[@]}"; do
    svg="${mmd%.mmd}.svg"
    if [[ ! -f "$svg" ]] || [[ "$mmd" -nt "$svg" ]]; then
        echo "  mermaid: $mmd → $svg"
        run_mermaid "$mmd" "$svg"
    else
        echo "  skip (up-to-date): $svg"
    fi
done

# .svg → .svg.png (pandoc に primary blip として PNG を渡すための前処理)
shopt -s nullglob
svg_files=( "$FIGS_DIR"/*.svg )
shopt -u nullglob

for svg in "${svg_files[@]}"; do
    png="${svg}.png"
    if [[ ! -f "$png" ]] || [[ "$svg" -nt "$png" ]]; then
        echo "  rsvg-convert: $svg → $png"
        run_rsvg_convert "$svg" "$png"
    else
        echo "  skip (up-to-date): $png"
    fi
done

echo ""

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
    if ! run_pandoc "$src" "${PANDOC_OPTS[@]}" --output="$out"; then
        echo "  FAIL: $src の変換に失敗しました" >&2
        FAILED=1
        continue
    fi
    echo "  OK pandoc: $out ($(du -h "$out" | cut -f1))"

    # --- Phase C: wrap_textbox 後処理 ---
    # narrative ごとに docPr@id 空間を分離（post-inject での衝突回避）
    case "$src" in
        *youshiki1_2.md) base=3000 ;;
        *youshiki1_3.md) base=4000 ;;
        *)               base=5000 ;;
    esac
    echo "  wrap_textbox (--docpr-id-base=$base): $out"
    if run_python main/step02_docx/wrap_textbox.py \
            --source "$src" --docpr-id-base "$base" "$out"; then
        echo "  OK wrap_textbox: $out"
    else
        echo "  FAIL: wrap_textbox の処理に失敗しました" >&2
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
