#!/usr/bin/env bash
# build.sh — 全ドキュメント生成マスタースクリプト
#
# Usage:
#   ./scripts/build.sh [SUBCOMMAND...]
#
# Subcommands:
#   (なし)      全ステップ実行（validate + forms + narrative + inject + security + excel）
#   validate   YAMLバリデーションのみ
#   forms      テーブルフォーム記入 (step02_docx/fill_forms.py)
#   narrative  Markdown→docx変換 (step02_docx/build_narrative.sh)
#   inject     ナラティブ挿入 (step02_docx/inject_narrative.py)
#   security   セキュリティ文書記入 (step02_docx/fill_security.py)
#   excel      Excel記入 (step03_excel/fill_excel.py)
#   package    パッケージング (scripts/create_package.sh)
#   clean      全output/をクリーン
#   check      全出力ファイルの存在とサイズチェック
#
# Environment:
#   RUNNER=docker   docker compose run 経由（デフォルト）
#   RUNNER=uv       uv run 経由
#   RUNNER=direct   直接実行

set -euo pipefail

# --- プロジェクトルート ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

# --- 設定 ---
COMPOSE_FILE="docker/docker-compose.yml"
RUNNER="${RUNNER:-docker}"
DATA_DIR="${DATA_DIR:-data/source}"
SETUP_DIR="${SETUP_DIR:-main/00_setup}"
TARGETS=()

# --- 結果追跡 ---
declare -A RESULTS=()

# --- 引数解析 ---
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            head -21 "$0" | tail -20
            exit 0
            ;;
        *) TARGETS+=("$1"); shift ;;
    esac
done

# デフォルト: 全ステップ
if [[ ${#TARGETS[@]} -eq 0 ]]; then
    TARGETS=("all")
fi

# --- 実行ヘルパー ---
run_python() {
    case "$RUNNER" in
        docker)
            docker compose -f "$COMPOSE_FILE" run --rm \
                -u "$(id -u):$(id -g)" python python "$@"
            ;;
        uv)
            uv run python "$@"
            ;;
        direct)
            python3 "$@"
            ;;
    esac
}

run_bash() {
    local script="$1"; shift
    case "$RUNNER" in
        docker)
            bash "$script" --docker "$@"
            ;;
        uv)
            # M12-07: uv モード時は対応スクリプトに --uv を伝搬
            bash "$script" --uv "$@"
            ;;
        direct)
            bash "$script" --local "$@"
            ;;
    esac
}

# --- Docker イメージ確認 ---
# N12-03: mermaid サービスも事前ビルド対象に含め、narrative 段で初めて
#         build が走って長時間止まる事故を防ぐ。
# M12-02: 詳細な Dockerfile 新鮮さ検査は build_narrative.sh:preflight_docker_images
#         で実施。ここでは「イメージが存在するか」だけを確認する最低保証。
ensure_docker_image() {
    if [[ "$RUNNER" != "docker" ]]; then return; fi
    for svc in python mermaid; do
        if ! docker compose -f "$COMPOSE_FILE" images --quiet "$svc" 2>/dev/null | grep -q .; then
            echo "Docker イメージが見つかりません ($svc)。ビルドします..."
            docker compose -f "$COMPOSE_FILE" build "$svc"
        fi
    done
}

# --- ステップ関数 ---

build_validate() {
    local script="scripts/validate_yaml.py"
    echo "=== validate: YAMLバリデーション ==="
    if run_python "$script" --setup-dir "$SETUP_DIR"; then
        RESULTS[validate]="OK"
    else
        RESULTS[validate]="FAIL"
        return 1
    fi
}

