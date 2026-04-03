#!/bin/bash

# 本番環境持ち込み用パッケージ作成スクリプト
# main/、docker/、外部マッパー等をzipファイルにまとめます
#
# 使用方法:
#   ./create_package.sh              # パッケージ作成 + Google Driveアップロード（デフォルト）
#   ./create_package.sh --no-upload  # パッケージ作成のみ（アップロードなし）
#   ./create_package.sh -n           # 同上（短縮形）

set -e

# コマンドライン引数処理
AUTO_UPLOAD=true
for arg in "$@"; do
    case $arg in
        --no-upload|-n)
            AUTO_UPLOAD=false
            shift
            ;;
    esac
done

# 基本設定
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
PROJECT_NAME="$(basename "$PROJECT_ROOT")"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
ZIP_FILENAME="cancer_claims_validation_package_${TIMESTAMP}.zip"
OUTPUT_DIR="/tmp/${PROJECT_NAME}"
ZIP_PATH="${OUTPUT_DIR}/${ZIP_FILENAME}"
ARCHIVE_DIR="${PROJECT_ROOT}/__archives"

echo "パッケージ作成開始: ${ZIP_FILENAME}"
echo "基準ディレクトリ: ${PROJECT_ROOT}"
echo "出力先: ${OUTPUT_DIR}/"

# 作業ディレクトリに移動
cd "${PROJECT_ROOT}"

# 出力ディレクトリ作成
if [ ! -d "${OUTPUT_DIR}" ]; then
    echo "出力ディレクトリを作成: ${OUTPUT_DIR}"
    mkdir -p "${OUTPUT_DIR}"
fi

# __archivesディレクトリ作成
if [ ! -d "${ARCHIVE_DIR}" ]; then
    echo "__archivesディレクトリを作成..."
    mkdir -p "${ARCHIVE_DIR}"
fi

# プロジェクトルート直下の既存zipファイルを__archivesに移動
if ls cancer_claims_validation_package_*.zip 1> /dev/null 2>&1; then
    echo "既存のパッケージファイルを__archivesに移動..."
    mv cancer_claims_validation_package_*.zip "${ARCHIVE_DIR}/"
    echo "$(ls ${ARCHIVE_DIR}/cancer_claims_validation_package_*.zip 2>/dev/null | wc -l) 個のファイルを移動しました"
fi

