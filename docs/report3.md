# 敵対的レビュー報告書（第3回）

レビュー実施日: 2026-04-04
レビュー対象: CLAUDE.md, SPEC.md, README.md, docs/prompts.md, docker/*, scripts/*, data/source/*, main/
前回レビュー: docs/report2.md (2026-04-03〜04)

## サマリ

- Critical: 2件 (新規2) → **対応済み2**
- Major: 8件 (新規5 / 既知未対応3) → **対応済み3 / 残5**
- Minor: 5件 (新規5) → **対応済み1 / 残4**
- Note: 3件 (新規3)

### 対応状況一覧

| ID | 重大度 | 状態 | 概要 |
|----|------|------|------|
| C3-01 | Critical | **対応済み** | 様式2-2 (Tables 5-9) の列構成がprompts.mdの記述と不一致 → budget.details スキーマ修正済み（unit_price削除、institution追加、列・行構造注記追加） |
| C3-02 | Critical | **対応済み** | scripts/ の3スクリプトが別プロジェクト → __archives/ に退避済み、Prompt 5-2 を「新規作成」に変更、README.md 更新済み |
| C3-03 | Major | **対応済み** | ドキュメントが `make build` を参照 → CLAUDE.md/SPEC.md/README.md/prompts.md を `scripts/build.sh` に統一済み |
| C3-04 | Major | **対応済み** | Table 3 行構成の誤記 → prompts.md Prompt 3-1 に正確な行構成と「物品費=equipment+consumablesの合算」注記を追加済み |
| C3-05 | Major | 未対応 | ruamel.yaml の C拡張 (ruamel.yaml.clib) が Docker 内で未インストール（実用上問題なし） |
| C3-06 | Major | 未対応 | templates/ ディレクトリと reference.docx が未作成（実装フェーズで対応） |
| C3-07 | Major | **対応済み** | prompts.md Step 6「OneDrive」→「Google Drive」に修正済み（2箇所） |
| C3-08 | Major | 既知未対応 | 全実装ファイル未作成（report2 C2-11） |
| C3-09 | Major | 既知未対応 | openpyxl Data Validation 拡張非対応（report2 C2-12） |
| C3-10 | Major | 既知未対応 | openpyxl 条件付き書式破損リスク（report2 C2-13） |
| C3-11 | Major | 既知未対応 | pyproject.toml 未作成（Prompt 0-2 未実施） |
| C3-12 | Minor | 未対応 | data/dummy/ が空（E2Eテスト用ダミーデータ未作成） |
| C3-13 | Minor | 未対応 | Dockerfile で ruamel.yaml.clib を明示的にインストールしていない |
| C3-14 | Minor | 未対応 | prompts.md に E2E テスト用 Prompt が存在しない |
| C3-15 | Minor | **対応済み** | README.md Scripts セクション → C3-02 対応時に更新済み |
| C3-16 | Minor | 未対応 | Docker 起動時に他プロジェクトの orphan container 警告が出る |
| C3-17 | Note | 新規 | Prompt 0-1 完了チェック全項目済みは検証可能 — Docker環境は正常動作 |
| C3-18 | Note | 新規 | SPEC.md §4.1 と実ファイル docker-compose.yml は完全一致 |
| C3-19 | Note | 新規 | Docker内 file permission (-u flag) 正常動作確認済み |

## report2.md との差分サマリ

- report2.md の未対応項目で今回解消されたもの: 1件（C2-03 Docker環境 → 部分的に解消）
- report2.md の未対応項目で依然として未対応のもの: 3件（C2-11, C2-12, C2-13）
- report2.md の「対応済み」項目で事実誤認が含まれていたもの: 1件（C2-01 Table 3 構造記述）
- report2.md に記載がなく今回新規発見したもの: 11件

---

## 指摘事項

---

### [C3-01] (Critical) 様式2-2 (Tables 5-9) の列構成が prompts.md と不一致 — config.yaml スキーマに波及 → **対応済み**

- **箇所**: docs/prompts.md Prompt 1-1:240-248行 (budget.details 設計), Prompt 3-1:649行
- **前回対応状況**: 新規（report2 C2-02 で追加されたスキーマ自体に誤りがある）
- **内容**: report2 C2-02 で追加された config.yaml の `budget.details` スキーマは以下の列構成を前提としている:

  | 列 | prompts.md 記載 |
  |----|---------------|
  | 0 | 項目（メーカー名、品名、仕様等） |
  | 1 | 数量 |
  | 2 | **単価** |
  | 3 | **金額** |
  | 4 | 使用目的及び必要性 |

  しかし実際の Tables 5-9 (様式2-2, 12r×5c) をダンプした結果、列構成は以下の通り:

  | 列 | 実際のヘッダ |
  |----|-----------|
  | 0 | 項目 (ﾒｰｶｰ名・規格等を併記) |
  | 1 | 数量 (単位) |
  | 2 | **金額（単位：千円）** |
  | 3 | **設置機関／担当研究機関** |
  | 4 | 使用目的及び必要性 |

  **差異:**
  1. 「単価」列は存在しない — 金額のみ（列2）
  2. 列3は「設置機関／担当研究機関」であり、config.yaml に対応フィールドがない
  3. config.yaml の `unit_price` フィールドは対応する列が存在しない
  4. config.yaml の `amount` の説明「= quantity × unit_price」は誤り（単価列がないため）

  さらに、行構造もフラットな行単位ではなく**カテゴリブロック構造**:
  ```
  Row 0: ヘッダ
  Row 1: "直接経費 / Ⅰ．物品費 / 1.設備備品費 / 2.消耗品費" ← 1セルに複数カテゴリ
  Row 2: 小計
  Row 3: "Ⅱ．人件費・謝金 / 1.人件費 / 2.謝金" ← 同様
  Row 4: 小計
  Row 5: "Ⅲ．旅費"
  ...
  ```

  各カテゴリの品目は**セル内の段落（改行区切り）**として記入される構造であり、prompts.md が想定する「行ごとに1品目」のフラットリスト構造とは根本的に異なる。

- **影響**: `budget.details` スキーマを前提に fill_forms.py を実装すると、(a) 存在しない単価列にデータを書こうとする、(b) 設置機関列を埋められない、(c) カテゴリブロック内の段落操作ができない、の3点で完全に動作しない。YAML スキーマの再設計と Prompt 3-1 のセルマッピング修正が必要。
- **推奨対応**:
  1. config.yaml の `budget.details` を以下のように修正:
     ```yaml
     budget:
       details:
         - year: 1
           line_items:
             - category: equipment  # 設備備品費 / consumables / travel / ...
               name: "品名（メーカー名、型番）"
               quantity: "1台"          # 数量+単位（文字列）
               amount: 0               # 千円
               institution: "○○大学"   # 設置機関／担当研究機関
               justification: "使用目的"
     ```
  2. `unit_price` フィールドを削除
  3. `institution` フィールドを追加
  4. Prompt 3-1 にカテゴリブロック構造での段落操作方針を追記

---

### [C3-02] (Critical) scripts/ の3スクリプトが別プロジェクト (cancer_claims_validation) のもの → **対応済み**

- **箇所**: scripts/create_package.sh, scripts/upload_to_gdrive.sh, scripts/backup.sh
- **前回対応状況**: 新規
- **内容**: 以下の3スクリプトが別プロジェクト由来のまま放置されている:

  | スクリプト | 問題 |
  |-----------|------|
  | `create_package.sh` | ZIP名が `cancer_claims_validation_package_*.zip`。PACKAGE_INFO.md に「Cancer Claims Validation」と記載。step0_interval_analysis, step1_table1 等の別プロジェクトのパスを参照。 |
  | `upload_to_gdrive.sh` | `cancer_claims_validation_package_*.zip` を検索対象としており、本プロジェクトのファイルは一切検出されない。 |
  | `backup.sh` | BACKUP_TARGETS に `"icdo3-to-ci5-mapper"`, `"jp-cancer-code-mapping"` 等の別プロジェクトディレクトリが設定されている。 |

  `create_package.sh` は prompts.md Prompt 5-2 で「更新」と指示されているが、実態は別プロジェクトのスクリプトであり、更新ではなく**完全な書き直し**が必要。

- **影響**: 
  - `scripts/create_package.sh` を実行すると、無関係なファイルをパッケージしようとして失敗する
  - `scripts/upload_to_gdrive.sh` は本プロジェクトでは何もアップロードできない
  - `scripts/backup.sh` は存在しないディレクトリをバックアップしようとして失敗する
  - README.md の Scripts セクションはこれらを「本プロジェクト用」として記載しており、利用者を誤解させる
- **推奨対応**:
  1. 3スクリプトを `__archives/` に退避（または削除）
  2. Prompt 5-2 の指示を「create_package.sh を**新規作成**」に変更
  3. backup.sh, upload_to_gdrive.sh も本プロジェクト用に書き直す Prompt を追加するか、Prompt 6-1 の同期スクリプトに統合

---

### [C3-03] (Major) ドキュメントのビルドコマンド記述が実態と不一致 — `make build` → scripts/ に統一が必要 → **対応済み**

- **箇所**: CLAUDE.md:Makefile行, SPEC.md §0.3, README.md:59行, docs/prompts.md Prompt 5-1
- **前回対応状況**: report2 C2-03 の Docker 部分は解消済み。ビルドコマンドの整合性は新規指摘。
- **内容**: ビルドは scripts/ フォルダのシェルスクリプトで行う方針だが、以下の4ファイルが `make build` を前提に記述されている:

  | ファイル | 該当箇所 | 記載内容 |
  |---------|---------|---------|
  | CLAUDE.md | Quick Reference / Containers 前 | `Makefile  # ビルドシステム` |
  | SPEC.md | §0.3 設計方針 | 「再現可能ビルド: `make build` で全成果物を再生成可能」 |
  | README.md | Getting Started | `make build` |
  | prompts.md | Prompt 5-1 | Makefile 作成の Prompt 全体 |

  また prompts.md Prompt 5-1 は Makefile 作成専用の Prompt であり、scripts/ ベースのビルドスクリプト（例: `scripts/build.sh`）に書き換える必要がある。

- **影響**: ドキュメント通りに `make build` を実行するとコマンドが見つからずエラー。AIエージェントに prompts.md を渡した際に不要な Makefile を作成してしまうリスク。
- **推奨対応**:
  1. CLAUDE.md, SPEC.md, README.md の `make build` 記述を `scripts/build.sh`（または適切なスクリプト名）に変更
  2. prompts.md Prompt 5-1 を Makefile 作成から scripts/build.sh 作成に書き換え
  3. CLAUDE.md の Project Structure から `Makefile` 行を削除

---

### [C3-04] (Major) 様式2-1 Table 3 の実際の行構成が report2 C2-01 の記述と不一致 → **対応済み**

- **箇所**: docs/report2.md C2-01 の Table 3 構造記述, docs/prompts.md Prompt 1-1
- **前回対応状況**: 新規（report2 の「対応済み」項目の事実誤認）
- **内容**: report2 C2-01 は Table 3 (様式2-1, 9r×7c) の行構成を以下のように記述した:

  | 行 | report2 C2-01 の記述 |
  |----|-------------------|
  | 1 | **設備備品費** |
  | 2 | **消耗品費** |
  | 3 | **（小計: 物品費）** |

  しかし実際の Table 3 をダンプした結果:

  | 行 | 実際の内容 |
  |----|---------|
  | 0 | ヘッダ（研究費の内訳 / 所要経費） |
  | 1 | ヘッダ（１年目〜５年目） |
  | 2 | **直接経費** |
  | 3 | **ア．物品費**（設備備品費・消耗品費の合算） |
  | 4 | **イ．人件費・謝金** |
  | 5 | **ウ．旅費** |
  | 6 | **エ．その他**（消費税相当額を含む） |
  | 7 | **間接経費（原則３０％）** |
  | 8 | **合計（①＋②）** |

  Table 3 に「設備備品費」「消耗品費」の**個別行は存在しない**。「ア．物品費」として1行に合算される。

  config.yaml の `budget.yearly` に `equipment` と `consumables` を分離したこと自体は Tables 5-9（様式2-2）で設備備品費/消耗品費を区別するために有用だが、Table 3 への記入時には**合算が必要**であることが prompts.md に明記されていない。

- **影響**: fill_forms.py 実装時に Table 3 の「ア．物品費」行に equipment + consumables の合算値を書くべきところ、個別行に書こうとして失敗する可能性。
- **推奨対応**: prompts.md Prompt 3-1 のセルマッピングに Table 3 の**正確な行構成**を記載し、「物品費 = equipment + consumables の合算」であることを明記。

---

### [C3-05] (Major) ruamel.yaml の C拡張 (ruamel.yaml.clib) が Docker 内で未インストール

- **箇所**: docker/python/Dockerfile:26-31行
- **前回対応状況**: 新規
- **内容**: Docker コンテナ内で検証した結果:
  ```
  ruamel.yaml.clib: NOT INSTALLED (C extension missing)
  ruamel.yaml version: (0, 19, 1)
  ```

  `pip install ruamel.yaml` は C拡張 (`ruamel.yaml.clib`) を自動インストールしない場合がある。python:3.12-slim イメージにはCコンパイラ (`gcc`) が含まれておらず、ruamel.yaml.clib のビルドに失敗するため。

  C拡張がない場合、pure Python フォールバック (`ruamel.yaml.cyaml` 不使用) で動作するが、パフォーマンスが**約10-50倍低下**する。本プロジェクトの YAML ファイルサイズでは実用上問題ないが、大量のYAMLを処理する場合にボトルネックとなる。

- **影響**: 機能面では問題なし（pure Python fallback で動作）。パフォーマンスへの影響は軽微。ただし、意図的にC拡張を入れる設計であった場合は期待と乖離。
- **推奨対応**: Dockerfile に以下を追加（C拡張が必要な場合）:
  ```dockerfile
  RUN apt-get update && apt-get install -y --no-install-recommends gcc \
      && pip install --no-cache-dir ruamel.yaml.clib \
      && apt-get purge -y gcc && apt-get autoremove -y
  ```
  または、pure Python で十分なら prompts.md / SPEC.md にその旨を明記。

---

### [C3-06] (Major) templates/ ディレクトリと reference.docx が未作成

- **箇所**: templates/reference.docx（不在）
- **前回対応状況**: 新規（report2 C2-09 で作成手順を prompts.md に追記済みだが、実ファイルが未作成）
- **内容**: prompts.md Prompt 3-2 で参照される `templates/reference.docx` が存在しない。templates/ ディレクトリ自体が未作成。

  Prompt 3-2 の build_narrative.sh は以下のコマンドを生成する:
  ```
  pandoc INPUT.md --reference-doc=templates/reference.docx --output OUTPUT.docx
  ```

  reference.docx がない場合、Pandocはデフォルトのスタイルで出力し、元の様式とフォント・段落書式が不一致になる。

  report2 C2-09 で作成手順は prompts.md に追記済み:
  1. `pandoc --print-default-data-file reference.docx -o templates/reference.docx`
  2. Wordでスタイル編集
  3. git管理

  しかし手順2はWindows環境（Microsoft Word）が必要であり、Linux環境のみでは完了できない。

- **影響**: build_narrative.sh 実行時にファイル不在エラー。スクリプト内にフォールバック（デフォルト生成 + 警告）が設計されているが、最終的なフォント一致は Windows 側での手動調整が必須。
- **推奨対応**:
  1. templates/ ディレクトリを作成（.gitkeep）
  2. デフォルト reference.docx を生成して配置: `pandoc --print-default-data-file reference.docx -o templates/reference.docx`
  3. .gitignore で templates/ を追跡対象にする（現状は問題なし）
  4. build_narrative.sh の設計に「reference.docx 不在時は自動生成して続行」のフォールバックが含まれていることを確認

---

### [C3-07] (Major) prompts.md Step 6 のタイトルが「OneDrive」だが内容は「Google Drive」 → **対応済み**

- **箇所**: docs/prompts.md:1115行, 1200行
- **前回対応状況**: 新規
- **内容**: 2箇所でサービス名が誤っている:

  | 行 | 記載 | 正しくは |
  |----|------|--------|
  | 1115 | `## Step 6: OneDrive同期設定` | `## Step 6: Google Drive同期設定` |
  | 1200 | `OneDrive経由で転送されたdocxファイル` | `Google Drive経由で転送されたdocxファイル` |

  CLAUDE.md, SPEC.md, README.md, prompts.md の他の全箇所では「Google Drive」「rclone gdrive」と正しく記載されており、この2箇所のみ不整合。

- **影響**: 実装者が OneDrive 用のスクリプトを書いてしまうリスク（低いが、AIエージェントに渡す場合は文脈混乱のリスクあり）。
- **推奨対応**: 2箇所を「Google Drive」に修正。

---

### [C3-08] (Major) 全実装ファイル未作成

- **箇所**: main/ 以下全体, pyproject.toml
- **前回対応状況**: report2 C2-11 未対応（実装フェーズで対応）
- **内容**: main/ 配下の全ディレクトリに .gitkeep のみ。以下が未作成:
  - `main/00_setup/*.yaml` — 4ファイル（config, researchers, other_funding, security）
  - `main/step01_narrative/*.md` — 2ファイル（youshiki1_2, youshiki1_3）
  - `main/step02_docx/*.py, *.sh` — 3ファイル（fill_forms, fill_security, build_narrative）
  - `main/step03_excel/fill_excel.py`
  - `scripts/windows/*.ps1` — 2ファイル（repair_and_pdf, batch_convert）
  - `scripts/build.sh`（ビルド統合スクリプト）, `pyproject.toml`

  提出期限まで**46日**（2026-04-04 → 2026-05-20）。全実装 + 本文執筆（15ページ）が必要。

- **影響**: スケジュールリスクが前回（47日）より1日進行。実装着手は Docker 環境構築完了により可能になった。
- **推奨対応**: 即座に Step 1（YAML定義）から着手。本文執筆は Step 2 完了後に並行開始。

---

### [C3-09] (Major) openpyxl Data Validation 拡張非対応

- **箇所**: data/source/r08youshiki6.xlsx
- **前回対応状況**: report2 C2-12 未対応（実装時に検証予定）
- **内容**: 前回から変化なし。openpyxl 読込時に `UserWarning: Data Validation extension is not supported and will be removed` が発生する。Docker 内の openpyxl は 3.1.5 であり、依然としてこの拡張は非サポート。
- **影響**: 保存時にドロップダウンリストが削除される可能性。
- **推奨対応**: Step 4 実装時に早期テスト。失敗時は xlsx ZIP 操作で `extLst` 要素を再注入。

---

### [C3-10] (Major) openpyxl 条件付き書式破損リスク

- **箇所**: data/source/r08youshiki6.xlsx
- **前回対応状況**: report2 C2-13 未対応（実装時に検証予定）
- **内容**: 前回から変化なし。19個の conditional_formatting ルールが存在。
- **影響**: 保存時に破損する可能性。
- **推奨対応**: 前回同様、実装時のテスト必須。

---

### [C3-11] (Major) pyproject.toml 未作成（Prompt 0-2 未実施）

- **箇所**: プロジェクトルート
- **前回対応状況**: report2 C2-03 の一部として言及
- **内容**: Docker 環境は構築済みだが、uv 代替環境（Prompt 0-2）が未実施。pyproject.toml が不在のため `uv sync` / `uv run` が使用不能。Makefile の `RUNNER=uv` オプションも前提を満たさない。
- **影響**: Docker が使えない環境での実行手段がない。ただし、Docker 環境が主要な実行環境であれば影響は限定的。
- **推奨対応**: Docker 優先で進め、pyproject.toml は必要に応じて後から対応。

---

### [C3-12] (Minor) data/dummy/ が空 — E2E テスト用ダミーデータ未作成

- **箇所**: data/dummy/（.gitkeep のみ）
- **前回対応状況**: 新規
- **内容**: prompts.md の前提文脈に「data/dummy/ はパイプラインのエンドツーエンドテスト用ダミーデータの配置場所」と明記されているが、ディレクトリは空。

  ダミーデータには以下が必要:
  - テスト用 YAML ファイル（config, researchers, other_funding, security の最小セット）
  - テスト用の小さな docx/xlsx スタブ（data/source/ がない環境でもテスト可能にする場合）
- **影響**: E2E テストが実行できない。ただし、data/source/ の実ファイルが存在する現環境では直接テスト可能。
- **推奨対応**: Step 1 完了後に、プレースホルダ値入りの YAML を data/dummy/ にコピーして配置。

---

### [C3-13] (Minor) Dockerfile で ruamel.yaml.clib を明示インストールしていない

- **箇所**: docker/python/Dockerfile:26-31行
- **前回対応状況**: 新規
- **内容**: C3-05 の補足。`pip install ruamel.yaml` のみで C拡張が入らない原因は python:3.12-slim にCコンパイラ (gcc) がないため。Cコンパイラを一時的にインストールするか、wheel が利用可能であれば `pip install ruamel.yaml.clib` で解決する。

  本プロジェクトの YAML ファイルサイズ（各数KB）では pure Python でも処理時間は数ミリ秒であり、実用上問題ない。
- **影響**: 軽微。パフォーマンスへの影響はほぼなし。
- **推奨対応**: SPEC.md または Dockerfile のコメントに「ruamel.yaml.clib は未インストール（pure Python fallback で動作）」を明記し、意図的であることを示す。

---

### [C3-14] (Minor) prompts.md に E2E テスト用 Prompt が存在しない

- **箇所**: docs/prompts.md 全体
- **前回対応状況**: 新規
- **内容**: prompts.md は Step 0〜7 まで定義しているが、「ダミーデータで全パイプラインを通す」E2E テストの Prompt がない。
  
  テストシナリオ例:
  1. data/dummy/ の YAML でパイプライン全体を実行
  2. 出力 docx/xlsx が開けることを確認
  3. ファイルサイズが 10MB 以下であることを確認
  4. 必須ファイルが揃っていることを確認（create_package.sh のバリデーション）
- **影響**: 各ステップの結合テストが計画されておらず、個別ステップは動くが結合すると壊れるリスク。
- **推奨対応**: Step 5 の後に「Step 5.5: E2E テスト」として Prompt を追加。または Prompt 5-1 (Makefile) に `make test` ターゲットを含める。

---

### [C3-15] (Minor) README.md Scripts セクションの説明が実態と不一致 → **対応済み**

- **箇所**: README.md:119-127行
- **前回対応状況**: 新規
- **内容**: README.md は以下のスクリプトを「本プロジェクト用」として記載:

  | スクリプト | README説明 | 実態 |
  |-----------|----------|------|
  | `scripts/create_package.sh` | パッケージング・バリデーション | cancer_claims 用 |
  | `scripts/backup.sh` | Google Drive (rclone) へバックアップ | 別プロジェクト参照 |
  | `scripts/upload_to_gdrive.sh` | Google Driveへのアップロード | cancer_claims 用 |
  | `scripts/sync_gdrive.sh` | Google Drive双方向同期 (rclone)（未作成） | 正確 |

- **影響**: 利用者の混乱。スクリプトを実行すると予期しない動作。
- **推奨対応**: C3-02 対応と同時に README.md を更新。

---

### [C3-16] (Minor) Docker 起動時に他プロジェクトの orphan container 警告

- **箇所**: docker/docker-compose.yml 実行時
- **前回対応状況**: 新規
- **内容**: `docker compose run` 実行時に以下の警告が出力される:
  ```
  Found orphan containers ([dp-surv-util-rstudio manifold-ged-r scr-python ...])
  ```
  これは他プロジェクトのコンテナが同一 Docker 環境に残存しているため。本プロジェクトの動作には影響しないが、ログが汚れる。
- **影響**: なし（機能面）。出力の可読性低下のみ。
- **推奨対応**: 不要。気になる場合は `docker compose -f docker/docker-compose.yml --project-name med-resist run ...` でプロジェクト名を明示。

---

### [C3-17] (Note) Docker環境は正常動作 — Prompt 0-1 完了チェック全項目を独立検証

- **箇所**: docker/python/Dockerfile, docker/docker-compose.yml
- **前回対応状況**: 新規
- **内容**: 以下を独立検証し、全項目の正常動作を確認:

  | チェック項目 | 結果 |
  |------------|------|
  | `docker compose build` | ✓ 成功 |
  | `python -c "import docx; import openpyxl; import yaml"` | ✓ 成功 |
  | `pandoc --version` | ✓ Pandoc 3.6.4 |
  | コンテナ内から `/workspace/data/source/` 参照 | ✓ 8ファイル確認 |
  | `-u $(id -u):$(id -g)` でのファイル書き込み | ✓ UID/GID一致 |
  | HOME=/tmp 環境変数 | ✓ 設定済み |

  インストール済みパッケージバージョン:
  - python-docx 1.2.0, openpyxl 3.1.5, PyYAML 6.0.3, ruamel.yaml 0.19.1, Jinja2 3.1.6

---

### [C3-18] (Note) SPEC.md §4.1 と実ファイル docker-compose.yml は完全一致

- **箇所**: SPEC.md:162-174行, docker/docker-compose.yml
- **前回対応状況**: report2 での修正済み
- **内容**: SPEC.md §4.1 の docker-compose.yml 記述:
  ```yaml
  services:
    python:
      build:
        context: ./python
        dockerfile: Dockerfile
      volumes:
        - ..:/workspace
      working_dir: /workspace
      environment:
        - HOME=/tmp
  ```
  実ファイルと**完全一致**を確認。

---

### [C3-19] (Note) prompts.md の Prompt 0-1 完了チェックは全て [x] 済み

- **箇所**: docs/prompts.md:113-119行
- **前回対応状況**: 前回変更後の状態を確認
- **内容**: 5項目すべて [x] チェック済み。独立検証（C3-17）でも全項目の正常動作を確認。

---

## リスクマトリクス

| # | リスク | カテゴリ | 影響度 | 発生確率 | 総合評価 | 対策 |
|---|-------|--------|------|--------|---------|-----|
| R1 | 様式2-2の列構成誤認によるスキーマ設計誤り | 要件 | 高 | 確定 | **Critical** | C3-01: config.yaml スキーマを実テーブルに合わせて再設計 |
| R2 | scripts/ が別プロジェクトのもので全く機能しない | 環境 | 高 | 確定 | **Critical** | C3-02: 3スクリプトを退避し本プロジェクト用に書き直し |
| R3 | ドキュメントが `make build` を参照しているが Makefile 不使用方針 | 要件 | 中 | 確定 | **Major** | C3-03: ドキュメント4ファイルのビルドコマンド記述を scripts/ に統一 |
| R4 | 提出期限まで46日で実装量ゼロ | スケジュール | 高 | 中〜高 | **Critical** | 即座に Step 1 着手。本文執筆と実装を並行 |
| R5 | openpyxl保存時にドロップダウン/条件付き書式が破損 | 技術 | 高 | 高 | **Critical** | C3-09/10: Step 4 実装初期に検証テストを実施 |
| R6 | Table 3 行構成の誤解に基づく予算テーブル記入失敗 | 要件 | 中 | 中 | **Major** | C3-04: Prompt 3-1 に正確な行構成を記載 |
| R7 | reference.docx 未作成によるPandoc出力の書式不一致 | 技術 | 中 | 高 | **Major** | C3-06: デフォルト生成→Windows側で調整の手順を実行 |
| R8 | python-docx で書式崩壊 | 技術 | 中 | 高 | **Major** | Windows Word COM API 修復で対応（設計済み） |
| R9 | セル結合テーブルへの書き込み失敗 | 技術 | 中 | 中 | **Major** | C2-14 セルマッピング表ベースのテスト駆動開発 |
| R10 | 段落インデックスベースの様式削除がdocx更新で壊れる | 技術 | 中 | 低 | **Major** | テキストパターンマッチとの併用を推奨 |
| R11 | Google Drive 同期の遅延・競合 | 環境 | 低 | 中 | **Minor** | 手動USB転送のフォールバック |
| R12 | Windows Word COM API の環境依存 | 環境 | 中 | 低 | **Minor** | jami-abstract-pandoc 実績あり |

---

## prompts.md 実装プロンプト品質検証結果

### 情報の十分性

| Prompt | 評価 | 問題点 |
|--------|------|--------|
| 0-1 Docker | ✓ 十分 | 完了済み。実際に構築・検証済み |
| 0-2 uv | △ 未検証 | 未実施のため品質未確認 |
| 1-1 config.yaml | ✗ 要修正 | budget.details の列構成が実テーブルと不一致（C3-01） |
| 1-2 researchers.yaml | ✓ 十分 | 様式4-1テーブル(10r×5c)の全行をカバー |
| 1-3 other_funding/security | ✓ 十分 | 様式3-1(6r×8c)、別紙5(24テーブル)、別添(13テーブル)対応済み |
| 2-1 様式1-2 | ✓ 十分 | セクション見出し修正済み、審査観点対応付き |
| 2-2 様式1-3 | ✓ 十分 | Type A での §4, §5 削除条件も明記 |
| 3-1 fill_forms.py | △ 要修正 | Table 3 行構成の訂正（C3-04）、セルマッピング概ね正確だが一部補正要 |
| 3-2 build_narrative.sh | △ 要補足 | reference.docx 作成手順は記載済みだが実ファイル未作成（C3-06） |
| 3-3 fill_security.py | ✓ 十分 | 別紙5/別添のテーブル構造と対応付け済み |
| 4-1 fill_excel.py | △ 要検証 | openpyxl 制約の検証が必須（C3-09, C3-10） |
| 5-1 Makefile | ✗ 要書換 | Makefile不使用方針のため scripts/build.sh 作成に変更が必要（C3-03） |
| 5-2 create_package.sh | ✗ 要修正 | 既存スクリプトが別プロジェクト（C3-02）、「更新」ではなく「新規作成」が必要 |
| 6-1 sync_gdrive.sh | ✓ 十分 | ただしタイトル誤記（C3-07） |
| 7-1 Windows scripts | ✓ 十分 | jami-abstract-pandoc 参照で設計方針明確 |

### 実行順序と依存関係

prompts.md の推奨順序: `Step 0 → 1 → 2 → 4 → 3 → 5 → 6 → 7`

依存関係は各 Prompt の「文脈」「参照」セクションで暗黙的に示されているが、**明示的な依存宣言がない**。

| 依存関係 | 明示されているか |
|---------|--------------|
| Step 3 は Step 1 の完了を前提 | △ 「参照」で yaml ファイルを指定しているが「Step 1 完了後」と明記していない |
| Step 4 は Step 1 の完了を前提 | △ 同上 |
| Step 5 は Step 3, 4 の完了を前提 | ✓ 「全コンポーネント完成後」と明記 |
| Step 3-2 は templates/reference.docx の存在を前提 | ✓ 作成手順が記載済み |

### 抜け漏れ

| 項目 | 存在するか |
|------|----------|
| ビルドスクリプト作成 Prompt | △ Prompt 5-1 が Makefile 前提 — scripts/build.sh 用に書換が必要（C3-03） |
| reference-doc 作成手順 | ✓ Prompt 3-2 内 |
| create_package.sh Prompt | ✓ Prompt 5-2（ただし「更新」→「新規作成」に要変更） |
| E2E テスト Prompt | ✗ **不在** — C3-14 で指摘 |
| ダミーデータ作成 Prompt | ✗ **不在** — 暗黙的に Step 1 後に配置する記述のみ |

---

## ドキュメント間整合性検証

### Docker 関連記述の4ファイル間整合性

| 項目 | CLAUDE.md | SPEC.md | README.md | prompts.md | 実ファイル |
|------|----------|---------|-----------|-----------|----------|
| サービス名 | python ✓ | python ✓ | (未記載) | python ✓ | python ✓ |
| ボリューム | ..:/workspace ✓ | ..:/workspace ✓ | (未記載) | ..:/workspace ✓ | ..:/workspace ✓ |
| 実行コマンド例 | `docker compose -f docker/docker-compose.yml run --rm -u ...` ✓ | (なし) | `docker compose -f docker/docker-compose.yml up -d --build` ✓ | `docker compose -f docker/docker-compose.yml run --rm ...` ✓ | N/A |
| HOME=/tmp | (なし) | ✓ | (なし) | ✓ | ✓ |

**結果**: Docker 関連記述は整合 ✓

### 出力ファイル名の統一性

| ファイル | CLAUDE.md | SPEC.md | prompts.md |
|---------|----------|---------|-----------|
| youshiki1_5_filled.docx | (提出書類一覧に記載なし) | ✓ | ✓ |
| youshiki1_2_narrative.docx | (提出書類一覧に記載なし) | ✓ | ✓ |
| youshiki1_3_narrative.docx | (提出書類一覧に記載なし) | ✓ | ✓ |
| besshi5_filled.docx | (提出書類一覧に記載なし) | ✓ | ✓ |
| betten_[氏名].docx | (提出書類一覧に記載なし) | ✓ | ✓ |
| youshiki6.xlsx | (提出書類一覧に記載なし) | ✓ | ✓ |
| youshiki7.xlsx | (提出書類一覧に記載なし) | ✓ | ✓ |
| youshiki8.xlsx | (提出書類一覧に記載なし) | ✓ | ✓ |

**結果**: SPEC.md と prompts.md 間のファイル名は統一 ✓（report2 C2-10 修正後）

---

## report2.md 対応済み項目の維持確認

| report2 ID | 報告状態 | 今回の確認結果 |
|-----------|--------|------------|
| C2-01 | 対応済み | △ config.yaml budget 修正済みだが、Table 3 構造記述が事実誤認（C3-04） |
| C2-02 | 対応済み | ✗ budget.details の列構成が実テーブルと不一致（C3-01） |
| C2-03 | 部分解消 | △ Docker環境は構築済み。ビルドコマンドのドキュメント整合性は未対応（C3-03） |
| C2-04 | 対応済み | ✓ 様式1-2 セクション見出し修正を確認 |
| C2-05 | 対応済み | ✓ 論文5本制限、全所属機関記載を確認 |
| C2-06 | 対応済み | ✓ 記載注意事項5項目の追記を確認 |
| C2-07 | 対応済み | ✓ 参考様式3種類の設計を確認 |
| C2-08 | 対応済み | ✓ 段落インデックスベースの削除ロジック設計を確認 |
| C2-09 | 対応済み | ✓ reference-doc 作成手順の記載を確認（ただし実ファイル未作成: C3-06） |
| C2-10 | 対応済み | ✓ besshi5_filled.docx への修正を確認 |
| C2-11 | 未対応 | ✗ 依然全ファイル未作成（C3-08） |
| C2-12 | 未対応 | ✗ 依然未テスト（C3-09） |
| C2-13 | 未対応 | ✗ 依然未テスト（C3-10） |
| C2-14 | 対応済み | ✓ セルマッピング表の追記を確認 |
| C2-15〜C2-23 | 対応済み | ✓ 全て修正維持を確認 |

---

## 優先対応順序の推奨

1. **C3-01**: config.yaml budget.details スキーマを実テーブル列構成に合わせて修正（全後続実装に影響）
2. **C3-04**: prompts.md Prompt 3-1 の Table 3 行構成を正確な内容に訂正
3. **C3-02**: scripts/ の3スクリプトを退避し、Prompt 5-2 の指示を「新規作成」に変更
4. **C3-03, C3-07**: ドキュメントの即時修正（`make build` → scripts/, 「OneDrive」→「Google Drive」）
5. **Step 1 着手**: YAML 定義（C3-01 修正後の正しいスキーマで）
6. **C3-06**: templates/ ディレクトリ作成 + デフォルト reference.docx 生成
7. **Step 2 → 4 → 3 → 5**: prompts.md 推奨順序で実装進行
8. **C3-09, C3-10**: Step 4 実装初期に openpyxl 制約の検証テスト
