# 敵対的レビュー報告書（第08回）— Step 9 実装直前の最終確認

レビュー実施日: 2026-04-06
レビュー対象: docs/step4plan.md, docs/prompts.md (Step 9), main/step02_docx/fill_forms.py, main/step02_docx/inject_narrative.py, scripts/build.sh, scripts/validate_yaml.py, data/dummy/generate_stubs.py, data/dummy/researchers.yaml, data/dummy/security.yaml, data/dummy/other_funding.yaml, pyproject.toml, docker/python/Dockerfile, SPEC.md, CLAUDE.md, README.md, templates/reference.docx, docs/template_analysis.md, /home/dryad/anal/jami-abstract-pandoc/scripts/wrap-textbox.py
前回レビュー: docs/report7.md (2026-04-05)

## サマリ

- Critical: 0件
- Major: 1件 (新規1)
- Minor: 4件 (新規4)
- Info: 4件 (新規4)

### 対応状況一覧

| ID | 重大度 | 状態 | 概要 |
|----|--------|------|------|
| M08-01 | Major | 新規 | copy_media ファイル名衝突時にリレーションシップ Target が更新されない |
| C08-02 | Minor | 新規 | Prompt 9-2 の Step 9 文脈セクションに残存する lxml 参照 |
| C08-03 | Minor | 新規 | inject_narrative.py が endnotes.xml を未実装（step4plan B-1 §6 との乖離） |
| C08-04 | Minor | 新規 | SPEC.md §2.4 の配置が不正（§4.3 の後に出現） |
| C08-05 | Minor | 新規 | Prompt 9-2 処理フロー 2.e の "lxml の addprevious/addnext" が実装と不整合 |
| I08-01 | Info | 新規 | ダミーデータ co-I=2 vs 本番 co-I=3（完全一致ではないが実用上問題なし） |
| I08-02 | Info | 新規 | build.sh に inject サブコマンド未実装（Prompt 9-3 スコープ） |
| I08-03 | Info | 新規 | generate_stubs.py にナラティブスタブ生成なし（Prompt 9-3 スコープ） |
| I08-04 | Info | 新規 | RUNNER=uv で narrative ステップ失敗（pandoc 未インストール、Docker専用） |

## report7.md との差分サマリ

- report7.md の未対応項目で今回解消されたもの: **11件**（C7-01〜C7-10, N7-04 全件対応完了）
- report7.md の未対応項目で依然として未対応のもの: **0件**
- report7.md で「対応済み」とされた項目で実際には不十分なもの: **0件**
- report7.md に記載がなく今回新規発見したもの: **9件**（Major 1, Minor 4, Info 4）
- report7.md の Note 項目で継続中のもの: **3件**（N7-01 YAML未完成, N7-02 プレースホルダ残存, N7-03 参考様式best-effort）

---

## report7 指摘対応の検証結果

### 検証サマリ

| report7 ID | 重大度 | 対応内容 | 検証結果 | 残存問題 |
|------------|--------|---------|---------|---------|
| C7-01 | Critical | styles.xml マージを Prompt 9-2 チェックリストに追加 | ✓ OK | なし |
| C7-02 | Major | SPEC.md §3.1 テーブルを OOXML injection 方式に修正 | ✓ OK | なし |
| C7-03 | Major | ダミーデータに 2人目 co-I 追加 | ✓ OK | 本番=3名との差異（I08-01） |
| C7-04 | Major | SPEC.md パイプライン図に inject_narrative.py 追加 | ✓ OK | なし |
| C7-05 | Major | Prompt 9-4 に Linux 代替検証手段追加 | ✓ OK | なし |
| C7-06 | Major | pyproject.toml 新規作成 | ✓ OK | なし |
| C7-07 | Minor | README.md テーマ更新 | ✓ OK | なし |
| C7-08 | Minor | DocxTable(new_tbl, doc.element.body) に修正 | ✓ OK | なし |
| C7-09 | Minor | step4plan.md B-1 に footnotes/endnotes 追加 | ✓ OK | 実装は footnotes のみ（C08-03） |
| C7-10 | Minor | Prompt 9-1 に Docker 実行指示追加 | ✓ OK | なし |
| N7-04 | Note | step4plan.md B-3「推奨」→「必須」に変更 | ✓ OK | なし |

