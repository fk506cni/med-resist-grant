# セッション開始プロンプト: 敵対的レビュー（第14回）— Prompt 10-5 成果物と M14-01 修正の健全性

以下の指示に従い、**Prompt 10-5（inject 連携と E2E 検証）の成果物および同セッションで
検出・修正した `wrap_textbox.py` の M14-01 namespace バグ**について敵対的レビューを
行ってください。レビュー結果は `docs/report14.md` に出力してください。

## レビュー方針

- **実装を開始しないでください。** レビューと指摘のみを行います。
- **研究計画書の論旨・学術的妥当性はレビュー対象外です。**
  ただし Markdown 構文・画像参照・YAML front-matter・`.textbox` Div 記述など
  パイプラインに影響する形式的要素は対象に含みます。
- **焦点は「Prompt 10-5 成果物と M14-01 修正の健全性」です。** 次の 6 領域を
  重点的に検証してください:
  - 領域 A: M14-01（wrap_textbox.py の `ET.SubElement` fully-qualified name 修正）
  - 領域 B: Prompt 10-5 の E2E 検証結果とその限界
  - 領域 C: SVG ベクタ保持の未達（Windows Word PDF 出力での asvg:svgBlob 無視）
  - 領域 D: Prompt 10-5 完了チェックの未達項目の扱い
  - 領域 E: 提出前健全性の総点検（report13 未対応項目のフォロー）
  - 領域 F: inject 再実行の非冪等性（新規観察事項）
- **敵対的に検証してください。** 「うまくいきそう」ではなく「どこで壊れるか」を探してください。
  特に以下の観点を重視:
  - **M14-01 修正**の副作用（同じ `ET.register_namespace` 相互上書き問題が他の XML 操作
    部位で潜在していないか、inject_narrative.py の `merge_rels` / `copy_media` /
    `merge_content_types` に似た経路はないか、将来の lxml 移行時に挙動が変わらないか）
  - **Windows Word COM 依存**（watch-and-convert.ps1 の `SaveAs2 17` が primary PNG blip を
    使用し asvg:svgBlob を参照しない事実、それにより SVG がラスタ化されテキストが
    selectable にならない事実）
  - **inject 再実行の非冪等性**（今回実地で観察された、`forms` を経由せずに `inject` を
    単独再実行すると rels が 4 件→7 件に増え `_n1` 付き媒体が生成される現象）
  - **report13 の残課題**（M13-02 / N13-01 / N13-03 / N13-05 / N13-06 / N13-09 / N13-10 /
    N13-11 / I13-01〜04）の現状変化
  - **完了チェック未達の扱い**（prompts.md Prompt 10-5 の「Windows Word PDF で図が
    ベクタ表示される」要件を満たせない事実をどう扱うか、提出時の実害評価）
- **`docs/__archives/report13.md` を読まずに**独立してレビューを行い、レポート作成時に
  `report13.md` と突き合わせて所見を統合してください。
- レビュー結果は `docs/report14.md` に、重大度（Critical / Major / Minor / Info）付きで
  出力してください。
- 前回レビューとの差分（新規発見 / 既知だが未対応 / 前回から改善済み）を明示してください。

## 前回（`docs/__archives/report13.md`）からの主な変化

Prompt 10-5 完了に伴い以下の変更・観察を実施しました。

### M14-01 修正: `wrap_textbox.py` の namespace バグ

**根本原因**: `embed_svg_native` が以下の順序で Python ElementTree を呼んでいた:

```python
ET.register_namespace("", RELS_NS)      # L502
rels_root = ET.fromstring(parts[rels_path])
...
ET.register_namespace("", CT_NS)        # L517  ← RELS_NS の "" 登録を上書き
ct_root = ET.fromstring(parts["[Content_Types].xml"])
...
for ...:
    rel_el = ET.SubElement(rels_root, "Relationship")   # L587  名前空間なしで追加
    ...
rels_buf = BytesIO(); ET.ElementTree(rels_root).write(...)   # L617
```