build_forms() {
    local script="main/step02_docx/fill_forms.py"
    if [[ ! -f "$script" ]]; then
        RESULTS[forms]="SKIP"
        echo "SKIP: $script が未作成です"
        return
    fi
    if [[ ! -f "$DATA_DIR/r08youshiki1_5.docx" ]]; then
        RESULTS[forms]="FAIL"
        echo "FAIL: $DATA_DIR/r08youshiki1_5.docx が見つかりません" >&2
        return 1
    fi
    echo "=== forms: テーブルフォーム記入 ==="
    if run_python "$script" \
        --config "$SETUP_DIR/config.yaml" \
        --researchers "$SETUP_DIR/researchers.yaml" \
        --other-funding "$SETUP_DIR/other_funding.yaml" \
        --source "$DATA_DIR/r08youshiki1_5.docx"; then
        RESULTS[forms]="OK"
    else
        RESULTS[forms]="FAIL"
        return 1
    fi
}

build_narrative() {
    local script="main/step02_docx/build_narrative.sh"
    if [[ ! -f "$script" ]]; then
        RESULTS[narrative]="SKIP"
        echo "SKIP: $script が未作成です"
        return
    fi
    echo "=== narrative: Markdown→docx 変換 ==="
    if run_bash "$script"; then
        RESULTS[narrative]="OK"
    else
        RESULTS[narrative]="FAIL"
        return 1
    fi
}

build_inject() {
    local script="main/step02_docx/inject_narrative.py"
    if [[ ! -f "$script" ]]; then
        RESULTS[inject]="SKIP"
        echo "SKIP: $script が未作成です"
        return
    fi
    local template="main/step02_docx/output/youshiki1_5_filled.docx"
    local narr12="main/step02_docx/output/youshiki1_2_narrative.docx"
    local narr13="main/step02_docx/output/youshiki1_3_narrative.docx"

    # Fallback: DATA_DIR にnarrative stubがあれば使用（E2Eテスト用）
    if [[ ! -f "$narr12" && -f "$DATA_DIR/youshiki1_2_narrative.docx" ]]; then
        narr12="$DATA_DIR/youshiki1_2_narrative.docx"
    fi
    if [[ ! -f "$narr13" && -f "$DATA_DIR/youshiki1_3_narrative.docx" ]]; then
        narr13="$DATA_DIR/youshiki1_3_narrative.docx"
    fi

    if [[ ! -f "$template" ]]; then
        RESULTS[inject]="FAIL"
        echo "FAIL: $template が見つかりません（forms ステップを先に実行してください）" >&2
        return 1
    fi
    if [[ ! -f "$narr12" || ! -f "$narr13" ]]; then
        RESULTS[inject]="FAIL"
        echo "FAIL: narrative docx が見つかりません（narrative ステップを先に実行してください）" >&2
        return 1
    fi

    # M14-04: template がすでに inject 済みかを検査する。build.sh の
    # inject は --template と --output が同じパスなので、forms を経由せず
    # 単独再実行すると rels orphan と `_n1` 付き重複 media が累積する
    # （report14 領域 F）。narrative 由来のマーカー（wp:anchor や asvg:svgBlob）
    # を document.xml 内で検出したら、forms を自動再実行して fresh template
    # に戻す。unzip が無い環境では検査をスキップして従来挙動を維持する。
    #
    # 注意: `grep -q` と `set -o pipefail` の組合せは SIGPIPE で upstream の
    # exit code を非零にし pipeline 全体を失敗させる。`grep -c` を使い count
    # ベースで判定することで pipefail と両立させる（|| true で fail-safe）。
    if command -v unzip &>/dev/null; then
        local _marker_count
        _marker_count=$(unzip -p "$template" word/document.xml 2>/dev/null \
                            | grep -cE 'wp:anchor|asvg:svgBlob' || true)
        if [[ "${_marker_count:-0}" -gt 0 ]]; then
            echo "INFO: $template はすでに inject 済みです（marker=${_marker_count}）。forms を再実行して fresh template に戻します。"
            if ! build_forms; then
                RESULTS[inject]="FAIL"
                return 1
            fi
        fi
    fi

    echo "=== inject: ナラティブ挿入 ==="
    if run_python "$script" \
        --template "$template" \
        --youshiki12 "$narr12" \
        --youshiki13 "$narr13" \
        --output "$template"; then
        RESULTS[inject]="OK"
    else
        RESULTS[inject]="FAIL"
        return 1
    fi
}

