# 敵対的レビュー報告書（第5回）

レビュー実施日: 2026-04-05
レビュー対象: docs/prompts.md (Step 8 設計), scripts/build.sh, scripts/roundtrip.sh, scripts/sync_gdrive.sh, scripts/create_package.sh, scripts/validate_yaml.py, data/dummy/ (全ファイル), main/step02_docx/ (fill_forms.py, fill_security.py, build_narrative.sh), main/step03_excel/fill_excel.py, CLAUDE.md, SPEC.md, README.md, .gitignore
前回レビュー: docs/report4.md (2026-04-04)

## サマリ

- Critical: 1件 (新規1)
- Major: 5件 (新規5)
- Minor: 5件 (新規3 / 既知未対応1 / 前回から改善1)
- Note: 4件

### 対応状況一覧

| ID | 重大度 | 状態 | 概要 |
|----|------|------|------|
| C5-01 | Critical | 新規 | Webhook URL が git管理下の prompts.md に平文で記載されている |
| C5-02 | Major | 新規 | notify_gchat() の JSON 構築にシェル変数直挿入 — JSONインジェクション脆弱性 |
| C5-03 | Major | 新規 | fig/ vs figs/ のディレクトリ名不整合 — 画像パスが壊れる |
| C5-04 | Major | 新規 | drafts/ → main/step01_narrative/ の同期で git管理ファイルを無検証で上書き |
| C5-05 | Major | 新規 | collab_watcher.sh の RUNNER 環境変数が未指定 — build.sh のデフォルト依存 |
| C5-06 | Major | 新規 | trigger.txt の読み取り→クリアに競合ウィンドウが存在（非原子操作） |
| C5-07 | Minor | 新規 | CLAUDE.md に未実装ファイル（collab_watcher.sh, scripts/collab/）が先行記載 |
| C5-08 | Minor | 新規 | .env.example テンプレートが未提供 — 環境セットアップ手順が暗黙的 |
| C5-09 | Minor | 新規 | rclone rcat で空文字書き込み時のゼロバイトファイル問題 |
| C5-10 | Minor | C4-14 未対応 | pyproject.toml 未作成（Docker主体のため影響限定的） |
| C5-11 | Minor | 前回から改善 | E2E テストの circle_choice 警告 — スタブのテーブルセル構造が不完全 |
| C5-12 | Note | — | Steps 0-7 完了により report4.md の主要リスクが大幅に軽減 |
| C5-13 | Note | — | E2E テストが全ステップ正常完走（validate/forms/narrative/security/excel 全 OK） |
| C5-14 | Note | — | roundtrip.sh と collab の Google Drive パス分離は設計上正しい |
| C5-15 | Note | — | SPEC.md §2.3 E2Eテスト、README.md E2Eコマンド — いずれも正確に記載済み |

## report4.md との差分サマリ

- report4.md の未対応項目で今回解消されたもの: **7件**
  - C4-06 (reference.docx): build_narrative.sh が自動生成するため**完全解消**
  - C4-07 (実装スクリプト未作成): Steps 0-7 全完了。fill_forms.py, fill_security.py, build_narrative.sh, fill_excel.py, build.sh, create_package.sh, validate_yaml.py すべて実装済み
  - C4-08 (openpyxl DV): fill_excel.py に extLst 再注入ロジック実装済み
  - C4-09 (openpyxl CF): fill_excel.py の extLst 再注入で条件付き書式も保護
  - C4-12 (YAML バリデーション不在): validate_yaml.py 実装済み（必須フィールド、budget整合、effort合算、研究者-セキュリティ突合）
  - C4-15 (data/dummy/ 空): YAML 4ファイル + generate_stubs.py + スタブ docx/xlsx 6ファイル配置済み
  - C4-16 (E2Eテスト Prompt 不在): E2Eテスト実装済み、全ステップ正常完走確認
- report4.md の未対応項目で依然として未対応のもの: **1件**
  - C4-14 → C5-10 (pyproject.toml 未作成)
