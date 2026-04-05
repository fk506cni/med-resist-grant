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
| **Step 8** | **共同執筆環境** | 完了 | **scripts/collab_watcher.sh** |
| **Step 9** | **様式1-2/1-3 統合（ナラティブ挿入）** | 未着手 | **main/step02_docx/inject_narrative.py** |

※ Steps 0-7 のプロンプト詳細は `docs/prompts_trash.md` に退避済み
※ Step 8 の完了チェックは本ファイル下部の Prompt 8-1〜8-3 を参照

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

---

## Step 9: 様式1-2/1-3 統合（ナラティブ挿入）

### 文脈

- 現在のパイプラインでは、様式1-2/1-3の本文（Pandoc生成）と様式1-1〜5のテーブル（fill_forms.py生成）が**別ファイル**として出力される
- r08youshiki1_5.docx テンプレートには様式1-2/1-3の空セクション（ヘッダのみ）が含まれており、提出時にはここにPandoc生成の本文を挿入する必要がある
- 提出要件: 「様式1-1〜5 + 参考様式は1つのPDFに結合して提出」（募集要項）
- 現状の youshiki1_5_filled.pdf には空の様式1-2/1-3セクションが残存し、本文が入っていない

### 設計方針

- テンプレートの様式ヘッダ（「（様式１−２）」等）を**維持**する
- 空セクションを削除するのではなく、Pandoc生成コンテンツを**挿入**する
- python-docx での文書結合は書式崩壊リスクがあるため（SPEC.md記載）、OOXML直接操作（lxml）を優先する
- 参考実装: `/home/dryad/anal/jami-abstract-pandoc/` のOOXML後処理パターン

### 詳細計画

`docs/step4plan.md` に策定済み。以下はその要約。

### Prompt 9-1: テンプレート構造解析

```
r08youshiki1_5.docx 内の様式1-2/1-3セクションの構造を解析してください。

## 文脈
fill_forms.py が出力する youshiki1_5_filled.docx には、様式1-2/1-3の空セクション（ヘッダ＋
セクション見出しのみ）が残っている。これらのセクション内にPandoc生成の本文を挿入するため、
正確なセクション境界を特定する必要がある。

## 参照すべき資料

- data/source/r08youshiki1_5.docx — オリジナルテンプレート
- main/step02_docx/output/youshiki1_5_filled.docx — fill_forms.py出力
- main/step02_docx/fill_forms.py — 既存のテーブル記入ロジック
- docs/step4plan.md — 統合計画
- SPEC.md §3.1 — 出力仕様

## 作業内容

1. python-docx で youshiki1_5_filled.docx の全 body 要素（段落・テーブル）を列挙し、
   各様式セクションの境界を特定する:
   - 様式1-1 の範囲（開始〜終了）
   - 様式1-2 の範囲（「（様式１−２）」ヘッダ〜セクション末尾）
   - 様式1-3 の範囲
   - 様式2-1 以降の開始位置
2. 様式1-2/1-3 セクション内のプレースホルダ要素（空段落、見出しテキスト等）を特定する
3. セクション境界の検出に使用できるテキストパターン or XML要素の特徴を整理する
4. 結果をコメント付きで報告する（inject_narrative.py の設計に使用）

## 出力

解析結果をコンソールに出力（スクリプト作成は不要、調査のみ）。
以下の情報を含めること:
- 各セクションの body 要素インデックス範囲
- セクション検出に使えるマーカーテキスト
- 挿入ポイント（Pandocコンテンツを挿入すべき位置）
- 注意事項（セクションブレーク、ヘッダ/フッタ、ページ番号等）
```

#### 完了チェック

- [ ] 様式1-2/1-3のセクション境界が特定されている
- [ ] 挿入ポイントが明確に定義されている
- [ ] セクション検出のためのテキストパターンが整理されている

---

### Prompt 9-2: inject_narrative.py の作成

```
Pandoc生成の様式1-2/1-3本文を youshiki1_5_filled.docx に挿入するスクリプトを作成してください。

## 文脈
Prompt 9-1 の構造解析結果に基づき、youshiki1_5_filled.docx の空セクションに
Pandoc生成コンテンツを挿入する。

## 参照すべき資料

- docs/step4plan.md — 統合計画（設計方針・リスク・代替案）
- Prompt 9-1 の解析結果 — セクション境界・挿入ポイント
- main/step02_docx/fill_forms.py — 既存のpython-docx操作パターン
- /home/dryad/anal/jami-abstract-pandoc/ — OOXML後処理の参考実装
- main/step02_docx/build_narrative.sh — Pandoc変換の設定（reference.docx等）
- SPEC.md §3.1 — 出力仕様
- CLAUDE.md — 制約（ホストPython禁止等）

## 出力先

main/step02_docx/inject_narrative.py

## 機能要件

1. コマンドライン引数:
   --template: youshiki1_5_filled.docx のパス
   --youshiki12: youshiki1_2_narrative.docx のパス
   --youshiki13: youshiki1_3_narrative.docx のパス
   --output: 出力ファイルパス（デフォルト: --template を上書き）

2. 処理フロー:
   a. template docx を読み込み
   b. 様式1-2 セクションを検出（Prompt 9-1 で特定したマーカーを使用）
   c. セクション内のプレースホルダ要素（空段落、見出しテキスト等）を削除
      ※ セクションヘッダ（「（様式１−２）」「研究課題名：」等のテンプレート要素）は維持
   d. youshiki1_2_narrative.docx の body 要素を抽出
   e. 挿入ポイントに body 要素を挿入（lxml の addprevious/addnext 等で直接操作）
   f. 様式1-3 についても同様に処理
   g. 出力ファイルに保存

3. スタイル処理:
   - Pandoc側の reference.docx はテンプレートと同じスタイル定義を使用する前提
   - スタイル名の衝突が発生した場合のフォールバック処理
   - 画像（図表）が含まれる場合の rId 再割り当て

4. エラー処理:
   - セクションマーカーが見つからない場合は明確なエラーメッセージ
   - 入力ファイルが存在しない場合のエラー
   - 挿入後のファイルが破損していないかの基本検証（python-docxで再読み込み可能か）

## 技術的注意事項

- python-docx の Document.element.body で lxml の _Element にアクセスし、
  直接 XML 操作を行う（python-docx の高レベルAPIでは文書間要素コピーが困難）
- Pandoc docx から body 要素をコピーする際、以下に注意:
  - 名前空間の整合性（w:p, w:tbl 等）
  - リレーションシップの移植（画像、ハイパーリンク等）
  - スタイル定義の重複回避
- jami-abstract-pandoc プロジェクトの実装を参考にすること

## 非機能要件

- Docker 環境（python:3.12-slim）で実行可能であること
- 追加 pip パッケージは不要（python-docx + lxml は既存）
- 処理時間: 10秒以内
```

