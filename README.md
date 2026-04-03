# med-resist-grant

令和8年度 安全保障技術研究推進制度（委託事業）の申請書類を、Markdownベースのソース管理と自動変換で作成するシステム。

## 概要

- **応募先**: 防衛装備庁 安全保障技術研究推進制度
- **研究テーマ**: (23) 医療・医工学に関する基礎研究
- **応募タイプ**: Type A（年間最大5200万円、最大3年）
- **提出期限**: 2026年5月20日(水) 正午（e-Rad経由）

### アーキテクチャ

```
[Markdown/YAML ソース]
        │
        ├── Pandoc ──────→ docx (様式1-2, 1-3: 研究計画本文)
        ├── python-docx ──→ docx (様式1-1, 2-1~4-2等: テーブルフォーム)
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

# 6. ビルド
make build
```

### uv環境（Docker不使用時）

```bash
uv sync
uv run python main/step02_docx/fill_forms.py
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
│   └── dummy/               # ダミーデータ
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
| 02 | `step02_docx` | Word文書生成 | YAML + MD + 様式docx | 記入済みdocx |
| 03 | `step03_excel` | Excel文書生成 | YAML + 様式xlsx | 記入済みxlsx |
| 04 | `step04_package` | パッケージング | step02-03の出力 | 提出用ファイル一式 |

## 提出書類

### Word → PDF（Windows環境でPDF化）

| 書類 | ファイル | 生成方法 |
|------|---------|----------|
| 様式1-1〜5 + 参考様式 | 1つのPDFに結合 | python-docx + Pandoc |
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
| `scripts/archive_message.sh` | message.md をタイムスタンプ付きで jank/ に退避 |
| `scripts/backup.sh` | Google Drive (rclone) へバックアップ |
| `scripts/commit-push.sh` | message.md の内容でコミット&プッシュ |
| `scripts/create_package.sh` | パッケージング・バリデーション |
| `scripts/upload_to_gdrive.sh` | Google Driveへのアップロード |
| `scripts/sync_gdrive.sh` | Google Drive双方向同期 (rclone)（未作成） |

## Development Workflow

1. **メタデータ記入**: `main/00_setup/*.yaml` を編集
2. **本文執筆**: `main/step01_narrative/*.md` をMarkdownで執筆
3. **ビルド**: `make build` で全書類を生成
4. **同期**: Google Drive経由でWindows環境に転送
5. **PDF化**: Windows側でWord修復＋PDF変換
6. **提出**: e-Radにアップロード
