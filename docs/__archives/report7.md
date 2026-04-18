# 敵対的レビュー報告書（第7回）— Step 9 実装前の最終準備レビュー

レビュー実施日: 2026-04-05
レビュー対象: docs/step4plan.md, docs/prompts.md (Step 9), main/step02_docx/fill_forms.py, main/step02_docx/build_narrative.sh, main/step02_docx/fix_reference_styles.py, scripts/build.sh, scripts/create_package.sh, scripts/windows/watch-and-convert.ps1, main/step01_narrative/youshiki1_2.md, main/step01_narrative/youshiki1_3.md, main/00_setup/*.yaml, data/dummy/*.yaml, data/dummy/generate_stubs.py, /home/dryad/anal/jami-abstract-pandoc/scripts/wrap-textbox.py, SPEC.md, CLAUDE.md, README.md, templates/reference.docx
前回レビュー: docs/report6.md (2026-04-05)

## サマリ

- Critical: 1件 (新規1)
- Major: 5件 (新規3 / 既知未対応1 / 既知対応不十分1)
- Minor: 5件 (新規3 / 既知未対応1 / 既知対応不十分1)
- Note: 4件 (新規2 / 既知未対応2)

### 対応状況一覧

| ID | 重大度 | 状態 | 概要 |
|----|--------|------|------|
| C7-01 | Critical | 新規 | Prompt 9-2 実装チェックリストに word/styles.xml マージが欠落 |
| C7-02 | Major | C6-04対応不十分 | SPEC.md §3.1 出力テーブルが旧ワークフロー記載のまま |
| C7-03 | Major | 新規 | C6-02/C6-03 修正がダミーデータ（co-I 1名）でしかテストされていない |
| C7-04 | Major | 新規 | SPEC.md パイプライン図・ステップ記述に inject_narrative.py が不在 |
| C7-05 | Major | 新規 | Prompt 9-4「Word修復ダイアログなし」検証にLinux代替手段が未記載 |
| C7-06 | Major | C6-15未対応 | pyproject.toml 未作成（5回連続） |
| C7-07 | Minor | C6-14対応不十分 | README.md の研究テーマが未更新 |
| C7-08 | Minor | 新規 | DocxTable(new_tbl, doc) — 非標準コンストラクタ使用 |
| C7-09 | Minor | 新規 | step4plan.md B-1 が footnotes.xml / endnotes.xml を 5パーツリストに含まない |
| C7-10 | Minor | 新規 | Prompt 9-1 に Docker 実行指示が明示されていない |
| N7-01 | Note | 新規 | YAML メタデータが大幅に未完成（researchers.yaml ~35%、other_funding.yaml ~10%） |
| N7-02 | Note | 新規 | youshiki1_2.md に「○○教授」等のプレースホルダが5箇所残存 |
| N7-03 | Note | N6-04継続 | 参考様式（承諾書）の記入が best-effort のまま |
| N7-04 | Note | 新規 | step4plan.md B-3 のスタイルマッピングが「推奨アプローチ」表現で必須性が曖昧 |

## report6.md との差分サマリ

- report6.md の未対応項目で今回解消されたもの: **0件**
  - C6-15（pyproject.toml）: 依然未対応 → C7-06 へ引継ぎ
  - N6-04（参考様式best-effort）: 依然未対応 → N7-03 へ引継ぎ
- report6.md の未対応項目で依然として未対応のもの: **2件**（C7-06, N7-03）
- report6.md で「対応済み」とされた項目で実際には不十分なもの: **2件**
  - C6-04（SPEC.md §3.1矛盾）→ 脚注は修正済みだがテーブル行が旧記述のまま（C7-02）
  - C6-14（旧テーマ残存）→ CLAUDE.md/SPEC.md/prompts.md は更新済みだが README.md が未更新（C7-07）
- report6.md に記載がなく今回新規発見したもの: **11件**（Critical 1, Major 3, Minor 3, Note 4）

---

## 指摘事項

### [C7-01] (Critical) Prompt 9-2 の実装チェックリストに word/styles.xml マージが欠落

- **箇所**: docs/prompts.md:524-529, docs/step4plan.md:99-128 (B-1), docs/step4plan.md:137-151 (B-3)
- **前回対応状況**: 新規（report6 C6-06 でスタイルマッピング仕様は B-3 に追加されたが、Prompt 9-2 の実装要件への反映が漏れている）
- **内容**:
  Prompt 9-2 (lines 524-529) は inject_narrative.py の実装者に対し、以下の5項目を明示的な処理リストとして提示している:

  1. rIdリナンバリング
  2. numbering統合
  3. メディアファイルコピー
  4. 末尾sectPr除外
  5. ルートタグ保存

  **word/styles.xml のマージがこのリストに含まれていない。** step4plan.md B-3 (lines 137-151) では「テンプレートの word/styles.xml にPandocスタイル定義を追加する」と記述されているが:

  - step4plan.md B-1 の「5つのZIPパーツ」リスト (lines 99-128) にも styles.xml は含まれない
  - Prompt 9-2 の line 523 は「docs/step4plan.md の Step B-1〜B-4 の仕様に従って実装すること」と参照を促すが、明示リスト (lines 524-529) が実装者の主たるチェックリストとして機能する
  - Prompt 9-2 は「そのままAIに渡して実装できるレベル」を目指して設計されており、明示リストの漏れはそのまま実装漏れになる

  **結果**: Pandoc生成コンテンツは `Heading 1`, `Body Text`, `First Paragraph`, `Compact` 等のスタイルIDを参照するが、テンプレートdocx（r08youshiki1_5.docx）にはこれらのスタイル定義が存在しない。Wordは未定義スタイルをNormalにフォールバックさせるため、研究計画本文全体のフォント・サイズ・行間が意図と異なる表示になる。

- **影響**: 様式1-2/1-3の本文（最大15ページ）が書式崩壊した状態で提出される。手戻りとして styles.xml マージロジックの追加実装が必要
- **推奨対応**:
  1. Prompt 9-2 の lines 524-529 に6番目の項目として「**styles.xmlマージ**: テンプレートの word/styles.xml にPandocスタイル定義（Heading 1, Body Text, First Paragraph, Compact）を追加。定義はテンプレートの既存スタイル（公募要領：本文１等）と同じフォント・サイズ・行間にする」を追加
  2. step4plan.md B-1 の記述を「5つのZIPパーツ」から「6つのZIPパーツ」に更新し、styles.xml を追加するか、B-3 への明確なクロスリファレンスを B-1 末尾に追記
  3. fix_reference_styles.py (lines 80-148) のスタイル定義をテンプレートにも適用するパターンとして Prompt 9-2 の参照リストに追加

---

### [C7-02] (Major) SPEC.md §3.1 出力テーブルが旧ワークフロー記載のまま

- **箇所**: SPEC.md:155-157
- **前回対応状況**: report6.md [C6-04] 対応済みとされたが不十分
- **内容**:
  report6 C6-04 への対応として SPEC.md §3.1 に OOXML挿入方式の脚注 (lines 161-165) が追加された。しかし、出力ファイルテーブル (lines 155-157) の記述は旧ワークフローのまま:

  ```
  | youshiki1_2_narrative.docx | 様式1-2 本文（Pandoc生成） | Windows側で個別PDF化 → PDF結合 |
  | youshiki1_3_narrative.docx | 様式1-3 本文（Pandoc生成） | 同上 |
  ```

  OOXML挿入方式では narrative docx は中間ファイルであり、最終的に youshiki1_5_filled.docx に統合される。テーブル行が「個別PDF化 → PDF結合」と記載しているのは脚注の「OOXMLレベルで直接挿入する」と直接矛盾する。

  実装者がテーブルを先に読み、脚注を見落とすと、旧方式で実装する恐れがある。
- **影響**: 実装方針の混乱による手戻り
- **推奨対応**: テーブル行を以下のように修正:
  ```
  | youshiki1_2_narrative.docx | 様式1-2 本文（Pandoc生成、中間ファイル） | inject_narrative.py で youshiki1_5_filled.docx に統合 |
  | youshiki1_3_narrative.docx | 様式1-3 本文（同上） | 同上 |
  ```

---

### [C7-03] (Major) C6-02/C6-03 修正がダミーデータ（co-I 1名）でしかテストされていない

- **箇所**: main/step02_docx/fill_forms.py:285-308 (C6-02), :876-897 (C6-03), data/dummy/researchers.yaml
- **前回対応状況**: 新規（report6 で C6-02/C6-03 は「対応済み、E2Eテスト通過」とされたが、テスト条件の制約が指摘されていなかった）
- **内容**:
  ダミーデータ (data/dummy/researchers.yaml) の co_investigators は1名のみ（△△ △△）。本番データ (main/00_setup/researchers.yaml) には3名の共同研究者が定義されている。

  **C6-02（行動的追加）**: `needed_rows = 18 + len(co_list)` の計算は正しいが、`copy.deepcopy(tbl.rows[-1]._element)` によるテンプレート最終行の複製は以下のリスクがある:
  - テンプレート様式1-1の行19（0-indexed）にセル結合（`w:gridSpan`, `w:vMerge`）がある場合、複製された行に不正な結合属性が継承される
  - `tbl.cell(row, col)` アクセスで列インデックスが結合セルの有無で変わりうる
  - ダミーデータの co-I=1 では `while` ループが回らないため（needed_rows=19、テンプレートrows=20）、行追加自体がテストされていない

  **C6-03（4-2複製）**: `copy.deepcopy(tables["4-2"]._element)` は co_list[0] のデータで fill 済みのテーブルをコピーする。fill_4() が全セルを上書きすれば問題ないが、部分的にしか上書きしない場合 co_list[0] のデータが後続の co-I テーブルに残留する。ダミーデータの co-I=1 では複製ループ自体が実行されない (`range(1, 1)` = 空)。

- **影響**: 本番ビルド時に初めて行追加・テーブル複製が実行され、結合セルやデータ残留に起因する不正な出力が発生する可能性。提出前の本番テストで発覚するが、修正に時間を要する
- **推奨対応**:
  1. data/dummy/researchers.yaml の co_investigators を2名以上に増やし、E2Eテストで行追加・テーブル複製を実際に実行する
  2. テンプレート r08youshiki1_5.docx の様式1-1テーブル行19のセル構造を手動確認し、結合セルの有無を記録
  3. fill_4() の上書き網羅性を確認（全10行×5列が上書きされるか）

---

### [C7-04] (Major) SPEC.md パイプライン図とステップ記述に inject_narrative.py が不在

- **箇所**: SPEC.md:59-93 (パイプライン図), SPEC.md:110-117 (Step 02 記述), SPEC.md:125-129 (Step 04 記述)
- **前回対応状況**: 新規
- **内容**:
  SPEC.md §2.1 のパイプライン図 (lines 59-93) は以下のフローを示す:

  ```
  build_narrative.sh → 様式1-2,1-3.docx
  ```

  inject_narrative.py による統合ステップが存在しない。同様に:
  - §2.2 Step 02 記述 (lines 113-116): `fill_forms.py`, `fill_security.py`, `build_narrative.sh` の3スクリプトのみ。`inject_narrative.py` への言及なし
  - §2.2 Step 04 記述 (lines 125-129): narrative docx が中間ファイルである旨の記載なし

  SPEC.md は設計文書として実装の全体像を示す役割を持つ。inject_narrative.py はパイプラインの中核的な新規ステップであり、記載がないことは仕様書としての網羅性を欠く。

- **影響**: SPEC.md を参照する新規参加者やレビュアーがパイプラインの全体像を正しく把握できない
- **推奨対応**:
  1. パイプライン図に inject ステップを追加
  2. Step 02 記述に `inject_narrative.py` を追加
  3. Step 04 記述で narrative docx が中間ファイルとして除外される旨を追記

---

### [C7-05] (Major) Prompt 9-4 の「Word修復ダイアログなし」検証に Linux 代替手段が未記載

- **箇所**: docs/prompts.md:644
- **前回対応状況**: 新規
- **内容**:
  Prompt 9-4 の検証項目3 (line 644) に「修復ダイアログが表示されないこと（表示された場合はOOXML構造に問題あり）」とあるが、この検証は **Windows + Microsoft Word** 環境でしか実行できない。

  ビルド・テストの主環境は Linux (Docker) であり、Prompt 9-4 の最初の実行は Linux 上で行われる可能性が高い。Word が利用できない環境での OOXML 構造健全性の代替検証手段が記述されていない。

  利用可能な代替手段:
  - `python-docx` での再読み込み成功確認 (Prompt 9-2 line 517 で言及はあるが Prompt 9-4 には未反映)
  - `zipfile` での ZIP 整合性チェック
  - LibreOffice での開閉テスト (`libreoffice --headless --convert-to pdf`)
  - OOXML バリデータ (例: `python-pptx` の `opc` モジュール、OOXMLValidator)

- **影響**: Linux 上での統合テスト実施時に OOXML 構造問題を検出できず、Windows テストまで問題が先送りされる
- **推奨対応**: Prompt 9-4 に Linux 環境での代替検証手段を追加（最低限: python-docx 再読み込み + LibreOffice 変換テスト）

---

### [C7-06] (Major) pyproject.toml 未作成（5回連続指摘）

- **箇所**: プロジェクトルート
- **前回対応状況**: report6.md [C6-15] 未対応 ← report5 [C5-10] ← report4 [C4-14] ← report3 [C3-11]
- **内容**: `RUNNER=uv` モードで `uv run` を使用する場合に必要な `pyproject.toml` が存在しない。Docker がデフォルト RUNNER であるため直接の実害は少ないが、5回連続の指摘となる。
- **影響**: uv 実行モードが使用不可。開発時の迅速な反復テストに uv が使えない
- **推奨対応**: 作成する（依存: python-docx, openpyxl, pyyaml のみ）か、RUNNER=uv サポートを SPEC.md で明示的に非対応と宣言する

---

### [C7-07] (Minor) README.md の研究テーマが未更新

- **箇所**: README.md:8
- **前回対応状況**: report6.md [C6-14] 対応済みとされたが不十分（CLAUDE.md, SPEC.md, prompts.md は更新済み、README.md が漏れ）
- **内容**:
  README.md line 8:
  ```
  - **研究テーマ**: (23) 医療・医工学に関する基礎研究
  ```
  CLAUDE.md (line 9) と SPEC.md (line 8) は「サイバー攻撃×地域医療シミュレーション」に更新済みだが、README.md には新テーマの具体的な記述がない。
- **影響**: GitHub上でプロジェクトを閲覧する共同研究者に旧テーマの印象を与える
- **推奨対応**: README.md line 8 を「(23) 医療・医工学に関する基礎研究（サイバー攻撃×地域医療シミュレーション）」に更新

---

### [C7-08] (Minor) DocxTable(new_tbl, doc) — 非標準コンストラクタ使用

- **箇所**: main/step02_docx/fill_forms.py:894
- **前回対応状況**: 新規
- **内容**:
  C6-03 修正で様式4-2テーブルの複製時に:
  ```python
  from docx.table import Table as DocxTable
  ...
  wrapped = DocxTable(new_tbl, doc)
  ```
  `Table.__init__(self, tbl, parent)` の `parent` 引数に `Document` オブジェクトを渡している。python-docx の内部 API では `parent` は通常 `BlockItemContainer`（body等）であり、`Document` オブジェクトは想定されていない。

  **現状での動作**: `Table.part` プロパティが `self._parent.part` を参照するため、`doc.part` が存在する `Document` オブジェクトでもアクセスは成功する。`fill_4()` 内で使用される `set_cell()` 等の操作は `Table.cell()` 経由であり、`parent` への依存は限定的。

  **リスク**: python-docx のバージョンアップで `parent` の型チェックが追加された場合や、`fill_4()` 内で `parent` を `BlockItemContainer` として使用する操作が追加された場合に破綻する。
- **影響**: 現時点では動作するが、将来の保守性に懸念
- **推奨対応**: `DocxTable(new_tbl, doc.element.body)` に変更するか、コメントで非標準使用であることを明記

---

### [C7-09] (Minor) step4plan.md B-1 が footnotes.xml / endnotes.xml を 5パーツリストに含まない

- **箇所**: docs/step4plan.md:99-128
- **前回対応状況**: 新規
- **内容**:
  step4plan.md B-1 は「5つのZIPパーツ」を列挙するが、`word/footnotes.xml` および `word/endnotes.xml` が含まれていない。Prompt 9-2 のエッジケースセクション (line 551) では脚注マージへの言及があるが、step4plan.md の仕様には反映されていない。

  youshiki1_2.md の現在の内容には脚注構文 (`[^1]`) は確認されなかったため、**現時点では実害なし**。ただし、今後の執筆で脚注が追加された場合に備え、仕様を網羅的にしておくべき。
- **影響**: 脚注を含むナラティブを挿入した場合に脚注参照が破損する（現時点ではリスク低）
- **推奨対応**: B-1 に「6. word/footnotes.xml / word/endnotes.xml（存在する場合のみ）」を追記するか、「脚注は使用しない」制約を明記

---

### [C7-10] (Minor) Prompt 9-1 に Docker 実行指示が明示されていない

- **箇所**: docs/prompts.md:405-465 (Prompt 9-1)
- **前回対応状況**: 新規
- **内容**:
  Prompt 9-1 はテンプレートおよび Pandoc 出力の構造解析を指示するが、解析スクリプトの実行環境（Docker, uv, direct）に関する指示がない。解析には python-docx または ElementTree を使用する Python コードの実行が必要であり、プロジェクトの方針（CLAUDE.md: 「ホストPythonを汚さない」）に従うには Docker 経由での実行が前提となる。

  step4plan.md Step C (line 193) には `docker compose ... run --rm python` の具体的なコマンドが記載されているが、Prompt 9-1 にはない。
- **影響**: 実装者がホスト環境で直接 Python を実行してしまう可能性（軽微）
- **推奨対応**: Prompt 9-1 に「Docker 環境で実行すること（build.sh と同じ RUNNER 方式）」の一文を追加

---

### [N7-01] (Note) YAML メタデータが大幅に未完成

- **箇所**: main/00_setup/researchers.yaml, main/00_setup/other_funding.yaml, main/00_setup/security.yaml
- **前回対応状況**: 新規（report6 のスコープ外だったため未検出）
- **内容**:

  | ファイル | 推定完成度 | 主な未記入項目 |
  |---------|-----------|-------------|
  | researchers.yaml | ~35% | e-Rad研究者ID（全員）、生年月日（全員）、学歴・職歴詳細、研究資金実績、業績リスト、3人目の共同研究者が「人選未定」 |
  | other_funding.yaml | ~10% | 全エントリが○○プレースホルダ。PI・co-I全員の他制度応募状況が未記入 |
  | security.yaml | ~45% | 各研究者の学歴・職歴・資金実績・業績が「要記入」マーク。3人目の共同研究者が全フィールドプレースホルダ |
  | config.yaml | ~98% | 決裁者名（○○ ○○）、決裁者肩書（○○○○）、設備ベンダー名、メールアドレス |

  これらのプレースホルダは Step 9 実装をブロックしないが、提出期限（2026-05-20）までに全記入が必要。特に e-Rad 研究者番号は本人以外が把握していない情報であり、収集に時間を要する。

- **影響**: Step 9 実装には影響なし。提出準備のボトルネックとなる可能性
- **推奨対応**: 各共同研究者にメタデータ記入を依頼するタスクを早期に開始。3人目の共同研究者の人選を確定させる

---

### [N7-02] (Note) youshiki1_2.md に「○○教授」等のプレースホルダが残存

- **箇所**: main/step01_narrative/youshiki1_2.md:132, 179, 198, 300, 369
- **前回対応状況**: 新規
- **内容**: 研究計画本文中に共同研究者名のプレースホルダ「○○教授」「○○ ○○」が5箇所残存。3人目の共同研究者が未確定のため記載できない状態。また line 392 に「ここに概要図を配置」の指示注記がある。
- **影響**: Step 9 実装には影響なし。提出前に確定・記入が必要
- **推奨対応**: 3人目の共同研究者確定後に一括置換

---

### [N7-03] (Note) 参考様式（承諾書）の記入が best-effort のまま

- **箇所**: main/step02_docx/fill_forms.py:659-692 (fill_consent_forms)
- **前回対応状況**: report6.md [N6-04] 残存
- **内容**: `fill_consent_forms` は「R8～R」→「R8～R10」のパターン置換のみ。機関名、学部長名等のプレースホルダは手動記入前提。report6 で指摘済みだが、手動記入ワークフローのドキュメント化も未実施。
- **推奨対応**: 手動記入が前提であることを create_package.sh のチェックリストに明記

---

### [N7-04] (Note) step4plan.md B-3 のスタイルマッピングが「推奨アプローチ」表現

- **箇所**: docs/step4plan.md:149
- **前回対応状況**: 新規
- **内容**:
  B-3 (line 149): 「**推奨アプローチ**: テンプレートの word/styles.xml にPandocスタイル定義を追加する。」

  「推奨」という表現は実装者に選択の余地を与えるが、styles.xml マージなしでは書式崩壊が確定する (C7-01 参照)。これは推奨ではなく**必須**である。
- **影響**: 実装者が「推奨」を読み飛ばし、スタイル処理を後回しにするリスク
- **推奨対応**: 「推奨アプローチ」を「必須: 」に変更

---

## Step 9 実装準備状況の総合評価

### 設計文書の充足度

**評価: B — 概ね十分だが、実装チェックリストに漏れがある**

step4plan.md は report6 の指摘を受けて大幅に拡充され、B-1〜B-4 の技術仕様は実装に着手可能なレベルに達している。特に:
- ZIPレベルマージの5パーツ処理 (B-1) は各パーツの処理手順が明確
- セクションブレーク保護ポリシー (B-2) は fill_forms.py の既存パターンと一貫
- ルートタグ保存 (B-4) は jami-abstract-pandoc の実コードとの対応が正確（lines 398-470 を実際に検証済み）
- フォールバック計画は方式比較表とピボット基準が具体的

**残存する問題**:
- styles.xml マージが B-1 のパーツリストに含まれず、B-3 の「推奨アプローチ」に留まる (C7-01)
- footnotes.xml/endnotes.xml が B-1 に含まれない (C7-09)
- jami-abstract-pandoc のパターン参照テーブルは正確だが、文書間コピーの新規実装部分の設計指針が概念レベル（具体的なアルゴリズム記述ではない）

### プロンプトの実装可能性

**評価: B- — AIに渡せるが、styles.xml 漏れで1回は手戻りが発生する**

Prompt 9-1〜9-4 は report6 の指摘を受けて改善され、構造は明確。特に:
- Prompt 9-1: テンプレート・Pandoc出力の両方の解析を指示 (C6-09 対応済み)
- Prompt 9-2: stdlib方式への一本化、jami参照テーブル（行番号付き）、エッジケース6項目が充実
- Prompt 9-3: ダミーnarrative必須化、generate_stubs.py更新指示あり
- Prompt 9-4: 5検証項目追加

**残存する問題**:
- Prompt 9-2 の実装チェックリスト (5項目) に styles.xml が欠落 (C7-01) — これが最大の問題
- Prompt 9-4 に Linux 代替検証手段がない (C7-05)
- Prompt 9-1 に Docker 実行指示がない (C7-10) — 軽微
- Prompt 9-3 の generate_stubs.py 更新指示は「見出し1つ、本文1つ、テーブル1つ」と最低要件は明記されているが、どの関数に追加するか等のコードレベルの指示はない

### ビルドパイプラインの安定性

**評価: A- — 現行パイプラインは安定。inject 未実装は期待どおり**

- validate/forms/narrative/security/excel の全ステップが E2E テスト (dummy data) で通過確認済み
- build.sh に inject サブコマンドは未実装だが、step4plan.md Step C に具体的な `phase_inject()` 関数定義が記述されており、実装は容易
- create_package.sh の変更 (narrative docx 除外) も step4plan.md Step D に明記
- watch-and-convert.ps1 はファイルサイズの制約なく動作するため、inject 後の統合 docx（サイズ増大）にも対応可能

**懸念点**:
- C6-02/C6-03 の修正は dummy data (co-I=1) でのみテスト済み。本番データ (co-I=3) での検証が未実施 (C7-03)
- SPEC.md のパイプライン記述が最新状態を反映していない (C7-04)

### 提出期限までのスケジュールリスク

**評価: 要注意 — 技術的作業は間に合うが、メタデータ収集がボトルネック**

**残り45日（2026-04-05 → 2026-05-20）のタスク内訳**:

| タスク | 見積り | 依存 | リスク |
|--------|--------|------|--------|
| Step 9 実装 (inject_narrative.py) | 10-15h (step4plan.md見積り) | 設計文書の修正 (C7-01等) | OOXML操作の技術的不確実性。フォールバック (Windows COM) で緩和可能 |
| youshiki1_2.md ○○プレースホルダ記入 | 1h | 3人目 co-I 確定 | 人選未定が解消しないと記入不可 |
| youshiki1_2.md 概要図のグラフィカル化 | 2-4h | 本文確定後 | 図のクオリティ次第 |
| researchers.yaml 完成 (~65%分) | 8-16h | **各研究者本人の情報提供** | e-Rad番号・業績リスト等は本人しか持っていない。依頼→回収のリードタイムが最大リスク |
| other_funding.yaml 完成 (~90%分) | 4-8h | **各研究者本人の確認** | 他制度応募状況は本人確認が必須 |
| security.yaml 完成 (~55%分) | 4-8h | researchers.yaml と共通部分あり | |
| config.yaml 残り (~2%分) | 1h | 決裁者・ベンダー情報 | |
| 本番ビルド→Windows PDF変換→最終確認 | 4-8h | 全タスク完了後 | Windows環境でのWord修復ダイアログチェック含む |
| e-Rad登録・提出作業 | 2-4h | PDF完成後 | e-Rad操作の習熟度に依存 |

**クリティカルパス**: researchers.yaml / other_funding.yaml の情報収集（外部依存）→ 本番ビルド → PDF確認 → e-Rad提出

**Step 9 フォールバック時のスケジュール影響**:
- OOXML挿入 → Windows COM ピボット: +3-5日（VBScript InsertFile実装）
- OOXML挿入 → PDF結合 ピボット: +1-2日（pypdf結合は単純だが、ページ番号非連続の対処が必要）
- いずれのフォールバックも提出期限内に収まるが、本番テスト期間が短縮される

**最大リスク**: 技術的作業（Step 9 + ビルド）は 45日で十分完了可能。しかし、YAML メタデータの情報収集は外部（共同研究者）への依存があり、コントロール困難。特に「人選未定」の3人目の共同研究者が確定しない場合、researchers.yaml / security.yaml / youshiki1_2.md のいずれも完成しない。**早急にメタデータ収集を開始すべき。**

---

## リスクマトリクス

| リスク | 影響度 | 発生確率 | 総合評価 | 対策 |
|--------|--------|---------|---------|------|
| R1: styles.xml 未マージで書式崩壊 | 高 | 高（Prompt 9-2 に記載なし） | **Critical** | C7-01: Prompt 9-2 / step4plan.md B-1 に明記 |
| R2: 本番 co-I=3 で行追加/テーブル複製が壊れる | 高 | 中（コードロジックは正しいが未テスト） | **Major** | C7-03: ダミーデータの co-I を増やして E2E 実行 |
| R3: OOXML挿入が1週間で安定しない | 高 | 中 | **Major** | フォールバック計画策定済み（Windows COM → PDF結合） |
| R4: 共同研究者メタデータ収集遅延 | 高 | 高（外部依存） | **Major** | 早急にメタデータ記入を依頼。依頼テンプレート作成 |
| R5: Linux上でOOXML構造問題を検出できない | 中 | 高（Linux代替検証手段なし） | **Major** | C7-05: Prompt 9-4 に LibreOffice 変換テスト追加 |
| R6: 3人目 co-I 未確定で書類不完全 | 高 | 中（現時点で「人選未定」） | **Major** | 人選確定の期限設定（遅くとも4月中旬） |
| R7: SPEC.md の旧記述で実装者が混乱 | 中 | 低（step4plan.md を参照すれば問題なし） | **Minor** | C7-02, C7-04: SPEC.md を更新 |
| R8: pyproject.toml 不在で uv 開発不可 | 低 | 確定 | **Minor** | C7-06: 作成 or 非対応宣言 |