`ET.register_namespace("", URI)` は `_namespace_map` 内で「そのプロセス唯一の default
xmlns」として扱われるため、後発の `("", CT_NS)` 呼び出しが先発の `("", RELS_NS)` を
上書きする。そのため rels を最終 serialize した時点で RELS_NS の default prefix 指定は
失効しており、ET は自動生成した `ns0:` prefix で既存要素を出力するが、**空 tag で
作成された新規 `<Relationship>` は RELS_NS namespace URI を持たないため bare `<Relationship>`
として出力される**。結果、`<ns0:Relationships>` ルート配下に namespace が異なる兄弟
要素ができ、Windows Word COM（`SaveAs2`）が narrative docx を「ファイルが壊れている
可能性があります」と判定して OPEN_ERROR を出す。

**修正内容**: `main/step02_docx/wrap_textbox.py` L587 と L611 の `ET.SubElement` 呼び出しを
fully-qualified name 版へ変更:

```python
# 修正前
rel_el = ET.SubElement(rels_root, "Relationship")
ct_default = ET.SubElement(ct_root, "Default")

# 修正後
rel_el = ET.SubElement(rels_root, f"{{{RELS_NS}}}Relationship")
ct_default = ET.SubElement(ct_root, f"{{{CT_NS}}}Default")
```

これにより、ET は新規要素を対応する namespace URI 付きで作成し、serialize 時に prefix
付きで emit される。既存要素と整合した `<ns0:Relationship>` として出力される。

**検証**: clean build → narrative docx を unzip → `word/_rels/document.xml.rels` の
全 11 Relationship が `<ns0:Relationship>` で統一されていることを確認。

### Prompt 10-5 実施結果

以下の検証項目を順次実施し、結果を取得した:

| 検証項目 | 結果 |
|---------|------|
| `./scripts/build.sh` フルビルド | 全 6 ステップ ✓ OK（validate / forms / narrative / inject / security / excel） |
| inject 後の `youshiki1_5_filled.docx` OOXML 構造 | `wp:anchor`×2, `a:blip`×2, `asvg:svgBlob`×1、`<Default Extension="svg">` あり、media に `rId23.jpg` / `rId30.png` / `svg1.svg` |
| primary blip / svgBlob 二段構成 | blip#1: rId12→media/rId23.jpg (JPG)、blip#2: rId13→media/rId30.png (PNG primary) + svgBlob rId14→media/svg1.svg (SVG) |
| docPr@id ユニーク性 | 通常ビルド 4/4 unique（24, 31 template + 3000, 3001 1-2）、1-2+1-3 両方に図の特別テストで 6/6 unique（+4000 for 1-3） |
| LibreOffice PDF 化（早期失敗検知） | 47 ページ生成、pdfimages で 2 raster、pdftotext でキャプション visible |
| ページ数（Word 実測） | 様式1-2 = pages 3-10 = 8 ページ（≤ 15） |
| docx サイズ | 158 KB（<< 3 MB 目標、<< 10 MB 制約） |
| 非破壊性 | デモ .textbox 削除で `DATA_DIR=data/dummy ./scripts/build.sh` 通過、wp:anchor / asvg:svgBlob ともに 0 件。復元後に再現性確認済み |
| roundtrip.sh 経由 Windows Word PDF | M14-01 修正後に 8/8 ファイル成功、`youshiki1_5_filled.pdf` 1.3 MB、29 ページ |
| SVG ベクタ表示 | **未達**: Word 365 `SaveAs2 wdFormatPDF` は primary PNG blip を使用。PDF 内 fig1_overview.svg は 943×136 ラスタ（204 ppi）、テキスト not selectable |

### 修正前に発生した Windows Word OPEN_ERROR の実ログ

```
[2026-04-17 19:22:19] [INFO] Processing: youshiki1_2_narrative.docx
[2026-04-17 19:22:20] [INFO] Converting via cscript (VBScript)...
[2026-04-17 19:22:24] [INFO] [DEBUG] cscript exited with code 1 in 4047ms
[2026-04-17 19:22:24] [WARN] [DEBUG] stderr: OPEN_ERROR: ファイルが壊れている可能性があります。
[2026-04-17 19:22:24] [ERROR] VBScript conversion failed (exit code: 1)
```

M14-01 修正後は同じ narrative docx が正常に開け、PDF 化できることを確認。

### 発見した副次的挙動（新規観察事項）

