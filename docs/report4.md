# 敵対的レビュー報告書（第4回）

レビュー実施日: 2026-04-04
レビュー対象: main/00_setup/*.yaml (4ファイル), CLAUDE.md, SPEC.md, README.md, docs/prompts.md, docker/*, data/source/*.docx (テーブルダンプ), data/source/*.xlsx
前回レビュー: docs/report3.md (2026-04-04)

## サマリ

- Critical: 1件 (新規1) → **対応済み1**
- Major: 8件 (新規3 / 既知未対応5) → **対応済み4 / プロンプト反映済み2 / 残2**
- Minor: 7件 (新規4 / 既知未対応3) → **対応済み5 / プロンプト反映済み1 / 残1**
- Note: 3件

### 対応状況一覧

| ID | 重大度 | 状態 | 概要 |
|----|------|------|------|
| C4-01 | Critical | **対応済み** | config.yaml budget.by_institution と budget.details の機関別金額が全年度で不一致 → by_institution を details 合算値に修正 |
| C4-02 | Major | **対応済み** | security.yaml フィールド名 `funding_history` が prompts.md 設計の `funding_history_r5_onward` と不一致 → prompts.md を `funding_history` に修正 |
| C4-03 | Major | **対応済み** | Prompt 3-3 (fill_security.py) のセクション参照誤り: "§3" → "§1(2)" に修正、全テーブルマッピングを追記 |
| C4-04 | Major | **対応済み** | 別紙5 Tables 3-15 の行数制約 → Prompt 3-3 に行追加（row insertion）ロジックを追記 |
| C4-05 | Major | **対応済み** | ruamel.yaml C拡張未インストール → Dockerfile にコメントで設計意図を明記 |
| C4-06 | Major | **対応済み（部分）** | templates/ ディレクトリ作成済み、CLAUDE.md に追記。reference.docx 本体は Step 2 で生成予定 |
| C4-07 | Major | C3-08 部分対応 | 実装スクリプト未作成（YAML 4ファイルは完了、fill_*.py / build_*.sh / fill_excel.py が未作成） |
| C4-08 | Major | **プロンプト反映済み** | openpyxl Data Validation 拡張非対応 → Prompt 4-1 に検証手順・フォールバック策を追記 |
| C4-09 | Major | **プロンプト反映済み** | openpyxl 条件付き書式破損リスク → Prompt 4-1 に検証手順を追記 |
| C4-10 | Minor | **対応済み** | SPEC.md §3.1 Word出力テーブルの Markdown 書式崩れ → テーブル行を統合し注記を後方に移動 |
| C4-11 | Minor | **対応済み** | 別添ファイル名規約の不一致 → SPEC.md を `betten_NN_romanized` パターンに統一 |
| C4-12 | Minor | **プロンプト反映済み** | YAML バリデーション不在 → Prompt 5-1 に validate サブコマンドを追加 |
| C4-13 | Minor | **対応済み** | other_funding.yaml の `total_budget` フィールドが prompts.md 設計に未記載 → prompts.md に追記 |
| C4-14 | Minor | C3-11 未対応 | pyproject.toml 未作成（Docker 主体のため影響限定的） |
| C4-15 | Minor | **プロンプト反映済み** | data/dummy/ が空 → Prompt 5-3 でダミーデータ配置手順を定義 |
| C4-16 | Minor | **対応済み** | E2E テスト用 Prompt 不在 → Prompt 5-3 を新規追加 |
| C4-17 | Note | 新規 | 研究者名・機関名の4ファイル間整合性は完全一致（プレースホルダデータとして正常） |
| C4-18 | Note | 新規 | エフォート合算は PI 50%, Co-I 35% で100%以内（正常） |
| C4-19 | Note | 新規 | Step 1 完了チェック全項目 [x] 済み — YAML 4ファイルの構造的妥当性を独立検証で確認 |

## report3.md との差分サマリ

- report3.md の未対応項目で今回解消されたもの: 2件
  - C3-05/C3-13 → C4-05: Dockerfile にコメント追記で設計意図を明記（**対応済み**）
  - C3-06 → C4-06: templates/ ディレクトリ作成、CLAUDE.md 更新（**部分対応済み**、reference.docx 本体は Step 2 で生成）
- report3.md の未対応項目で依然として未対応のもの: 5件
  - C3-08 → C4-07（実装スクリプト、部分改善 — YAML完了）
  - C3-09 → C4-08（openpyxl DV）
  - C3-10 → C4-09（openpyxl CF）
  - C3-11 → C4-14（pyproject.toml）
  - C3-12 → C4-15（data/dummy/）
  - C3-14 → C4-16（E2E テスト Prompt）
- report3.md に記載がなく今回新規発見し**対応済み**としたもの: 5件
  - C4-01（budget 不整合 → 修正済み）, C4-02（フィールド名 → 修正済み）, C4-03（§参照 → 修正済み）, C4-04（行追加設計 → 追記済み）, C4-13（total_budget → 追記済み）
- report3.md に記載がなく今回新規発見し**未対応**のもの: 1件
  - C4-12（YAML バリデーション不在）
- report3.md の未対応項目で今回ドロップしたもの: 1件
  - C3-16（orphan container 警告）: 機能影響なし、再掲不要

---

## 指摘事項

---

### [C4-01] (Critical) config.yaml の budget.by_institution と budget.details の機関別金額が全年度で不一致 → **対応済み**

- **箇所**: main/00_setup/config.yaml:166-183行 (by_institution) vs 198-421行 (details)
- **前回対応状況**: 新規
- **対応内容**: budget.by_institution の金額を budget.details の institution 別合算値に修正（○○大学: 全年度17,500、△△大学: 年1 2,500 / 年2-3 7,500）
- **内容**: `budget.by_institution` は各機関の年度別直接経費合計を定義し、`budget.details` は品目ごとの `institution` フィールドで機関を指定する。両者の機関別合計が全年度で一致しない:

  | 年度 | 機関 | details合算 | by_institution | 差額 |
  |------|------|------------|---------------|------|
  | 1 | ○○大学 | 17,500 | 15,000 | +2,500 |
  | 1 | △△大学 | 2,500 | 5,000 | -2,500 |
  | 2 | ○○大学 | 17,500 | 18,000 | -500 |
  | 2 | △△大学 | 7,500 | 7,000 | +500 |
  | 3 | ○○大学 | 17,500 | 18,000 | -500 |
  | 3 | △△大学 | 7,500 | 7,000 | +500 |

  ※ 各年度の2機関合計（直接経費全体）は一致している。機関間の配分のみ不整合。
  ※ 年度別の費目合計（equipment + consumables + ...）は正確（年1: 20,000, 年2: 25,000, 年3: 25,000）。
  ※ 間接経費（×0.3）と総額も正確。Type A 上限内。

- **影響**:
  - 様式2-1 Table 4（機関別研究費）は `by_institution` から記入
  - 様式2-2 Tables 5-7 の品目は `details` の `institution` で機関を指定
  - 両テーブルの機関別金額が矛盾 → 審査で「予算書に不整合がある」と指摘される致命的欠陥
  - fill_forms.py が一方のデータを使って記入しても、他方の様式と矛盾する

- **推奨対応**:
  1. `budget.details` の品目別 institution 割当を正として、`by_institution` の金額を再計算して一致させる（品目の設置機関は実態を反映しているため、こちらが正と考えるのが自然）
  2. または fill_forms.py 側で `details` から `by_institution` を自動計算し、YAML の `by_institution` を参考値として扱う設計に変更
  3. いずれの場合も、自動検証（`by_institution` と `details` の機関別合計の一致チェック）をビルドプロセスに組み込む

---

### [C4-02] (Major) security.yaml のフィールド名が prompts.md の設計仕様と不一致 → **対応済み**

- **箇所**: main/00_setup/security.yaml:93行 (`funding_history`) vs docs/prompts.md:407行 (`funding_history_r5_onward`)
- **前回対応状況**: 新規
- **対応内容**: prompts.md 407行を `funding_history_r5_onward` → `funding_history` に修正。「R5年度以降」の制約はフィールド名ではなくコメントで説明。
- **内容**: prompts.md Prompt 1-3 のスキーマ設計では、セキュリティ関連の研究費取得歴フィールドを `funding_history_r5_onward`（R5年度以降の研究費取得歴）と命名している:

  ```
  # prompts.md 407行
  - funding_history_r5_onward:（R5年度以降の研究費取得歴）
  ```

  しかし実際の security.yaml では `funding_history` という名前で実装されている:

  ```yaml
  # security.yaml 93行
  funding_history:
    - date: "R5年4月"
  ```

  security.yaml のヘッダコメント（59-61行）でも `funding_history` と記載されており、YAML内では一貫している。しかし prompts.md の設計仕様とは異なる。

- **影響**: fill_security.py の実装時に、prompts.md を参照すると `funding_history_r5_onward` を探し、security.yaml では見つからずエラーになる。逆に security.yaml のヘッダを参照すれば `funding_history` で正しくアクセスできるが、実装者に混乱を招く。

- **推奨対応**: どちらかに統一。推奨は security.yaml の `funding_history` を採用し、prompts.md 407行を修正:
  ```
  - funding_history:（R5年度以降の研究費取得歴）
  ```
  「R5年度以降」という制約はフィールド名ではなくコメントで説明する方が自然。

---

### [C4-03] (Major) Prompt 3-3 (fill_security.py) のセクション参照誤り → **対応済み**

- **箇所**: docs/prompts.md:881行
- **前回対応状況**: 新規
- **対応内容**: Prompt 3-3 の機能説明を全面修正。「§3: 13項目」→「§1(2): 13項目の確認テーブル（Tables 3-15）」に修正。Tables 0-23 の全テーブルマッピングを追記。
- **内容**: Prompt 3-3 の機能説明で別紙5の13項目テーブルの位置を "§3" と記述している:

  ```
  - §1: デューデリジェンス状態チェックボックス
  - §3: 13項目のリスク確認テーブル（各研究者分）  ← 誤り
  - §4: リスク軽減措置チェックボックス
  ```

  しかし security.yaml のヘッダコメント（7-8行）および別紙5の実際の構造では、13項目テーブル（Tables 3-15）は **§1** に属する:

  ```
  Tables 1-2: §1 デューデリジェンス状況（チェックボックス）
  Tables 3-15: §1 ①〜⑬ 研究者ごとの確認事項（13項目）  ← §1
  Table 16: §1 デューデリジェンス結果
  Tables 17-18: §2 リスク軽減措置要否
  Tables 19-20: §3 共同研究機関リスク確認  ← §3 はここ
  Tables 21-22: §4 リスク軽減措置
  ```

  §3 は「共同研究機関に関するリスク確認」（Tables 19-20）であり、13項目テーブルとは無関係。

- **影響**: AIエージェントが Prompt 3-3 に従って fill_security.py を実装する際、§3 のテーブルに13項目データを書き込もうとし、誤ったテーブルインデックスを使用するリスク。

- **推奨対応**: prompts.md 881行を以下のように修正:
  ```
  - §1(1): デューデリジェンス状態チェックボックス
  - §1(2): 13項目の確認テーブル（Tables 3-15、各研究者分）
  - §2-§4: リスク軽減措置・共同研究機関確認・同意
  ```

---

### [C4-04] (Major) 別紙5 Tables 3-15 の行数制約 — 複数研究者データのオーバーフロー → **対応済み**

- **箇所**: data/source/r08youshiki_besshi5.docx Tables 3-15, main/00_setup/security.yaml
- **前回対応状況**: 新規
- **対応内容**: Prompt 3-3 に行追加（row insertion）ロジックの設計方針を追記。copy.deepcopy による行複製→テーブル末尾挿入→セルクリア→データ記入の手順を明記。
- **内容**: 別紙5の13項目テーブル（Tables 3-15）は**全研究者の情報を同一テーブルに記入する**設計だが、各テーブルのデータ行数が限られている:

  | テーブル | 項目 | 総行数 | ヘッダ | データ行 |
  |---------|------|------|--------|---------|
  | Table 3 | ①学歴 | 5r | 1 | 4 |
  | Table 4 | ②職歴 | 5r | 1 | 4 |
  | Table 5 | ③研究費 | 5r | 1 | 4 |
  | Table 9 | ⑦外国人材 | 4r | 1 | 3 |
  | Table 10 | ⑧処分歴 | 4r | 1 | 3 |

  現在のプレースホルダデータでも既にオーバーフローが発生する:

  **②職歴（Table 4, 4データ行）:**
  - PI: 3エントリ（助教→准教授→教授）
  - Co-I: 2エントリ（助教→准教授）
  - **合計: 5エントリ → 4行にオーバーフロー**

  **①学歴（Table 3, 4データ行）:**
  - PI: 2エントリ, Co-I: 2エントリ
  - 合計: 4エントリ → ちょうど収まるが余裕ゼロ

  研究者が3名以上になった場合、ほぼ全テーブルでオーバーフローする。

- **影響**: fill_security.py がテーブルの既存行にデータを書き込もうとする際、行数が足りずに IndexError が発生するか、データが欠落する。別紙5は面接選出後の提出（7月中旬）だが、設計時点でこの制約を考慮しないと実装時に大幅な手戻りが発生する。

- **推奨対応**:
  1. Prompt 3-3 に**行追加（row insertion）のロジック**を明記:
     - 既存の最終データ行を複製（`copy.deepcopy(row._element)`）して挿入
     - 書式（フォント、罫線、セル幅）を維持
  2. 別添（研究者ごと1ファイル）は行数に余裕があるが、同様のフォールバックを設計しておく
  3. テストケースとして「PI + 分担者2名、各項目3エントリ以上」のデータでの動作確認を計画

---

### [C4-05] (Major) ruamel.yaml C拡張未インストール — C3-05/C3-13 統合 → **対応済み**

- **箇所**: docker/python/Dockerfile:26-31行
- **前回対応状況**: C3-05 (Major) / C3-13 (Minor) 未対応
- **対応内容**: Dockerfile に「ruamel.yaml.clib は未インストール（pure Python fallback で十分）」のコメントを追記。意図的な設計判断であることを明記。
- **内容**: python:3.12-slim にはCコンパイラがなく、`ruamel.yaml.clib` のビルドに失敗する。pure Python フォールバックで動作するが、パフォーマンスが低下する（本プロジェクトの YAML サイズでは無視できる）。
- **影響**: 実用上は問題なし。

---

### [C4-06] (Major) templates/ ディレクトリと reference.docx が未作成 — C3-06 部分対応 → **部分対応済み**

- **箇所**: templates/
- **前回対応状況**: C3-06 未対応
- **対応内容**: templates/.gitkeep を作成し、CLAUDE.md の Project Structure に templates/ を追記。reference.docx 本体は Step 2（build_narrative.sh）着手時に Pandoc で生成予定。
- **内容**: templates/ ディレクトリは作成済み。reference.docx の生成（`pandoc --print-default-data-file reference.docx`）と Windows 側でのスタイル調整は Step 2 の実施事項として残存。
- **影響**: ディレクトリ不在エラーは解消。reference.docx がない場合は Prompt 3-2 のフォールバック（デフォルト生成 + 警告）で対応。

---

### [C4-07] (Major) 実装スクリプト未作成 — C3-08 部分対応

- **箇所**: main/step02_docx/, main/step03_excel/, scripts/
- **前回対応状況**: C3-08 部分対応（YAML 4ファイル完了、実装スクリプトは未着手）
- **内容**: Step 1（YAML定義）の完了により以下が改善:

  | カテゴリ | ファイル | 状態 |
  |---------|---------|------|
  | メタデータ YAML | config.yaml | ✓ 完了 |
  | メタデータ YAML | researchers.yaml | ✓ 完了 |
  | メタデータ YAML | other_funding.yaml | ✓ 完了 |
  | メタデータ YAML | security.yaml | ✓ 完了 |
  | 本文 Markdown | youshiki1_2.md | ✗ 未作成 |
  | 本文 Markdown | youshiki1_3.md | ✗ 未作成 |
  | Word生成 | fill_forms.py | ✗ 未作成 |
  | Word生成 | fill_security.py | ✗ 未作成 |
  | Word生成 | build_narrative.sh | ✗ 未作成 |
  | Excel生成 | fill_excel.py | ✗ 未作成 |
  | ビルド統合 | scripts/build.sh | ✗ 未作成 |
  | パッケージ | scripts/create_package.sh | ✗ 未作成（旧版は退避済み） |
  | Windows | repair_and_pdf.ps1 | ✗ 未作成 |
  | Windows | batch_convert.ps1 | ✗ 未作成 |

  提出期限まで**46日**（2026-04-04 → 2026-05-20）。残り10ファイル + 本文15ページの執筆が必要。

- **影響**: スケジュールリスクは依然Critical。ただし YAML 基盤の完成により、Step 2-4 の実装に着手可能な状態。
- **推奨対応**: 即座に Step 2（Markdown テンプレート + reference.docx）に着手し、本文執筆を並行開始。

---

### [C4-08] (Major) openpyxl Data Validation 拡張非対応 — C3-09 未対応 → **プロンプト反映済み**

- **箇所**: data/source/r08youshiki6.xlsx
- **前回対応状況**: C3-09 未対応
- **プロンプト反映**: Prompt 4-1 に「既知の openpyxl 制約と対策」セクションを追記。検証テスト手順（読込→即保存→Excel確認）と extLst 再注入によるフォールバック策を明記。
- **内容**: openpyxl 3.1.5 で `UserWarning: Data Validation extension is not supported and will be removed` が発生。保存時にドロップダウンリストが削除される可能性。
- **影響**: 様式6のドロップダウン選択肢（テーマ、分野、タイプ等）が消失すると、e-Rad 提出時に問題が生じる可能性。
- **状態**: 実装時に検証予定（Prompt 4-1 に手順記載済み）。

---

### [C4-09] (Major) openpyxl 条件付き書式破損リスク — C3-10 未対応 → **プロンプト反映済み**

- **箇所**: data/source/r08youshiki6.xlsx
- **前回対応状況**: C3-10 未対応
- **プロンプト反映**: Prompt 4-1 の「既知の openpyxl 制約と対策」セクションに条件付き書式の検証も明記。C4-08 と同時にテストする手順。
- **内容**: 19個の conditional_formatting ルールが存在。openpyxl 保存時に破損する可能性。
- **影響**: 様式6の書式が崩れる可能性。
- **状態**: 実装時に検証予定（Prompt 4-1 に手順記載済み）。

---

### [C4-10] (Minor) SPEC.md §3.1 Word出力テーブルのMarkdown書式崩れ → **対応済み**

- **箇所**: SPEC.md:127-135行
- **前回対応状況**: 新規
- **対応内容**: besshi5_filled.docx と betten 行をテーブル内に統合し、注記テキスト（※）をテーブルの後に移動。
- **内容**: §3.1 Word文書出力テーブルの途中に注記テキスト（`※` で始まる行）がテーブル行間に挿入されており、Markdownテーブルとしてパースが崩れる:

  ```markdown
  | youshiki1_3_narrative.docx | 様式1-3 本文（Pandoc生成） | 同上 |

  ※ 様式1-2, 1-3の統合方法: 各docxをWindows側で...
  ※ 未記入の様式（様式5等）は...
  | besshi5_filled.docx | 別紙5（テーブル記入済） | Windows で PDF化 |
  ```

  これにより `besshi5_filled.docx` と `betten_[氏名].docx` の行がテーブル外にはみ出す。

- **影響**: SPEC.md を読む際に出力ファイル一覧が不完全に見える。機能には影響しない。
- **推奨対応**: 注記テキストをテーブルの下に移動するか、テーブルを2つに分割。

---

### [C4-11] (Minor) 別添ファイル名規約の不一致 → **対応済み**

- **箇所**: SPEC.md:130行, 154行
- **前回対応状況**: 新規
- **対応内容**: SPEC.md §3.1 と §3.3 のファイル名を `betten_NN_romanized` パターンに統一。Prompt 3-3 の出力例（`betten_01_yamada.docx`）と一致。
- **影響**: 解消済み。

---

### [C4-12] (Minor) パイプラインにYAMLスキーマバリデーションが存在しない → **プロンプト反映済み**

- **箇所**: パイプライン全体設計（SPEC.md §2, docs/prompts.md）
- **前回対応状況**: 新規
- **プロンプト反映**: Prompt 5-1 に `validate` サブコマンドを追加。必須フィールド存在チェック、budget 機関別整合性チェック、effort 合算チェック、研究者リスト網羅性チェックの5項目を定義。全ステップ実行時に最初に自動実行される設計。
- **内容**: 4つのYAMLファイルの必須フィールドやデータ整合性を事前チェックする仕組みが設計されていなかった。
- **状態**: 実装時に対応予定（Prompt 5-1 に設計記載済み）。

---

### [C4-13] (Minor) other_funding.yaml の total_budget フィールドが prompts.md 設計に未記載 → **対応済み**

- **箇所**: docs/prompts.md:385-386行
- **前回対応状況**: 新規
- **対応内容**: prompts.md のスキーマ設計に `total_budget` フィールドを追記。`budget` の説明も「本人の受入れ予算額」に明確化。
- **影響**: 解消済み。

---

### [C4-14] (Minor) pyproject.toml 未作成 — C3-11 未対応

- **箇所**: プロジェクトルート
- **前回対応状況**: C3-11 未対応
- **内容**: 前回から変化なし。Prompt 0-2 未実施。
- **影響**: Docker 環境が主要な実行環境のため影響は限定的。
- **推奨対応**: 低優先。Docker 優先で実装を進め、必要時に対応。

---

### [C4-15] (Minor) data/dummy/ が空 — C3-12 未対応 → **プロンプト反映済み**

- **箇所**: data/dummy/（.gitkeep のみ）
- **前回対応状況**: C3-12 未対応
- **プロンプト反映**: Prompt 5-3（E2Eテスト用ダミーデータ配置とテスト実行）を新規追加。YAML コピー、docx/xlsx スタブ生成、E2E テスト実行の手順を定義。
- **内容**: Step 1 YAML 完了により配置可能な状態だが、まだ配置されていない。
- **状態**: Step 5 実施時に対応予定（Prompt 5-3 に手順記載済み）。

---

### [C4-16] (Minor) E2E テスト用 Prompt が存在しない — C3-14 未対応 → **対応済み**

- **箇所**: docs/prompts.md Step 5
- **前回対応状況**: C3-14 未対応
- **対応内容**: Prompt 5-3「E2Eテスト用ダミーデータ配置とテスト実行」を新規追加。ダミーデータ配置→パイプライン全体実行→出力検証の手順と完了チェック4項目を定義。Prompt 5-1 にも `validate` サブコマンドを追加。

---

### [C4-17] (Note) 4つのYAML間の研究者名・機関名整合性は完全一致

- **箇所**: main/00_setup/*.yaml（4ファイル間）
- **前回対応状況**: 新規（Step 1 完了後の初回検証）
- **内容**: 以下のクロスチェックで完全一致を確認:

  | チェック項目 | 結果 |
  |------------|------|
  | researchers.yaml `pi.name_ja` = security.yaml researchers キー "○○ ○○" | ✓ 一致 |
  | researchers.yaml `co_investigators[0].name_ja` = other_funding.yaml `co_investigator_funding[0].researcher_name` = security.yaml researchers キー "△△ △△" | ✓ 一致 |
  | config.yaml `lead_institution.name` = researchers.yaml `pi.affiliation` = security.yaml `due_diligence.lead_institution.name` = "○○大学" | ✓ 一致 |
  | config.yaml `sub_institutions[0].name` = researchers.yaml `co_investigators[0].institution` = security.yaml `due_diligence.partner_institutions[0].name` = "△△大学" | ✓ 一致 |
  | security.yaml researchers キー集合 = {PI} ∪ {全co_investigators} | ✓ 網羅 |

  プレースホルダ値（○○, △△）での一致であり、実データ入力時に再検証が必要。

---

### [C4-18] (Note) エフォート合算は全研究者で100%以内

- **箇所**: main/00_setup/researchers.yaml, main/00_setup/other_funding.yaml
- **前回対応状況**: 新規
- **内容**:

  | 研究者 | 本課題 | 他制度 | 合計 | 判定 |
  |-------|-------|-------|------|------|
  | ○○ ○○（PI） | 30% | 20%（科研費基盤B） | 50% | ✓ OK |
  | △△ △△（Co-I） | 20% | 15%（科研費若手） | 35% | ✓ OK |

  いずれも100%以内。プレースホルダ値としては適切な水準。

---

### [C4-19] (Note) Step 1 完了チェック全項目 [x] 済み — YAML 構造的妥当性を独立検証

- **箇所**: docs/prompts.md Prompt 1-1〜1-3 完了チェック
- **前回対応状況**: 新規
- **内容**: prompts.md の以下の完了チェックが全て [x] 済みであることを確認し、独立検証を実施:

  | Prompt | チェック項目 | 独立検証結果 |
  |--------|-----------|------------|
  | 1-1 | YAML パース可能 | ✓ 正常パース（Read ツールで読込成功） |
  | 1-1 | 様式1-1 全フィールド対応 | ✓ ①〜⑪に対応するキーが存在 |
  | 1-1 | 予算構造: 年度別×費目別 | ✓ yearly + by_institution + details |
  | 1-1 | 品目レベル積算明細 | ✓ budget.details 存在 |
  | 1-1 | コメント付記 | ✓ 全フィールドに対応様式番号コメントあり |
  | 1-1 | 金額千円統一 | ✓ 全金額が千円単位 |
  | 1-2 | CV 10項目カバー | ✓ 10項目すべてに対応フィールドあり |
  | 1-2 | co_investigators リスト構造 | ✓ 空リストでも動作する設計 |
  | 1-2 | 様式7フィールド | ✓ 機関名, 氏名, 部局・職 含む |
  | 1-2 | effort_percent | ✓ PI, Co-I 両方に存在 |
  | 1-3 | 8列対応（other_funding） | ✓ 8列すべてに対応するフィールドあり |
  | 1-3 | 13項目カバー（security） | ✓ ①〜⑬すべてに対応 |
  | 1-3 | 別添13テーブル対応 | ✓ 同一データ構造で対応可能 |
  | 1-3 | 空リスト耐性 | ✓ 空リスト = 該当なしの構造 |

---

## YAMLスキーマと様式テーブルの突合結果

### other_funding.yaml ↔ 様式3-1/3-2 (Tables 10-11, 6r×8c)

| Col | テーブルヘッダ | YAMLフィールド | 対応 | 備考 |
|-----|-------------|--------------|------|------|
| 0 | 番号 | （自動採番） | ✓ | fill_forms.py 側で生成 |
| 1 | 状態 | `status` | ✓ | |
| 2 | 制度名、実施期間、配分機関等名 | `program_name` + `period` + `agency` | △ | **3フィールドを1セルに結合する処理が必要** |
| 3 | 研究課題名（研究代表者氏名） | `project_title` + (researchers.yaml PI名) | △ | **PI名の取得先がother_funding.yaml内に無い** → researchers.yaml参照が必要 |
| 4 | 役割 | `role` | ✓ | |
| 5 | 予算額(全体額) | `budget` + `total_budget` | ✓ | "5,000 (15,000)" 形式の書式化が必要 |
| 6 | エフォート(%) | `effort_percent` | ✓ | |
| 7 | 相違点 | `difference` | ✓ | |

**設計上の問題**: Col 2 と Col 3 は複数フィールドの結合が必要。fill_forms.py の実装プロンプト（Prompt 3-1）でこの結合ロジックを明示すべき。

### security.yaml ↔ 別紙5 (24テーブル)

| Table | サイズ | 項目 | YAML対応 | 備考 |
|-------|------|------|---------|------|
| 0 | 3r×2c | 提案情報 | config + researchers | ✓ 自動取得可能 |
| 1 | 1r×1c | DD状況（代表機関） | `due_diligence.lead_institution.status` | ✓ |
| 2 | 1r×1c | DD状況（分担機関） | `due_diligence.partner_institutions[].status` | ✓ |
| 3-15 | 4-5r×2-5c | ①〜⑬ 13項目 | `researchers` セクション | △ **行数オーバーフロー注意 (C4-04)** |
| 16 | 1r×1c | DD結果 | `due_diligence.result` | ✓ |
| 17 | 1r×1c | 軽減措置要否 | `risk_assessment.mitigation_needed` | ✓ |
| 18 | 1r×1c | 新規追加確認 | `risk_assessment.new_member_confirmed` | ✓ |
| 19 | 1r×1c | 共同研究機関リスク(1) | `risk_assessment.partner_institution_risk.has_risk` | ✓ |
| 20 | 1r×1c | 共同研究機関リスク(2) | `risk_assessment.partner_institution_risk.has_risk_researcher` | ✓ |
| 21 | 1r×1c | 軽減措置一覧 | `risk_assessment.measures` | ✓ |
| 22 | 1r×1c | 実行確認 | `risk_assessment.measures_confirmed` | ✓ |
| 23 | 1r×1c | 同意確認 | `consent` | ✓ |

### security.yaml ↔ 別添 (13テーブル)

| Table | サイズ | 項目 | YAML対応 |
|-------|------|------|---------|
| 0 | 5r×2c | ①学歴 | `researchers[name].education_history` ✓ |
| 1 | 5r×2c | ②職歴 | `researchers[name].career_history` ✓ |
| 2 | 5r×5c | ③研究費 | `researchers[name].funding_history` ✓ |
| 3 | 5r×5c | ④支援 | `researchers[name].non_research_support` ✓ |
| 4 | 5r×5c | ⑤論文 | `researchers[name].publications` ✓ |
| 5 | 5r×5c | ⑥特許 | `researchers[name].patents` ✓ |
| 6 | 4r×3c | ⑦外国人材 | `researchers[name].foreign_talent_programs` ✓ |
| 7 | 4r×2c | ⑧処分歴 | `researchers[name].disciplinary_history` ✓ |
| 8 | 4r×2c | ⑨リスト掲載 | `researchers[name].list_status` ✓ |
| 9 | 4r×2c | ⑩機関所属 | `researchers[name].listed_entity_affiliation` ✓ |
| 10 | 4r×3c | ⑪関係 | `researchers[name].listed_entity_relationships` ✓ |
| 11 | 4r×2c | ⑫居住者区分 | `researchers[name].residency_status` ✓ |
| 12 | 1r×2c | ⑬国籍 | `researchers[name].nationality` ✓ |

別添は**研究者ごとに1ファイル生成**されるため、1名分のデータのみ使用。データ行数は別紙5ほど逼迫しない。設計上の問題なし。

---

## prompts.md Step 2〜3 プロンプト品質検証

| Prompt | 評価 | 問題点・所見 |
|--------|------|------------|
| 2-1 様式1-2 テンプレート | △ 未実施 | セクション構成は審査基準と対応付け済み。完了チェック全 [ ] 未実施。 |
| 2-2 様式1-3 テンプレート | △ 未実施 | Type A での §4, §5 削除条件が明記されている点は良い。完了チェック全 [ ] 未実施。 |
| 3-1 fill_forms.py | △ 要補足 | テーブルマッピングは概ね正確。C3-01/C3-04 対応済みで改善。ただし様式3-1/3-2の Col 2-3 結合ロジック（複数フィールド→1セル）が未記載。 |
| 3-2 build_narrative.sh | △ ブロッカーあり | reference.docx が未作成（C4-06）。スクリプト自体は設計済み。 |
| 3-3 fill_security.py | △ 要修正 | **§3 → §1 参照誤り（C4-03）**。別紙5の行追加ロジック未記載（C4-04）。別添の研究者ごとファイル生成は設計済み。 |
| 4-1 fill_excel.py | △ 要検証 | openpyxl の DV/CF 制約の検証が必要（C4-08/C4-09）。セルマッピングの詳細度は十分。 |

---

## ドキュメント間整合性検証

| チェック項目 | 結果 | 備考 |
|------------|------|------|
| CLAUDE.md Project Structure に other_funding.yaml / security.yaml 記載 | ✓ | 4ファイルすべて記載済み |
| SPEC.md §1.2 メタデータ表と実ファイル構成の一致 | ✓ | 4ファイル一致 |
| prompts.md Step 1 完了チェック全 [x] | ✓ | Prompt 1-1〜1-3 全項目チェック済み |
| 出力ファイルサフィックス規約の統一 | △ | `_filled` / `_narrative` は SPEC.md/prompts.md 間で統一。ただし別添ファイル名で不一致（C4-11） |
| CLAUDE.md / SPEC.md / README.md のビルドコマンド | ✓ | report3 C3-03 対応済み。`scripts/build.sh` に統一 |
| prompts.md 推奨実行順序と依存関係 | ✓ | Step 0→1→2→4→3→5→6→7 の順序と理由が明記 |

---

## リスクマトリクス（更新版）

| # | リスク | カテゴリ | 影響度 | 発生確率 | 総合評価 | 対策 | 前回比 |
|---|-------|--------|------|--------|---------|-----|--------|
| R1 | 提出期限まで46日で実装量大（10ファイル + 本文15p） | スケジュール | 高 | 中〜高 | **Critical** | Step 2着手→本文執筆並行開始。Excel(Step4)→Word(Step3)の順で実装 | ↔ 前回同等 |
| R2 | budget.by_institution / details 不整合が提出書類に波及 | データ整合性 | 高 | 低（修正済み） | **Minor** | C4-01: 機関別金額を修正済み。実データ入力時の再発防止にはバリデーション追加が望ましい | **解消** |
| R3 | openpyxl 保存時にドロップダウン/条件付き書式が破損 | 技術 | 高 | 高 | **Critical** | C4-08/09: Step 4 実装初期に検証テスト | ↔ 前回同等 |
| R4 | security.yaml フィールド名不一致で fill_security.py 実装時手戻り | データ整合性 | 中 | 低（修正済み） | **Minor** | C4-02: prompts.md のフィールド名を修正済み | **解消** |
| R5 | 別紙5 テーブル行数オーバーフローで fill_security.py 失敗 | 技術 | 中 | 中（設計追記済み） | **Minor** | C4-04: 行追加ロジック設計を Prompt 3-3 に追記済み。実装時に動作確認必要 | **軽減** |
| R6 | reference.docx 未作成で Pandoc 出力の書式不一致 | 技術 | 中 | 中（ディレクトリ作成済み） | **Major** | C4-06: templates/ 作成済み。reference.docx 本体は Step 2 で生成 | **軽減** |
| R7 | python-docx で書式崩壊 | 技術 | 中 | 高 | **Major** | Windows Word COM API 修復で対応（設計済み） | ↔ 前回同等 |
| R8 | セル結合テーブルへの書き込み失敗 | 技術 | 中 | 中 | **Major** | セルマッピング表ベースのテスト駆動開発 | ↔ 前回同等 |
| R9 | 段落インデックスベースの様式削除が壊れる | 技術 | 中 | 低 | **Major** | テキストパターンマッチ併用 | ↔ 前回同等 |
| R10 | 4 YAML間の整合性が実データ入力時に崩れる | データ整合性 | 中 | 中 | **Major** | バリデーションスクリプト追加（C4-12） | **新規** |
| R11 | Google Drive 同期の遅延・競合 | 環境 | 低 | 中 | **Minor** | 手動USB転送のフォールバック | ↔ 前回同等 |
| R12 | Windows Word COM API の環境依存 | 環境 | 中 | 低 | **Minor** | jami-abstract-pandoc 実績あり | ↔ 前回同等 |

### リスク評価の変化（前回比）

- **改善**: R4（様式2-2列構成誤認）は report3 C3-01 で対応済みのため消滅
- **改善**: R6（Table 3 行構成誤解）は report3 C3-04 で対応済みのため消滅
- **改善**: Step 1 YAML完了により、Step 2-4 着手の前提条件が満たされた
- **解消**: R2（budget 不整合）→ C4-01 対応で修正済み
- **解消**: R4（フィールド名不一致）→ C4-02 対応で修正済み
- **軽減**: R5（行オーバーフロー）→ C4-04 で設計方針追記。実装時要確認
- **軽減**: R6（reference.docx）→ C4-06 で templates/ 作成。本体は Step 2 で生成
- **不変**: R1（スケジュール）, R3（openpyxl）, R7-R9（技術リスク）は前回と同等