### 各項目の検証詳細

**C7-01**: `docs/prompts.md:539` に6番目の項目として styles.xml マージが追加されている。記述内容は「Heading 1, Heading 2, Body Text, First Paragraph, Compact」のスタイル名と「fix_reference_styles.py のスタイル定義を参考」の参照を含み、step4plan.md B-3（line 155: 「**必須**」）と整合。**十分。**

**C7-02**: `SPEC.md:160` が `youshiki1_2_narrative.docx | 様式1-2 本文（Pandoc生成、中間ファイル） | inject_narrative.py で youshiki1_5_filled.docx に統合` に修正済み。youshiki1_5_filled.docx の行（line 159）にも「inject済」の記述あり。旧脚注との矛盾なし。**十分。**

**C7-03**: `data/dummy/researchers.yaml` に□□ □□（Jiro TANAKA、講師、15%エフォート）が追加。`security.yaml` に□□ □□の全13項目エントリあり。`other_funding.yaml` に□□ □□のエントリあり（entries: []）。3ファイル間で名前「□□ □□」が一致。RUNNER=uv で validate/forms/security/excel の4ステップが E2E 通過を確認。**十分。**

**C7-04**: SPEC.md パイプライン図（line 69）に `inject_narrative.py` ステップあり。§2.2 Step 02（line 120）に `inject_narrative.py` の説明あり。§2.2 Step 04（line 130 付近）で narrative docx が中間ファイルとして除外される旨が明記。**十分。**

**C7-05**: Prompt 9-4（`docs/prompts.md:655`）に「Linux代替検証: python-docx での再読み込み成功確認 + `libreoffice --headless --convert-to pdf` での変換成功確認（Word環境がない場合）」が追加。実用的な手段であり、inject_narrative.py の基本検証（line 749-753: read_docx による再読み込みテスト）とも整合。**十分。**

**C7-06**: `pyproject.toml` が存在。依存関係: python-docx, openpyxl, pyyaml, ruamel.yaml, Jinja2。Dockerfile（lines 29-34）の `pip install` と完全一致。RUNNER=uv で validate ステップ通過を確認。**十分。**

**C7-07**: `README.md:4` に「（サイバー攻撃×地域医療シミュレーション）」が記載。CLAUDE.md（line 9）、SPEC.md（line 8）と一致。**十分。**

**C7-08**: `fill_forms.py:894` が `DocxTable(new_tbl, doc.element.body)` に修正済み。python-docx の `Table.__init__(self, tbl, parent)` において `parent` は `BlockItemContainer` が期待される。`doc.element.body` は `CT_Body`（OxmlElement サブクラス）であり、`.part` プロパティを持つため `Table.part` 経由のアクセスが正常に動作する。`doc`（Document）を渡すよりも型的に適切。**十分。**

**C7-09**: `docs/step4plan.md:129-133` に「#### 6. word/footnotes.xml / word/endnotes.xml」セクションが追加。IDリナンバリング、参照書き換え、スキップ条件（ソースに footnotes.xml がない場合）が記述されている。**十分。**（ただし実装では footnotes のみで endnotes が未実装 — C08-03 参照）

**C7-10**: `docs/prompts.md:427-430` に「## 実行環境」セクションとして「解析スクリプトは Docker 環境で実行すること（build.sh と同じ RUNNER 方式）。ホスト Python に直接パッケージをインストールしないこと。」が追加。**十分。**

**N7-04**: `docs/step4plan.md:155` が「**必須**:」に変更済み。「推奨アプローチ」の表現は完全に排除されている。**十分。**

---

## 指摘事項

### [M08-01] (Major) copy_media ファイル名衝突時にリレーションシップ Target が更新されない

