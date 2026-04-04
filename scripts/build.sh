#!/usr/bin/env bash
# build.sh — 全ドキュメント生成マスタースクリプト
#
# Usage:
#   ./scripts/build.sh [--docker|--local] [TARGET...]
#
# Targets:
#   all        全ステップ実行（デフォルト）
#   forms      様式1-1〜5 テーブルフォーム記入 (fill_forms.py)
#   narrative  様式1-2, 1-3 Markdown→docx (build_narrative.sh)
#   security   別紙5, 別添 セキュリティ関連 (fill_security.py)
#   excel      様式6-8 Excel記入 (fill_excel.py)

set -euo pipefail

# --- プロジェクトルート ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

# --- 設定 ---
COMPOSE_FILE="docker/docker-compose.yml"
MODE="docker"
TARGETS=()

# --- 結果追跡 ---
declare -A RESULTS=()

# --- 引数解析 ---
while [[ $# -gt 0 ]]; do
    case $1 in
        --docker) MODE="docker"; shift ;;
        --local)  MODE="local"; shift ;;
        -h|--help)
            head -14 "$0" | tail -13
            exit 0
            ;;
        *) TARGETS+=("$1"); shift ;;
    esac
done

# デフォルト: all
if [[ ${#TARGETS[@]} -eq 0 ]]; then
    TARGETS=("all")
fi

# --- Docker実行ヘルパー ---
run_docker() {
    docker compose -f "$COMPOSE_FILE" run --rm \
        -u "$(id -u):$(id -g)" python "$@"
}

# --- Docker イメージ確認 ---
ensure_docker_image() {
    if [[ "$MODE" != "docker" ]]; then return; fi
    if ! docker compose -f "$COMPOSE_FILE" images --quiet python 2>/dev/null | grep -q .; then
        echo "Docker イメージが見つかりません。ビルドします..."
        docker compose -f "$COMPOSE_FILE" build python
    fi
}

# --- ステップ関数 ---

build_forms() {
    local script="main/step02_docx/fill_forms.py"
    if [[ ! -f "$script" ]]; then
        RESULTS[forms]="SKIP"
        echo "SKIP: $script が未作成です"
        return
    fi
    if [[ ! -f "data/source/r08youshiki1_5.docx" ]]; then
        RESULTS[forms]="FAIL"
        echo "FAIL: data/source/r08youshiki1_5.docx が見つかりません" >&2
        return
    fi
    echo "=== forms: テーブルフォーム記入 ==="
    if [[ "$MODE" == "docker" ]]; then
        run_docker python "$script"
    else
        python3 "$script"
    fi
    RESULTS[forms]="OK"
}

build_narrative() {
    local script="main/step02_docx/build_narrative.sh"
    if [[ ! -f "$script" ]]; then
        RESULTS[narrative]="SKIP"
        echo "SKIP: $script が未作成です"
        return
    fi
    echo "=== narrative: Markdown→docx 変換 ==="
    if [[ "$MODE" == "docker" ]]; then
        bash "$script" --docker
    else
        bash "$script" --local
    fi
    RESULTS[narrative]="OK"
}

build_security() {
    local script="main/step02_docx/fill_security.py"
    if [[ ! -f "$script" ]]; then
        RESULTS[security]="SKIP"
        echo "SKIP: $script が未作成です"
        return
    fi
    echo "=== security: セキュリティ関連書類 ==="
    if [[ "$MODE" == "docker" ]]; then
        run_docker python "$script"
    else
        python3 "$script"
    fi
    RESULTS[security]="OK"
}

build_excel() {
    local script="main/step03_excel/fill_excel.py"
    if [[ ! -f "$script" ]]; then
        RESULTS[excel]="SKIP"
        echo "SKIP: $script が未作成です"
        return
    fi
    echo "=== excel: Excel記入 ==="
    if [[ "$MODE" == "docker" ]]; then
        run_docker python "$script"
    else
        python3 "$script"
    fi
    RESULTS[excel]="OK"
}

# --- ステップ実行 ---
run_step() {
    local step="$1"
    case "$step" in
        forms)     build_forms ;;
        narrative) build_narrative ;;
        security)  build_security ;;
        excel)     build_excel ;;
        *)
            echo "ERROR: 不明なターゲット: $step" >&2
            echo "  有効なターゲット: all, forms, narrative, security, excel" >&2
            exit 1
            ;;
    esac
}

# --- メイン ---
echo "Mode: $MODE"
echo ""

ensure_docker_image

ALL_STEPS=(forms narrative security excel)

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
for step in "${ALL_STEPS[@]}"; do
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
