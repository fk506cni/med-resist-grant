# 実装プロンプト集

令和8年度 安全保障技術研究推進制度（委託事業）申請書類作成システムの実装手順。
各セクションを順にClaudeに依頼して実装する。

## 前提文脈（全ステップ共通）

すべてのプロンプトを実行する際、エージェントは以下を把握しておく必要がある:

### プロジェクト概要

- **応募先**: 防衛装備庁 令和8年度 安全保障技術研究推進制度（委託事業）
- **研究テーマ**: (23) 医療・医工学に関する基礎研究（抗菌薬耐性関連）
- **応募タイプ**: Type A（総額最大5200万円/年 ＝ 直接経費4,000万円 + 間接経費1,200万円、最大3年）
- **提出期限**: 2026年5月20日(水) 正午 e-Rad経由
- **提出物**: Word→PDF（様式1-5結合PDF + 別紙5 PDF + 別添PDF×人数分）、Excel（様式6,7,8）

### 読むべきドキュメント

| ファイル | 読むタイミング | 内容 |
|---------|--------------|------|
| `CLAUDE.md` | 毎回 | プロジェクト構成、提出書類一覧、Tech Stack、制約 |
| `SPEC.md` | 毎回 | 入出力仕様、パイプライン、制約条件 |
| `data/source/募集要項.pdf` | テーマ・審査基準を参照する時 | 公募要領全文（44p + 別紙） |

### 絶対的な制約

1. **data/source/ のファイルは絶対に変更しない** — 常にコピーしてから操作
2. **ホストPythonを汚さない** — Docker or uv 経由でのみ実行
3. **提出ファイルサイズ**: 各10MB以下、目標3MB
4. **様式1-2は最大15ページ**

### data/dummy/ の位置づけ

- `data/dummy/` はパイプラインのE2Eテスト用ダミーデータの配置場所
- YAML 4ファイル + スタブ docx/xlsx 6ファイルを配置済み
- `RUNNER=docker DATA_DIR=data/dummy SETUP_DIR=data/dummy ./scripts/build.sh` でE2Eテスト実行可能

### Step番号とディレクトリの対応

| prompts.md Step | 内容 | 状態 | 対応ディレクトリ |
|----------------|------|------|---------------|
| Step 0 | Docker/uv環境構築 | 完了 | docker/, pyproject.toml |
| Step 1 | メタデータYAML定義 | 完了 | main/00_setup/ |
| Step 2 | Markdown本文執筆環境 | 完了 | main/step01_narrative/ |
| Step 3 | Word文書生成 | 完了 | main/step02_docx/ |
| Step 4 | Excel文書生成 | 完了 | main/step03_excel/ |
| Step 5 | ビルド統合・パッケージング | 完了 | main/step04_package/ + scripts/build.sh |
| Step 6 | Google Drive同期設定 | 完了 | scripts/sync_gdrive.sh, scripts/roundtrip.sh |
| Step 7 | Windows側Word修復・PDF変換 | 完了 | scripts/windows/ |
| **Step 8** | **共同執筆環境** | 未着手 | **scripts/collab_watcher.sh** |

※ Steps 0-7 のプロンプト詳細は `docs/prompts_trash.md` に退避済み

### 現在のパイプライン全体像

```
[main/00_setup/*.yaml] + [main/step01_narrative/*.md] + [data/source/*]
                        │
              ./scripts/build.sh
                        │
              [main/step02_docx/output/*.docx]
              [main/step03_excel/output/*.xlsx]
                        │
              ./scripts/roundtrip.sh
                        │
              rclone push → Google Drive → Windows watch-and-convert.ps1 → PDF
                        │
              rclone pull → data/products/*.pdf
                        │
              e-Rad提出
```

### 参考プロジェクト

類似のMarkdown→Word変換システムが `/home/dryad/anal/jami-abstract-pandoc/` にある。

---

<!-- Steps 0-7 は完了済み。docs/prompts_trash.md に退避。 -->

## Step 8: 共同執筆環境（Google Drive + Webhook通知）

### 文脈