- report4.md に記載がなく今回新規発見したもの: **9件**
  - C5-01 (Webhook URL 露出), C5-02 (JSON インジェクション), C5-03 (fig/figs 不整合), C5-04 (sync 上書き), C5-05 (RUNNER 未指定), C5-06 (race condition), C5-07 (CLAUDE.md 先行記載), C5-08 (.env.example), C5-09 (rclone rcat 空書込)

---

## 指摘事項

---

### [C5-01] (Critical) Webhook URL が git管理下の prompts.md に平文で記載されている

- **箇所**: docs/prompts.md:141行
- **前回対応状況**: 新規（Step 8 設計追加に伴い発生）
- **内容**: Google Chat Webhook の完全な URL（API key + token を含む）が prompts.md に記載されている:

  ```
  GCHAT_WEBHOOK_URL="https://chat.googleapis.com/v1/spaces/AAQADyojcn0/messages?key=AIzaSyDdI0hCZtE6vySjMm-WEfRq3CPzqKqqsHI&token=3EQ2dOXJlinvC1Ta83loh2J2PFAnQ42SK__b7lvwC8Y"
  ```

  このファイルは git 管理下にある（`git status` で `M docs/prompts.md` として表示）。

- **影響**:
  - リポジトリが public に設定された場合、または共同研究者に共有された場合、Webhook URL が漏洩する
  - 任意の第三者が Google Chat スペースにメッセージを送信可能になる（スパム、フィッシング、なりすまし通知）
  - GitHub にプッシュ済みの場合、git 履歴から URL を完全に除去するには force push + BFG Repo-Cleaner が必要
  - .env ファイルへの記載という**正しい設計が同じ prompts.md 内で示されている**にもかかわらず、設計ドキュメント自体に秘密情報が含まれている矛盾

- **推奨対応**:
  1. prompts.md から Webhook URL を即座に除去し、`GCHAT_WEBHOOK_URL="<.env ファイルに記載>"` に置換
  2. git 履歴の確認: 既にリモートにプッシュ済みであれば Webhook URL の再発行を検討
  3. .env.example テンプレートに `GCHAT_WEBHOOK_URL=` のプレースホルダを配置

---

### [C5-02] (Major) notify_gchat() の JSON 構築にシェル変数直挿入 — JSONインジェクション

- **箇所**: docs/prompts.md:197-200行（設計仕様）
- **前回対応状況**: 新規
- **内容**: Webhook 通知関数の設計が以下のようになっている:

  ```bash
  notify_gchat() {
      local message="$1"
      curl -s -X POST "$GCHAT_WEBHOOK_URL" \
          -H "Content-Type: application/json" \
          -d "{\"text\": \"$message\"}"
  }
  ```

  `$message` がシェル変数として展開されるため、メッセージ内に `"`, `\`, `}`, 改行等が含まれるとJSONが壊れる。具体的に問題が起きるシナリオ:
  - ビルドエラーメッセージに `"` やパス内の `\` が含まれる場合
  - ファイル名に日本語やスペースが含まれる場合

- **影響**: ビルド失敗時のエラー通知が送信できない（curl が不正JSON送信→400エラー）。通知が届かないため、共同研究者はビルドが無応答と認識する。

- **推奨対応**: `jq` を使った安全なJSON構築に変更:
  ```bash
  notify_gchat() {
      local message="$1"
      curl -s -X POST "$GCHAT_WEBHOOK_URL" \
          -H "Content-Type: application/json" \
          -d "$(jq -n --arg text "$message" '{text: $text}')"
  }
  ```
  または `jq` がない環境向けに Python ワンライナーで JSON エスケープ。

---

### [C5-03] (Major) fig/ vs figs/ のディレクトリ名不整合 — 画像パス破損

