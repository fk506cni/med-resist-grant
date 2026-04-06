#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# create_package.sh — ビルド成果物を集約し、提出前バリデーション
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

# ソースディレクトリ
DOCX_OUTPUT="main/step02_docx/output"
EXCEL_OUTPUT="main/step03_excel/output"
PACKAGE_OUTPUT="main/step04_package/output"

# サイズ制限
MAX_SIZE=$((10 * 1024 * 1024))   # 10MB: e-Rad上限
WARN_SIZE=$((3 * 1024 * 1024))   # 3MB: 目標上限

# --- ヘルパー関数 ---

human_size() {
    local bytes="$1"
    if [[ "$bytes" -ge $((1024 * 1024)) ]]; then
        printf "%.1fMB" "$(echo "scale=1; $bytes / 1048576" | bc)"
    elif [[ "$bytes" -ge 1024 ]]; then
        printf "%.0fKB" "$(echo "scale=0; $bytes / 1024" | bc)"
    else
        printf "%dB" "$bytes"
    fi
}

file_size() {
    stat -c%s "$1" 2>/dev/null || stat -f%z "$1" 2>/dev/null || echo 0
}

# --- 必須ファイルリスト ---

# 固定名ファイル（docx）
# ※ youshiki1_2/1_3_narrative.docx は youshiki1_5_filled.docx に統合済み
REQUIRED_DOCX=(
    "youshiki1_5_filled.docx"
    "besshi5_filled.docx"
)

# 固定名ファイル（xlsx）
REQUIRED_XLSX=(
    "youshiki6.xlsx"
    "youshiki7.xlsx"
    "youshiki8.xlsx"
)

# --- バリデーション ---

echo "=== create_package: 提出パッケージ作成 ==="
echo ""

errors=0
warnings=0

# Step 1: ソースディレクトリの存在確認
for dir in "$DOCX_OUTPUT" "$EXCEL_OUTPUT"; do
    if [[ ! -d "$dir" ]]; then
        echo "ERROR: ディレクトリが存在しません: $dir" >&2
        echo "  → 先にビルドを実行してください: ./scripts/build.sh" >&2
        errors=$((errors + 1))
    fi
done

if [[ "$errors" -gt 0 ]]; then
    echo ""
    echo "エラーがあるため中断します。"
    exit 1
fi

# Step 2: 必須ファイルの存在チェック
echo "--- ファイル存在チェック ---"
echo ""

missing_files=()

for f in "${REQUIRED_DOCX[@]}"; do
    path="$DOCX_OUTPUT/$f"
    if [[ ! -f "$path" ]]; then
        printf "  ✗ %s (未生成)\n" "$path"
        missing_files+=("$path")
    else
        printf "  ✓ %s\n" "$path"
    fi
done

for f in "${REQUIRED_XLSX[@]}"; do
    path="$EXCEL_OUTPUT/$f"
    if [[ ! -f "$path" ]]; then
        printf "  ✗ %s (未生成)\n" "$path"
        missing_files+=("$path")
    else
        printf "  ✓ %s\n" "$path"
    fi
done

# 動的ファイル: betten_*.docx（研究者人数分）
betten_files=()
for f in "$DOCX_OUTPUT"/betten_*.docx; do
    if [[ -f "$f" ]]; then
        betten_files+=("$f")
        printf "  ✓ %s\n" "$f"
    fi
done

