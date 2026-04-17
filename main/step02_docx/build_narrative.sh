#!/usr/bin/env bash
# build_narrative.sh — Markdown本文をPandocでdocxに変換する
#
# Usage:
#   bash main/step02_docx/build_narrative.sh [--docker|--local|--uv]
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
    elif [[ "${1:-}" == "--uv" ]]; then
        echo "uv"; return
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
# pandoc は Python パッケージではないので uv モードでも host PATH を使う
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
    elif [[ "$MODE" == "uv" ]]; then
        # M12-07: RUNNER=uv 経由時に Python 依存を uv 管理下で解決する
        uv run python3 "$@"
    else
        python3 "$@"
    fi
}

# --- mermaid / rsvg-convert 実行関数 ---
# M12-03: 一時ファイルに書き出してから mv で確定することで、mmdc/rsvg-convert が
#         中途失敗した際に stale な出力ファイルが残ることを防ぐ。
# C12-01: ホストにツールが無い場合は silent skip ではなく fail で終了する。
# mmdc: $1=入力 .mmd, $2=出力 .svg
run_mermaid() {
    local mmd="$1" svg="$2"
    local tmp="${svg}.tmp.$$"
    local ret=0
    if [[ "$MODE" == "docker" ]]; then
        docker compose -f docker/docker-compose.yml run --rm \
            -u "$(id -u):$(id -g)" mermaid \
            mmdc -i "$mmd" -o "$tmp" \
            -p /etc/puppeteer-config.json \
            -c /etc/mermaid-config.json || ret=$?
    else
        if ! command -v mmdc &>/dev/null; then
            echo "ERROR: mmdc がホストに見つかりません: $mmd" >&2
            echo "  --docker または --uv（docker 経由）での実行を試してください" >&2
            rm -f "$tmp"
            return 1
        fi
        mmdc -i "$mmd" -o "$tmp" || ret=$?
    fi
    if [[ $ret -ne 0 ]]; then
        rm -f "$tmp"
        return $ret
    fi
    mv "$tmp" "$svg"
}

# rsvg-convert: $1=入力 .svg, $2=出力 .png (300dpi)
run_rsvg_convert() {
    local svg="$1" png="$2"
    local tmp="${png}.tmp.$$"
    local ret=0
    if [[ "$MODE" == "docker" ]]; then
        docker compose -f docker/docker-compose.yml run --rm \
            -u "$(id -u):$(id -g)" python \
            rsvg-convert -d 300 -p 300 "$svg" -o "$tmp" || ret=$?
    else
        if ! command -v rsvg-convert &>/dev/null; then
            echo "ERROR: rsvg-convert がホストに見つかりません: $svg" >&2
            echo "  librsvg2-bin をインストールするか --docker での実行を試してください" >&2
            rm -f "$tmp"
            return 1
        fi
        rsvg-convert -d 300 -p 300 "$svg" -o "$tmp" || ret=$?
    fi
    if [[ $ret -ne 0 ]]; then
        rm -f "$tmp"
        return $ret
    fi
    mv "$tmp" "$png"
}

# --- M12-02 / N12-03: docker 実行環境の pre-flight 検査 ---
# Dockerfile 更新時にキャッシュ済みの古いイメージが使われて rsvg-convert が
# 見つからない事故を防ぐ。イメージが Dockerfile より古ければビルドし直す。
preflight_docker_images() {
    [[ "$MODE" != "docker" ]] && return 0

    for svc in python mermaid; do
        local df="docker/${svc}/Dockerfile"
        [[ "$svc" == "python" ]] && df="docker/python/Dockerfile"
        [[ "$svc" == "mermaid" ]] && df="docker/mermaid-svg/Dockerfile"

        local img_id
        img_id=$(docker compose -f docker/docker-compose.yml images --quiet "$svc" 2>/dev/null | head -1 || true)

        local need_build=0
        if [[ -z "$img_id" ]]; then
            echo "  Docker イメージ未ビルド ($svc): ビルドします"
            need_build=1
        else
            local img_created
            img_created=$(docker inspect --format='{{.Created}}' "$img_id" 2>/dev/null || true)
            if [[ -n "$img_created" && -f "$df" ]]; then
                # Dockerfile の mtime がイメージ作成時刻より新しければ再ビルド
                local df_mtime img_mtime
                df_mtime=$(stat -c%Y "$df" 2>/dev/null || stat -f%m "$df" 2>/dev/null || echo 0)
                # ISO8601 → epoch 変換（GNU date）
                img_mtime=$(date -d "$img_created" +%s 2>/dev/null || echo 0)
                if [[ "$df_mtime" -gt "$img_mtime" && "$img_mtime" -gt 0 ]]; then
                    echo "  Dockerfile が更新されています ($df): $svc を再ビルドします"
                    need_build=1
                fi
            fi
        fi

        if [[ "$need_build" -eq 1 ]]; then
            docker compose -f docker/docker-compose.yml build "$svc"
        fi
    done

    # rsvg-convert が python コンテナで動くことを確認する最終検査
    if ! docker compose -f docker/docker-compose.yml run --rm \
            -u "$(id -u):$(id -g)" python rsvg-convert --version &>/dev/null; then
        echo "ERROR: python コンテナで rsvg-convert が動作しません" >&2
        echo "  docker compose -f docker/docker-compose.yml build python" >&2
        echo "  を明示的に実行してください（librsvg2-bin が Dockerfile に追加されています）" >&2
        exit 1
    fi
}