- ビルドパイプライン（Steps 0-7）は完成済み。`./scripts/build.sh` で全書類を自動生成、`./scripts/roundtrip.sh` でビルド→Google Drive push→Windows PDF変換→pull が一括実行できる
- 次のフェーズとして、**共同研究者がMarkdown本文を編集し、ビルドをトリガーできる環境**を構築する
- 共同研究者はLinux/Git環境を持たない前提 → Google Drive上で完結する操作フローが必要
- ビルド状況はGoogle Chat Webhook経由で通知する

### 共有フォルダ

- Windows側パス: `I:\マイドライブ\share_temp\med-resist-collab`
- rcloneパス: `gdrive:share_temp/med-resist-collab`（要確認・設定）

### 参照すべき資料

| ファイル | 確認ポイント |
|---------|------------|
| `scripts/roundtrip.sh` | 既存のビルド→push→PDF待ち→pull フロー |
| `scripts/sync_gdrive.sh` | rclone copy のパターン |
| `CLAUDE.md` | プロジェクト構成 |
| `SPEC.md` | パイプライン仕様 |

### Prompt 8-1: 共同執筆 watcher スクリプトと .env 設定

```
scripts/collab_watcher.sh を作成し、.env ファイルにWebhook設定を配置してください。

## 文脈
共同研究者がGoogle Drive上のトリガーファイルを編集すると、Linux側でビルドが自動発火し、
成果物が共有フォルダに配信される仕組みを構築します。
Google Chat Webhook で各ステップの進捗を通知します。

## 参照すべき資料

- scripts/roundtrip.sh — 既存のビルド→push→PDF待ち→pullフロー
- scripts/sync_gdrive.sh — rclone copy パターン
- docs/prompts.md（全体的な文脈記載有り）
- SPEC.md
- README.md
- CLAUDE.md

## Google Drive 共有フォルダ構成

rcloneパス: gdrive:share_temp/med-resist-collab

  med-resist-collab/
  ├── README_使い方.md           # 共同研究者向けの使い方説明（Prompt 8-2で作成）
  ├── drafts/                    # 共同研究者が編集するMarkdown本文
  │   ├── youshiki1_2.md         # 様式1-2: 研究計画詳細
  │   ├── youshiki1_3.md         # 様式1-3: 追加説明事項
  │   └── figs/                  # 図表ファイル
  ├── trigger.txt                # トリガーファイル（"build" と記入で発火）
  ├── status.txt                 # 現在の状態（更新はスクリプトが行う）
  └── products/                  # 成果物配信先（PDF/docx）

## .env ファイル（プロジェクトルート、gitignored）

  # Google Chat Webhook URL（実際のURLは .env にのみ記載、git管理下には含めない）
  GCHAT_WEBHOOK_URL=

  # rclone リモートとパス
  COLLAB_REMOTE="gdrive:"
  COLLAB_PATH="share_temp/med-resist-collab"

  # 実行環境（docker / uv / direct）
  RUNNER="docker"

  # ポーリング間隔（秒）
  COLLAB_POLL_SEC=15

  # クールダウン（前回ビルドからの最低間隔、秒）
  COLLAB_COOLDOWN_SEC=120

※ .env はプロジェクトルートの .gitignore に追加すること
※ .env.example を作成してプレースホルダ値を配置すること（Webhook URL は空欄）

## collab_watcher.sh の機能

### メインループ
1. .env を source して環境変数を読み込む（RUNNER, GCHAT_WEBHOOK_URL 等）
2. COLLAB_POLL_SEC 間隔で trigger.txt を rclone cat で読み取り
3. 内容が "build" で始まる場合:
   a. ロックチェック（前回ビルドからCOLLAB_COOLDOWN_SEC以内なら無視、通知のみ）
   b. trigger.txt を "IDLE" で上書き（echo "IDLE" | rclone rcat ...）
   c. status.txt を「ビルド中」に更新
   d. 以下の各フェーズを実行し、フェーズごとにWebhook通知
4. trigger.txt の内容がそれ以外（"IDLE", 空文字等）なら何もしない

### フェーズと通知

  Phase 1: 双方向ドラフト同期
    - Linux→Drive: rclone copy で main/step01_narrative/*.md → drafts/ に同期
    - Linux→Drive: main/step01_narrative/figs/ → drafts/figs/ に同期
    - Drive→Linux: rclone copy で drafts/*.md → main/step01_narrative/ に同期
    - Drive→Linux: drafts/figs/ → main/step01_narrative/figs/ に同期
    - ※ rclone copy は更新日時が新しいファイルのみ転送（--update フラグ使用）
    - 通知: "📥 ドラフトを同期しました"

  Phase 1.5: ソースコードバックアップ
    - プロジェクトルート配下のソースコード（git管理ファイル）をタイムスタンプ付き zip に圧縮
    - zip ファイル名: src_YYYYMMDD_HHMMSS.zip
    - rclone copy で gdrive:tmp/med-resist-grant/src/ にアップロード
    - 通知: "💾 ソースコードをバックアップしました"
    - ※ バックアップ先は最終的に別のストレージに移動する想定のため、毎回生成で問題なし

  Phase 2: ビルド
    - ./scripts/build.sh を実行
    - 通知（成功時）: "🔨 ビルド完了（validate ✓ / forms ✓ / narrative ✓ / security ✓ / excel ✓）"
    - 通知（失敗時）: "❌ ビルド失敗: <エラー概要>"
    - 失敗時は status.txt を「エラー」に更新して中断

  Phase 3: roundtrip（push → PDF待ち → pull）
    - ./scripts/roundtrip.sh --skip-build を実行
    - 通知: "📤 Google Driveにアップロード中..."
    - PDF変換完了後: "✅ PDF変換完了（N個）"

  Phase 4: 成果物配信
    - data/products/ の PDF と data/output/ の docx/xlsx を
      rclone copy で共有フォルダの products/ にコピー
    - 通知: "📦 成果物を共有フォルダに配信しました"

  Phase 5: 完了
    - status.txt を「完了 (YYYY-MM-DD HH:MM)」に更新
    - 通知: "🎉 全工程完了。products/ フォルダを確認してください"

### Webhook 通知関数

  notify_gchat() {
      local message="$1"
      curl -s -X POST "$GCHAT_WEBHOOK_URL" \
          -H "Content-Type: application/json" \
          -d "$(jq -n --arg text "$message" '{text: $text}')"
  }
  # ※ jq を使って安全にJSON構築する（メッセージ内の ", \, 改行等を自動エスケープ）
  # ※ Docker イメージに jq を追加するか、ホストの jq を使用

### エラーハンドリング
- 各フェーズで失敗した場合、Google Chat に失敗通知を送信
- status.txt を「エラー: <フェーズ名>」に更新
- ロックを解除してループを継続（次のトリガーを待つ）

### ロック機構
- ビルド中は /tmp/collab_watcher.lock を作成
- 他のトリガーが来てもロックファイルが存在する間はスキップ
- クールダウン: 前回ビルド完了から COLLAB_COOLDOWN_SEC 以内のトリガーは
  「クールダウン中」と通知して無視

### 起動・停止
- フォアグラウンド実行: ./scripts/collab_watcher.sh
- バックグラウンド実行: nohup ./scripts/collab_watcher.sh &
- 停止: Ctrl+C（フォアグラウンド）または kill
- 起動時に Google Chat に "🟢 Watcher起動" を通知
- 停止時（trap EXIT）に "🔴 Watcher停止" を通知
```

