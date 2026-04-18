# CLAUDE.md - AI Assistant Context

## Project Overview

**プロジェクト名**: med-resist-grant（薬剤耐性研究 科研費申請書類作成システム）
**概要**: 令和8年度 安全保障技術研究推進制度（委託事業）の申請書類を、Markdownソース管理＋自動変換で作成するシステム。

**応募先**: 防衛装備庁 安全保障技術研究推進制度
**研究テーマ**: (23) 医療・医工学に関する基礎研究（サイバー攻撃×地域医療シミュレーション）
**応募タイプ**: Type A（年間最大5200万円 ＝ 直接経費4,000万円+間接経費30%、最大3年）想定
**提出期限**: 2026年5月20日(水) 正午（e-Rad経由）

## Quick Reference

### Project Structure

```
med-resist-grant/
├── CLAUDE.md                    # AI アシスタント向けコンテキスト（本ファイル）
├── SPEC.md                      # 技術仕様書
├── README.md                    # プロジェクト概要
├── .env                         # 環境変数 (gitignored, Webhook URL・rcloneパス等)
├── .env.example                 # .env テンプレート（Webhook URL 空欄）
├── scripts/build.sh             # ビルドスクリプト
├── __archives/                  # 退避先 (gitignored)
├── data/
│   ├── source/                  # オリジナル様式ファイル (gitignored, 改変不可)
│   │   ├── r08youshiki1_5.docx  # 様式1-1〜5 + 参考様式 + チェックリスト
│   │   ├── r08youshiki_besshi5.docx  # 別紙5: 研究セキュリティ質問票
│   │   ├── r08youshiki_betten.docx   # 別添: セキュリティ自己申告書
│   │   ├── r08youshiki6.xlsx    # 様式6: 申請概要
│   │   ├── r08youshiki7.xlsx    # 様式7: 研究者一覧
│   │   ├── r08youshiki8.xlsx    # 様式8: 連絡先
│   │   └── 募集要項.pdf          # 公募要領 (44p + 別紙)
│   ├── dummy/                   # E2Eテスト用ダミーデータ (git管理、generate_stubs.py でスタブ生成)
│   ├── output/                  # ビルド成果物集約先 (gitignored)
│   └── products/                # Windows変換済みPDF (gitignored)
├── docker/                      # Docker設定
│   ├── docker-compose.yml
│   └── python/Dockerfile
├── docs/
│   ├── prompts.md               # 実装プロンプト集（Step 8〜）
│   ├── prompts_trash.md         # 完了済みプロンプト（Steps 0-7 アーカイブ）
│   ├── step4plan.md             # 様式1-2/1-3 統合実装計画
│   ├── template_analysis.md     # テンプレート構造解析レポート（Prompt 9-1 成果物）
│   └── __archives/
├── jank/                        # 一時ファイル (gitignored)
├── main/
│   ├── 00_setup/                # 共通設定・メタデータ (YAML)
│   │   ├── config.yaml          # プロジェクト設定
│   │   ├── researchers.yaml     # 研究者情報
│   │   ├── other_funding.yaml   # 他制度応募状況
│   │   ├── security.yaml        # セキュリティ情報
│   │   └── package.yaml         # PDF結合設定 (submission/interview の sources・metadata)
│   ├── step01_narrative/        # Markdown本文ソース
│   │   ├── youshiki1_2.md       # 様式1-2: 研究計画詳細 (最大15p)
│   │   ├── youshiki1_3.md       # 様式1-3: 追加説明事項
│   │   └── output/
│   ├── step02_docx/             # Word文書生成
│   │   ├── fill_forms.py        # テーブルフォーム記入
│   │   ├── fill_security.py     # セキュリティ関連記入
│   │   ├── build_narrative.sh   # Pandoc変換
│   │   ├── inject_narrative.py  # 様式1-2/1-3本文をテンプレートに挿入 (OOXML)
│   │   └── output/
│   ├── step03_excel/            # Excel文書生成
│   │   ├── fill_excel.py        # Excel記入
│   │   └── output/
│   └── step04_package/          # パッケージング
│       ├── merge_pdfs.py        # 結合PDF生成 (pypdf, package.yaml 駆動)
│       └── output/
├── refs/                        # 参考資料 (gitignored)
├── templates/                   # Pandoc reference-doc 等
│   └── reference.docx           # Pandocスタイル定義 (デフォルト生成済み、スタイル要調整)
└── scripts/
    ├── build.sh                 # 全ドキュメント生成 (RUNNER=docker/uv/direct)
    ├── validate_yaml.py         # YAMLバリデーション (build.sh validate から呼出、--setup-dir で参照先変更可)
    ├── roundtrip.sh             # ビルド→push→PDF待ち→pull 一括実行
    ├── create_package.sh        # パッケージング・バリデーション (成果物集約・サイズチェック・チェックリスト)
    ├── sync_gdrive.sh           # Google Drive同期 (rclone copy)
    ├── collab_watcher.sh        # 共同執筆トリガー監視 (Google Drive polling → ビルド → 成果物配信 → Google Chat通知)
    ├── collab/                  # 共同執筆用リソース
    │   └── README_使い方.md     # 共同研究者向け使い方説明
    └── windows/                 # Windows側PDF変換スクリプト
        ├── watch-and-convert.ps1   # フォルダ監視 docx→PDF 自動変換
        └── watch-and-convert.bat   # PS1のランチャー
```

