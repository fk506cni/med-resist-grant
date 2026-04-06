# med-resist-grant

令和8年度 安全保障技術研究推進制度（委託事業）の申請書類を、Markdownベースのソース管理と自動変換で作成するシステム。

## 概要

- **応募先**: 防衛装備庁 安全保障技術研究推進制度
- **研究テーマ**: (23) 医療・医工学に関する基礎研究（サイバー攻撃×地域医療シミュレーション）
- **応募タイプ**: Type A（年間最大5200万円、最大3年）
- **提出期限**: 2026年5月20日(水) 正午（e-Rad経由）

### アーキテクチャ

```
[Markdown/YAML ソース]
        │
        ├── python-docx ──→ youshiki1_5_filled.docx (様式1-1, 2-1~4-2等: テーブルフォーム)
        ├── Pandoc ──────→ narrative.docx (様式1-2, 1-3: 研究計画本文, 中間ファイル)
        │                       │
        │   inject_narrative.py ←┘  OOXML ZIP-level merge
        │         │
        │         └──→ youshiki1_5_filled.docx (様式1-2/1-3 本文が統合済み)
        └── openpyxl ────→ xlsx (様式6, 7, 8: Excelシート)
                                    │
                          [Google Drive同期]
                                    │
                          [Windows環境]
                                    ├── Word修復
                                    └── PDF変換
                                    │
                              [e-Rad提出]
```

## Getting Started

### 前提条件

- Docker / Docker Compose（または uv）
- Git
- Windows環境 + Microsoft Word（PDF変換用）
- Google Drive（環境間同期用）

### セットアップ

```bash
# 1. リポジトリをクローン
git clone <repository-url>
cd med-resist-grant

# 2. Docker コンテナをビルド・起動
docker compose -f docker/docker-compose.yml up -d --build

# 3. オリジナル様式ファイルを data/source/ に配置
# （r08youshiki1_5.docx, r08youshiki6.xlsx 等）

# 4. メタデータを編集
# main/00_setup/config.yaml, researchers.yaml 等

# 5. 本文を執筆
# main/step01_narrative/youshiki1_2.md, youshiki1_3.md

# 6. ビルド（デフォルト: Docker経由）
./scripts/build.sh

# サブコマンド例
./scripts/build.sh validate   # YAMLバリデーションのみ
./scripts/build.sh forms      # テーブルフォーム記入のみ
./scripts/build.sh inject     # ナラティブ挿入のみ
./scripts/build.sh clean      # 全output/をクリーン
./scripts/build.sh check      # 出力ファイルの存在・サイズチェック

# 実行環境切替（RUNNER環境変数）
RUNNER=docker ./scripts/build.sh   # Docker (デフォルト)
RUNNER=uv ./scripts/build.sh       # uv run 経由
RUNNER=direct ./scripts/build.sh   # 直接実行

# E2Eテスト（data/source/ の実ファイル不要）
RUNNER=docker DATA_DIR=data/dummy SETUP_DIR=data/dummy ./scripts/build.sh
```

## Project Structure

```
.
├── main/
│   ├── 00_setup/            # メタデータ (YAML)
│   ├── step01_narrative/    # Markdown本文ソース
│   ├── step02_docx/         # Word文書生成
│   ├── step03_excel/        # Excel文書生成
│   └── step04_package/      # パッケージング
├── data/
│   ├── source/              # オリジナル様式 (gitignored)
│   ├── dummy/               # ダミーデータ
│   ├── output/              # ビルド成果物集約先 (gitignored)
│   └── products/            # Windows変換済みPDF (gitignored)
├── docker/                  # Docker設定
├── docs/                    # ドキュメント
├── scripts/                 # ユーティリティ
├── CLAUDE.md                # AI アシスタント向けコンテキスト
├── SPEC.md                  # 技術仕様書
└── README.md                # 本ファイル
```

## Pipeline Steps

| Step | フォルダ | 内容 | 入力 | 出力 |
|------|---------|------|------|------|
| 00 | `00_setup` | メタデータ定義 | - | YAML設定ファイル |
| 01 | `step01_narrative` | 本文執筆 | - | Markdownファイル |
| 02 | `step02_docx` | Word文書生成 (fill_forms→Pandoc→inject_narrative) | YAML + MD + 様式docx | 記入済みdocx |
| 03 | `step03_excel` | Excel文書生成 | YAML + 様式xlsx | 記入済みxlsx |
| 04 | `step04_package` | パッケージング | step02-03の出力 | 提出用ファイル一式 |

## 提出書類

### Word → PDF（Windows環境でPDF化）

| 書類 | ファイル | 生成方法 |
|------|---------|----------|
| 様式1-1〜5 + 参考様式 | 1つのPDFに結合 | python-docx + Pandoc + inject_narrative.py |
| 別紙5 | 個別PDF | python-docx |
| 別添 | 研究者ごとに個別PDF | python-docx |

### Excel（そのまま提出）

| 書類 | ファイル | 生成方法 |
|------|---------|----------|
| 様式6: 申請概要 | xlsx | openpyxl |
| 様式7: 研究者一覧 | xlsx | openpyxl |
| 様式8: 連絡先 | xlsx | openpyxl |

## Scripts

| スクリプト | 説明 |
|-----------|------|
| `scripts/build.sh` | 全ドキュメント生成 (validate/forms/narrative/inject/security/excel/clean/check) |
| `scripts/validate_yaml.py` | YAMLバリデーション（必須フィールド、予算整合性、エフォート率等） |
| `scripts/roundtrip.sh` | ビルド→push→PDF待ち→pull 一括実行 |
| `scripts/sync_gdrive.sh` | Google Drive同期 (rclone copy, push/pull) |
| `scripts/collab_watcher.sh` | 共同執筆トリガー監視（Google Drive polling → 自動ビルド → 成果物配信 → Google Chat通知） |
| `scripts/create_package.sh` | パッケージング・バリデーション（成果物集約、サイズチェック、チェックリスト出力） |
| `data/dummy/generate_stubs.py` | E2Eテスト用スタブ docx/xlsx 生成 |
| `scripts/archive_message.sh` | message.md をタイムスタンプ付きで jank/ に退避 |
| `scripts/commit-push.sh` | message.md の内容でコミット&プッシュ |
| `scripts/windows/watch-and-convert.ps1` | Windows: フォルダ監視→docx→PDF自動変換 |
| `scripts/windows/watch-and-convert.bat` | 上記PS1のランチャー |

## Development Workflow

1. **メタデータ記入**: `main/00_setup/*.yaml` を編集
2. **本文執筆**: `main/step01_narrative/*.md` をMarkdownで執筆
3. **ビルド→PDF取得**: `./scripts/roundtrip.sh` で一括実行
   - ビルド成果物: `data/output/` (docx/xlsx)
   - 変換済みPDF: `data/products/`
4. Windows側では `watch-and-convert.ps1` が常駐してdocx→PDF自動変換
5. **提出**: e-Radにアップロード