#### 完了チェック

- [x] .env が作成され .gitignore に追加されている
- [x] .env.example が作成されている（Webhook URL は空欄のプレースホルダ）
- [x] `./scripts/collab_watcher.sh` が起動し、ポーリングループに入る
- [x] trigger.txt に "build" を書くとビルドが発火する
- [x] 双方向ドラフト同期が動作する（Linux↔Drive の --update ベース）
- [x] ソースコードバックアップ zip が gdrive:tmp/med-resist-grant/src/ に作成される
- [x] 各フェーズで Google Chat に通知が届く（jq によるJSON構築）
- [x] ビルド失敗時にエラー通知が届き、status.txt が「エラー」になる
- [x] クールダウン期間内の再トリガーが無視される
- [x] 成果物が共有フォルダの products/ に配信される
- [x] trigger.txt クリア後の状態が "IDLE"（ゼロバイトではない）

---

### Prompt 8-2: 共同研究者向け使い方ドキュメント

```
共同研究者向けの使い方説明ドキュメントを作成してください。

## 文脈
共同研究者はLinux/Git環境を持たないため、Google Drive上での操作だけで
Markdown本文の編集→ビルド→成果物確認ができる手順書が必要です。
このファイルは Google Drive 共有フォルダに直接配置されます。

## 参照すべき資料

- docs/prompts.md（全体的な文脈記載有り）
- SPEC.md
- README.md
- CLAUDE.md

## 出力先

Google Drive共有フォルダにコピーされるローカルファイル:
  scripts/collab/README_使い方.md

※ collab_watcher.sh の初回起動時に共有フォルダにコピーする想定

## 内容

### 1. はじめに
- この共有フォルダの目的（申請書の共同執筆）
- フォルダ構成の説明

### 2. Markdownの編集方法
- drafts/ 内のファイルを直接編集する
- 使えるエディタの案内:
  - Google Drive上で直接開く → テキストエディタ（Markdownのプレビューなし）
  - VS Code (ブラウザ版: vscode.dev) にドラッグ&ドロップ → Markdownプレビュー付き
  - ローカルにダウンロードして任意のエディタで編集 → 保存して再アップロード
- Markdown記法の簡易リファレンス（見出し, リスト, 表, 画像参照, 強調, コメント）
- 図表の追加方法: figs/ フォルダに画像を入れ、本文から `![説明](figs/filename.png)` で参照

### 3. ビルドの実行方法
- trigger.txt を開き、"build" と入力して保存
- 数十秒以内にGoogle Chatに通知が届く
- status.txt で現在の状態を確認可能
- ビルド完了後、products/ フォルダにPDF/docx/xlsxが配信される

### 4. 成果物の確認
- products/ 内のPDFを開いてレイアウトを確認
- 修正が必要な場合は drafts/ を編集して再度ビルド

### 5. 注意事項
- 前回ビルドから2分以内の再トリガーはスキップされる
- Google Driveの同期に数秒〜十数秒のラグがある
- ビルド中（status.txt が「ビルド中」の間）は drafts/ の編集を避ける
- 問題が起きた場合はGoogle Chatで連絡

### 6. Markdown記法クイックリファレンス
- 基本記法の一覧表

## スタイル
- 日本語で記述
- 技術用語は最小限に
- 手順はスクリーンショットなしでも伝わるよう具体的に
```