- **箇所**: docs/prompts.md:133行 (fig/), 171行 (fig/ → figs/), 271行 (fig/filename.png), main/step01_narrative/youshiki1_2.md:277行 (figs/overview.png)
- **前回対応状況**: 新規
- **内容**: 以下の4箇所でディレクトリ名が不一致:

  | 場所 | 名前 | 用途 |
  |------|------|------|
  | Google Drive 共有フォルダ構成 (prompts.md:133) | `drafts/fig/` | 共同研究者が画像を配置 |
  | Phase 1 同期先 (prompts.md:171) | `fig/ → main/step01_narrative/figs/` | Drive→Localの同期マッピング |
  | README_使い方.md の案内 (prompts.md:271) | `fig/filename.png` | Markdown 内の画像参照パス |
  | 既存 Markdown (youshiki1_2.md:277) | `figs/overview.png` | 実際の Markdown 内参照 |

  共同研究者が README_使い方.md に従い `![説明](fig/filename.png)` と記述した場合:
  1. 画像は `drafts/fig/` に配置される
  2. Phase 1 で `fig/` → `main/step01_narrative/figs/` に同期される
  3. Markdown 内の参照パス `fig/filename.png` は `figs/` にリネームされない
  4. **Pandoc ビルド時に画像が見つからない**

- **影響**: 共同研究者が追加した図表がPDF出力に反映されない。デバッグも困難（パスの不一致は Pandoc のエラーメッセージに明示されない場合がある）。

- **推奨対応**: `fig/` に統一する:
  1. Google Drive 側は `drafts/fig/` のまま
  2. Phase 1 の同期先を `main/step01_narrative/fig/` に変更
  3. 既存の youshiki1_2.md 内の `figs/` 参照を `fig/` に修正
  4. または逆に `figs/` で統一し、README_使い方.md の案内と Drive フォルダ名を `figs/` に変更

---

### [C5-04] (Major) drafts/ → main/step01_narrative/ の同期で git管理ファイルを無検証で上書き

- **箇所**: docs/prompts.md:170-171行（Phase 1 設計）
- **前回対応状況**: 新規
- **内容**: Phase 1 で `rclone copy drafts/ → main/step01_narrative/` を実行すると、git で管理されている既存の Markdown ファイル（youshiki1_2.md, youshiki1_3.md）が Google Drive 上のファイルで無条件に上書きされる。

  以下のシナリオで問題が発生する:
  1. Linux 側で直接 Markdown を編集・コミット済み
  2. Google Drive 上の drafts/ は古いバージョンのまま
  3. 共同研究者が trigger.txt に BUILD を書く
  4. Phase 1 で古い drafts/ が main/step01_narrative/ を上書き → **Linux 側の最新編集が消失**

  同期方向が一方向（Drive→Linux）であるため、Linux 側で行った変更が保護されない。

- **影響**: 本文の変更が消失する。特に提出期限直前の並行編集時に致命的。git diff で検出は可能だが、自動ビルド後にコミットされると取り返しが困難。

- **推奨対応**:
  1. Phase 1 で同期前に `git stash` または `git diff --stat main/step01_narrative/` を実行し、差分があれば通知して中断するガード
  2. 同期前にタイムスタンプ比較（Drive 側が新しい場合のみ同期）
  3. 最低限: Phase 1 実行前に main/step01_narrative/ の内容を一時ディレクトリにバックアップ

---

### [C5-05] (Major) collab_watcher.sh の RUNNER 環境変数が未指定

- **箇所**: docs/prompts.md:175-178行（Phase 2 設計）
- **前回対応状況**: 新規
- **内容**: Phase 2 で `./scripts/build.sh` を実行する際、`RUNNER` 環境変数が設計で明示されていない。build.sh のデフォルトは `RUNNER=docker` だが:
  - `.env` で `RUNNER` を設定する設計にもなっていない
  - watcher スクリプト内で `export RUNNER=docker` する設計にもなっていない
  - build.sh は `RUNNER=${RUNNER:-docker}` でデフォルト docker を使うが、.env を source した後に別の `RUNNER` 値が設定されている場合は予期しない動作になる

  同様に `DATA_DIR` / `SETUP_DIR` も watcher から渡す設計が明示されていない。watcher のユースケースでは `main/00_setup/`（デフォルト値）を使うのが正しいが、ドキュメントに明記すべき。

- **影響**: Docker が起動していない環境で watcher を起動した場合、build.sh が docker compose run で失敗し、エラー通知のみで原因が不明瞭。

