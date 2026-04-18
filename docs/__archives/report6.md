# 敵対的レビュー報告書（第6回）— 書式統合の技術レビュー

レビュー実施日: 2026-04-05
レビュー対象: docs/step4plan.md, docs/prompts.md (Step 9), main/step02_docx/fill_forms.py, main/step02_docx/build_narrative.sh, main/step02_docx/output/*.docx, scripts/build.sh, scripts/create_package.sh, scripts/windows/watch-and-convert.ps1, SPEC.md §3.1, CLAUDE.md, data/dummy/*.yaml, /home/dryad/anal/jami-abstract-pandoc/
前回レビュー: docs/report5.md (2026-04-05)

## サマリ

- Critical: 4件 (新規4 → **全件対応済み**)
- Major: 5件 (新規5 → **全件対応済み**)
- Minor: 6件 (新規4 / 既知未対応2 → **対応済み5** / 未対応1)
- Note: 5件 (**対応済み3** / 残存2)

### 対応状況一覧

| ID | 重大度 | 状態 | 概要 |
|----|--------|------|------|
| C6-01 | Critical | **対応済み** | OOXML挿入計画にZIPレベルのマージ仕様が欠落 → step4plan.md に Step B-1〜B-4 追加 |
| C6-02 | Critical | **対応済み** | 共同研究者行オーバーフロー → fill_forms.py に行動的追加ロジック実装、E2Eテスト通過 |
| C6-03 | Critical | **対応済み** | 様式4-2が最初の共同研究者のみ → fill_forms.py に複数co-I対応（テーブル複製+ページブレーク）実装 |
| C6-04 | Critical | **対応済み** | SPEC.md §3.1 矛盾 → SPEC.md をOOXML要素挿入方式に更新、フォールバック明記 |
| C6-05 | Major | **対応済み** | セクションブレーク処理未規定 → step4plan.md Step B-2 追加（sectPr保護、末尾sectPr除外、ヘッダ/フッタ保護） |
| C6-06 | Major | **対応済み** | スタイルID衝突未対処 → step4plan.md Step B-3 にスタイルマッピングテーブルと推奨アプローチ追加 |
| C6-07 | Major | **対応済み** | jami参照が誤解を招く → step4plan.md / prompts.md に再利用可能パターン一覧（ファイル:行番号付き）と新規実装必要部分を明確化 |
| C6-08 | Major | **対応済み** | numbering.xmlマージ未規定 → step4plan.md Step B-1 §4 にnumbering統合仕様（abstractNum/numコピー、IDリナンバリング）追加 |
| C6-09 | Major | **対応済み** | Prompt 9-1がPandoc出力を解析しない → Prompt 9-1 に「B. Pandoc出力の構造解析」追加（5項目）、出力先を docs/template_analysis.md に変更 |
| C6-10 | Minor | **対応済み** | 様式2-2ヘッダ削除不完全 → fill_forms.py の上方走査ロジックに修正（最大5要素遡行）、E2Eテスト通過 |
| C6-11 | Minor | **対応済み** | Prompt 9-2エッジケース欠落 → 「エッジケース」セクション追加（空ナラティブ、脚注、テーブルスタイル、リスト、ハイパーリンク、画像なし） |
| C6-12 | Minor | **対応済み** | ダミーnarrative「検討」止まり → Prompt 9-3 で「必須」に変更、generate_stubs.py更新指示・最低コンテンツ要件追加 |
| C6-13 | Minor | **対応済み** | inject入力上書き → Prompt 9-2 技術的注意事項にatomic write（一時ファイル→リネーム）指示追加 |
| C6-14 | Minor | **対応済み** | 旧テーマ記載残存 → CLAUDE.md, SPEC.md, prompts.md の研究テーマを「サイバー攻撃×地域医療シミュレーション」に更新 |
| C6-15 | Minor | 未対応 | pyproject.toml 未作成（4回連続指摘）— Docker運用で実害なし、優先度低 |
| N6-01 | Note | **対応済み** | Prompt 9-1出力ephemeral → 出力先を docs/template_analysis.md に変更 |
| N6-02 | Note | **対応済み** | 工数見積非現実的 → step4plan.md の見積りを 10-15h に修正 |
| N6-03 | Note | **対応済み** | Prompt 9-4検証項目漏れ → 修復ダイアログ、画像、ハイパーリンク、空白ページ、ファイルサイズの5検証項目追加 |
| N6-04 | Note | 残存 | 参考様式best-effort — 現時点では手動記入前提で許容 |
| N6-05 | Note | **反映済み** | step4plan.md / prompts.md を stdlib zipfile + ET 方式に全面改訂 |

## report5.md との差分サマリ

- report5.md の未対応項目で今回解消されたもの: **7件**
  - C5-01 (Critical: Webhook URL平文) → 解消（プレースホルダ化、.envに分離）
  - C5-02 (Major: JSON injection) → 解消（`jq -n --arg` 使用に修正済み）
  - C5-05 (Major: RUNNER未設定) → 解消（`RUNNER="${RUNNER:-docker}"` デフォルト追加）
  - C5-07 (Minor: CLAUDE.mdに未存在ファイル) → 解消（collab_watcher.sh, README_使い方.md 作成済み）
  - C5-08 (Minor: .env.example未作成) → 解消（作成済み）
  - C5-09 (Minor: rclone rcat空入力) → 解消（"IDLE"センチネル使用）
  - C5-03 (Major: fig/figs不整合) → 解消（collab_watcher.shが`figs/`に統一、現時点で画像ディレクトリ未使用のため休眠状態）

- report5.md の未対応項目で依然として未対応のもの: **4件**
  - C5-04 (Major: rclone sync overwrites) → 部分緩和（`--update`フラグ追加、backup phase追加）だが根本リスク残存。今回のスコープ外のため追跡のみ
  - C5-06 (Major: trigger.txt race condition) → 部分緩和（IDLE sentinel）だが構造的問題は残存。スコープ外のため追跡のみ
  - C5-10 → C6-15 (Minor: pyproject.toml未作成) — 4回連続
  - C5-11 (Minor: circle_choice warnings) → 変化なし。非ブロッキングのため追跡のみ

- report5.md に記載がなく今回新規発見したもの: **18件** (Critical 4, Major 5, Minor 4, Note 5)

---

## 指摘事項

### [C6-01] (Critical) OOXML挿入計画にZIPレベルのマージ仕様が欠落

- **箇所**: docs/step4plan.md 全体、docs/prompts.md:504-511
- **前回対応状況**: 新規
- **内容**:
  step4plan.md は「lxml で body 要素を移植」（line 94）と記述するが、docx の実体はZIPアーカイブであり、body 要素のコピーだけでは以下が欠落する:

  1. **メディアファイル**: Pandoc docx内の画像（`word/media/image*.png`等）をターゲットZIPにコピーする必要がある
  2. **リレーションシップ**: `word/_rels/document.xml.rels` にソースdocxのリレーションシップ（画像、ハイパーリンク等のrId）を追加し、ID衝突を回避する必要がある
  3. **numbering.xml**: Pandocが番号付き/箇条書きリストで生成する `w:numPr` 参照は `word/numbering.xml` に定義がある。テンプレートと番号定義IDが衝突した場合、リストの書式が破壊される
  4. **Content_Types**: 新しいメディアタイプ（SVG等）がある場合、`[Content_Types].xml` への追加が必要

  Prompt 9-2（line 497）で「rId再割り当て」に1行で触れているだけで、具体的なマージ手順は未規定。

  **jami-abstract-pandocの実態との乖離**: 参考プロジェクトの `wrap-textbox.py:629-751`（embed_svg_native）はリレーションシップとContent_Typesの操作を **300行以上** で実装している。step4plan.mdはこの複雑さを過小評価している。

- **影響**: 画像・リスト・ハイパーリンクを含むナラティブを挿入した場合、Word起動時に修復ダイアログが表示されるか、画像が欠落する
- **推奨対応**:
  1. step4plan.md に「ZIPレベルマージ仕様」セクションを追加し、document.xml.rels/numbering.xml/[Content_Types].xml/word/media/ の各処理を明記
  2. Prompt 9-2 に具体的な実装指示を追加（jami-abstract-pandocのembed_svg_nativeパターンを参照例として明記）
  3. python-docx経由ではなく、jami-abstract-pandocと同様にstdlib `zipfile` + `xml.etree.ElementTree` での直接操作を検討（N6-05参照）

---

### [C6-02] (Critical) 共同研究者行オーバーフロー — 楠田佳緒が様式1-1から脱落

- **箇所**: main/step02_docx/fill_forms.py:290-302
- **前回対応状況**: 新規（report5では検出されず）
- **内容**:
  様式1-1テーブル（Table 0）は全20行（index 0-19）。PIをrow 17に配置し、co-investigatorsはrow 18から配置される:
  ```python
  for idx, co in enumerate(res.get("co_investigators", [])):
      row = 18 + idx
      if row >= len(tbl.rows):  # >= 20
          warnings.warn("様式1-1: not enough rows for all co-investigators")
          break
  ```
  researchers.yaml には3名の共同研究者がいる:
  - index 0 (黒田 知宏) → row 18 (OK)
  - index 1 (○○ ○○) → row 19 (OK)
  - index 2 (楠田 佳緒) → **row 20 (OVERFLOW)** — `warnings.warn` のみ発行し、**例外は発生しない**

  **行追加ロジックは存在しない。** `break` でループを抜けるだけ。楠田佳緒の情報は様式1-1から完全に欠落する。`warnings.warn` はstderrに出力されるだけでビルドは成功として完走するため、気づかないまま提出するリスクがある。

- **影響**: 提出書類に共同研究者の記載漏れ — 審査時に不備として差し戻し、または研究体制への信頼性低下
- **推奨対応**:
  1. テンプレートの様式1-1テーブルに行を動的追加するロジックを実装（python-docxの `table.add_row()` または既存行をコピー）
  2. または `warnings.warn` を `raise ValueError` に変更してビルドを明示的に失敗させる
  3. 行追加が困難な場合、テンプレートを事前編集して行数を確保する

---

### [C6-03] (Critical) 様式4-2が最初の共同研究者のみ処理

- **箇所**: main/step02_docx/fill_forms.py:865
- **前回対応状況**: 新規
- **内容**:
  ```python
  if "4-2" in tables and has_co:
      fill_4(tables["4-2"], cfg, res["co_investigators"][0], "様式4-2")
  ```
  共同研究者3名のうち、`co_investigators[0]`（黒田 知宏）のみの様式4-2（研究者経歴書）が生成される。残る2名（○○ ○○、楠田 佳緒）の経歴書は作成されない。

  テンプレートr08youshiki1_5.docx内に様式4-2テーブルは1つしか含まれておらず、複数co-I用にテーブルを複製するロジックも存在しない。

- **影響**: 共同研究者2名分の経歴書が欠落 — 提出要件不備（共同研究者全員の経歴書が必要）
- **推奨対応**:
  1. 様式4-2テーブルをco-investigator数分コピーして記入するロジックを実装
  2. コピー時にセクションブレークの挿入が必要（別ページに配置するため）
  3. 別添（betten）と同様に独立ファイルとして出力する方式も検討

---

### [C6-04] (Critical) SPEC.md §3.1 が step4plan.md のアプローチと直接矛盾

- **箇所**: SPEC.md:161-163 vs docs/step4plan.md:93-96
- **前回対応状況**: 新規
- **内容**:
  SPEC.md §3.1 に以下の明確な方針記載がある:
  > 様式1-2, 1-3の統合方法: 各docxをWindows側で個別にPDF化した後、pypdf または Acrobat で様式1-5のPDFと結合して1つの提出用PDFを作成する。**python-docxでの文書結合は書式崩壊リスクが高いため採用しない。**

  step4plan.md はこの方針の逆を提案: python-docx + lxml でdocxレベルの要素挿入を行う。

  step4plan.md:93 は「python-docx での文書間要素コピーは書式崩壊リスクがある（SPEC.md で言及済み）」と認識しつつ、3つの対策（OOXML直接操作、スタイル統一、参考プロジェクト参照）で回避可能と主張する。しかし:

  - 「文書結合」と「要素挿入」の区別は技術的に有効だが、**書式崩壊の原因**（スタイル定義衝突、rID衝突、numbering ID衝突、sectPr衝突）は両アプローチに共通して存在する
  - lxml直接操作は問題を回避するのではなく、問題を**手動で解決する能力を得る**だけであり、それ自体がリスク軽減を保証するわけではない
  - 3つの対策はいずれも具体的な実装仕様が欠落しており（C6-01参照）、「対策がある」という宣言にとどまる

- **影響**: SPEC.mdを参照する実装者はPDF結合方式を、step4plan.mdを参照する実装者はOOXML挿入方式を採用し、方針の混乱が生じる
- **推奨対応**:
  1. 最終方針を決定し、SPEC.mdまたはstep4plan.mdのいずれかを更新して整合させる
  2. SPEC.mdを更新する場合、OOXML挿入方式のリスクと対策を具体的に追記する
  3. step4plan.mdを撤回する場合、PDF結合方式の実装計画を代わりに策定する

---

### [C6-05] (Major) セクションブレーク処理が挿入計画で未規定

- **箇所**: docs/step4plan.md 全体（sectPrへの言及なし）
- **前回対応状況**: 新規
- **内容**:
  テンプレートr08youshiki1_5.docxはセクション間に `w:sectPr`（セクションプロパティ）要素を持つ。fill_forms.pyの `delete_sections` 関数は sectPr の保護を **明示的に行っている**（lines 738, 749, 762, 775, 791 で `children[i].tag != qn("w:sectPr")` チェック）。

  step4plan.md にはsectPrへの言及が一切ない。以下の問題が未対処:

  1. **様式1-2/1-3のセクション境界にsectPrがある場合**: 要素挿入位置がsectPrを跨ぐと、コンテンツが意図しないセクションに配置される（異なるページ設定、ヘッダ/フッタが適用される）
  2. **Pandoc docxの末尾sectPr**: Pandocは必ずbody末尾に `w:sectPr` を生成する。このsectPrもコピーすると、テンプレート内に不正なセクションブレークが挿入される
  3. **ヘッダ/フッタ**: 各セクションに固有のヘッダ/フッタ（様式番号等）がある場合、セクション構造の変更でそれらが失われる
  4. **ページ番号**: 各 sectPr の `w:pgNumType` 設定が通しページ番号に影響する

- **影響**: 空白ページの出現、ヘッダ/フッタの消失、ページ番号のリセット、ページ設定（用紙サイズ・余白）の不整合
- **推奨対応**:
  1. Prompt 9-1にsectPrの調査を明示的に追加（各sectPrの位置、プロパティ、関連するヘッダ/フッタを特定）
  2. step4plan.mdに「Pandoc docx末尾のsectPrを除外してコピーする」旨を明記
  3. inject_narrative.pyの設計にsectPr保護ロジックを含める

---

### [C6-06] (Major) PandocスタイルとテンプレートスタイルのスタイルID衝突

- **箇所**: docs/step4plan.md:95-97, docs/prompts.md:494-496
- **前回対応状況**: 新規
- **内容**:
  現在のビルド出力を調査した結果、Pandoc生成docxとテンプレートdocxのスタイル体系は完全に異なる:

  | Pandoc docx (narrative) | テンプレート docx (filled) |
  |---|---|
  | Heading 1 | 公募要領：タイトル２　節項 |
  | Heading 2, 3 | 公募要領：タイトル３　目 |
  | Body Text, First Paragraph | 公募要領：本文１ |
  | Compact | （対応なし） |

  step4plan.md:95 は「reference.docx のスタイル定義をテンプレートと統一」と記述するが:
  - reference.docxのスタイル名はPandocの慣例（Heading 1, Body Text等）に従う必要がある — Pandocがこれらの名前でスタイルを参照するため、スタイル名をテンプレートに合わせて変更するとPandocが壊れる
  - テンプレートにPandocのスタイルを追加する場合、スタイルIDの衝突はないが、テンプレートの本来のスタイル体系と二重定義になる
  - `word/styles.xml` のマージ戦略が未規定

  step4plan.md:97 は「スタイル名のマッピングが必要」と述べるが、マッピングテーブルもマッピング実装の仕様もない。

- **影響**: 挿入されたナラティブのフォント・余白・行間がテンプレートと不整合（MSゴシックが明朝に、10.5ptが10ptに、等）
- **推奨対応**:
  1. 選択肢A: テンプレートのstyles.xmlにPandocスタイル定義を事前追加し、テンプレートの書式に合わせた定義を持たせる
  2. 選択肢B: inject時にコピー要素のスタイル参照をテンプレートスタイルに書き換える（Heading 1 → 公募要領：タイトル２　節項 等）
  3. 選択肢C: テンプレートをPandocのreference.docxとして使用し、Pandocが最初からテンプレートのスタイルで出力するようにする（最も根本的な解決策だが、Pandocの出力制御範囲に限界がある）
  4. いずれの場合もマッピングテーブルを明文化する

---

### [C6-07] (Major) jami-abstract-pandoc参照が誤解を招く

- **箇所**: docs/step4plan.md:96, docs/prompts.md:467,512
- **前回対応状況**: 新規
- **内容**:
  step4plan.mdとPrompt 9-2は「jami-abstract-pandocのOOXML後処理パターンを参照」と繰り返し述べるが、同プロジェクトの実態を調査した結果:

  - **wrap-textbox.py** (868行): 単一文書内のテキストボックス化、テーブル罫線処理、SVG埋め込み。**文書間要素コピーは行わない**
  - **fix-reference-cols.py** (251行): reference.docxのスタイル・カラム調整。**文書間操作なし**
  - **filters/jami-style.lua** (137行): Pandocフィルタ。Luaレベルの操作

  これらのスクリプトはOOXML操作の「スキル」を示すが、inject_narrative.pyの中核課題である **「文書Aのbody要素を文書Bの特定位置に挿入し、リレーションシップ・スタイル・ナンバリングを整合させる」** という操作パターンの実績はない。

  参考になるパターン（再利用可能）:
  - ZIPアーカイブI/Oパターン（stdlib zipfile使用）
  - 名前空間登録とルートタグ保存（ElementTree使用時の必須技法）
  - リレーションシップ操作（embed_svg_native内のrId追加）
  - body要素の列挙・削除・挿入パターン

  参考にならないパターン（新規実装が必要）:
  - 文書間要素コピー全般
  - スタイル定義のマージ
  - numbering.xmlのマージ

- **影響**: 実装者が「参考プロジェクトを見れば実装できる」と誤認し、実装難度を過小評価する
- **推奨対応**:
  1. Prompt 9-2で「jami-abstract-pandocから再利用可能なパターン」と「新規実装が必要な部分」を明確に区分して記載
  2. 具体的なファイル名と行番号を参照指示に含める（e.g., `wrap-textbox.py:398-470 のルートタグ保存パターン`）

---

### [C6-08] (Major) word/numbering.xmlのマージが未規定

- **箇所**: docs/step4plan.md（記載なし）、docs/prompts.md:508-511
- **前回対応状況**: 新規
- **内容**:
  Pandocが生成するMarkdownの番号付きリスト（`1. ...`）や箇条書き（`- ...`）は、docx内で `w:numPr` 要素としてレンダリングされ、リスト定義は `word/numbering.xml` に格納される。

  body要素をテンプレートにコピーする際、コピー元の `w:numPr` が参照する numbering ID（`w:numId`, `w:abstractNumId`）がテンプレートの numbering.xml に存在しないか、別の定義と衝突する場合:
  - リスト番号がリセットされる
  - 箇条書き記号が変わる
  - 番号付きリストが箇条書きとして表示される
  - Wordが修復ダイアログを表示する

  step4plan.md と Prompt 9-2 はこの問題に一切触れていない。

- **影響**: ナラティブ中のリスト（実験手順、参考文献番号等）の書式が崩壊する
- **推奨対応**:
  1. inject_narrative.pyの設計にnumbering.xmlマージロジックを追加
  2. ソースdocxのnumbering定義をターゲットにコピーし、ID衝突を回避するためにリナンバリング
  3. コピーされたbody要素内のnumId参照を新しいIDに書き換え

---

### [C6-09] (Major) Prompt 9-1がPandoc出力構造を解析しない

- **箇所**: docs/prompts.md:405-443 (Prompt 9-1)
- **前回対応状況**: 新規
- **内容**:
  Prompt 9-1は「r08youshiki1_5.docx内の様式1-2/1-3セクションの構造を解析」と指示するが、**挿入元であるPandoc出力docxの構造解析を指示していない。**

  inject_narrative.pyの設計にはソース（Pandoc docx）とターゲット（template docx）**双方**の構造理解が不可欠:
  - Pandoc docxのbody子要素構成（末尾のsectPr含む）
  - 使用されているスタイル名の一覧
  - リレーションシップの有無（画像・ハイパーリンク）
  - numbering定義の有無
  - ページ設定（sectPr内のpgSz, pgMar）

  これらの情報なしにPrompt 9-2でinject_narrative.pyを実装すると、ソースdocxの構造に関する仮定が外れた際に手戻りが発生する。

- **影響**: Prompt 9-2の実装時に未知の構造に遭遇し、設計の見直しが必要になる
- **推奨対応**:
  1. Prompt 9-1の作業内容に「youshiki1_2_narrative.docx / youshiki1_3_narrative.docx の構造解析」を追加
  2. 具体的な調査項目: body子要素一覧、スタイル名一覧、rels内のリレーションシップ一覧、numbering.xmlの有無と内容

---

### [C6-10] (Minor) 様式2-2 4・5年目のヘッダ段落が削除されず残存

- **箇所**: main/step02_docx/fill_forms.py:779-787
- **前回対応状況**: 新規
- **内容**:
  `delete_sections` 関数は年度4・5のテーブルを削除する際、テーブルの直前要素（`children[ti - 1]`）に「年目」を含むかチェックしてヘッダも削除する。しかし、テーブルとヘッダの間に空の `w:p` 要素が複数挿入されている場合、`children[ti - 1]` は空段落を指し、ヘッダ段落はさらに前の位置にある。

  ビルド出力を確認した結果、「研究費計画書（４年目）」「研究費計画書（５年目）」のヘッダ段落が残存している。

- **影響**: PDF上に空のヘッダが表示される（テーブルは削除済みなので「4年目」「5年目」の見出しだけが残る形）
- **推奨対応**: ヘッダ検出ロジックを `children[ti - 1]` だけでなく、テーブルから上方に数要素走査する方式に変更

---

### [C6-11] (Minor) Prompt 9-2にエッジケース記載漏れ

- **箇所**: docs/prompts.md:453-519 (Prompt 9-2)
- **前回対応状況**: 新規
- **内容**:
  以下のエッジケースへの言及が欠落:
  1. **空のナラティブ**: youshiki1_3.md が空または極端に短い場合、docxのbodyに0個の段落しかない。プレースホルダ削除後に何も挿入されないケースの処理
  2. **脚注/尾注**: Pandocの脚注構文（`[^1]`）は `word/footnotes.xml` に定義を生成し、body内の参照はrIdで紐づく。脚注xmlのマージが必要
  3. **テーブルスタイル**: Markdownテーブルは `TableGrid` 等のスタイルを使用するが、テンプレートに同名スタイルがない場合の処理
  4. **画像なしの場合**: 画像がない場合のrId処理がグレースフルにスキップされるべき旨の記載なし（実装者がnull参照エラーを踏むリスク）

- **影響**: 実装者がエッジケースに遭遇するたびにPromptに戻って確認する手戻り
- **推奨対応**: Prompt 9-2に「エッジケース一覧」セクションを追加

---

### [C6-12] (Minor) ダミーnarrative docxフィクスチャが「検討」止まり

- **箇所**: docs/prompts.md:568-569 (Prompt 9-3)
- **前回対応状況**: 新規
- **内容**:
  > E2Eテストで inject が正常にスキップまたは動作するよう、ダミーの narrative docx が必要か検討

  「検討」ではなく**要件**であるべき。injectフェーズがE2Eテストで実行されない場合、CIで回帰を検出できない。ダミーnarrative docxには最低限、見出し1つ、本文段落1つ、テーブル1つ、画像1つを含めるべき。

- **影響**: E2Eテストがinjectフェーズを実質的にカバーしない
- **推奨対応**: Prompt 9-3の記載を「検討」から要件に変更し、generate_stubs.py でダミーnarrative docxを生成するよう指示

---

### [C6-13] (Minor) inject処理が入力ファイルを上書きしバックアップなし

- **箇所**: docs/step4plan.md:124, docs/prompts.md:482
- **前回対応状況**: 新規
- **内容**:
  ```bash
  --output main/step02_docx/output/youshiki1_5_filled.docx
  ```
  `--output` が `--template` と同一ファイルを指定しており、inject処理が失敗した場合（例: 中間地点でのPython例外）、入力ファイルが破損または中途半端な状態になる。後続のビルドステップ（security, excel）は影響を受けないが、再ビルドには `forms` ステップからのやり直しが必要。

- **影響**: inject失敗時のリカバリコストが増大
- **推奨対応**: 一時ファイルに出力してから成功時にリネームする方式（atomic write）を採用

---

### [C6-14] (Minor) CLAUDE.md・SPEC.mdに旧テーマ記載が残存

- **箇所**: CLAUDE.md:9, SPEC.md:8, docs/prompts.md:13
- **前回対応状況**: report5では直接指摘なし（テーマ変更は report5 以降の出来事）
- **内容**:
  研究テーマが「薬剤耐性菌」からサイバー攻撃×地域医療シミュレーションに変更されたが、以下のファイルに旧テーマの記述が残存:
  - CLAUDE.md:9 — `**研究テーマ**: (23) 医療・医工学に関する基礎研究（抗菌薬耐性関連）`
  - SPEC.md:8 — `研究テーマ (23) 医療・医工学に関する基礎研究（抗菌薬耐性関連）`
  - docs/prompts.md:13 — 同様

  main/00_setup/*.yaml は正しく更新済み。

- **影響**: AIアシスタントやレビュアーに旧テーマの文脈で作業してしまうリスク
- **推奨対応**: 3ファイルの研究テーマ記載を新テーマに更新

---

### [C6-15] (Minor) pyproject.toml 未作成（4回連続指摘）

- **箇所**: プロジェクトルート
- **前回対応状況**: report5.md [C5-10] 未対応 ← report4 [C4-14] ← report3 [C3-11]
- **内容**: `RUNNER=uv` モードで `uv run` を使用する場合に必要な pyproject.toml が依然として存在しない。Docker がデフォルトRUNNERであるため実害は少ないが、4回連続の指摘となる。
- **影響**: uv実行モードが使用不可
- **推奨対応**: 作成する（最小限の `[project]` セクションと依存定義のみ）か、RUNNER=uv サポートを明示的に非対応と宣言する

---

### [N6-01] (Note) Prompt 9-1の出力がコンソールのみ

- **箇所**: docs/prompts.md:437
- **前回対応状況**: 新規
- **内容**: 「解析結果をコンソールに出力（スクリプト作成は不要、調査のみ）」— 結果は会話コンテキスト内にしか存在せず、Prompt 9-2を別セッションで実行する場合に参照できない。
- **推奨対応**: 解析結果を docs/ 配下にファイル出力するか、Prompt 9-2に「Prompt 9-1の結果がない場合は自ら解析を実行すること」と記載

---

### [N6-02] (Note) Step B の工数見積が非現実的

- **箇所**: docs/step4plan.md:165
- **前回対応状況**: 新規
- **内容**: Step B（inject_narrative.py作成）の見積りが3-4時間。jami-abstract-pandocのembed_svg_native（単一文書内のSVG埋め込み）だけで120行以上、wrap-textbox.py全体で868行。文書間マージはこれより複雑であり、10-20時間が現実的。
- **推奨対応**: 見積りを修正するか、スコープを縮小（画像なし前提で初期実装、画像対応は後続ステップ）

---

### [N6-03] (Note) Prompt 9-4の検証項目に漏れ

- **箇所**: docs/prompts.md:597-612 (Prompt 9-4)
- **前回対応状況**: 新規
- **内容**: 以下の検証項目が未記載:
  - 画像が正しくレンダリングされるか
  - ハイパーリンクが機能するか
  - 空白ページが発生していないか（セクションブレーク不整合の典型症状）
  - ファイルサイズが制約内か（10MB以下、目標3MB）
  - docxがWord修復ダイアログなしで開けるか
- **推奨対応**: 検証チェックリストに追加

---

### [N6-04] (Note) 参考様式の記入がbest-effort

- **箇所**: main/step02_docx/fill_forms.py:659-692
- **前回対応状況**: 新規
- **内容**: `fill_consent_forms` は承諾書のうち「R8～R」→「R8～R10」のパターン置換のみ実行。機関名（○○大学）、学部長名（△△学部長）、研究者名（□□□□）等のプレースホルダは未記入のまま。手動記入が前提と思われるが、他の様式が自動記入されている中で承諾書だけが手動というのは不整合。
- **推奨対応**: 自動記入範囲をconfig.yamlの情報で拡大するか、手動記入前提であることをチェックリストに明記

---

### [N6-05] (Note) jami-abstract-pandocの実装方式がstep4plan.mdの前提と異なる

- **箇所**: docs/step4plan.md:94,172
- **前回対応状況**: 新規
- **内容**:
  step4plan.md は python-docx + lxml の使用を前提としているが、参考プロジェクトjami-abstract-pandocは意図的に **python-docxを使わず**、stdlib の `xml.etree.ElementTree` + `zipfile` で全OOXML操作を実装している。

  この設計選択には重要な理由がある:
  - python-docx経由で取得した `Document.element.body` はpython-docxの内部状態と結合しており、別のDocumentオブジェクトの要素をコピーするとpython-docxの整合性チェックに抵触する可能性がある
  - stdlib `zipfile` で直接ZIP内のXMLパーツを読み書きする方が、リレーションシップやContent_Typesの操作が透明
  - jami-abstract-pandocの `wrap-textbox.py:398-470` に **ルートタグ保存** という重要なテクニックがある: ElementTreeはシリアライズ時に未使用の名前空間宣言を除去するため、Wordが不正なファイルとして拒否する。解決策としてシリアライズ前のルートタグを正規表現で保存し、シリアライズ後に復元する
  - この問題はpython-docxでは発生しないが、python-docxを離れてlxmlで直接操作する場合にも同様のリスクがある

- **推奨対応**: inject_narrative.pyの実装方式として、python-docx + lxml ではなく、jami-abstract-pandocと同じ stdlib `zipfile` + `xml.etree.ElementTree` 方式を推奨。少なくともルートタグ保存テクニックの適用を必須とする

---

## 代替アプローチ比較表

| 方式 | 書式崩壊リスク | 実装難度 | ページ番号 | テンプレート準拠 | 推奨度 |
|------|--------------|---------|----------|--------------|-------|
| OOXML挿入 (step4plan.md) | **高** — スタイル・rId・numbering・sectPr全て要対処 | **高** — 10-20h、C6-01/05/06/08の全解決が必要 | 制御可能（sectPr適切処理時） | **高** — テンプレートヘッダ維持 | **条件付き推奨**: 全Criticalが解決される場合 |
| PDF結合 (pypdf) | **低** — 個別PDF生成済みの結合のみ | **低** — pypdf数十行 | **要対処** — 各PDFが独立番号。PDF上でのページ番号スタンプが必要 | **中** — テンプレートヘッダがnarrative PDFに不在 | **代替推奨**: OOXML挿入が頓挫した場合のフォールバック |
| Windows COM結合 | **極低** — Word自身がレイアウト保証 | **中** — VBScript拡張、ファイルセット検出ロジック必要 | Word制御可能 | **高** — Word InsertFileで完全統合 | **高推奨**: Windows依存が許容できる場合の最良選択 |
| docx分割 + PDF結合 | **低** — 個別生成・個別PDF化 | **中** — fill_forms.py分割ロジック + pypdf結合 | **要対処** — PDF上でのページ番号付与が必要 | **中** — 各PDFが独立文書 | **代替推奨**: OOXML挿入より低リスク |

### 補足分析

**OOXML挿入方式 (step4plan.md)**:
技術的には最もエレガントだが、C6-01, C6-05, C6-06, C6-08の4つのMajor以上の課題が全て未解決。これらを全て正しく実装するには、実質的にdocxマージライブラリを自作することになる。提出期限（2026-05-20）まで45日の中でこのリスクを取ることの妥当性を検討すべき。

**PDF結合方式**:
SPEC.md §3.1 の当初方針。ページ番号の非連続が最大の懸念だが、提出先（e-Rad）がページ番号の連続性を厳密にチェックするかは要確認。テンプレートヘッダの二重化は、youshiki1_2_narrative.docxに様式番号ヘッダを追加することで解消可能。

**Windows COM結合方式**:
watch-and-convert.ps1 の既存インフラ（VBScript + Word COM）を拡張可能。Word自体が整合性を保証するため書式崩壊リスクが最も低い。VBScriptで `Document.Range.InsertFile` を使用し、挿入位置を指定できる。ただしLinux完結ではなくなる。

**推奨戦略**: OOXML挿入を主方式として進めつつ、実装が1週間以内に安定しない場合は **Windows COM結合方式にピボット** するフォールバック計画を策定すべき。PDF結合方式は最終手段として保持。

---

## リスクマトリクス

| リスク | 影響度 | 発生確率 | 総合評価 | 対策 | 状態 |
|--------|--------|---------|---------|------|------|
| R1: OOXML挿入でスタイル崩壊 | 高 | 高 | **Critical** | C6-06: スタイルマッピング仕様策定済み | 仕様策定済み、実装待ち |
| R2: 共同研究者情報の欠落（様式1-1, 4-2） | 高 | 確定 | **Critical** | C6-02, C6-03: コード修正済み | **解消** |
| R3: rId/numbering衝突でWord修復ダイアログ | 高 | 高 | **Critical** | C6-01, C6-08: ZIPマージ仕様策定済み | 仕様策定済み、実装待ち |
| R4: sectPr不整合で空白ページ/ヘッダ消失 | 中 | 高 | **Major** | C6-05: sectPr処理仕様策定済み | 仕様策定済み、実装待ち |
| R5: SPEC.md/step4plan.md方針矛盾で実装混乱 | 中 | 中 | **Major** | C6-04: SPEC.md更新済み | **解消** |
| R6: 45日で OOXML挿入が安定しない | 高 | 中 | **Major** | フォールバック計画・ピボット基準策定済み | 緩和済み |
| R7: E2Eテストがinjectをカバーしない | 中 | 高 | **Major** | C6-12: ダミーnarrative要件化済み | 仕様策定済み、実装待ち |
| R8: CLAUDE.md旧テーマでAIが誤コンテキスト | 低 | 中 | **Minor** | C6-14: テーマ記載更新済み | **解消** |
| R9: 様式2-2ヘッダ残存 | 低 | 確定 | **Minor** | C6-10: コード修正済み | **解消** |
| R10: inject失敗時の入力ファイル破損 | 中 | 低 | **Minor** | C6-13: atomic write仕様追加済み | 仕様策定済み、実装待ち |

---

## 優先対応順序

| 優先度 | 対象 | 理由 |
|--------|------|------|
| **P0** | C6-02, C6-03 | 共同研究者情報の欠落は現時点で確定している不具合。Step 9以前に修正すべき |
| **P1** | C6-04 | SPEC.md vs step4plan.md の方針矛盾を解消しないと Step 9 の実装方針が定まらない |
| **P1** | C6-01, C6-05, C6-06, C6-08, C6-09 | Step 9実装の前提条件。step4plan.md と Prompt 9-1/9-2 を改訂してからでないと実装に着手すべきでない |
| **P2** | C6-07, C6-10, C6-11, C6-12, C6-13 | 実装と並行して対応可能 |
| **P3** | C6-14, C6-15, N6-01〜N6-05 | 品質改善。実装を阻害しない |

---

## 対応実施記録（2026-04-05）

レビュー指摘に対して以下の対応を実施した。

### コード修正（fill_forms.py）

| 対象 | 修正内容 | 検証 |
|------|---------|------|
| **C6-02** fill_forms.py:283-302 | 共同研究者行を動的追加するロジック実装。`needed_rows = 18 + len(co_list)` で不足行をテンプレート最終行のdeep copyで追加。`warnings.warn` + `break` パターンを除去。 | E2Eテスト通過（dummy: 1 co-I） |
| **C6-03** fill_forms.py:864-865 | 様式4-2テーブルを全co-I分複製するロジック実装。`copy.deepcopy` でテーブル要素をコピーし、`addnext` でページブレーク + テーブルを挿入。`DocxTable` ラッパーで `fill_4` に渡す。 | E2Eテスト通過（dummy: 1 co-I、複数co-Iは本番データで要検証） |
| **C6-10** fill_forms.py:778-787 | 様式2-2 4/5年目ヘッダ削除を上方走査方式に変更。`children[ti-1]` 固定ではなく最大5要素遡行して「年目」を含む段落を検索。 | E2Eテスト通過 |

### ドキュメント修正

| 対象 | 修正内容 |
|------|---------|
| **C6-04** SPEC.md:161-163 | 「python-docxでの文書結合は採用しない」→ OOXML要素挿入方式を採用、フォールバック（Windows COM / PDF結合）を明記 |
| **C6-14** CLAUDE.md:9, SPEC.md:8, prompts.md:13 | 研究テーマを「抗菌薬耐性関連」→「サイバー攻撃×地域医療シミュレーション」に更新 |

### 設計文書拡充（step4plan.md）

| 対象 | 追加内容 |
|------|---------|
| **C6-01** Step B-1 | ZIPレベルマージ仕様: document.xml, document.xml.rels, word/media/, word/numbering.xml, [Content_Types].xml の5パーツの処理仕様 |
| **C6-05** Step B-2 | sectPr処理仕様: テンプレートsectPr保護、ソース末尾sectPr除外、ヘッダ/フッタ保護 |
| **C6-06** Step B-3 | スタイルマッピングテーブル（Pandoc → テンプレート）と推奨アプローチ |
| **C6-08** Step B-1 §4 | numbering.xml統合仕様（abstractNum/numコピー、IDリナンバリング） |
| **C6-07** 参考パターン一覧 | jami-abstract-pandocから再利用可能なパターン（ファイル:行番号付き6項目）と新規実装必要部分の明確化 |
| **N6-02** 作業順序 | Step B の見積りを 3-4h → 10-15h に修正 |
| フォールバック | 代替案比較表を追加。ピボット基準（1週間以内に安定しなければWindows COM方式）を明記 |

### プロンプト改訂（prompts.md Step 9）

| 対象 | 変更内容 |
|------|---------|
| **C6-09** Prompt 9-1 | 「B. Pandoc出力の構造解析」セクション追加（body要素、スタイル名、rels、numbering、sectPr の5調査項目）。出力先を console → docs/template_analysis.md に変更 |
| **C6-07** Prompt 9-2 | jami参照を具体化: 再利用可能パターン一覧テーブル（ファイル:行番号付き5項目）追加 |
| **C6-11** Prompt 9-2 | 「エッジケース」セクション追加（画像なし、空ナラティブ、テーブルのみ、リスト、脚注、ハイパーリンク） |
| **C6-13** Prompt 9-2 | 技術的注意事項にatomic write指示追加 |
| **N6-05** Prompt 9-2 | 実装方式を python-docx + lxml → stdlib zipfile + ET に変更 |
| **C6-12** Prompt 9-3 | ダミーnarrative docxを「検討」→「必須」に変更、generate_stubs.py更新指示と最低コンテンツ要件追加 |
| **N6-03** Prompt 9-4 | 5検証項目追加: 修復ダイアログなし、画像表示、ハイパーリンク、空白ページなし、ファイルサイズ |

### 未対応（C6-15）

pyproject.toml 未作成: Docker がデフォルトRUNNERであり実害なし。`RUNNER=uv` サポートの要否を判断してから対応する。