- **inject 再実行の非冪等性**: `./scripts/build.sh inject` を単独で再実行した場合、
  `scripts/build.sh:160-197` では `--template` と `--output` がいずれも
  `main/step02_docx/output/youshiki1_5_filled.docx` を指すため、**すでに inject 済みの
  filled docx に対して narrative をさらに重ね merge する非対称挙動**になる。
  1-2+1-3 両方に図を追加した状態で実地検証したところ:
  - rels が 4 件 → 7 件（`rId12-14` が orphan、blip が参照するのは `rId15-17` + `rId18`）
  - media に `_n1` 付き重複ファイル生成（`rId23_n1.jpg` 等）
  - docPr@id のユニーク性は維持（6/6 unique）
  - clean build（`./scripts/build.sh clean` → `./scripts/build.sh`）では問題なし
- **LibreOffice が narrative docx 単体を開けない現象**: 本 M14-01 修正後も再現。
  filled docx（inject 後）は LO で開けるため、narrative docx 中間成果物特有の問題
  （reference.docx スタイル継承の未完全？ pandoc の fragment docx 扱い？）。
  本セッションでは原因追及せず。

### 残存する懸念事項

1. **SVG ベクタ保持が未達**: prompts.md Prompt 10-5 完了チェックの「roundtrip.sh 経由の
   Windows Word PDF で図がベクタ表示される」は達成できていない。Word 365 の SaveAs2 が
   primary PNG blip を優先する仕様であり、`watch-and-convert.ps1` を
   `ExportAsFixedFormat` ベースへ書き換えない限り解決しない。
2. **inject 再実行の非冪等性**: ワークフロー制約（`forms` を必ず先に実行）で回避可能だが、
   `./scripts/build.sh inject` 単独再実行に対するガード未整備。

## レビュー対象

### 領域 A: M14-01（wrap_textbox.py 名前空間修正）の健全性

具体的に検証してほしい観点:

- **修正箇所の正当性**
  - `ET.SubElement(rels_root, f"{{{RELS_NS}}}Relationship")` は ElementTree の Clark
    notation。これで作成した要素が serialize 時に確実に `ns0:` prefix で emit されるか。
  - `ET.SubElement(ct_root, f"{{{CT_NS}}}Default")` も同様。既存の `<Default>` は
    `<Types xmlns="CT_NS">` デフォルト名前空間の下に置かれるため bare で書かれていたが、
    fully-qualified 化しても同じ結果になるか。
  - 修正箇所のコメント M14-01 の記述が根本原因を正しく説明しているか、将来の読者が
    「なぜこの書き方を強制されるのか」を理解できるか。

- **同プロセス内の他 XML 操作との相互作用**
  - `inject_narrative.py` の `merge_rels` / `copy_media` / `merge_content_types` は
    ET.SubElement をどう呼んでいるか。同じ落とし穴はないか（line 319, 611 など既に
    clean だが潜在 bug として振る舞う可能性）。
  - `fix_reference_styles.py` / `fill_forms.py` / `fill_security.py` / `fill_excel.py`
    で同種の `ET.SubElement(root, "tag")` 記法を使っていないか。
  - 今後 XML 操作を追加する開発者が同じバグを再導入しないためのセーフティネットを
    設けるべきか（lint rule、helper 関数、lxml 切替）。

- **`ET.register_namespace` のグローバル副作用**
  - `wrap_textbox.py` / `inject_narrative.py` がそれぞれ独立プロセスで走っている間は
    問題ないが、将来統合された場合の挙動は？
  - report13 N13-10 の「グローバル副作用」指摘は本修正で解消されたか？ むしろ悪化したか？

### 領域 B: Prompt 10-5 の E2E 検証結果とその限界

具体的に検証してほしい観点:

- **roundtrip.sh 実行の再現性**
  - 初回実行時に `timeout 15 rclone lsf` が exit 124 で失敗した経路（`scripts/roundtrip.sh:132`）。
    retry で成功したが、`rclone lsf` の 15 秒 timeout は妥当か。Google Drive の応答遅延が
    常態化した場合、roundtrip 全体が通らなくなる。
  - Windows Word watch-and-convert.ps1 の処理途中で polling が `0 / 8` → `7 / 8` →
    `0 / 8` → `7 / 8` と振動している。Google Drive の eventual consistency か、
    rclone lsf のキャッシュ挙動か。