- **推奨対応**: .env テンプレートに `RUNNER=docker` を追加するか、collab_watcher.sh 内で明示的に export する設計をプロンプトに追記。

---

### [C5-06] (Major) trigger.txt の読み取り→クリアに競合ウィンドウが存在

- **箇所**: docs/prompts.md:158-164行（メインループ設計）
- **前回対応状況**: 新規
- **内容**: メインループの処理フロー:
  1. `rclone cat` で trigger.txt を読み取り
  2. "BUILD" を検知
  3. trigger.txt をクリア（空文字で上書き）

  ステップ 1 と 3 の間（数秒〜数十秒の rclone API レイテンシ含む）に別のユーザーが trigger.txt を編集した場合:
  - ユーザーA: "BUILD" を書き込み → watcher が検知
  - watcher: ビルド開始処理中（ロック取得、status.txt 更新等）
  - ユーザーB: trigger.txt に "BUILD 追加修正" と書き込み
  - watcher: trigger.txt をクリア → **ユーザーBのトリガーが消失**

  Google Drive はファイルレベルのロックをサポートしないため、原子的な read-and-clear は不可能。

- **影響**: 実運用では発生頻度は低い（ポーリング間隔15秒 × クールダウン120秒）。ただし、クールダウン終了直後に2人が同時にトリガーした場合に一方の意図が失われる。

- **推奨対応**:
  1. 設計上の制約として README_使い方.md に明記（「ビルド中は trigger.txt を編集しないでください」は既に記載予定）
  2. ステップ 3 のクリア前に trigger.txt の内容を再確認し、変化があればログに記録
  3. 低優先: trigger.txt の代わりに Google Drive API の変更通知（push notifications）を使う設計への移行を将来的に検討

---

### [C5-07] (Minor) CLAUDE.md に未実装ファイルが先行記載されている

- **箇所**: CLAUDE.md:73-74行
- **前回対応状況**: 新規
- **内容**: CLAUDE.md の Project Structure に以下が記載されているが、実際には存在しない:
  ```
  ├── collab_watcher.sh        # 共同執筆トリガー監視 (Step 8)
  ├── collab/                  # 共同執筆用リソース
  │   └── README_使い方.md     # 共同研究者向け使い方説明
  ```
  `scripts/collab_watcher.sh` は glob で検索しても見つからず、`scripts/collab/` ディレクトリも存在しない。

- **影響**: AI エージェントが CLAUDE.md を読んでファイルを参照しようとした場合に混乱する可能性。機能面では影響なし。

- **推奨対応**: Step 8 実装完了まで CLAUDE.md から除去するか、`(Step 8 で作成予定)` 注記を追加。

---

### [C5-08] (Minor) .env.example テンプレートが未提供

- **箇所**: プロジェクトルート
- **前回対応状況**: 新規
- **内容**: `.env` は `.gitignore` に含まれている（70行: `.env`）ため git 管理外。しかし:
  - `.env.example` や `.env.template` が存在しない
  - 必要な環境変数一覧がドキュメント化されていない（prompts.md 内に設計仕様はあるが、すぐに使えるテンプレートがない）
  - collab_watcher.sh の動作に `.env` は必須（GCHAT_WEBHOOK_URL 等）

- **影響**: Step 8 実装時に .env を手作業で作成する必要があり、設定漏れのリスク。

- **推奨対応**: Prompt 8-1 の完了チェックに `.env.example` 作成を追加:
  ```
  # .env.example
  GCHAT_WEBHOOK_URL=
  COLLAB_REMOTE=gdrive:
  COLLAB_PATH=share_temp/med-resist-collab
  COLLAB_POLL_SEC=15
  COLLAB_COOLDOWN_SEC=120
  ```

---

### [C5-09] (Minor) rclone rcat で空文字書き込み時のゼロバイトファイル問題

