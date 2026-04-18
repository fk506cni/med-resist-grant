# セッション開始プロンプト: 敵対的レビュー（第5回）

以下の指示に従い、Step 8（共同執筆環境）の実装プランと、プロジェクト全体の現在の準備状況について敵対的レビューを行ってください。レビュー結果は `docs/report5.md` に出力してください。

## レビュー方針

- **実装を開始しないでください。** レビューと指摘のみを行います。
- **研究内容のレビューは不要です。** refs/ 以下の研究資料には触れないでください。
- **敵対的に検証してください。** 「うまくいきそう」ではなく「どこで壊れるか」を探してください。
- **docs/report4.md を読まずに**独立してレビューを行い、レポート作成時に report4.md と突き合わせて所見を統合してください。
- レビュー結果は docs/report5.md に、重大度（Critical / Major / Minor / Note）付きで出力してください。
- 前回レビューとの差分（新規発見 / 既知だが未対応 / 前回から改善済み）を明示してください。

## 前回（report4.md）からの主な変化

- Steps 0-7 がすべて完了。完了済みプロンプトは docs/prompts_trash.md に退避済み
- E2Eテスト環境構築済み: `DATA_DIR=data/dummy SETUP_DIR=data/dummy ./scripts/build.sh` で全ステップ完走確認済み
- build.sh に `DATA_DIR` / `SETUP_DIR` 環境変数サポートを追加
- validate_yaml.py に `--setup-dir` 引数を追加
- data/dummy/ に YAML 4ファイル + スタブ docx/xlsx 6ファイル（generate_stubs.py）を配置
- Step 8（共同執筆環境）の実装プランを docs/prompts.md に追加（Prompt 8-1, 8-2, 8-3）
- 既存スクリプト: scripts/roundtrip.sh, scripts/sync_gdrive.sh, scripts/windows/watch-and-convert.ps1 は動作済み

## レビュー対象

### 1. Step 8 実装プラン（docs/prompts.md）の設計レビュー

Prompt 8-1（collab_watcher.sh）の設計が**実装可能で、エッジケースを網羅しているか**を検証してください:

#### rclone 操作の実現可能性
- `rclone cat` で trigger.txt を読み取る設計 — rclone cat は Google Drive 上のファイルに対して正しく動作するか
- trigger.txt のクリア（空文字で上書き）— rclone で単一ファイルを上書きする適切な方法は何か（rclone copyto? rclone rcat?）
- status.txt の更新 — 同上
- `gdrive:share_temp/med-resist-collab` というパスが rclone の Google Drive リモートとして有効か（「マイドライブ」配下のパス表現）