- **LibreOffice が narrative docx を開けない原因の深掘り**
  - filled docx は LO で開けるので、inject 時に補完されている何かが narrative docx に
    欠けている。candidate:
    - `mc:Ignorable` の `wps` flag（report13 M13-01 対応で restore_root_tag に追加済み）が
      narrative docx には反映されていない可能性
    - styles.xml / numbering.xml が不完全
    - header1.xml / footer1.xml の欠如
  - これが e-Rad 提出に影響するか（narrative docx は中間成果物で提出対象外のため、影響なし）。

- **Prompt 10-5 完了チェックの実地結果**
  - 完了チェック 8 項目中、7 項目は明示的に達成。「roundtrip.sh 経由の Windows Word PDF で
    図がベクタ表示される」のみ未達。この事実を report14 でどう位置づけるか
    （Critical / Major / Minor / Info のどれか）。

### 領域 C: SVG ベクタ保持の未達

具体的に検証してほしい観点:

- **Word 365 の PDF 出力挙動の検証**
  - `SaveAs2 wdFormatPDF`（17）は docx 内の primary blip（`a:blip/@r:embed`）を PDF に
    embedded raster として書き出す。asvg:svgBlob は Word UI 上では SVG をレンダリングするが、
    PDF export には反映されない。
  - 代替: `ExportAsFixedFormat` + `OptimizeFor=wdExportOptimizeForPrint` + `UseISO19005_1=True` で
    SVG をベクタとして保持できるかは不確実。
  - 別案: Word の `Application.Options.ExportPictureGraphicsOption` を切り替える。

- **submitted PDF の品質への影響**
  - 943×136 ラスタ（204 ppi）= 約 12 cm × 2 cm のサイズで PDF に配置される。
    A4 紙印刷時は **良好に見える**（204 ppi は印刷標準の 200-300 ppi 下限を満たす）。
  - テキストが selectable でない点は審査・OCR で実害があるか。
    e-Rad 提出 PDF は審査員が目視評価する形式で、OCR による自動処理を前提としないため
    実害は低い。
  - 本 Prompt の要件「ベクタ図として表示される」を字義通り満たしていないが、
    提出品質として受容できるかは判断事項。

- **改修コストの見積もり**
  - `watch-and-convert.ps1` の VBScript 部分（`doc.SaveAs2`）を `doc.ExportAsFixedFormat`
    ベースに書き換える作業量。
  - 本質的にはテキストボックス内の画像レンダリングを Word に委ねているので、Word が
    svgBlob を PDF に書き出す方法を持たない限り、根本解決は難しい。

### 領域 D: Prompt 10-5 完了チェックの扱い

具体的に検証してほしい観点:

- `prompts.md` Prompt 10-5 完了チェックの 8 項目を全件点検し、各項目の達成状況を
  第三者の視点で評価してほしい:
  - [x] フルビルドで図が運搬 — 要確認
  - [x] a:blip→PNG、asvg:svgBlob→SVG の二段構成 — 要確認
  - [x] wp:docPr/@id 全件ユニーク — 要確認
  - [x] LibreOffice PDF 化で画像視認可能 — 要確認
  - [ ] **roundtrip.sh 経由の Windows Word PDF で図がベクタ表示**（本番判定）— **未達**
  - [x] Content_Types / rels / media の正しい更新 — 要確認
  - [x] 様式1-2 が 15 ページ以内 — Word 実測 8 ページ
  - [x] デモを外した E2E 通過 — 要確認
- 「ベクタ表示」を諦めて「ラスタで提出品質として OK」と割り切る場合、
  prompts.md の完了チェックの該当項目を編集すべきか（それとも「ラスタ代替で了承」の
  注記を加えるか）。

### 領域 E: 提出前健全性の総点検（report13 未対応項目のフォロー）

以下の report13 未対応項目について、現状の変化を検証してほしい:

- **M13-02**（mc:AlternateContent 未使用）: Word 2010+ 前提として許容している。
  実地 Windows Word PDF 生成で問題が出ていないので正当性は担保されるが、e-Rad 側の
  処理系が Word 2007 互換で読み込むケースはあるか。
- **N13-01**（rels prefix 混在）: 本セッションの M14-01 で **解消された**はず。
  実地 narrative rels を unzip して全件 `<ns0:Relationship>` になっていることを
  レビューで二次確認してほしい。
- **N13-03**（--resource-path の cwd 依存）: 未対応。build_narrative.sh の cwd が
  `PROJECT_ROOT` に強制される前提で動作しており、現状リスクなし。