- **箇所**: main/step02_docx/inject_narrative.py:295-317 (copy_media), :238-288 (merge_rels)
- **前回対応状況**: 新規
- **内容**:
  `merge_rels()` はソースのリレーションシップをターゲットに追加する際、ソースの元の `Target` パスをそのまま使用する（line 270: `new_rel.set("Target", rel.get("Target", ""))`）。その後 `copy_media()` が呼ばれ、ターゲットZIP内でファイル名衝突があるとリネームする（例: `media/image1.png` → `media/image1_n1.png`）。

  しかし **リネーム後にリレーションシップの Target を更新する処理がない**。結果として、リレーションシップは `media/image1.png` を参照するが、実際のZIPエントリは `media/image1_n1.png` になり、Wordが画像を表示できない。

  **現時点での影響**: template_analysis.md によると、現在の narrative docx には画像が含まれておらず（`youshiki1_2.md` にも `youshiki1_3.md` にも図は未挿入）、テンプレート側にも `word/media/` 配下のファイルはない。そのため **現時点では発現しない**。

  しかし `youshiki1_2.md:392` に「ここに概要図を配置」の注記があり、今後画像が追加される可能性が高い。その際にこのバグが発現する。

- **影響**: 将来的に Markdown に画像を追加した場合、生成 docx 内で画像が表示されない。原因の特定が困難（rels と ZIP エントリの不一致は目視で検出しにくい）
- **推奨対応**: 以下のいずれか:
  1. `copy_media()` がリネームした場合、返り値で新パスを通知 → `merge_rels()` で追加済みのリレーションシップ Target を更新
  2. `merge_rels()` と `copy_media()` を統合し、メディアコピーとリレーションシップ追加を一つのトランザクションとして処理

---

### [C08-02] (Minor) Prompt 9-2 の Step 9 文脈セクションに残存する lxml 参照

- **箇所**: docs/prompts.md:398
- **前回対応状況**: 新規（report6 N6-05 で stdlib 方式に統一されたが、文脈セクションの記述が未更新）
- **内容**:
  prompts.md の Step 9 設計方針セクション（Prompt 9-2 の外側）に以下の記述が残存:

  > python-docx での文書結合は書式崩壊リスクがあるため（SPEC.md記載）、OOXML直接操作（**lxml**）を優先する

  Prompt 9-2 の技術的注意事項（line 530）では正しく「stdlib `zipfile` + `xml.etree.ElementTree`」と記述されており、実装（inject_narrative.py）も stdlib を使用している。文脈セクションの「lxml」は過去の設計段階の残滓。

  inject_narrative.py は既に実装済み（4/6チェック完了）のため実害はないが、Prompt 9-2 を再実行する場合や新規参加者が文脈を読む場合に混乱を招く。

- **影響**: 軽微。実装済みのため直接的な影響なし
- **推奨対応**: line 398 の「lxml」を「stdlib zipfile + xml.etree.ElementTree」に修正

---

### [C08-03] (Minor) inject_narrative.py が endnotes.xml を未実装

- **箇所**: main/step02_docx/inject_narrative.py (merge_footnotes のみ), docs/step4plan.md:129-133 (footnotes AND endnotes)
- **前回対応状況**: 新規（C7-09 対応で step4plan.md に endnotes が追加されたが、実装に反映されていない）
- **内容**:
  step4plan.md B-1 §6 は「word/footnotes.xml / word/endnotes.xml — 脚注・尾注統合」と両方を規定する。inject_narrative.py には `merge_footnotes()` 関数（lines 554-598）が実装されているが、`merge_endnotes()` に相当する関数は存在しない。`endnotes` を grep しても inject_narrative.py 内に一致なし。

  template_analysis.md によると、現在の narrative docx には実脚注がなく（Pandocデフォルトの separator/continuationSeparator のみ）、尾注も使用されていない。Pandoc は Markdown の `[^1]` 構文を footnotes.xml に変換するため、endnotes が生成されるケースは通常ない。

- **影響**: 現時点で実害なし。Pandoc がデフォルトで endnotes を生成することはないため、発現確率は極めて低い
- **推奨対応**: 以下のいずれか:
  1. `merge_footnotes()` を汎用化し、endnotes にも対応する引数を追加（XML構造は footnotes とほぼ同一）
  2. step4plan.md B-1 §6 に「Pandocは通常endnotesを生成しないため、footnotes のみ実装。endnotes が必要になった場合は追加実装」と注記

---

### [C08-04] (Minor) SPEC.md §2.4 の配置が不正

