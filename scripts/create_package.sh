#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# create_package.sh — ビルド成果物を集約し、提出前バリデーション
# ============================================================
#
# 環境変数:
#   PACKAGE_MODE  submission | interview  (default: submission)
#                 — submission: 応募時 (2026-05-20) 提出物のみ
#                              （様式1-1〜5+参考様式 + 様式6/7/8 + 結合PDF）
#                 — interview:  面接時 (7月中旬) 提出物のみ
#                              （別紙5 + 別添人数分 + 結合PDF）
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

# ソースディレクトリ
DOCX_OUTPUT="main/step02_docx/output"
EXCEL_OUTPUT="main/step03_excel/output"
PRODUCTS_DIR="data/products"
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

# --- モード判定 ---
# C15-01: 応募時パッケージに別添 (betten) を混入させない設計。
# submission は別紙5/別添を含めず、interview は様式1-5/様式6-8 を含めない。
PACKAGE_MODE="${PACKAGE_MODE:-submission}"

case "$PACKAGE_MODE" in
    submission)
        REQUIRED_DOCX=("youshiki1_5_filled.docx")
        REQUIRED_XLSX=("youshiki6.xlsx" "youshiki7.xlsx" "youshiki8.xlsx")
        INCLUDE_BETTEN=false
        MERGED_PDF_SRC="$PRODUCTS_DIR/submission_merged.pdf"
        MERGED_PDF_LABEL="応募時 e-Rad 添付物（様式1-1〜5+参考様式の単一 PDF）"
        ;;
    interview)
        REQUIRED_DOCX=("besshi5_filled.docx")
        REQUIRED_XLSX=()
        INCLUDE_BETTEN=true
        MERGED_PDF_SRC="$PRODUCTS_DIR/interview_merged.pdf"
        MERGED_PDF_LABEL="面接時提出物（別紙5+別添の結合 PDF）"
        ;;
    *)
        echo "ERROR: 未知の PACKAGE_MODE='$PACKAGE_MODE' (submission|interview)" >&2
        exit 1
        ;;
esac

# --- バリデーション ---

echo "=== create_package: 提出パッケージ作成 (mode=$PACKAGE_MODE) ==="
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

# 動的ファイル: betten_*.docx（interview のみ、研究者人数分）
betten_files=()
if [[ "$INCLUDE_BETTEN" == "true" ]]; then
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

# 既存ファイルをクリア（モード切替時の前回成果物混入防止も兼ねる）
if [[ -n "$(ls -A "$PACKAGE_OUTPUT" 2>/dev/null)" ]]; then
    rm -f "$PACKAGE_OUTPUT"/*
    echo "  既存ファイルをクリアしました"
fi

copied=0

# docx
for f in "${REQUIRED_DOCX[@]}"; do
    src="$DOCX_OUTPUT/$f"
    if [[ -f "$src" ]]; then
        cp "$src" "$PACKAGE_OUTPUT/"
        copied=$((copied + 1))
    fi
done

# betten (interview のみ)
if [[ "$INCLUDE_BETTEN" == "true" ]]; then
    for f in "${betten_files[@]}"; do
        cp "$f" "$PACKAGE_OUTPUT/"
        copied=$((copied + 1))
    done
fi

# xlsx
for f in "${REQUIRED_XLSX[@]}"; do
    src="$EXCEL_OUTPUT/$f"
    if [[ -f "$src" ]]; then
        cp "$src" "$PACKAGE_OUTPUT/"
        copied=$((copied + 1))
    fi
done

# 結合済み PDF（mode に応じて submission_merged.pdf or interview_merged.pdf）
if [[ -f "$MERGED_PDF_SRC" ]]; then
    cp "$MERGED_PDF_SRC" "$PACKAGE_OUTPUT/"
    copied=$((copied + 1))
fi

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
echo "  提出チェックリスト (mode=$PACKAGE_MODE)"
echo "=========================================="
echo ""

merged_basename="$(basename "$MERGED_PDF_SRC")"

if [[ "$PACKAGE_MODE" == "submission" ]]; then
    # --- 応募時 ---
    if [[ -f "$PACKAGE_OUTPUT/youshiki1_5_filled.docx" ]]; then
        sz=$(human_size "$(file_size "$PACKAGE_OUTPUT/youshiki1_5_filled.docx")")
        echo "  ☑ 様式1-1〜5:  youshiki1_5_filled.docx ($sz)"
        echo "     （様式1-2/1-3本文 統合済み、参考様式 含む）"
    else
        echo "  ☐ 様式1-1〜5:  youshiki1_5_filled.docx (未生成)"
    fi

    if [[ -f "$PACKAGE_OUTPUT/$merged_basename" ]]; then
        sz=$(human_size "$(file_size "$PACKAGE_OUTPUT/$merged_basename")")
        echo "  ☑ 結合PDF:    $merged_basename ($sz)"
        echo "     （$MERGED_PDF_LABEL）"
    else
        echo "  ☐ 結合PDF:    $merged_basename (未生成)"
        echo "     → roundtrip.sh で Windows PDF 化 → Phase 5 で生成されます"
    fi

    for n in 6 7 8; do
        f="$PACKAGE_OUTPUT/youshiki${n}.xlsx"
        if [[ -f "$f" ]]; then
            sz=$(human_size "$(file_size "$f")")
            echo "  ☑ 様式${n}:       youshiki${n}.xlsx ($sz)"
        else
            echo "  ☐ 様式${n}:       youshiki${n}.xlsx (未生成)"
        fi
    done

    echo ""
    echo "  --- 手動確認項目（応募時） ---"
    echo "  ☐ PDF確認: 様式1-2/1-3の本文が挿入されていること"
    echo "  ☐ PDF確認: ページ番号が通しで振られていること"
    echo "  ☐ PDF確認: 承諾書の placeholder が全て埋まっていること"
    echo "  ☐ PDF確認: 「○○」「△△」「□□」「XX」等の placeholder が残っていない"
    echo "  ☐ e-Radアップロード（提出期限: 2026-05-20 正午）"

elif [[ "$PACKAGE_MODE" == "interview" ]]; then
    # --- 面接時 ---
    if [[ -f "$PACKAGE_OUTPUT/besshi5_filled.docx" ]]; then
        sz=$(human_size "$(file_size "$PACKAGE_OUTPUT/besshi5_filled.docx")")
        echo "  ☑ 別紙5:       besshi5_filled.docx ($sz)"
    else
        echo "  ☐ 別紙5:       besshi5_filled.docx (未生成)"
    fi

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

    if [[ -f "$PACKAGE_OUTPUT/$merged_basename" ]]; then
        sz=$(human_size "$(file_size "$PACKAGE_OUTPUT/$merged_basename")")
        echo "  ☑ 結合PDF:    $merged_basename ($sz)"
        echo "     （$MERGED_PDF_LABEL）"
    else
        echo "  ☐ 結合PDF:    $merged_basename (未生成)"
        echo "     → MERGE_MODE=interview ./scripts/build.sh merge で生成"
    fi

    echo ""
    echo "  --- 手動確認項目（面接時） ---"
    echo "  ☐ 別添の研究者数が researchers.yaml と一致すること"
    echo "  ☐ 機微情報が含まれるため取扱い注意"
fi

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
    echo "  結果: OK — 全ファイル準備完了 (mode=$PACKAGE_MODE)"
    echo "=========================================="
    exit 0
fi