if [[ ${#betten_files[@]} -eq 0 ]]; then
    printf "  ✗ %s/betten_*.docx (未生成)\n" "$DOCX_OUTPUT"
    missing_files+=("$DOCX_OUTPUT/betten_*.docx")
fi

echo ""

if [[ ${#missing_files[@]} -gt 0 ]]; then
    echo "ERROR: ${#missing_files[@]} 個のファイルが不足しています" >&2
    echo "  → ビルドを実行してください: ./scripts/build.sh" >&2
    echo ""
    errors=$((errors + 1))
fi

# Step 3: パッケージディレクトリへコピー
echo "--- パッケージ作成 ---"
echo ""

mkdir -p "$PACKAGE_OUTPUT"

# 既存ファイルをクリア
if [[ -n "$(ls -A "$PACKAGE_OUTPUT" 2>/dev/null)" ]]; then
    rm -f "$PACKAGE_OUTPUT"/*
    echo "  既存ファイルをクリアしました"
fi

copied=0

# docxファイルをコピー
for f in "${REQUIRED_DOCX[@]}"; do
    src="$DOCX_OUTPUT/$f"
    if [[ -f "$src" ]]; then
        cp "$src" "$PACKAGE_OUTPUT/"
        copied=$((copied + 1))
    fi
done

# betten_*.docxをコピー
for f in "${betten_files[@]}"; do
    cp "$f" "$PACKAGE_OUTPUT/"
    copied=$((copied + 1))
done

# xlsxファイルをコピー
for f in "${REQUIRED_XLSX[@]}"; do
    src="$EXCEL_OUTPUT/$f"
    if [[ -f "$src" ]]; then
        cp "$src" "$PACKAGE_OUTPUT/"
        copied=$((copied + 1))
    fi
done

echo "  $copied ファイルを $PACKAGE_OUTPUT/ にコピーしました"
echo ""

# Step 4: ファイルサイズチェック
echo "--- ファイルサイズチェック ---"
echo ""

oversize=0
over_warn=0

for f in "$PACKAGE_OUTPUT"/*; do
    if [[ ! -f "$f" ]]; then
        continue
    fi
    local_size=$(file_size "$f")
    local_human=$(human_size "$local_size")
    fname=$(basename "$f")

    if [[ "$local_size" -gt "$MAX_SIZE" ]]; then
        printf "  ✗ %-45s %s (>10MB: 提出不可!)\n" "$fname" "$local_human"
        oversize=$((oversize + 1))
    elif [[ "$local_size" -gt "$WARN_SIZE" ]]; then
        printf "  △ %-45s %s (>3MB: 要確認)\n" "$fname" "$local_human"
        over_warn=$((over_warn + 1))
    else
        printf "  ✓ %-45s %s\n" "$fname" "$local_human"
    fi
done

echo ""

if [[ "$oversize" -gt 0 ]]; then
    echo "ERROR: $oversize 個のファイルが10MBを超えています（提出制限超過）" >&2
    errors=$((errors + 1))
fi
if [[ "$over_warn" -gt 0 ]]; then
    echo "WARNING: $over_warn 個のファイルが3MBを超えています" >&2
    warnings=$((warnings + 1))
fi

# Step 5: チェックリスト出力
echo ""
echo "=========================================="
echo "  提出チェックリスト"
echo "=========================================="
echo ""

# 様式1-1〜5（様式1-2/1-3本文をinject済み）
if [[ -f "$PACKAGE_OUTPUT/youshiki1_5_filled.docx" ]]; then
    sz=$(human_size "$(file_size "$PACKAGE_OUTPUT/youshiki1_5_filled.docx")")
    echo "  ☑ 様式1-1〜5:  youshiki1_5_filled.docx ($sz)"
    echo "     （様式1-2/1-3本文 統合済み）"
else
    echo "  ☐ 様式1-1〜5:  youshiki1_5_filled.docx (未生成)"
fi

# 別紙5
if [[ -f "$PACKAGE_OUTPUT/besshi5_filled.docx" ]]; then
    sz=$(human_size "$(file_size "$PACKAGE_OUTPUT/besshi5_filled.docx")")
    echo "  ☑ 別紙5:       besshi5_filled.docx ($sz)"
else
    echo "  ☐ 別紙5:       besshi5_filled.docx (未生成)"
fi

# 別添（人数分）
betten_count=0
for f in "$PACKAGE_OUTPUT"/betten_*.docx; do
    if [[ -f "$f" ]]; then
        fname=$(basename "$f")
        sz=$(human_size "$(file_size "$f")")
        echo "  ☑ 別添:         $fname ($sz)"
        betten_count=$((betten_count + 1))
    fi
done
if [[ "$betten_count" -eq 0 ]]; then
    echo "  ☐ 別添:         betten_*.docx (未生成)"
else
    echo "     (別添 ${betten_count}人分)"
fi

# 様式6
if [[ -f "$PACKAGE_OUTPUT/youshiki6.xlsx" ]]; then
    sz=$(human_size "$(file_size "$PACKAGE_OUTPUT/youshiki6.xlsx")")
    echo "  ☑ 様式6:       youshiki6.xlsx ($sz)"
else
    echo "  ☐ 様式6:       youshiki6.xlsx (未生成)"
fi

# 様式7
if [[ -f "$PACKAGE_OUTPUT/youshiki7.xlsx" ]]; then
    sz=$(human_size "$(file_size "$PACKAGE_OUTPUT/youshiki7.xlsx")")
    echo "  ☑ 様式7:       youshiki7.xlsx ($sz)"
else
    echo "  ☐ 様式7:       youshiki7.xlsx (未生成)"
fi

# 様式8
if [[ -f "$PACKAGE_OUTPUT/youshiki8.xlsx" ]]; then
    sz=$(human_size "$(file_size "$PACKAGE_OUTPUT/youshiki8.xlsx")")
    echo "  ☑ 様式8:       youshiki8.xlsx ($sz)"
else
    echo "  ☐ 様式8:       youshiki8.xlsx (未生成)"
fi

echo ""
echo "  --- 手動確認項目 ---"
echo "  ☐ Windows側PDF変換（youshiki1_5_filled.docx → PDF）"
echo "  ☐ PDF確認: 様式1-2/1-3の本文が挿入されていること"
echo "  ☐ PDF確認: ページ番号が通しで振られていること"
echo "  ☐ e-Radアップロード（提出期限: 2026-05-20 正午）"
echo ""

# --- 最終結果 ---
echo "=========================================="
if [[ "$errors" -gt 0 ]]; then
    echo "  結果: エラーあり ($errors 件)"
    echo "=========================================="
    exit 1
elif [[ "$warnings" -gt 0 ]]; then
    echo "  結果: 警告あり ($warnings 件) — 確認してください"
    echo "=========================================="
    exit 0
else
    echo "  結果: OK — 全ファイル準備完了"
    echo "=========================================="
    exit 0
fi