#### 完了チェック

- [x] scripts/collab/README_使い方.md が作成されている
- [x] Markdown記法のリファレンスが含まれている
- [x] trigger.txt の使い方が明確に説明されている
- [x] 技術用語が最小限で、非技術者にも理解できる

---

### Prompt 8-3: 共有フォルダの初期化と動作テスト

```
共有フォルダの初期セットアップと動作テストを実施してください。

## 文脈
Prompt 8-1, 8-2 で作成したスクリプトとドキュメントを使って、
共有フォルダの初期配置と、トリガー→ビルド→配信の一連の動作を確認します。

## 参照すべき資料

- docs/prompts.md（全体的な文脈記載有り）
- SPEC.md
- README.md
- CLAUDE.md

## 手順

1. rclone で共有フォルダの初期構造を作成:
   - drafts/ に main/step01_narrative/*.md をコピー
   - drafts/figs/ を作成
   - trigger.txt を "IDLE" で配置
   - status.txt を「待機中」で配置
   - README_使い方.md を配置

2. collab_watcher.sh を起動し、Google Chat に起動通知が届くことを確認

3. trigger.txt に "build テスト" を rclone で書き込み

4. 以下を検証:
   - Google Chat に各フェーズの通知が届く
   - ビルドが完走する
   - products/ に成果物が配信される
   - trigger.txt が "IDLE" になっている
   - status.txt が「完了」になっている

5. クールダウンテスト:
   - 完了直後に再度 trigger.txt に "build" を書き込み
   - クールダウン通知が来て、ビルドがスキップされることを確認

6. エラーテスト:
   - YAML を意図的に壊してトリガー
   - エラー通知が届き、status.txt が「エラー」になることを確認
   - YAML を修復
```

#### 完了チェック

- [x] 共有フォルダに初期構造が配置されている
- [x] trigger.txt → ビルド → 成果物配信の一連の流れが動作する
- [x] Google Chat に全フェーズの通知が届く
- [x] クールダウンが正常に機能する
- [x] エラー時の通知と status.txt 更新が正しい