- **箇所**: SPEC.md（§2.4 が §4.3 の後に出現）
- **前回対応状況**: 新規
- **内容**:
  SPEC.md のセクション構造:

  ```
  §2.1 全体フロー
  §2.2 各ステップ仕様
  §2.3 E2Eテスト
  §3.1 Word文書
  §3.2 Excelファイル
  §3.3 提出ファイル
  §4.1 Docker
  §4.2 パッケージ
  §4.3 外部環境
  §2.4 共同執筆環境 ← ここ（§4.3 の後）
  §5 制約・前提条件
  ```

  §2.4 は Step 8 で追加された共同執筆環境の記述で、本来 §2.3 と §3.1 の間に配置されるべき。

- **影響**: SPEC.md の可読性低下。レビュアーが §2.4 を見落とす可能性
- **推奨対応**: §2.4 を §2.3 と §3 の間に移動

---

### [C08-05] (Minor) Prompt 9-2 処理フロー 2.e の "lxml の addprevious/addnext" が実装と不整合

- **箇所**: docs/prompts.md:514
- **前回対応状況**: 新規
- **内容**:
  Prompt 9-2 の処理フロー step 2.e:

  > 挿入ポイントに body 要素を挿入（**lxml の addprevious/addnext** 等で直接操作）

  `addprevious` / `addnext` は lxml 固有の API であり、stdlib `xml.etree.ElementTree` には存在しない。実際の inject_narrative.py は `body.insert(index, elem)` と `body.remove(elem)` を使用（ElementTree の標準 API）。

  C08-02 と同根の問題だが、こちらは **Prompt 9-2 のコードブロック内部** であり、実装手順として直接読まれる位置にある。

- **影響**: Prompt 9-2 を再実行した場合、実装者が lxml を import しようとして失敗する可能性。ただし技術的注意事項（line 530）で stdlib が指定されているため、注意深い実装者であれば回避可能
- **推奨対応**: line 514 を「ElementTree の body.insert() / body.remove() で直接操作」に修正

---

### [I08-01] (Info) ダミーデータ co-I=2 vs 本番 co-I=3

- **箇所**: data/dummy/researchers.yaml (co-I: △△, □□), main/00_setup/researchers.yaml (co-I: 黒田, ○○, 楠田)
- **前回対応状況**: 新規（C7-03 対応で co-I=2 に拡張済み）
- **内容**:
  ダミーデータの co-I は2名。本番データの co-I は3名（うち1名は「○○ ○○」プレースホルダ）。co-I=2 のテストは co-I>1 の行追加・テーブル複製パスを通過するため、fill_forms.py の基本ロジックは検証される。co-I=3 固有のエッジケースは本番テストで確認。
- **影響**: なし。co-I=2 で十分な検証が可能

---

### [I08-02] (Info) build.sh に inject サブコマンド未実装

- **箇所**: scripts/build.sh
- **前回対応状況**: 新規
- **内容**: Prompt 9-3 のスコープ。step4plan.md Step C に `phase_inject()` の具体的な関数定義が記述済み。実装は容易。

---

### [I08-03] (Info) generate_stubs.py にナラティブスタブ生成なし

- **箇所**: data/dummy/generate_stubs.py
- **前回対応状況**: 新規
- **内容**: Prompt 9-3 のスコープ。Prompt 9-3 に「generate_stubs.py を更新し、最低限以下を含む narrative docx スタブを生成: 見出し1つ、本文段落1つ、テーブル1つ」と明記済み。

---

### [I08-04] (Info) RUNNER=uv で narrative ステップ失敗

- **箇所**: scripts/build.sh narrative ステップ, main/step02_docx/build_narrative.sh
- **前回対応状況**: 新規
- **内容**: pandoc がホストに未インストールのため、`RUNNER=uv` では narrative ステップが `ERROR: pandoc がインストールされていません` で失敗する。validate / forms / security / excel の4ステップは uv で正常通過。pandoc は Docker コンテナ内にインストールされているため、`RUNNER=docker` では問題なし。
- **影響**: なし。narrative ステップは本来 Docker 経由で実行される想定

---

## step4plan.md の最終状態レビュー

### B-1 ZIPレベルマージ: **十分**