# --- C12-01 / N12-01: Phase A 突入前に依存する画像ファイルの整合を検査 ---
# Lua フィルタが .svg → .svg.png に書き換えるため、pandoc 実行時には
# .svg.png が存在している必要がある。silent な画像欠落 docx を防ぐための
# 事前チェックをここで行う。大文字拡張子 .SVG は Phase A の glob と整合しないため reject。
preflight_image_case() {
    shopt -s nullglob
    local bad=()
    for f in "$FIGS_DIR"/*.SVG "$FIGS_DIR"/*.Svg; do
        bad+=( "$f" )
    done
    shopt -u nullglob
    if (( ${#bad[@]} > 0 )); then
        echo "ERROR: SVG ファイルに大文字拡張子が含まれています（.svg 小文字のみ許可）:" >&2
        for f in "${bad[@]}"; do echo "  - $f" >&2; done
        echo "  これらは Phase A の glob と整合しないため、.svg に rename してください" >&2
        exit 1
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

# --- Phase A pre-flight ---
preflight_image_case
preflight_docker_images

# --- Phase A: mermaid → svg → svg.png ---
# md ループの外で 1 回だけ実行（複数 md 間で共有される figs/ を対象）
echo "Phase A: mermaid → svg → svg.png"

# .mmd → .svg
shopt -s nullglob
mmd_files=( "$FIGS_DIR"/*.mmd )
shopt -u nullglob

# N12-06: bash 3.2 互換のため空配列を参照する前に要素数をガード
if (( ${#mmd_files[@]} > 0 )); then
    for mmd in "${mmd_files[@]}"; do
        svg="${mmd%.mmd}.svg"
        if [[ ! -f "$svg" ]] || [[ "$mmd" -nt "$svg" ]]; then
            echo "  mermaid: $mmd → $svg"
            run_mermaid "$mmd" "$svg"
        else
            echo "  skip (up-to-date): $svg"
        fi
    done
fi

# .svg → .svg.png (pandoc に primary blip として PNG を渡すための前処理)
shopt -s nullglob
svg_files=( "$FIGS_DIR"/*.svg )
shopt -u nullglob

if (( ${#svg_files[@]} > 0 )); then
    for svg in "${svg_files[@]}"; do
        png="${svg}.png"
        if [[ ! -f "$png" ]] || [[ "$svg" -nt "$png" ]]; then
            echo "  rsvg-convert: $svg → $png"
            run_rsvg_convert "$svg" "$png"
        else
            echo "  skip (up-to-date): $png"
        fi
    done
fi

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
    # N12-05: 将来 narrative を増やす際は、case ラベルを明示的に追加し
    #         5000 以降の id 空間を個別に割り当てること（現状 *) は fail-fast）。
    case "$src" in
        *youshiki1_2.md) base=3000 ;;
        *youshiki1_3.md) base=4000 ;;
        *)
            echo "  FAIL: 未知の narrative: $src (docpr-id-base の割当が未定義)" >&2
            FAILED=1
            continue
            ;;
    esac
    echo "  wrap_textbox (--docpr-id-base=$base): $out"
    if run_python main/step02_docx/wrap_textbox.py \
            --source "$src" --docpr-id-base "$base" "$out"; then
        echo "  OK wrap_textbox: $out"
    else
        echo "  FAIL: wrap_textbox の処理に失敗しました" >&2
        # M12-04: 中途失敗した asvg 層なし docx が残ると inject で silent に
        #         品質劣化するため、失敗時は出力を削除して次回のフル再生成を強制する。
        rm -f "$out"
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
