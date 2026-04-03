# CLAUDE.md - AI Assistant Context

## Project Overview

<!-- プロジェクト名と概要を記入 -->
**プロジェクト名**: (プロジェクト名)
**概要**: (1-2文でプロジェクトの目的を記述)

## Quick Reference

### Project Structure

```
project-name/
├── CLAUDE.md                # AI アシスタント向けコンテキスト (本ファイル)
├── SPEC.md                  # 技術仕様書
├── README.md                # プロジェクト概要
├── message.md               # コミットメッセージ / 作業メモ (一時ファイル)
├── __archives/              # 古いファイルの退避先 (gitignored)
├── data/                    # データ格納
│   ├── source/              # 本番データ (gitignored)
│   └── dummy/               # ダミーデータ (git管理)
├── docker/                  # コンテナ設定
│   ├── docker-compose.yml
│   ├── python/              # Python コンテナ
│   └── r/                   # R コンテナ
├── docs/                    # ドキュメント
│   └── __archives/          # 古いドキュメント退避先 (gitignored)
├── jank/                    # 一時ファイル置き場 (gitignored)
├── main/                    # メイン処理パイプライン
│   ├── 00_setup/            # 共通設定・関数
│   ├── step01_xxx/          # ステップ01: (内容)
│   │   └── output/          # ステップ出力 (gitignored)
│   ├── step02_yyy/          # ステップ02: (内容)
│   │   └── output/
│   └── step03_zzz/          # ステップ03: (内容)
│       └── output/
├── refs/                    # 参考資料 (gitignored)
└── scripts/                 # ユーティリティスクリプト
    ├── archive_message.sh   # message.md をjankに退避
    ├── backup.sh            # Google Drive バックアップ
    └── commit-push.sh       # message.md でコミット&プッシュ
```

### Tech Stack

<!-- 使用する技術スタックを記入 -->

| 用途 | 技術 |
|------|------|
| 言語 | Python / R |
| 実行環境 | Docker |
| 可視化 | ggplot2 / matplotlib |
| データ形式 | Parquet / CSV |

### Containers

<!-- Docker コンテナ設定を記入 -->

- Python Container:
  - Port: `127.0.0.1:8888 -> 8888` (Jupyter Lab)
  - SSH トンネル前提
- R Container:
  - Port: `127.0.0.1:8787 -> 8787` (RStudio)
  - Login: rstudio / rstudio

```bash
# コンテナ起動
docker compose -f docker/docker-compose.yml up -d --build

# コンテナ停止
docker compose -f docker/docker-compose.yml down
```

## Development Guidelines

### Step-by-Step Pipeline

- 各ステップは `main/stepNN_name/` に配置
- ステップ間のデータ受け渡しは `output/` ディレクトリ経由
- 各ステップは独立して再実行可能であること
- ステップ追加時は連番を維持する

### Naming Conventions

- ステップフォルダ: `main/step01_xxx/`, `main/step02_yyy/`
- 共通設定: `main/00_setup/`
- R スクリプト: `*.R`, R Markdown: `*.Rmd`
- Python スクリプト: `*.py`, Notebook: `*.ipynb`

### Output Handling

- 各ステップの出力は `main/stepNN_xxx/output/` に配置
- 出力ディレクトリ構成例:
  - `output/fig/{png,svg,pdf}/` - 図
  - `output/table/` - テーブル
  - `output/rds/` - R データ
- すべての `output/` は `.gitignore` で除外済み

### Environment Detection

```bash
# 開発環境マーカー作成 → ダミーデータ使用
echo "Development environment" > .development

# 削除 → 本番データ使用
rm .development
```

### Data Management

- `data/source/` に本番データ (gitignored)
- `data/dummy/` にダミーデータ (git管理)
- 開発時はダミーデータで動作確認

## File Patterns to Ignore

- `refs/` - 参考資料
- `__archives/` - 退避ファイル
- `docs/__archives/` - 退避ドキュメント
- `jank/` - 一時ファイル
- `data/source/` - 本番データ
- `main/*/output/` - ステップ出力