- **箇所**: docs/prompts.md:162行（trigger.txt クリア設計）
- **前回対応状況**: 新規
- **内容**: trigger.txt のクリア方法として「空文字で上書き」が設計されているが、`rclone rcat` でゼロバイトの入力を渡した場合の Google Drive の挙動が不確実:
  - `echo -n "" | rclone rcat gdrive:path/trigger.txt` — 一部の rclone バージョン/バックエンドでゼロバイトファイルの作成に失敗する報告がある
  - Google Drive API はゼロバイトファイルをサポートするが、rclone の中間処理で問題が起きる可能性

  `rclone cat` で読み取り側は問題ない（ゼロバイトなら空文字列が返る）。

- **影響**: trigger.txt のクリアに失敗すると、次のポーリングサイクルで再度 "BUILD" を検知し、無限ビルドループに陥る可能性。クールダウン機構が緩和するが、120秒ごとにビルドが繰り返される。

- **推奨対応**: 空文字ではなく既知のクリア状態文字列を使用:
  ```bash
  echo "IDLE" | rclone rcat "${COLLAB_REMOTE}${COLLAB_PATH}/trigger.txt"
  ```
  メインループ側は `"BUILD"` で始まる場合のみトリガーし、それ以外（`"IDLE"` 含む）は無視する設計。

---

### [C5-10] (Minor) pyproject.toml 未作成 — C4-14 未対応

- **箇所**: プロジェクトルート
- **前回対応状況**: C4-14 (Minor) → C3-11 (Minor) — 3回連続で未対応
- **内容**: Docker 環境が主要な実行環境のため実質的影響は限定的。ただし `RUNNER=uv` で実行する場合は `pyproject.toml` に依存関係を記述する必要がある。
- **影響**: `RUNNER=uv` での実行が機能しない可能性。
- **推奨対応**: 低優先のまま維持。`RUNNER=uv` を使う予定がなければ対応不要。

---

### [C5-11] (Minor) E2E テストの circle_choice 警告 — スタブ構造の限界

- **箇所**: data/dummy/generate_stubs.py, main/step02_docx/fill_forms.py:98行
- **前回対応状況**: C4-08 から改善（openpyxl 問題は解消、circle_choice は新規指摘）
- **内容**: E2E テスト実行時に以下の UserWarning が3件出力される:
  ```
  circle_choice: '医療' not found in ''
  circle_choice: 'タイプＡ' not found in ''
  circle_choice: '無' not found in ''
  ```
  これは generate_stubs.py が生成するスタブ docx のセル内テキストに、fill_forms.py が期待するラジオボタン的テキスト（「医療 / 材料 / ...」等）が含まれていないため。

  fill_forms.py は warning を出すがエラーにはならず、処理は続行される。ビルド全体は正常完走する。

- **影響**: E2E テストの出力にノイズが混じるが、機能には影響なし。実ファイル（data/source/r08youshiki1_5.docx）でビルドすれば発生しない。

- **推奨対応**: 低優先。generate_stubs.py の様式1-1 テーブルのセルに選択肢テキストを追加すれば解消可能だが、テスト目的としては現状で十分。

---

### [C5-12] (Note) Steps 0-7 完了による report4.md 主要リスクの大幅軽減

- **内容**: report4.md 時点で最大のリスクだった「実装スクリプト未作成」(C4-07) が完全に解消された。以下が新たに確認された:

  | カテゴリ | ファイル | report4 時点 | 現在 |
  |---------|---------|-------------|------|
  | Word生成 | fill_forms.py | 未作成 | 実装済み・E2E通過 |
  | Word生成 | fill_security.py | 未作成 | 実装済み・E2E通過 |
  | Word生成 | build_narrative.sh | 未作成 | 実装済み・E2E通過 |
  | Excel生成 | fill_excel.py | 未作成 | 実装済み（extLst再注入あり）・E2E通過 |
  | ビルド統合 | build.sh | 未作成 | 実装済み（DATA_DIR/SETUP_DIR対応） |
  | パッケージ | create_package.sh | 未作成 | 実装済み |
  | バリデーション | validate_yaml.py | 未作成 | 実装済み（--setup-dir対応） |
  | E2Eテスト | generate_stubs.py | data/dummy/ 空 | 実装済み・6スタブ生成 |
  | Windows変換 | watch-and-convert.ps1 | 未確認 | 実装済み（VBScript経由） |
  | Pandocテンプレート | reference.docx | 未生成 | build_narrative.sh で自動生成 |

  report4.md のリスクマトリクス R1（スケジュール: Critical）は「10ファイル + 本文15p」の実装量だったが、現在はインフラ実装が完了し、残りは **Step 8 実装 + 本文執筆** のみ。