build_security() {
    local script="main/step02_docx/fill_security.py"
    if [[ ! -f "$script" ]]; then
        RESULTS[security]="SKIP"
        echo "SKIP: $script が未作成です"
        return
    fi
    echo "=== security: セキュリティ関連書類 ==="
    if run_python "$script" \
        --config "$SETUP_DIR/config.yaml" \
        --researchers "$SETUP_DIR/researchers.yaml" \
        --security "$SETUP_DIR/security.yaml" \
        --besshi5 "$DATA_DIR/r08youshiki_besshi5.docx" \
        --betten "$DATA_DIR/r08youshiki_betten.docx"; then
        RESULTS[security]="OK"
    else
        RESULTS[security]="FAIL"
        return 1
    fi
}

build_excel() {
    local script="main/step03_excel/fill_excel.py"
    if [[ ! -f "$script" ]]; then
        RESULTS[excel]="SKIP"
        echo "SKIP: $script が未作成です"
        return
    fi
    echo "=== excel: Excel記入 ==="
    if run_python "$script" \
        --config "$SETUP_DIR/config.yaml" \
        --researchers "$SETUP_DIR/researchers.yaml" \
        --source-dir "$DATA_DIR"; then
        RESULTS[excel]="OK"
    else
        RESULTS[excel]="FAIL"
        return 1
    fi
}

build_package() {
    local script="scripts/create_package.sh"
    if [[ ! -f "$script" ]]; then
        RESULTS[package]="SKIP"
        echo "SKIP: $script が未作成です"
        return
    fi
    echo "=== package: パッケージング ==="
    if bash "$script"; then
        RESULTS[package]="OK"
    else
        RESULTS[package]="FAIL"
        return 1
    fi
}

