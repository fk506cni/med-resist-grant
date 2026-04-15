# セッション開始プロンプト: 敵対的レビュー（第11回）— Prompt 10-2 成果物

以下の指示に従い、**Prompt 10-2 で新規作成した 2 ファイル**
（`filters/textbox-minimal.lua` と `main/step02_docx/wrap_textbox.py`）について
敵対的レビューを行ってください。レビュー結果は `docs/report11.md` に出力してください。

## レビュー方針

- **実装を開始しないでください。** レビューと指摘のみを行います。
- **焦点は「Prompt 10-2 成果物（textbox-minimal.lua + wrap_textbox.py）の健全性」です。**
- **敵対的に検証してください。** 「うまくいきそう」ではなく「どこで壊れるか」を探してください。
- **`docs/__archives/report10.md` を読まずに**独立してレビューを行い、レポート作成時点で
  report10.md と突き合わせて所見を統合してください。
- レビュー結果は `docs/report11.md` に、重大度（Critical / Major / Minor / Info）付きで
  出力してください。
- 前回レビュー（report10）との差分（新規発見 / 既知だが未対応 / 前回から改善済み）を
  明示してください。Prompt 10-2 成果物は第10回時点で未実装だったため、原則として
  全件新規扱いとなる見込みですが、report10 の残課題（I10-03、および
  `embed_svg_native` への `<foreignObject>` 検出時安全装置メモ）との関連は明記すること。

## 前回（report10.md）からの主な変化

本セッションで **Prompt 10-2 を実装**し、以下を新規作成した。report10 の対応結果には
触れない（git log を参照）。

### 新規ファイル

1. **`filters/textbox-minimal.lua`**（94 行）
   - `next-gen-comp-paper/filters/jami-style.lua` から最小抽出
   - 保持: `to_emu()`, `textbox_marker()`, `process_textbox()`、および
     Pass 1（`.svg → .svg.png` リネーム）+ Pass 2（`.textbox` Div 展開）
   - 削除: JSEK本文 の全 Para ラップ、OrderedList 手動番号化、.grid/GRID_TABLE マーカー
   - `process_blocks` は top-level のみを対象とし、`.textbox` 以外のブロックはすべて素通し

2. **`main/step02_docx/wrap_textbox.py`**（568 行）
   - `next-gen-comp-paper/scripts/wrap-textbox.py` から最小移植
   - **保持**: NSMAP (+`asvg` / +`a14` 追加)、`extract_root_tag` / `restore_root_tag`、
     `is_textbox_marker` / `get_marker_text` / `parse_attrs`、
     `resize_images_in_content`、`build_textbox_paragraph`、`embed_svg_native`、
     `process_docx` メインフロー
   - **削除**: `apply_booktabs_borders` + セル罫線ユーティリティ一式、
     `resize_tables_in_content`、`relocate_textbox_by_page`
   - **変更**:
     - `embed_svg_native` のパス解決を `source_md` 親ディレクトリ基準に修正
       （CWD 依存で silent fail していた移植元バグの修正、C09-01 / 旧 M09-04 対応）
       未検出時は `FileNotFoundError` で非ゼロ exit
     - `build_textbox_paragraph(..., id_base)` に引数追加し、
       `docPr@id = id_base + z_order` で採番
     - CLI に `--docpr-id-base`（int, 既定 3000）、`--source`、
       `--no-relocate`（default=True、互換用）
     - `process_docx(..., no_relocate=True)` を**既定**にした

### Docker 経由のスモーク確認

- `docker compose ... run --rm python pandoc youshiki1_2.md --lua-filter=filters/textbox-minimal.lua ...`
  → docx 生成に成功、`document.xml` 内の `TextBoxMarker` = **0 件**（`.textbox` 未使用）
- `docker compose ... run --rm python python3 wrap_textbox.py jank/tb_smoke.docx`
  → `No TextBoxMarker regions found` を出して exit 0（副作用なし）
- ホスト Python / ホスト pandoc は未使用

### 参考: report10 の残課題メモ

- **I10-03**（`mermaid-build` サブコマンド検討）: Step 10 着手後の最適化扱い、
  本プロンプトでは触れない
- **M10-02 連動メモ**: 「`embed_svg_native` 内で `<foreignObject>` 検出時に非ゼロ exit
  を上げる安全装置追加を検討」— 今回の wrap_textbox.py には**未実装**。レビュー時に
  この観点の欠落を評価対象とすること

## レビュー対象

### 1. `filters/textbox-minimal.lua` の壊れ方

`.textbox` Div 以外は素通しする設計だが、どこで破綻するか敵対的に探ること。