---

### [C5-13] (Note) E2E テスト全ステップ正常完走確認

- **内容**: `RUNNER=docker DATA_DIR=data/dummy SETUP_DIR=data/dummy ./scripts/build.sh` を実行し、以下を確認:

  | ステップ | 結果 | 出力 |
  |---------|------|------|
  | validate | OK | 全チェック OK |
  | forms | OK | youshiki1_5_filled.docx (40K) |
  | narrative | OK | youshiki1_2_narrative.docx (12K), youshiki1_3_narrative.docx (12K) |
  | security | OK | besshi5_filled.docx (40K), betten_01_yamada.docx (40K), betten_02_suzuki.docx (40K) |
  | excel | OK | youshiki6.xlsx (8K), youshiki7.xlsx (8K), youshiki8.xlsx (8K) |

  デフォルトパス（DATA_DIR=data/source, SETUP_DIR=main/00_setup）への影響もない（build.sh 34行で `${DATA_DIR:-data/source}` / `${SETUP_DIR:-main/00_setup}` のデフォルト値設定を確認）。

---

### [C5-14] (Note) roundtrip.sh と collab の Google Drive パス分離は設計上正しい

- **内容**: 以下のパス分離が設計意図通りであることを確認:
  - `roundtrip.sh`: `gdrive:tmp/med-resist-grant` — Windows PDF変換用の中間パス
  - `collab_watcher.sh`: `gdrive:share_temp/med-resist-collab` — 共同研究者向け共有フォルダ

  watcher の処理フロー:
  1. Phase 2: `build.sh` でビルド（ローカル出力）
  2. Phase 3: `roundtrip.sh --skip-build` で collect→push（tmp/...）→Windows PDF待ち→pull
  3. Phase 4: `data/products/` + `data/output/` を collab の `products/` にコピー

  Phase 3 は既存の roundtrip.sh のパスをそのまま使い、Phase 4 で collab 共有フォルダに別途配信する設計。二重パスの問題はない。

---

### [C5-15] (Note) ドキュメント整合性は概ね良好

- **内容**: 以下のドキュメント間突合を実施:

  | チェック項目 | 結果 | 備考 |
  |------------|------|------|
  | SPEC.md §2.3 E2Eテスト記載 | ✓ 正確 | 実行コマンド、環境変数、スタブ生成の説明あり |
  | README.md E2Eコマンド記載 | ✓ 正確 | 73行に `RUNNER=docker DATA_DIR=data/dummy SETUP_DIR=data/dummy ./scripts/build.sh` |
  | prompts.md Step番号表「状態」列 | ✓ 正確 | Steps 0-7: 完了、Step 8: 未着手 |
  | prompts_trash.md に Steps 0-7 完全移行 | ✓ 確認 | Step 0〜7 の全ヘッダが存在。prompts.md に残骸なし（80行のコメントのみ） |
  | CLAUDE.md collab_watcher.sh 先行記載 | △ | C5-07 で指摘。実体なし |
  | CLAUDE.md scripts/collab/ 先行記載 | △ | 同上 |
  | validate_yaml.py --setup-dir 仕様と実装 | ✓ 一致 | SPEC.md, CLAUDE.md, build.sh いずれも正確 |

---

## リスクマトリクス（更新版）