### 提出書類一覧

| 書類 | 形式 | 生成方法 | 提出形式 | 提出タイミング |
|------|------|----------|----------|--------------|
| 様式1-1: 申請書概要 | docx | python-docx (テーブル記入) | PDF | 応募時(5/20) |
| 様式1-2: 申請書詳細 | docx | Pandoc→inject_narrative.py で統合 | PDF | 応募時(5/20) |
| 様式1-3: 追加説明事項 | docx | Pandoc→inject_narrative.py で統合 | PDF | 応募時(5/20) |
| 様式2-1: 研究費見込額 | docx | python-docx (テーブル記入) | PDF | 応募時(5/20) |
| 様式2-2: 研究費計画書 | docx | python-docx (テーブル記入) | PDF | 応募時(5/20) |
| 様式3-1: 他制度(代表者) | docx | python-docx (テーブル記入) | PDF | 応募時(5/20) |
| 様式3-2: 他制度(分担者) | docx | python-docx (テーブル記入) | PDF | 応募時(5/20) |
| 様式4-1: 代表者調書 | docx | python-docx (テーブル記入) | PDF | 応募時(5/20) |
| 様式4-2: 分担者調書 | docx | python-docx (テーブル記入) | PDF | 応募時(5/20) |
| 様式5: 法人概要 | docx | python-docx (該当時のみ) | PDF | 応募時(5/20) |
| 参考様式: 承諾書 | docx | python-docx | PDF | 応募時(5/20) |
※ 参考様式は3種類（委託・代表機関 / 委託・分担機関 / 補助金）。Type Aでは補助金版を削除。
| 別紙5: セキュリティ質問票 | docx | python-docx | PDF | 面接選出後(7月中旬) |
| 別添: 自己申告書 | docx | python-docx (人数分) | PDF | 面接選出後(7月中旬) |
| 様式6: 申請概要 | xlsx | openpyxl | Excel | 応募時(5/20) |
| 様式7: 研究者一覧 | xlsx | openpyxl | Excel | 応募時(5/20) |
| 様式8: 連絡先 | xlsx | openpyxl | Excel | 応募時(5/20) |

※ 様式1-1〜5 + 参考様式は **1つのPDF** に結合して提出（未記入の様式は削除すること）
  → 現状は `youshiki1_5_filled.docx` 1 docx に統合済み、Windows Word PDF 化で
    `youshiki1_5_filled.pdf` を生成、`merge_pdfs.py` (pypdf) が
    `submission_merged.pdf` として metadata 付きで仕上げる。将来様式単位に分割
    した際は `main/00_setup/package.yaml` の `sources` リストを更新するだけで対応。
※ チェックリストの提出は不要（提出前の自己確認用）

### Tech Stack

| 用途 | 技術 |
|------|------|
| 本文執筆 | Markdown (Pandoc Markdown) |
| メタデータ | YAML |
| Word変換 | Pandoc 3.6.x + python-docx |
| Excel記入 | openpyxl |
| PDF結合 | pypdf (Linux/Docker, package.yaml 駆動) |
| 実行環境 | Docker / uv |
| Word修復・PDF化 | Windows + Word COM API |
| データ同期 | Google Drive (rclone copy) |
| バージョン管理 | Git |