- **N13-05**（reference.docx 冪等性）: 未対応。CI 未導入のため現実問題なし。
- **N13-06**（copy_media rename の命名規約非対称）: 未対応。今回 inject 再実行時に
  実際に `_n1` 付き rename が観察された（領域 F）。dormant ではなくなった。
- **N13-09**（comments.xml 破棄）: 未対応。現状 pandoc comments.xml は空で dormant。
- **N13-10**（register_namespace グローバル副作用）: M14-01 で顕在化し fix したが、
  根本的な mitigation（lxml 移行等）は未対応。
- **N13-11**（.textbox 内 figure caption の配置）: Windows Word PDF で検証可能になった。
  実地 PDF を見てキャプションの配置が期待通りか確認してほしい。
- **I13-01**〜**I13-04**: 現状変化なし。

### 領域 F: inject 再実行の非冪等性（新規観察事項）

具体的に検証してほしい観点:

- **`scripts/build.sh:188-192` の inject 呼び出し**
  - `--template` と `--output` が同じファイル `main/step02_docx/output/youshiki1_5_filled.docx` を
    指している。forms ステップがこのファイルを生成し、inject が上書きする前提。
  - この前提が成り立たない経路:
    - `./scripts/build.sh inject` を単独実行した場合（forms をスキップ）
    - forms が失敗したまま inject を再実行した場合
    - 手動で filled docx を触った後に inject を再実行した場合
  - 現状、単独再実行時にガード（input が既に inject 済みかの検査）がない。

- **実地再現した挙動**
  - 本セッションで `./scripts/build.sh narrative && ./scripts/build.sh inject` を実行した
    ところ、narrative の前に forms が回らなかったため、**すでに injected 済みの filled
    docx に対して narrative を再度 merge**する経路に入った。結果:
    - rels 4 件 → 7 件（orphan 3 件）
    - media に `_n1` 付き重複ファイル
    - 最終 docx 内の blip は新しい rId を参照するので、見た目は壊れていない（docPr@id も
      ユニーク）
    - ただし、unused rels / media が肥大化する副作用あり
  - clean build（`./scripts/build.sh clean && ./scripts/build.sh`）では問題なし。

- **推奨される対策の方向性**
  - inject 呼び出し時に `--template` が `data/source/r08youshiki1_5.docx` の forms-filled 状態か、
    既に inject 済みかを判定するガード。
  - もしくは `scripts/build.sh` の `inject` サブコマンドが常に先に `forms` を実行する
    ように依存関係を宣言。
  - report でどのアプローチが妥当かの論点を整理してほしい。

## 参照すべき資料

| ファイル | 確認ポイント |
|---------|------------|
| `main/step02_docx/wrap_textbox.py`（M14-01 修正後） | L585-601 の rels Relationship 追加（fully-qualified name）、L604-616 の CT Default 追加、NSMAP 定義、`embed_svg_native` 全体フロー |
| `main/step02_docx/inject_narrative.py` | `merge_rels` / `copy_media` / `merge_content_types` / `merge_numbering` / `merge_styles` / `merge_footnotes` / `merge_endnotes` の冪等性、特に inject を 2 回実行した場合の rels / media 累積挙動（L924-933 の merge_rels / copy_media 呼び出し） |
| `scripts/build.sh` inject 関数（L158-198） | `--template` と `--output` が同一パスであること、forms との実行順序依存性 |
| `scripts/roundtrip.sh` | Phase 3 push → Phase 4 polling の挙動、`rclone lsf` timeout 15s、PDF 検出 polling の振動 |
| `scripts/windows/watch-and-convert.ps1` | `doc.SaveAs2 "...", 17`（wdFormatPDF）の仕様、`ExportAsFixedFormat` 代替の可否、VBScript 呼び出しチェーン |
| `main/step02_docx/output/youshiki1_5_filled.docx`（最新 clean build 結果） | rels / Content_Types / media の整合、docPr@id ユニーク性、wp:anchor / a:blip / asvg:svgBlob 数 |
| `main/step02_docx/output/youshiki1_2_narrative.docx`（M14-01 修正後） | rels 全件が `<ns0:Relationship>` で統一、`[Content_Types].xml` の Default/Override |
| `data/products/youshiki1_5_filled.pdf`（Windows Word COM 生成） | 29 ページ、Microsoft Word Producer、page 4 に raster 2 個（600×338 JPG + 943×136 PNG）、キャプション「病院施設の外観（デモ画像）」「医療需給動態モデルの処理フロー（概念図）」visible |
| `docs/__archives/report13.md` | **先に読まずに**独立レビュー後、レポート作成時の突合用 |
| `docs/prompts.md` Prompt 10-5 セクション | 完了チェックの 8 項目、特に「ベクタ表示される（本番判定）」の扱い |
| `docs/plan2.md` §9, §11, §12 | inject 連携設計、リスク表、primary blip / asvg 二段構成の設計根拠 |
| `CLAUDE.md` | プロジェクト制約（10MB 上限、15 ページ制限、host Python 不使用、data/source 改変不可） |