- `.textbox` のネスト（`.textbox` の内側に別の `.textbox` がある場合）
- `.textbox` Div が Blockquote / 別の Div / List の内側に入っている場合
  （`process_blocks` は top-level しか見ないため、検出漏れしないか）
- 空 Div（`content` が空）で `result:extend(div.content)` した場合の挙動
- 属性未指定時の EMU=0 が OOXML で `<wp:extent cx="0" cy="0">` を生む
  → Word 側で不正 / silent drop されないか
- FORMAT 非 docx 時の `return {}` が、他 writer で想定通りスキップされるか
- **Image filter の `.svg` 末尾判定**: `foo.svg.png` を処理済みとして再リネームしないか
  （二重 pass で `.svg.png.png` にならないか）
- **OOXML RawBlock のエスケープ**: `params` 文字列内の属性値に `<`, `>`, `&`, `"` が
  含まれた場合、`<w:t>` の中身として XML が壊れる可能性
  （`textbox_marker` が生の文字列連結している）
- **JSEK本文 / OrderedList 除去の副作用**: 移植元が全 Para を JSEK本文 でラップして
  いた理由を確認し、削ったことで Word 側の既定スタイル適用が変わらないか
- reference.docx に `TextBoxMarker` スタイルが未定義なら hidden 化が効かず、
  START/END が可視段落として残る可能性

### 2. `wrap_textbox.py` のエッジケース

- **`embed_svg_native` の image 正規表現** `r'!\[.*?\]\(([^)\s]+)'` は以下で壊れる:
  - reference-style image（`![alt][ref]`）
  - angle-bracket URL（`![alt](<path with space.svg>)`）
  - alt テキスト内の `]` / 括弧エスケープ
  - `!\[.*?\]\(` の `.*?` が改行を跨ぐケース（デフォルトで `.` は改行非マッチなので
    複数行 alt で破綻）
- **`_strip_yaml_and_code`** が fenced code の backtick カウントを考慮していない
  （````` 4 重 backtick 内に ``` があるケース等）
- **`extract_root_tag` の正規表現**が複数行属性の `<w:document\n xmlns:...>` に対応するか
  （`[^>]*` は greedy + 改行非マッチ）
- **`restore_root_tag` の mc:Ignorable merge**: 既存 root に `mc:Ignorable="w14 w15"`
  がある場合、`wps wp14` 追記が単純置換で壊れないか
- **zipfile 再書き込み**: 元の `mimetype`（ZIP_STORED 無圧縮）を `ZIP_DEFLATED` で
  書き戻すと docx パッケージ仕様違反になる可能性
- **`parts` dict の iteration 順**が元 zip の順序を維持しない → Word が依存する
  `[Content_Types].xml` 先頭位置等で問題が起きないか
- **`--no-relocate` フラグのバグ**: `action="store_true"` + `default=True` により、
  `--no-relocate` を指定しても値は True のまま、指定しなくても True。実質デッド引数
  （UX バグ）
- **`docPr@id` 衝突**: plan2.md §7.2 の「テンプレート既存 id = 実測 0 件」前提を疑う。
  今回の wrap_textbox は重複チェックを一切行わない（id_base 3000 で固定）
- **SVG blip 対応の K 番目一致**: `md_text` から `!\[...]\(...\)` で抽出した image
  順序と `document.xml` 内の `a:blip` 順序が常に一致する保証はない
  （例: OrderedList/Div 内画像、pandoc の出力順、figure caption 化の影響）
- **FileNotFoundError** は CI では止まるが、開発中に「まだ SVG を作ってない図がある」
  状況で build 全体が止まる。skip-missing オプションが無いのは過剰厳格ではないか
- **`resize_images_in_content`** が `a:ext` まで触るが、scale 連動が不完全で画像が
  歪む可能性（縦横比維持ロジックを改めて検算）
- `build_textbox_paragraph` 内部で `content_elements` を直接 `txbxc.append(elem)` して
  いるため、同じ content を再利用すると親要素が移動する ElementTree の仕様で
  副作用が起きる（ただし本関数は呼び出し側で 1 回しか使わない設計）
- **`<foreignObject>` 検出時安全装置の欠落**（report10 の残課題メモより）—
  mermaid が出力する SVG に残存した場合に Word が silent drop する既知問題への
  対策が無い

### 3. `inject_narrative.py` との統合点

wrap_textbox 処理済みの docx を `inject_narrative.py` に渡した時に壊れる可能性を
探ること。