#### Google Chat Webhook
- Webhook URL が .env に格納される設計だが、**prompts.md 本文にも平文で記載されている** — これはgit管理下のファイル。リスク評価
- `curl -d "{\"text\": \"$message\"}"` でのJSON構築 — メッセージ内に `"` や `\` が含まれる場合のエスケープ問題
- Webhook のレート制限（1メッセージ/秒）に対して、Phase 2 のビルドログが大量行になる場合の考慮

#### 並行性とレースコンディション
- trigger.txt の読み取り→クリアの間に別のユーザーが書き込む可能性
- rclone polling の遅延中に drafts/ が編集中のままビルドが走る可能性
- roundtrip.sh 内の phase_wait_and_pull がタイムアウトした場合の watcher の挙動
- watcher プロセスが異常終了した場合のロックファイル残存問題

#### ドラフト同期の安全性
- Phase 1 で `rclone copy drafts/ → main/step01_narrative/` を行う際、main/step01_narrative/ にある既存ファイル（gitで管理されている）との競合
- fig/ → figs/ のディレクトリ名の不一致（prompts.md では fig/ と figs/ が混在していないか確認）
- 同期方向が一方向（Drive→Linux）だが、Linux側での編集がDrive側に反映されない設計の意図的な制限か

### 2. 既存スクリプトとの統合検証

Step 8 の watcher が呼び出す既存スクリプトが**現在の設計のまま呼び出し可能か**を検証してください:

- `./scripts/build.sh`: DATA_DIR / SETUP_DIR を watcher から渡す必要があるか。それとも main/00_setup/ のデフォルトパスで良いか（drafts/ から同期した後なら main/ に実データがあるため）
- `./scripts/roundtrip.sh --skip-build`: この既存スクリプトは GDRIVE_REMOTE / GDRIVE_PATH 環境変数で Google Drive パスを制御する。collab の共有フォルダパスとは別のパス（tmp/med-resist-grant）を使っている。共有フォルダの products/ への配信は別途 rclone copy が必要な設計になっているか
- build.sh の RUNNER 環境変数: watcher 内で RUNNER=docker が前提になっているか、明示する設計か

### 3. セキュリティ監査

- **Webhook URL の露出**: docs/prompts.md（git管理下）に Webhook URL が平文で含まれている。このリポジトリが public / 共同研究者に共有された場合のリスク
- **.env の運用**: .gitignore に .env が含まれていることを確認。ただし .env のテンプレート（.env.example）は提供されているか
- **トリガーファイルの認証**: trigger.txt に "BUILD" と書けば誰でもビルドを発火できる。Google Drive の共有範囲が適切に制限されているかは運用側の責任だが、スクリプト側で何らかの認証・検証を行うべきか
- **rclone 認証トークン**: ~/.config/rclone/rclone.conf の権限設定

### 4. E2Eテスト環境の検証

前回までに構築されたE2Eテスト環境の品質を検証してください:

- data/dummy/generate_stubs.py が生成するスタブファイルのテーブル構造は、実際の data/source/ ファイルの構造を正しく模倣しているか
- `RUNNER=docker DATA_DIR=data/dummy SETUP_DIR=data/dummy ./scripts/build.sh` を実際に実行し、全ステップが通ることを確認（circle_choice の UserWarning 等、既知の警告の影響度を評価）
- build.sh に DATA_DIR / SETUP_DIR を追加した変更が、デフォルト動作（data/source/、main/00_setup/）に影響を与えていないか

### 5. ドキュメント間の整合性

以下のファイルを突き合わせてください:
- `CLAUDE.md`
- `SPEC.md`
- `README.md`
- `docs/prompts.md`

特に:
- CLAUDE.md の Project Structure に collab_watcher.sh / scripts/collab/ が記載されているか（未実装ファイルの先行記載は問題ないか）
- SPEC.md に §2.3 E2Eテスト が追加されているか、内容が正確か
- README.md に E2E テストコマンドが記載されているか
- prompts.md の Step番号表の「状態」列が正確か
- prompts_trash.md に Steps 0-7 が完全に移行されているか（prompts.md に残骸がないか）

### 6. report4.md の残存指摘事項の確認（レポート作成時のみ）

レポート作成の最終段階で docs/report4.md を読み、以下を確認してください:
- 前回「未対応」とされた項目の現在の状況
- Step 8 の新機能導入に伴い新たに発生する懸念
- Steps 0-7 完了によって解消された問題

### 7. リスクマトリクス（更新版）

Steps 0-7 完了 + Step 8 設計段階を踏まえ、残存リスクを再評価してください:

- **技術リスク**: rclone polling 方式の信頼性、Google Chat Webhook の安定性
- **セキュリティリスク**: Webhook URL 露出、トリガー認証なし、rclone 認証情報
- **統合リスク**: 既存スクリプト（roundtrip.sh, build.sh）との引数/環境変数の整合
- **運用リスク**: watcher プロセスの常駐管理、異常終了時の復旧
- **スケジュールリスク**: 提出期限(5/20)まで残り45日に対する残作業量

## 出力フォーマット

`docs/report5.md` に以下の形式で出力してください:

```markdown
# 敵対的レビュー報告書（第5回）

レビュー実施日: YYYY-MM-DD
レビュー対象: （対象ファイル一覧）
前回レビュー: docs/report4.md

## サマリ

- Critical: N件 (新規N / 既知未対応N)
- Major: N件 (新規N / 既知未対応N)
- Minor: N件 (新規N / 既知未対応N)
- Note: N件

### 対応状況一覧

| ID | 重大度 | 状態 | 概要 |
|----|------|------|------|
| C5-01 | Critical | ... | ... |

## report4.md との差分サマリ

- report4.md の未対応項目で今回解消されたもの: N件
- report4.md の未対応項目で依然として未対応のもの: N件
- report4.md に記載がなく今回新規発見したもの: N件

## 指摘事項

### [C5-01] (Critical) タイトル
- **箇所**: ファイル名:行番号 or セクション名
- **前回対応状況**: 新規 / report4.md [C4-NN] 対応済み / report4.md [C4-NN] 未対応
- **内容**: 具体的な問題の説明
- **影響**: この問題が放置された場合に起きること
- **推奨対応**: 修正方針

## リスクマトリクス

| リスク | 影響度 | 発生確率 | 総合評価 | 対策 |
|-------|------|--------|--------|-----|
| ... | 高/中/低 | 高/中/低 | Critical/Major/Minor | ... |
```

重大度の基準:
- **Critical**: 実装がブロックされる、または提出物に致命的欠陥が生じる
- **Major**: 実装に手戻りが発生する、または提出物の品質に重大な影響がある
- **Minor**: 修正すべきだが実装を進めながら対応可能
- **Note**: 改善推奨だが現状でも問題なく進められる