do_clean() {
    echo "=== clean: 全output/をクリーン ==="
    local count=0
    for dir in main/step01_narrative/output \
               main/step02_docx/output \
               main/step03_excel/output \
               main/step04_package/output \
               data/output; do
        if [[ -d "$dir" ]]; then
            # .gitkeep は残す
            for f in "$dir"/*.docx "$dir"/*.xlsx "$dir"/*.pdf; do
                if [[ -f "$f" ]]; then
                    rm "$f"
                    count=$((count + 1))
                fi
            done
        fi
    done
    echo "  $count ファイルを削除しました"
}

do_check() {
    echo "=== check: 出力ファイルチェック ==="
    echo ""

    # 必須ファイル（固定名）
    local expected_files=(
        "main/step02_docx/output/youshiki1_5_filled.docx"
        "main/step02_docx/output/youshiki1_2_narrative.docx"
        "main/step02_docx/output/youshiki1_3_narrative.docx"
        "main/step02_docx/output/besshi5_filled.docx"
        "main/step03_excel/output/youshiki6.xlsx"
        "main/step03_excel/output/youshiki7.xlsx"
        "main/step03_excel/output/youshiki8.xlsx"
    )

    local ok=0
    local missing=0
    local oversize=0
    local MAX_SIZE=$((10 * 1024 * 1024))  # 10MB

    check_file() {
        local f="$1"
        if [[ -f "$f" ]]; then
            local size
            size=$(stat -c%s "$f" 2>/dev/null || stat -f%z "$f" 2>/dev/null || echo 0)
            local human
            human=$(du -h "$f" | cut -f1)
            if [[ "$size" -gt "$MAX_SIZE" ]]; then
                printf "  ✗ %-55s %s (>10MB!)\n" "$f" "$human"
                oversize=$((oversize + 1))
            else
                printf "  ✓ %-55s %s\n" "$f" "$human"
            fi
            ok=$((ok + 1))
        else
            printf "  - %-55s (未生成)\n" "$f"
            missing=$((missing + 1))
        fi
    }

    for f in "${expected_files[@]}"; do
        check_file "$f"
    done

    # 動的ファイル: betten_*.docx（研究者人数分）
    local betten_found=0
    for f in main/step02_docx/output/betten_*.docx; do
        if [[ -f "$f" ]]; then
            check_file "$f"
            betten_found=$((betten_found + 1))
        fi
    done
    if [[ "$betten_found" -eq 0 ]]; then
        printf "  - %-55s (未生成)\n" "main/step02_docx/output/betten_*.docx"
        missing=$((missing + 1))
    fi

    echo ""
    echo "結果: $ok 存在 / $missing 未生成 / $oversize サイズ超過"

    if [[ "$oversize" -gt 0 ]]; then
        echo "WARNING: 10MBを超えるファイルがあります（提出制限: 各10MB以下）" >&2
    fi
}

# --- ステップ実行 ---
run_step() {
    local step="$1"
    case "$step" in
        validate)  build_validate ;;
        forms)     build_forms ;;
        narrative) build_narrative ;;
        inject)    build_inject ;;
        security)  build_security ;;
        excel)     build_excel ;;
        package)   build_package ;;
        clean)     do_clean ;;
        check)     do_check ;;
        *)
            echo "ERROR: 不明なサブコマンド: $step" >&2
            echo "  有効なサブコマンド: validate, forms, narrative, inject, security, excel, package, clean, check" >&2
            exit 1
            ;;
    esac
}

# --- メイン ---
echo "Runner: $RUNNER"
echo "Data:   $DATA_DIR"
echo "Setup:  $SETUP_DIR"
echo ""

ensure_docker_image

ALL_STEPS=(validate forms narrative inject security excel)

for target in "${TARGETS[@]}"; do
    if [[ "$target" == "all" ]]; then
        for step in "${ALL_STEPS[@]}"; do
            run_step "$step" || RESULTS[$step]="FAIL"
            echo ""
        done
    else
        run_step "$target" || RESULTS[$target]="FAIL"
        echo ""
    fi
done

# clean / check はサマリー不要
for target in "${TARGETS[@]}"; do
    if [[ "$target" == "clean" || "$target" == "check" ]]; then
        exit 0
    fi
done

# --- サマリー ---
echo "=========================================="
echo "  ビルド結果"
echo "=========================================="

# 出力ファイル一覧
echo ""
echo "--- 出力ファイル ---"
for dir in main/step02_docx/output main/step03_excel/output; do
    if [[ -d "$dir" ]]; then
        for f in "$dir"/*.docx "$dir"/*.xlsx; do
            [[ -f "$f" ]] && printf "  %-50s %s\n" "$f" "$(du -h "$f" | cut -f1)"
        done
    fi
done

# ステップ結果
echo ""
echo "--- ステップ結果 ---"
HAS_FAIL=0

# 対象ステップの特定
if [[ " ${TARGETS[*]} " == *" all "* ]]; then
    SHOW_STEPS=("${ALL_STEPS[@]}")
else
    SHOW_STEPS=("${TARGETS[@]}")
fi

for step in "${SHOW_STEPS[@]}"; do
    status="${RESULTS[$step]:-N/A}"
    case "$status" in
        OK)   printf "  %-12s ✓ OK\n" "$step" ;;
        SKIP) printf "  %-12s - SKIP\n" "$step" ;;
        FAIL) printf "  %-12s ✗ FAIL\n" "$step"; HAS_FAIL=1 ;;
        N/A)  ;;
    esac
done
echo ""

if [[ "$HAS_FAIL" -eq 1 ]]; then
    echo "一部のステップが失敗しました" >&2
    exit 1
fi