6パーツ（document.xml, rels, media, numbering, Content_Types, footnotes/endnotes）が網羅されている。各パーツの処理手順は具体的:
- rId リナンバリング: 「ターゲットの既存rIdの最大値を取得→ソース側をリナンバリング→body要素内の参照を書き換え」— 明確
- numbering ID リナンバリング: 「abstractNumId / numId の衝突を回避するためリナンバリング」— 明確
- footnotes ID リナンバリング: 追加済み（C7-09 対応）

実装（inject_narrative.py）は B-1 の仕様を正確に反映している（merge_rels, copy_media, merge_numbering, merge_content_types, merge_footnotes の各関数が対応）。

### B-2 セクションブレーク: **十分**

sectPr 保護ポリシーは明確（「絶対に削除・移動しない」）。Prompt 9-1 で sectPr 位置・プロパティの調査が指示されており、template_analysis.md に結果が記録されている（inline sectPr at [4], body-level sectPr at [351]）。inject_narrative.py の `extract_narrative_body()` は末尾 sectPr を正しく除外している（line 205-206）。

### B-3 スタイルマッピング: **十分**

「**必須**」に変更済み（N7-04 対応）。マッピングテーブルは Pandoc→テンプレート の5スタイル対応を明示。inject_narrative.py の `_PANDOC_STYLES` 辞書（lines 434-449）が7スタイル（Heading1-3, BodyText, FirstParagraph, Compact, SourceCode）を定義しており、仕様を超えた網羅性を持つ。フォントサイズ（MS明朝 10.5pt / MSゴシック 12pt, 10.5pt）は fix_reference_styles.py と一致。

### B-4 ルートタグ保存: **十分**

jami-abstract-pandoc wrap-textbox.py:398-470 の行番号参照を実際に検証 — 正確。inject_narrative.py の `extract_root_tag()` / `restore_root_tag()` は jami パターンを改良し、新規名前空間宣言のマージにも対応（lines 104-113）。document.xml, numbering.xml, styles.xml, footnotes.xml の4ファイルでルートタグ保存が適用されている。

### フォールバック計画: **十分**

方式比較表（OOXML / Windows COM / PDF結合 / 手動）が具体的。ピボット基準「1週間以内にWord修復ダイアログなしで開けるdocxが生成できない場合」は計測可能で明確。

### 作業順序・工数見積り: **概ね妥当**

Step A（構造解析）1-2h: **Prompt 9-1 完了済み**（template_analysis.md が成果物）
Step B（inject_narrative.py）10-15h: **大部分が完了済み**（786行のスクリプト、4/6チェック通過）
Step C（build.sh統合）30min: 妥当
Step D（package更新）30min: 妥当
Step E（テスト）2h: 妥当（Linux 代替検証手段が追加されたため効率向上）

実際の残作業は Step B の残り（Word検証, E2Eテスト）+ Step C + D + E であり、**見積りの約20-30%** が残存。

---

## prompts.md Step 9 の最終状態レビュー

### Prompt 9-1: **完了済み — 十分**

構造解析タスクは完了し、template_analysis.md に結果が出力されている。Docker 実行指示が追加済み（C7-10 対応）。解析結果はセクション境界、挿入ポイント、sectPr プロパティ、Pandoc スタイル一覧を網羅。

### Prompt 9-2: **実装済み — 概ね十分（Minor 2件）**

inject_narrative.py が786行で実装完了。チェックリスト6項目中4項目が通過。技術的注意事項（line 530）は正確に stdlib を指定。jami 参照テーブルの行番号は全件正確（実際のファイルで検証済み）。

**残存問題**:
- C08-02: 文脈セクション (line 398) の lxml 参照
- C08-05: 処理フロー 2.e (line 514) の lxml API 参照

### Prompt 9-3: **未実行 — 十分**

build.sh への統合指示は具体的（`phase_inject()` 関数定義が step4plan.md に記載）。create_package.sh の変更指示も明確。generate_stubs.py への narrative スタブ追加要件が記述されている。

### Prompt 9-4: **未実行 — 十分**

検証項目は13項目に拡充。Linux 代替検証（python-docx 再読み込み + LibreOffice 変換）が追加済み（C7-05 対応）。ファイルサイズチェック（10MB以下、目標3MB）も含まれている。

