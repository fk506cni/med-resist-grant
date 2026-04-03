# (プロジェクト名)

<!-- プロジェクトの概要を1-2文で記述 -->

(プロジェクトの概要を記述してください)

## Getting Started

### 前提条件

- Docker / Docker Compose
- Git
- (その他必要なツール)

### セットアップ

```bash
# 1. リポジトリをクローン
git clone <repository-url>
cd <project-name>

# 2. 開発環境マーカーを作成
echo "Development environment" > .development

# 3. Docker コンテナをビルド・起動
docker compose -f docker/docker-compose.yml up -d --build

# 4. アクセス (SSH トンネル経由)
# Jupyter Lab:  http://localhost:8888
# RStudio:      http://localhost:8787 (rstudio/rstudio)
```

### 本番データの配置

```bash
# data/source/ に本番データを配置（またはシンボリックリンク）
ln -s /path/to/real/data data/source/actual_data.parquet
```

## Project Structure

```
.
├── main/                    # メイン処理パイプライン
│   ├── 00_setup/            # 共通設定
│   ├── step01_xxx/          # Step 01: (内容)
│   ├── step02_yyy/          # Step 02: (内容)
│   └── step03_zzz/          # Step 03: (内容)
├── data/                    # データ
│   ├── source/              # 本番データ (gitignored)
│   └── dummy/               # ダミーデータ
├── docker/                  # Docker 設定
├── docs/                    # ドキュメント
├── refs/                    # 参考資料 (gitignored)
├── scripts/                 # ユーティリティ
├── CLAUDE.md                # AI アシスタント向けコンテキスト
├── SPEC.md                  # 技術仕様書
└── README.md                # 本ファイル
```

## Pipeline Steps

| Step | フォルダ | 内容 | 入力 | 出力 |
|------|---------|------|------|------|
| 00 | `00_setup` | 共通設定・関数 | - | 共通関数 |
| 01 | `step01_xxx` | (内容) | (入力) | (出力) |
| 02 | `step02_yyy` | (内容) | Step 01 出力 | (出力) |
| 03 | `step03_zzz` | (内容) | Step 02 出力 | (出力) |

## Scripts

| スクリプト | 説明 |
|-----------|------|
| `scripts/archive_message.sh` | message.md をタイムスタンプ付きで jank/ に退避 |
| `scripts/backup.sh` | Google Drive (rclone) へバックアップ |
| `scripts/commit-push.sh` | message.md の内容でコミット&プッシュ |

## Development Workflow

1. **ステップを追加**: `main/stepNN_name/` フォルダを作成
2. **開発**: Docker コンテナ内で実行・デバッグ
3. **出力確認**: `main/stepNN_name/output/` に結果が格納される
4. **コミット**: `message.md` にコミットメッセージを書いて `scripts/commit-push.sh`
5. **次のステップへ**: 前ステップの出力を入力として次のステップを開発

## License

<!-- ライセンスを記述 -->