### 参考プロジェクト

- `/home/dryad/anal/jami-abstract-pandoc/` — JAMI学会抄録のMarkdown→Word変換システム
  - Pandocワークフロー、Docker構成、Luaフィルタ、OOXML後処理等を参考

### Build

```bash
# 全ステップ実行（デフォルト: Docker経由）
./scripts/build.sh

# サブコマンド: validate, forms, narrative, inject, security, excel, merge, package, clean, check
./scripts/build.sh validate    # YAMLバリデーションのみ
./scripts/build.sh clean       # 全output/をクリーン
./scripts/build.sh check       # 出力ファイルの存在・サイズチェック
MERGE_MODE=submission ./scripts/build.sh merge   # data/products/*.pdf を結合
                                                 #   (通常は roundtrip.sh Phase 5 から自動呼出)

# 実行環境切替（RUNNER環境変数）
RUNNER=docker ./scripts/build.sh   # Docker (デフォルト)
RUNNER=uv ./scripts/build.sh       # uv run 経由
RUNNER=direct ./scripts/build.sh   # 直接実行

# E2Eテスト（data/source/ の実ファイル不要、ダミーデータで全ステップ実行）
RUNNER=docker DATA_DIR=data/dummy SETUP_DIR=data/dummy ./scripts/build.sh

# 環境変数:
#   DATA_DIR   — 様式テンプレート参照先 (デフォルト: data/source)
#   SETUP_DIR  — YAML設定参照先 (デフォルト: main/00_setup)
```

### Containers

```bash
# コンテナ起動
docker compose -f docker/docker-compose.yml up -d --build

# スクリプト実行（コンテナ内）
docker compose -f docker/docker-compose.yml run --rm -u $(id -u):$(id -g) python \
  python main/step02_docx/fill_forms.py

# コンテナ停止
docker compose -f docker/docker-compose.yml down
```

## Development Guidelines

### 重要な制約

1. **data/source/ のファイルは絶対に変更しない** — 常にコピーして編集
2. **ホストPythonを汚さない** — Docker or uv経由で実行
3. **提出ファイルサイズ**: 各10MB以下、目標3MB
4. **様式1-2は最大15ページ**

### ワークフロー

1. `main/00_setup/*.yaml` にメタデータを記入
2. `main/step01_narrative/*.md` に本文を執筆
3. `./scripts/roundtrip.sh` でビルド→push→PDF変換待ち→pull→結合 を一括実行
   - ビルド成果物: `data/output/` (docx/xlsx)
   - 変換済みPDF: `data/products/`
   - 結合PDF: `data/products/submission_merged.pdf`（Phase 5、Windows gdrive にも push back）
4. Windows側では `watch-and-convert.ps1` が常駐してdocx→PDF自動変換
5. e-Radで `submission_merged.pdf` ＋ 様式6/7/8.xlsx を提出

### Step-by-Step Pipeline

- 各ステップは `main/stepNN_name/` に配置
- ステップ間のデータ受け渡しは `output/` ディレクトリ経由
- 各ステップは独立して再実行可能であること
- ステップ追加時は連番を維持する

### Naming Conventions

- メタデータ: `main/00_setup/*.yaml`
- 本文Markdown: `main/step01_narrative/*.md`
- Pythonスクリプト: `main/stepNN_*/fill_*.py`, `build_*.sh`
- 出力: `main/stepNN_*/output/`

### Output Handling

- 各ステップの出力は `main/stepNN_xxx/output/` に配置
- すべての `output/` は `.gitignore` で除外済み
- 最終成果物は `main/step04_package/output/` に集約

### Data Management

- `data/source/` にオリジナル様式ファイル (gitignored)
- `data/dummy/` にダミーデータ (git管理)
- data/source/ のファイルは読み取り専用として扱い、コピーして加工する

## File Patterns to Ignore

- `refs/` - 参考資料
- `__archives/` - 退避ファイル
- `docs/__archives/` - 退避ドキュメント
- `jank/` - 一時ファイル
- `data/source/` - オリジナル様式
- `main/*/output/` - ステップ出力
