# CLAUDE.md - AI Assistant Context

## Project Overview

**プロジェクト名**: med-resist-grant（薬剤耐性研究 科研費申請書類作成システム）
**概要**: 令和8年度 安全保障技術研究推進制度（委託事業）の申請書類を、Markdownソース管理＋自動変換で作成するシステム。

**応募先**: 防衛装備庁 安全保障技術研究推進制度
**研究テーマ**: (23) 医療・医工学に関する基礎研究（抗菌薬耐性関連）
**応募タイプ**: Type A（年間最大5200万円 ＝ 直接経費4,000万円+間接経費30%、最大3年）想定
**提出期限**: 2026年5月20日(水) 正午（e-Rad経由）

## Quick Reference

### Project Structure

```
med-resist-grant/
├── CLAUDE.md                    # AI アシスタント向けコンテキスト（本ファイル）
├── SPEC.md                      # 技術仕様書
├── README.md                    # プロジェクト概要
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
│   └── dummy/                   # ダミーデータ (git管理)
├── docker/                      # Docker設定
│   ├── docker-compose.yml
│   └── python/Dockerfile
├── docs/
│   ├── prompts.md               # 実装プロンプト集
│   └── __archives/
├── jank/                        # 一時ファイル (gitignored)
├── main/
│   ├── 00_setup/                # 共通設定・メタデータ (YAML)
│   │   ├── config.yaml          # プロジェクト設定
│   │   ├── researchers.yaml     # 研究者情報
│   │   ├── other_funding.yaml   # 他制度応募状況
│   │   └── security.yaml        # セキュリティ情報
│   ├── step01_narrative/        # Markdown本文ソース
│   │   ├── youshiki1_2.md       # 様式1-2: 研究計画詳細 (最大15p)
│   │   ├── youshiki1_3.md       # 様式1-3: 追加説明事項
│   │   └── output/
│   ├── step02_docx/             # Word文書生成
│   │   ├── fill_forms.py        # テーブルフォーム記入
│   │   ├── fill_security.py     # セキュリティ関連記入
│   │   ├── build_narrative.sh   # Pandoc変換
│   │   └── output/
│   ├── step03_excel/            # Excel文書生成
│   │   ├── fill_excel.py        # Excel記入
│   │   └── output/
│   └── step04_package/          # パッケージング
│       └── output/
├── refs/                        # 参考資料 (gitignored)
├── templates/                   # Pandoc reference-doc 等
│   └── reference.docx           # Pandocスタイル定義 (デフォルト生成済み、スタイル要調整)
└── scripts/
    ├── build.sh                 # 全ドキュメント生成 (未作成)
    ├── create_package.sh        # パッケージング・バリデーション (未作成)
    ├── sync_gdrive.sh           # Google Drive双方向同期 (未作成)
    └── windows/                 # Windows側スクリプト (未作成)
        ├── repair_and_pdf.ps1
        └── batch_convert.ps1
```

### 提出書類一覧

| 書類 | 形式 | 生成方法 | 提出形式 | 提出タイミング |
|------|------|----------|----------|--------------|
| 様式1-1: 申請書概要 | docx | python-docx (テーブル記入) | PDF | 応募時(5/20) |
| 様式1-2: 申請書詳細 | docx | Pandoc (Markdown→docx) | PDF | 応募時(5/20) |
| 様式1-3: 追加説明事項 | docx | Pandoc (Markdown→docx) | PDF | 応募時(5/20) |
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
※ チェックリストの提出は不要（提出前の自己確認用）

### Tech Stack

| 用途 | 技術 |
|------|------|
| 本文執筆 | Markdown (Pandoc Markdown) |
| メタデータ | YAML |
| Word変換 | Pandoc 3.6.x + python-docx |
| Excel記入 | openpyxl |
| 実行環境 | Docker / uv |
| Word修復・PDF化 | Windows + Word COM API |
| データ同期 | Google Drive (rclone gdrive bisync) |
| バージョン管理 | Git |

### 参考プロジェクト

- `/home/dryad/anal/jami-abstract-pandoc/` — JAMI学会抄録のMarkdown→Word変換システム
  - Pandocワークフロー、Docker構成、Luaフィルタ、OOXML後処理等を参考

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
3. `./scripts/build.sh` で全ドキュメントを生成
4. `scripts/sync_gdrive.sh` でGoogle Drive経由でWindows環境に同期
5. Windows側で `repair_and_pdf.ps1` でWord修復＋PDF化
6. e-Radで提出

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