#### 完了チェック

- [ ] inject_narrative.py が作成されている
- [ ] コマンドライン引数が仕様どおり動作する
- [ ] 様式1-2/1-3の本文が正しい位置に挿入される
- [ ] テンプレートヘッダ（「（様式１−２）」等）が維持されている
- [ ] 挿入後の docx が Word で正常に開ける
- [ ] E2E テストで全ステップ通過する

---

### Prompt 9-3: ビルドパイプライン統合

```
inject_narrative.py を build.sh に統合し、create_package.sh を更新してください。

## 文脈
Prompt 9-2 で作成した inject_narrative.py をビルドパイプラインに組み込む。
build.sh の処理順序に inject フェーズを追加し、create_package.sh から
個別ナラティブファイルの必須チェックを除外する。

## 参照すべき資料

- scripts/build.sh — 既存のビルドスクリプト
- scripts/create_package.sh — パッケージングスクリプト
- docs/step4plan.md Step C, D — 統合計画

## 変更内容

### build.sh
- 処理順序を変更: validate → forms → narrative → **inject** → security → excel
- inject サブコマンドを追加:
  - main/step02_docx/inject_narrative.py を Docker/uv/direct で実行
  - 入力: youshiki1_5_filled.docx, youshiki1_2_narrative.docx, youshiki1_3_narrative.docx
  - 出力: youshiki1_5_filled.docx（上書き）
- inject 成功/失敗をビルド結果サマリに表示

### create_package.sh
- REQUIRED_DOCX から youshiki1_2_narrative.docx と youshiki1_3_narrative.docx を除外
  （youshiki1_5_filled.docx に統合済みのため）
- チェックリストの「手動確認項目」から PDF結合手順を削除
- 統合済みの確認メッセージを追加

### roundtrip.sh
- 変更不要（youshiki1_5_filled.docx がそのまま push される）

### data/dummy/
- E2Eテストで inject が正常にスキップまたは動作するよう、
  ダミーの narrative docx が必要か検討
```

#### 完了チェック

- [ ] build.sh に inject サブコマンドが追加されている
- [ ] `./scripts/build.sh` で全ステップ（validate/forms/narrative/inject/security/excel）が通過する
- [ ] `./scripts/build.sh inject` で inject のみ実行可能
- [ ] create_package.sh が更新されている
- [ ] E2Eテスト（DATA_DIR=data/dummy）が通過する
- [ ] roundtrip.sh で生成された PDF に様式1-2/1-3の本文が含まれている
- [ ] PDF のページ番号が通しで振られている

---

### Prompt 9-4: 統合テスト・検証

```
Step 9 の実装結果を検証してください。

## 文脈
Prompt 9-1〜9-3 の実装が完了した状態で、エンドツーエンドの動作確認を行う。

## 参照すべき資料

- docs/step4plan.md Step E — テスト計画
- data/products/*.pdf — 検証対象

## 検証項目

1. フルビルド: ./scripts/build.sh で全ステップ OK
2. roundtrip: ./scripts/roundtrip.sh で PDF 生成完了
3. youshiki1_5_filled.pdf を開き以下を確認:
   - 様式1-1 の後に様式1-2 の本文が正しく挿入されている
   - 様式1-2 のテンプレートヘッダ（「（様式１−２）」「研究課題名：」）が維持されている
   - 様式1-2 の本文内容が youshiki1_2.md の記述と一致する
   - 様式1-3 についても同様
   - 様式2-1 以降が正常に表示される
   - ページ番号が通しで振られている（全体で1から連番）
   - フォント・スタイルが統一されている（MS明朝 10.5pt / MSゴシック見出し）
   - 表（Markdown テーブル）が正しくレンダリングされている
   - 様式1-2 が15ページ以内に収まっている
4. E2Eテスト: DATA_DIR=data/dummy で全ステップ通過
5. create_package.sh が正常に動作し、チェックリストが正しい
6. 問題があれば修正し、再検証

## 出力

検証結果をコンソールに報告。問題がなければ docs/prompts.md の完了チェックを更新。
```

#### 完了チェック

- [ ] フルビルドが全ステップ OK
- [ ] youshiki1_5_filled.pdf に様式1-2/1-3の本文が含まれている
- [ ] テンプレートヘッダが維持されている
- [ ] ページ番号が通し番号
- [ ] フォント・スタイルが統一
- [ ] 様式1-2 が15ページ以内
- [ ] E2Eテスト通過
- [ ] create_package.sh のチェックリストが正しい