- **NSMAP 対称性**: inject 側には `w14` / `w15` があるが wrap 側には無い。
  inject が body をコピーする時点で名前空間の再解決が必要になるか、
  欠落 prefix で ElementTree が壊れないか
- **docPr@id 採番帯**: 1-2=3000, 1-3=4000 で分離する前提だが、inject 側は
  本文の docPr@id を renumber しない。テンプレート `r08youshiki1_5.docx` の
  実測 0 件を疑い、Prompt 10-1 で確認済みとされる検証の再現性を問う
- **`[Content_Types].xml` / `document.xml.rels` のマージ**: wrap_textbox が追加した
  SVG の rId と ContentType "svg" が inject_narrative の body 結合で保存されるか。
  inject 側の rels マージロジックの確認が必要
- **mc:Ignorable の上書き**: wrap 側が `wps wp14` を付与した後、inject 側が root tag
  を再生成 / 上書きするとき `wps wp14` が消えないか
- **asvg:svgBlob の rId renumber**: inject 側が rels を renumber する場合、
  svgBlob 内の `r:embed="rId42"` が更新されず孤児化しないか
- **body 要素の取り込み単位**: wrap_textbox は `wp:anchor` を含む paragraph を body
  直下に置く。inject が section 単位で body を切り出す場合、anchor paragraph の
  位置関係（直前 section との関係）で wrap 動作が崩れないか

## 参照すべき資料

| ファイル | 確認ポイント |
|---------|------------|
| `filters/textbox-minimal.lua` | 94 行の最小構成、top-level only 処理、Image filter、RawBlock エスケープ |
| `main/step02_docx/wrap_textbox.py` | 568 行、NSMAP、`embed_svg_native`、`build_textbox_paragraph`、`process_docx` |
| `main/step02_docx/inject_narrative.py` | NSMAP（w14/w15 含む）、body 結合、rels/Content_Types マージ、root tag 復元 |
| `docs/plan2.md` §6 §7 | 設計意図（特に §7.2 の docPr@id 帯と §7.1 の SVG パス解決設計） |
| `docs/prompts.md` Prompt 10-2 (244-392行) | 完了チェック項目と実装ポイント（C09-01 / M09-04 対策） |
| `/home/dryad/anal/next-gen-comp-paper/scripts/wrap-textbox.py` | 移植元との差分（削った機能が残すべきだった可能性を探る） |
| `/home/dryad/anal/next-gen-comp-paper/filters/jami-style.lua` | 削った JSEK本文 / OrderedList 処理の必要性の再評価 |
| `templates/reference.docx` | `TextBoxMarker` スタイルが定義されているかの確認 |

## 出力フォーマット

`docs/report11.md` に以下の形式で出力してください:

```markdown
# 敵対的レビュー報告書（第11回）— Prompt 10-2 成果物

レビュー実施日: 2026-04-15
レビュー対象:
- filters/textbox-minimal.lua
- main/step02_docx/wrap_textbox.py
- （統合点検証のため参照）main/step02_docx/inject_narrative.py
前回レビュー: docs/__archives/report10.md (2026-04-XX)

## サマリ

- Critical: N件 (新規N / 既知未対応N)
- Major: N件 (新規N / 既知未対応N)
- Minor: N件 (新規N / 既知未対応N)
- Info: N件

### 対応状況一覧

| ID | 重大度 | 状態 | 概要 |
|----|--------|------|------|
| C11-01 | Critical | ... | ... |

## report10.md との差分サマリ

- 前回の未対応項目で今回解消されたもの: N件
- 前回の未対応項目で依然として未対応のもの: N件
- 前回に記載がなく今回新規発見したもの: N件

## 指摘事項

### [C11-01] (Critical) タイトル
- **箇所**: ファイル名:行番号 or セクション名
- **前回対応状況**: 新規 / report10.md [X10-XX] 対応済み / 未対応
- **内容**: 具体的な問題の説明
- **影響**: この問題が放置された場合に起きること
- **推奨対応**: 修正方針

## リスクマトリクス

| リスク | 影響度 | 発生確率 | 総合評価 | 対策 |
|--------|--------|---------|---------|------|
| ... | 高/中/低 | 高/中/低 | Critical/Major/Minor | ... |
```

重大度の基準:
- **Critical**: 実装がブロックされる、または成果物に致命的欠陥が生じる（Prompt 10-3
  以降に進めない / 生成 docx が Word で開けない）
- **Major**: 実装に手戻りが発生する、または成果物の品質に重大な影響がある
- **Minor**: 修正すべきだが実装を進めながら対応可能
- **Info**: 改善推奨だが現状でも問題なく進められる