| # | リスク | カテゴリ | 影響度 | 発生確率 | 総合評価 | 対策 | report4 比 |
|---|-------|--------|------|--------|---------|-----|-----------|
| R1 | 提出期限まで45日で本文15p未執筆 + Step 8 実装 | スケジュール | 高 | 中 | **Major** | インフラ完成済み。本文執筆を最優先し、Step 8 は並行実装 | **↓ 軽減**（Critical→Major、インフラ完成により） |
| R2 | Webhook URL が git 履歴に残存 | セキュリティ | 高 | 高（既に記載済み） | **Critical** | C5-01: 即座に除去。push 済みなら URL 再発行 | **新規** |
| R3 | collab_watcher.sh の JSON インジェクション | セキュリティ/技術 | 中 | 高 | **Major** | C5-02: jq による安全な JSON 構築 | **新規** |
| R4 | fig/ vs figs/ 不整合で画像欠落 | 技術 | 中 | 高（設計段階で混在確認済み） | **Major** | C5-03: 名前を統一（fig/ に統一推奨） | **新規** |
| R5 | drafts/ 同期で git 管理ファイル消失 | 運用 | 高 | 中 | **Major** | C5-04: 同期前の diff チェックまたは git stash | **新規** |
| R6 | python-docx で書式崩壊 | 技術 | 中 | 高 | **Major** | Windows Word COM API 修復で対応（実装済み） | ↔ R7 同等 |
| R7 | セル結合テーブルへの書き込み失敗 | 技術 | 中 | 中 | **Major** | E2E テストで基本動作は確認済み。実データでの検証が必要 | **↓ 軽減**（E2E通過により） |
| R8 | watcher プロセス常駐管理（異常終了、再起動） | 運用 | 中 | 中 | **Major** | systemd ユニットファイルまたは supervisor での管理を推奨 | **新規** |
| R9 | trigger.txt 競合によるトリガー消失 | 技術 | 低 | 低 | **Minor** | C5-06: クールダウン機構で緩和。README に注意書き | **新規** |
| R10 | openpyxl DV/CF 破損 | 技術 | 高 | 低（extLst 再注入済み） | **Minor** | C4-08/09: fill_excel.py の extLst 再注入で対策済み。実データで最終確認 | **↓ 解消に近い**（Critical→Minor） |
| R11 | Google Drive 同期の遅延・競合 | 環境 | 低 | 中 | **Minor** | 手動 USB 転送のフォールバック | ↔ 前回同等 |
| R12 | Windows Word COM API の環境依存 | 環境 | 中 | 低 | **Minor** | jami-abstract-pandoc 実績あり。VBScript 方式で実装済み | ↔ 前回同等 |

### リスク評価の変化サマリ（report4 比）

- **大幅改善**: R1（スケジュール: Critical → Major） — Steps 0-7 完了、インフラ全実装済み
- **解消**: R3（openpyxl: Critical → Minor） — extLst 再注入ロジック実装済み
- **解消**: R5（行オーバーフロー）, R6（reference.docx）, R9（段落インデックス問題）, R10（YAML 整合性） — 全て実装・テストにより解消
- **新規**: R2（Webhook URL）, R3（JSON injection）, R4（fig/figs）, R5（sync上書き）, R8（watcher常駐管理）
- **不変**: R6（python-docx 書式崩壊）, R11（Google Drive 遅延）, R12（Windows COM）

### 提出期限までの残作業と優先度

| 優先度 | 作業 | 所要期間（見込み） | 備考 |
|--------|------|----------------|------|
| P0 | C5-01: Webhook URL 除去 | 即時 | セキュリティ修正 |
| P1 | 本文執筆（youshiki1_2.md 15p） | 2-4週間 | 最大のボトルネック。内容は研究者が記述 |
| P1 | 本文執筆（youshiki1_3.md） | 1-2週間 | 同上 |
| P2 | Step 8 実装（Prompt 8-1, 8-2, 8-3） | 3-5日 | 本レビューの指摘を反映した上で実装 |
| P2 | 実データ（data/source/）でのフルビルド検証 | 1-2日 | E2E はスタブで通過済み。実データで書式検証 |
| P3 | 実データ YAML 記入（main/00_setup/） | 1週間 | プレースホルダ → 実データへの置換 |
| P3 | Windows PDF 変換の end-to-end 検証 | 1日 | VBScript 方式での PDF 品質確認 |