---

## SPEC.md / CLAUDE.md / README.md の整合性

### SPEC.md と step4plan.md の整合性: **概ね良好**

- §2.1 パイプライン図に inject_narrative.py ステップあり（C7-04 対応済み）
- §2.2 Step 02 に inject_narrative.py の説明あり
- §3.1 出力テーブルが OOXML injection 方式を正しく反映（C7-02 対応済み）
- OOXML直接操作方式の脚注記述（lines 167-171）と step4plan.md が整合
- **例外**: §2.4 の配置が不正（C08-04）

### CLAUDE.md: **最新**

- プロジェクト構成に inject_narrative.py が含まれている（line 62）
- 提出書類一覧で様式1-2/1-3 の生成方法が「Pandoc→inject_narrative.py で統合」に更新（lines 91-92）
- Tech Stack は最新
- pyproject.toml は構成図に含まれていないが、ルートファイルとして必須ではないため問題なし

### README.md: **最新**

- 研究テーマが更新済み（C7-07 対応）
- アーキテクチャ図に inject_narrative.py のフローが記載
- Pipeline Steps テーブルで Step 02 に「fill_forms→Pandoc→inject_narrative」と記載
- Scripts テーブルは inject サブコマンドを含む記述に更新済み

### 3ファイル間の矛盾: **なし**

研究テーマ、パイプライン構成、Tech Stack がCLAUDE.md / SPEC.md / README.md で統一されている。

---

## ビルドパイプラインの健全性

### E2Eテスト結果（RUNNER=uv, DATA_DIR=data/dummy）

| ステップ | 結果 | 備考 |
|---------|------|------|
| validate | ✓ OK | co-I=2 のデータで正常パス |
| forms | ✓ OK | 行追加・テーブル複製が co-I=2 で実行される |
| narrative | ✗ FAIL | pandoc 未インストール（Docker 専用、期待どおり） |
| security | ✓ OK | 3名分（PI + co-I×2）の別添生成を確認 |
| excel | ✓ OK | 様式6/7/8 生成 |

### ダミー YAML と本番 YAML の構造整合性: **良好**

| 項目 | ダミー | 本番 | 一致 |
|------|--------|------|------|
| researchers.yaml トップキー | pi, co_investigators, admin_contact | 同左 | ✓ |
| co-I 構造（name_ja, institution, effort_percent 等） | 全フィールドあり | 同左 | ✓ |
| security.yaml 研究者名キー | ○○ ○○, △△ △△, □□ □□ | 本名3名 | ✓（構造一致） |
| other_funding.yaml pi/co_investigators | entries リスト | 同左 | ✓ |

### validate_yaml.py の co-I=2 対応: **問題なし**

`check_researcher_security()` は `co_investigators` リストを動的にイテレートし、各 co-I のセキュリティエントリ存在を検証。co-I 数に依存するハードコードなし。

### generate_stubs.py の co-I=2 対応: **対応済み**

スタブ docx のテーブル構造は固定（様式1-1 の研究者欄は最大行数で生成）。fill_forms.py が動的に行追加するため、スタブ側の行数は問題にならない。ただし **narrative スタブは未生成**（I08-03: Prompt 9-3 スコープ）。

### pyproject.toml と Dockerfile の依存整合性: **完全一致**

| パッケージ | pyproject.toml | Dockerfile |
|-----------|---------------|------------|
| python-docx | ✓ | ✓ |
| openpyxl | ✓ | ✓ |
| pyyaml | ✓ | ✓ |
| ruamel.yaml | ✓ | ✓ |
| Jinja2 | ✓ | ✓ |

---

## 提出期限までのスケジュールリスク

提出期限 2026-05-20 まで **44日**（2026-04-06 → 2026-05-20）。

### Step 9 実装の残作業

| タスク | 見積り | 備考 |
|--------|--------|------|
| Prompt 9-3: build.sh 統合 + generate_stubs.py 更新 | 1-2h | phase_inject() の設計は step4plan.md に記載済み |
| Prompt 9-4: 統合テスト | 2-3h | Linux 代替検証手段あり |
| M08-01 修正: copy_media rels Target 更新 | 1h | 画像追加前に対応必須 |
| C08-02/05 修正: lxml 参照の除去 | 15min | ドキュメント修正のみ |
| **合計** | **4-6h** | |