# パッケージ情報ファイル作成
create_package_info() {
    cat > PACKAGE_INFO.md << EOF
# Cancer Claims Validation パッケージ情報

作成日時: $(date "+%Y-%m-%d %H:%M:%S")
パッケージID: cancer_claims_validation_package_${TIMESTAMP}

## 含まれるファイル

### main/ フォルダ
- step0_interval_analysis/: Location interval分析
- step1_table1/: Table 1生成（R）
- step2_hsta_module/: HSTAモジュール（Python）
- step3_location_sets/: Location Set生成
- step4_evaluation/: 評価指標計算
- step5_visualization/: 可視化（R）
- notebooks/: 検証用Jupyterノートブック

### docker/ フォルダ
- docker-compose.yml: コンテナ設定
- python/: Pythonコンテナ設定
- r/: RStudioコンテナ設定

### scripts/ フォルダ
- generate_dummy_data.py: ダミーデータ生成
- backup.sh: バックアップスクリプト
- create_package.sh: 本スクリプト
- deploy_to_network.bat: Windows展開バッチ

### ドキュメント
- CLAUDE.md: AI開発エージェント向け指示書
- SPEC.md: 技術仕様書
- README.md: プロジェクト概要
- formula.md: 数式定義
- prompts.md: 実装プロンプト集
- materials_and_methods.md: 論文用手法説明

## 使用方法

1. このzipファイルを本番環境に展開
2. docker/ 配下で \`docker compose up -d\` を実行
3. data/source/ 配下に本番データのシンボリックリンクを作成:
   - rece.pq → レセプトデータ
   - regi.pq → 癌登録データ
   - si.pq → 診療行為データ
4. 各Stepを順番に実行

## 注意事項

- data/source/ は本パッケージに含まれていません
- 本番データへのシンボリックリンクを手動で作成してください
- Dockerコンテナはホスト127.0.0.1にバインドされます
- SSHトンネル経由でJupyter/RStudioにアクセス:
  \`\`\`bash
  ssh -L 8889:127.0.0.1:8889 -L 8787:127.0.0.1:8787 user@server
  \`\`\`

## ファイル構成

\`\`\`
cancer_claims_validation_package/
├── main/
│   ├── step0_interval_analysis/
│   ├── step1_table1/
│   ├── step2_hsta_module/
│   ├── step3_location_sets/
│   ├── step4_evaluation/
│   ├── step5_visualization/
│   └── notebooks/
├── docker/
│   ├── docker-compose.yml
│   ├── python/
│   └── r/
├── scripts/
├── data/
│   └── dummy/  (ダミーデータのみ)
├── CLAUDE.md
├── SPEC.md
├── README.md
├── formula.md
├── prompts.md
├── materials_and_methods.md
└── PACKAGE_INFO.md
\`\`\`
EOF
}

# パッケージ情報ファイル作成
echo "パッケージ情報ファイルを作成..."
create_package_info

# zipファイル作成
echo "zipファイルを作成中..."

# 除外パターンを設定したzipコマンド実行
zip -r "${ZIP_PATH}" \
    main/ \
    docker/ \
    scripts/ \
    data/dummy/ \
    PACKAGE_INFO.md \
    -x \
    "**/__pycache__/*" \
    "**/*.pyc" \
    "**/*.pyo" \
    "**/.DS_Store" \
    "**/.ipynb_checkpoints/*" \
    "**/*.tmp" \
    "**/.git/*" \
    "**/.git" \
    "**/output/*.parquet" \
    "**/output/*.xlsx" \
    "**/output/*.csv" \
    "main/step3_location_sets/output/*" \
    "main/step4_evaluation/output/*" \
    "main/step5_visualization/output/*"

# ドキュメントファイルを追加
for doc in CLAUDE.md SPEC.md README.md formula.md prompts.md materials_and_methods.md; do
    if [ -f "$doc" ]; then
        echo "${doc}ファイルを追加..."
        zip "${ZIP_PATH}" "$doc"
    fi
done

# 一時ファイル削除
rm -f PACKAGE_INFO.md

# 結果表示
echo ""
echo "=============================================="
echo " パッケージ作成完了: ${ZIP_PATH}"
echo "=============================================="
echo " ファイルサイズ: $(du -h "${ZIP_PATH}" | cut -f1)"

# zip内容確認（フォルダ構造のみ）
echo ""
echo "=== パッケージ構成 ==="
unzip -l "${ZIP_PATH}" | head -50
echo "..."
echo "(合計 $(unzip -l "${ZIP_PATH}" | tail -1))"

# Google Driveへのアップロード処理
if [ "$AUTO_UPLOAD" = true ]; then
    # --upload オプション指定時は自動アップロード
    echo ""
    echo "Google Driveにアップロード中..."
    "${SCRIPT_DIR}/upload_to_gdrive.sh"
elif [ -t 0 ]; then
    # インタラクティブモードの場合は確認
    echo ""
    read -p "Google Driveにアップロードしますか？ (y/N): " UPLOAD_CHOICE
    if [[ "$UPLOAD_CHOICE" =~ ^[Yy]$ ]]; then
        echo ""
        echo "Google Driveにアップロード中..."
        "${SCRIPT_DIR}/upload_to_gdrive.sh"
    else
        echo ""
        echo "次のステップ:"
        echo "1. ${ZIP_PATH} を本番環境にアップロード"
        echo "   - 手動: Google Driveにアップロード後、Windows環境でダウンロード"
        echo "   - 自動: ./scripts/upload_to_gdrive.sh を実行"
        echo "2. 本番環境で unzip ${ZIP_PATH} を実行"
        echo "3. data/source/ にデータのシンボリックリンクを作成"
        echo "4. docker compose up -d でコンテナ起動"
        echo ""
        echo "Windows環境からの展開:"
        echo "  scripts/deploy_to_network.bat を実行"
    fi
else
    # 非インタラクティブモードかつアップロードなしの場合は案内のみ
    echo ""
    echo "次のステップ:"
    echo "1. ${ZIP_PATH} を本番環境にアップロード"
    echo "   - 自動: ./scripts/create_package.sh（デフォルトでアップロード）"
    echo "   - 手動: ./scripts/upload_to_gdrive.sh を実行"
    echo "2. 本番環境で unzip ${ZIP_PATH} を実行"
    echo "3. data/source/ にデータのシンボリックリンクを作成"
    echo "4. docker compose up -d でコンテナ起動"
    echo ""
    echo "Windows環境からの展開:"
    echo "  scripts/deploy_to_network.bat を実行"
fi