## 出力フォーマット

`docs/report14.md` に以下の形式で出力してください:

```markdown
# 敵対的レビュー報告書（第14回）— Prompt 10-5 成果物と M14-01 修正の健全性

レビュー実施日: YYYY-MM-DD
レビュー対象:
- `main/step02_docx/wrap_textbox.py`（M14-01 修正後）
- `main/step02_docx/inject_narrative.py`
- `scripts/build.sh`（inject 関数）
- `scripts/roundtrip.sh`
- `scripts/windows/watch-and-convert.ps1`
- `main/step02_docx/output/youshiki1_5_filled.docx`（clean build 結果）
- `main/step02_docx/output/youshiki1_2_narrative.docx`（M14-01 修正後）
- `data/products/youshiki1_5_filled.pdf`（Windows Word COM 生成）
- （参考）`docs/plan2.md` / `docs/prompts.md` / `docs/__archives/report13.md`

前回レビュー: `docs/__archives/report13.md`（2026-04-17、対応済み）

## サマリ

- Critical: N件 (新規N / 既知未対応N)
- Major: N件 (新規N / 既知未対応N)
- Minor: N件 (新規N / 既知未対応N)
- Info: N件

### 対応状況一覧

| ID | 重大度 | 状態 | 概要 |
|----|--------|------|------|
| C14-01 | Critical | ... | ... |
| ... | ... | ... | ... |

## report13.md との差分サマリ

- 前回の未対応項目で今回解消されたもの: N件
- 前回の未対応項目で依然として未対応のもの: N件
- 前回に記載がなく今回新規発見したもの: N件

## 指摘事項

### [C14-01] (Critical) タイトル
- **箇所**: ファイル名:行番号 or セクション名
- **前回対応状況**: 新規 / report13.md [C13-XX / M13-XX / N13-XX] 対応済み / 未対応
- **内容**: 具体的な問題の説明
- **影響**: この問題が放置された場合に起きること
- **推奨対応**: 修正方針

### [M14-01] (Major) ...
...

### [N14-01] (Minor) ...
...

### [I14-01] (Info) ...
...

## リスクマトリクス

| リスク | 影響度 | 発生確率 | 総合評価 | 対策 |
|--------|--------|---------|---------|------|
| ... | 高/中/低 | 高/中/低 | Critical/Major/Minor | ... |

## 総評

（Prompt 10-5 成果物の健全性評価、SVG ベクタ保持未達の扱い、
 Prompt 11（または最終提出前タスク）に進んでよいか、優先すべき対応順序）
```

### 重大度の基準

- **Critical**: 実装がブロックされる、または成果物に致命的欠陥が生じる
  （例: Windows Word が docx を開けない、inject 後に figs が欠落する、提出 docx が
  e-Rad に受理されない）
- **Major**: 実装に手戻りが発生する、または成果物の品質に重大な影響がある
  （例: 提出 PDF で図が期待通りに表示されない、inject 非冪等性で silent データ肥大）
- **Minor**: 修正すべきだが実装を進めながら対応可能
  （例: UX 改善、ログメッセージ不足、コメント不備、命名規約の非対称）
- **Info**: 改善推奨だが現状でも問題なく進められる
  （例: 将来の設計提案、仕様の備忘メモ）

### 命名規則

- 指摘 ID: `C14-NN` (Critical) / `M14-NN` (Major) / `N14-NN` (Minor) / `I14-NN` (Info)
- NN は 2 桁ゼロパディング（01, 02, ...）
- 本セッションで既に発見・修正済みの M14-01（wrap_textbox の namespace バグ）は
  既知 ID として扱い、report14 での新規番号は M14-02 以降から採番する。