### report7 から継続する非技術タスク

| タスク | 見積り | リスク |
|--------|--------|--------|
| researchers.yaml 完成 (~65%) | 8-16h | **外部依存**（各研究者からの情報提供） |
| other_funding.yaml 完成 (~90%) | 4-8h | **外部依存** |
| security.yaml 完成 (~55%) | 4-8h | researchers.yaml と共通部分あり |
| 3人目 co-I 確定 | - | **最大リスク**（未確定のまま） |
| 本番ビルド→PDF確認→e-Rad提出 | 6-12h | 全データ完成後 |

### クリティカルパス

```
[今日 4/6] ──→ Step 9 残作業 (4-6h) ──→ YAML メタデータ収集 (外部依存) ──→ 本番ビルド ──→ PDF確認 ──→ e-Rad [5/20]
                ↑ 技術的にはブロッカーなし        ↑ ボトルネック
```

**技術的作業（Step 9 残り + ビルド + 提出）は合計2-3日で完了可能。** 44日の余裕は十分。

**最大リスクは依然として YAML メタデータの外部収集**（report7 N7-01 継続）。特に3人目の共同研究者が未確定のため、researchers.yaml / security.yaml / youshiki1_2.md のいずれも完成しない。

---

## Step 9 実装開始の可否判定

### 判定結果: GO

### 判定理由

1. **report7 の全11件が適切に対応済み**: Critical 0件。全項目の修正内容が正確かつ十分であることを検証済み
2. **inject_narrative.py が既に大部分実装済み**: 786行、ZIPレベルマージ（rels, numbering, styles, footnotes, content_types）を網羅。Prompt 9-2 の6チェック項目中4件が通過
3. **設計文書が実装に十分な品質**: step4plan.md は B-1〜B-4 の技術仕様が具体的で、jami-abstract-pandoc の参照行番号が全件正確
4. **ビルドパイプラインが安定**: co-I=2 のダミーデータで validate/forms/security/excel が通過。inject 統合（Prompt 9-3）は phase_inject() の設計が完了しておりブロッカーなし
5. **新規発見の問題はすべて Minor 以下**: M08-01（copy_media）は画像追加前に修正すればよく、現時点の実装をブロックしない
6. **フォールバック計画が具体的**: OOXML → Windows COM → PDF結合 の3段階。ピボット基準が計測可能

### 推奨実装順序

Prompt 9-1 は完了済み、Prompt 9-2 は大部分完了済みのため:

1. **M08-01 修正**: copy_media の rels Target 更新バグを修正（Prompt 9-4 実行前に）
2. **Prompt 9-3**: build.sh inject 統合 + generate_stubs.py narrative スタブ追加
3. **Prompt 9-4**: 統合テスト（Docker 環境でフルビルド、Linux 代替検証）
4. **ドキュメント修正**: C08-02/04/05 の Minor 修正（テスト通過後に）

---

## リスクマトリクス

| リスク | 影響度 | 発生確率 | 総合評価 | 対策 |
|--------|--------|---------|---------|------|
| R1: copy_media リネーム時に画像参照が壊れる | 中 | 低（現在画像なし、将来追加時） | **Major** | M08-01: Prompt 9-4 前に修正 |
| R2: OOXML挿入が1週間で安定しない | 高 | 低（大部分実装済み、4/6テスト通過） | Minor | フォールバック計画策定済み |
| R3: 共同研究者メタデータ収集遅延 | 高 | 高（外部依存） | **Major** | 早急にメタデータ記入を依頼 |
| R4: 3人目 co-I 未確定で書類不完全 | 高 | 中（「人選未定」継続） | **Major** | 人選確定の期限設定（遅くとも4月中旬） |
| R5: pandoc 出力の OOXML 構造が Word バージョンで非互換 | 中 | 低 | Minor | Prompt 9-4 の Word 検証で検出可能 |
| R6: endnotes.xml 未実装でエッジケース発生 | 低 | 極低（Pandoc は通常 endnotes を生成しない） | Info | C08-03: 必要時に追加実装 |
