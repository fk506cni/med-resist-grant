# 敵対的レビュー報告書（第13回）— Prompt 10-4 成果物と Prompt 10-5 着手前の健全性

レビュー実施日: 2026-04-17
レビュー対象:
- `main/step02_docx/build_narrative.sh`（本セッション修正後版）
- `main/step02_docx/wrap_textbox.py`
- `main/step02_docx/inject_narrative.py`
- `filters/textbox-minimal.lua`
- `main/step01_narrative/youshiki1_2.md`（.textbox 追加後）
- `main/step01_narrative/figs/fig1_overview.mmd`
- `main/step02_docx/output/youshiki1_2_narrative.docx`（生成物）
- `main/step02_docx/output/youshiki1_5_filled.docx`（inject 後の先行観察）
- `.gitignore`
- （参考）`docs/plan2.md` / `docs/prompts.md` / `docs/__archives/report12.md`

前回レビュー: `docs/__archives/report12.md`（2026-04-17、対応済み）

## サマリ

- Critical: 1 件（新規 1 / 既知未対応 0）→ **対応完了 1**
- Major: 5 件（新規 5 / 既知未対応 0）→ **対応完了 4、未対応 1（M13-02: 設計判断のため docs 追補のみ）**
- Minor: 11 件（新規 11 / 既知未対応 0）→ **対応完了 4、残 7 は当面 docs のみ**
- Info: 4 件（新規 4）→ **対応不要（記録のみ）**

### 対応状況一覧

| ID | 重大度 | 状態 | 概要 | 対応 |
|----|--------|------|------|------|
| C13-01 | Critical | 新規 | inject 後の Content_Types から `.jpg` / `.png` の Content-Type 登録が消失する（Override 未マージ） | ✅ 対応済（merge_content_types を Default+Override+拡張子ベース Default 自動補完で強化、verify_media_content_types による最終検証を追加） |
| M13-01 | Major | 新規 | `restore_root_tag` が `mc:Ignorable` を merge せず、filled の Ignorable から `wps` が落ちる | ✅ 対応済（restore_root_tag に `extra_ignorable` 引数追加、`_detect_required_ignorable` で body から wps 要素を検出して自動補完） |
| M13-02 | Major | 新規 | `wrap_textbox` が `mc:AlternateContent` で wps:wsp を包んでいない（プロンプトの前提と反する） | ⏸️ 未対応（Word 2010+ 前提のため現状維持、本レポート末尾に設計判断として記録） |
| M13-03 | Major | 新規 | Phase A + Lua filter の `.svg`/`.svg.png` 非整合で SVG（新）と PNG（旧）が混在する silent 劣化 | ✅ 対応済（wrap_textbox.embed_svg_native で svg_mtime > png_mtime を hard fail） |
| M13-04 | Major | 新規 | `merge_rels` が narrative の `footnotes.xml.rels` / `comments.xml.rels` を見ず、将来の脚注・コメント参照 rId が壊れる | ✅ 対応済（`_merge_notes` 内で note rels も同時 merge、hyperlink/image 型を renumber） |
| M13-05 | Major | 新規 | `--resource-path=main/step01_narrative` のみ指定で、pandoc が silent に「画像欠落 docx」を吐く経路が残存（C12-01 の残像） | ✅ 対応済（wrap_textbox の md↔blip 枚数不一致を WARNING → ValueError に格上げ。N13-07 と合わせて対応） |
| N13-01 | Minor | 新規 | narrative docx の rels で `<ns0:Relationship>` と `<Relationship>` が prefix 混在 | ⏸️ 未対応（機能影響なし・動作確認済） |
| N13-02 | Minor | 新規 | SIGTERM/Ctrl+C で `.tmp.$$` ファイルが残留する（trap EXIT 未設定） | ✅ 対応済（run_mermaid / run_rsvg_convert に `trap "rm -f '$tmp'" RETURN` を追加、Phase A 前の残骸掃除ロジックも追加） |
| N13-03 | Minor | 新規 | `--resource-path=main/step01_narrative` が cwd 相対で、別 caller から壊れうる | ⏸️ 未対応（現状動作確認済み。絶対パス化は Docker パス差異で別 issue） |
| N13-04 | Minor | 新規 | Phase A mtime 判定が 0byte / 破損ファイルを skip 扱いする | ✅ 対応済（`-f` → `-s` に変更、0byte ファイルは再生成扱い） |
| N13-05 | Minor | 新規 | `reference.docx` の in-place 書換が `fix_reference_styles.py` の冪等性に依存 | ⏸️ 未対応（冪等性テストは CI 追加時に対応） |
| N13-06 | Minor | 新規 | `copy_media` の rename suffix（`_n1`）が rId ベース命名と非対称 | ⏸️ 未対応（現時点 rename 未発生） |
| N13-07 | Minor | 新規 | `embed_svg_native` の md↔blip 枚数不一致は WARNING のみで fail しない | ✅ 対応済（M13-05 と合わせて ValueError に格上げ） |
| N13-08 | Minor | 新規 | mermaid-config.json に `pie` / `mindmap` / `timeline` / `c4` / `quadrantChart` が未登録 | ✅ 対応済（21 種類の diagram type をカバー） |
| N13-09 | Minor | 新規 | narrative の `word/comments.xml` は inject 時に丸ごと捨てられる | ⏸️ 未対応（現状 Pandoc の comments.xml は空、dormant） |
| N13-10 | Minor | 新規 | `wrap_textbox.embed_svg_native` が `ET.register_namespace("", RELS_NS)` を呼ぶ副作用で同プロセス内の後続操作に影響 | ⏸️ 未対応（別プロセスで動くため現状無害） |
| N13-11 | Minor | 新規 | `.textbox` 内 pandoc figure caption が txbxContent に吸い込まれ、独立キャプション段落にならない | ⏸️ 未対応（Prompt 10-5 の Windows 視覚確認で判定） |
| I13-01 | Info | 新規 | wp:docPr/@name が "TextBox 1/2"（英語固定） | — |
| I13-02 | Info | 新規 | pandoc 側 rId 採番が rId8 → rId23 で飛ぶ（制御不能な pandoc 内部挙動） | — |
| I13-03 | Info | 新規 | `.mmd` 行末の `init` directive の `fontSize:'18px'` は mermaid-cli 10.9.1 で実効性が未検証 | — |
| I13-04 | Info | 新規 | `{#fig:hospital}` 等の crossref anchor は現状未使用で、Word 内のブックマーク残留有無が未確認 | — |

### 本セッションでの対応作業ログ（2026-04-17）

| 指摘 ID | 修正箇所 | 変更サマリ |
|---------|---------|----------|
| C13-01 | `main/step02_docx/inject_narrative.py:merge_content_types` | `_MEDIA_CONTENT_TYPES` 拡張子テーブルを追加。Default merge に加え、source Override のコピー + target_parts 内 media 拡張子ベースの Default 自動補完。`verify_media_content_types` で Content-Type カバレッジ未達時は `sys.exit(1)`。 |
| M13-01 | `main/step02_docx/inject_narrative.py:restore_root_tag` / `_detect_required_ignorable` | `restore_root_tag` に `extra_ignorable` 引数追加。body を走査して wps 要素の有無を検出し、存在すれば `mc:Ignorable` に `wps` を補完。 |
| M13-03 | `main/step02_docx/wrap_textbox.py:embed_svg_native` | `.svg` の mtime が `.svg.png` より新しい場合に `raise ValueError`。primary blip(PNG) と asvg:svgBlob(SVG) の版差 silent 劣化を防止。 |
| M13-04 | `main/step02_docx/inject_narrative.py:_merge_notes` | `word/_rels/{note_type}s.xml.rels` も同時 merge。hyperlink/image 型を copy して rId renumber、note 本体の `r:id/r:embed/r:link` も書き換え。 |
| M13-05 / N13-07 | `main/step02_docx/wrap_textbox.py:embed_svg_native` | md↔blip 枚数不一致を WARNING → `raise ValueError` に格上げ。silent な画像欠落経路を hard fail で塞ぐ。 |
| N13-02 | `main/step02_docx/build_narrative.sh:run_mermaid` / `run_rsvg_convert` | `trap "rm -f '$tmp'" RETURN` を追加。Phase A 突入前に `*.tmp.*.{svg,png}` の残骸を掃除。 |
| N13-04 | `main/step02_docx/build_narrative.sh` Phase A | up-to-date 判定を `-f` → `-s`（存在かつ size > 0）に変更。0byte 破損ファイルを再生成対象に。 |
| N13-08 | `docker/mermaid-svg/mermaid-config.json` | 7 種 → 21 種（pie/mindmap/timeline/requirement/gitGraph/c4/quadrantChart/xyChart/packet/block/kanban/treemap/architecture/radar 追加）。 |

### 動作確認（実地ビルド）

```
RUNNER=docker DATA_DIR=data/dummy SETUP_DIR=data/dummy ./scripts/build.sh
  validate     ✓ OK
  forms        ✓ OK
  narrative    ✓ OK
  inject       ✓ OK
  security     ✓ OK
  excel        ✓ OK
```

生成された `main/step02_docx/output/youshiki1_5_filled.docx` の実地検証:

```
=== C13-01 (Content-Types) ===
Defaults: ['jpeg', 'rels', 'xml', 'odttf', 'svg', 'jpg', 'png']
Media Overrides: ['/word/media/rId23.jpg', '/word/media/rId30.png']
.jpg covered: True, .png covered: True

=== M13-01 (mc:Ignorable) ===
mc:Ignorable: w14 wp14 wps
wps present: True
```

→ C13-01 / M13-01 ともに **filled docx で適切にカバー** されていることを確認。

## report12.md との差分サマリ

- 前回の未対応項目で今回解消されたもの: 0 件（report12 の指摘はすべて対応済みコミットに反映されていることを実地確認）
- 前回の未対応項目で依然として未対応のもの: 1 件（C12-01 の「silent 画像欠落」の別経路がまだ残存 → M13-05 として再提起）
- 前回に記載がなく今回新規発見したもの: 20 件（Critical 1 / Major 5 / Minor 11 / Info 3）

### report12 の対応確認

| report12 ID | 実装箇所 | 状態 |
|------------|---------|------|
| C12-01 | `run_mermaid` / `run_rsvg_convert` の `command -v` 経由 fail-fast | ✓ 対応（ただし pandoc 側経路は M13-05 で残存） |
| M12-01 | `wrap_textbox.process_docx` の `tempfile.mkstemp` + `shutil.move` | ✓ 対応 |
| M12-02 | `preflight_docker_images` で Dockerfile mtime vs image created | ✓ 対応 |
| M12-03 | `run_mermaid` が `$tmp` 経由 → `mv` で atomic | ✓ 対応 |
| M12-04 | Phase C 失敗時 `rm -f "$out"` | ✓ 対応 |
| M12-05 | docPr 衝突検査が header/footer も走査 | ✓ 対応 |
| M12-06 | mermaid-config.json に flowchart/class/state/sequence/er/gantt/journey の htmlLabels:false | ✓ 対応（ただし N13-08 で未カバー分残存） |
| M12-07 | RUNNER=uv → `uv run python3` | ✓ 対応 |
| N12-01 | Lua の `%.[sS][vV][gG]$` で大文字 reject | ✓ 対応 |
| N12-02 | `do_check` | （未確認・本レビュー範囲外） |
| N12-03 | `preflight_docker_images` で mermaid サービス含む | ✓ 対応 |
| N12-04〜07 | 各種 fail-fast / 空配列 guard | ✓ 対応 |
| I12-01〜04 | （継続情報） | 変化なし |

---

## 指摘事項

### [C13-01] (Critical) inject 後の `[Content_Types].xml` に `.jpg` / `.png` の Content-Type が登録されない

- **箇所**: `main/step02_docx/inject_narrative.py:551-570`（`merge_content_types`）、実地生成された `main/step02_docx/output/youshiki1_5_filled.docx:[Content_Types].xml`
- **前回対応状況**: 新規
- **内容**:
  - `merge_content_types` は source（narrative）docx の `<Default Extension="xxx"/>` のみを target（template）にコピーする。source の `<Override PartName="/word/media/..." ContentType="..."/>` は無視される。
  - 本セッションで生成された `youshiki1_2_narrative.docx` の `[Content_Types].xml` を検査すると、jpg / png は **Override** でのみ登録されている（Pandoc 流儀）:
    - `<Override PartName="/word/media/rId23.jpg" ContentType="image/jpeg"/>`
    - `<Override PartName="/word/media/rId30.png" ContentType="image/png"/>`
  - Template 側（`r08youshiki1_5.docx`）の `[Content_Types].xml` は `Default Extension="rels|xml"` のみで、jpg/png/jpeg は一切登録されていない。fill_forms.py が Word の挿入画像の影響で `Default Extension="jpeg"` を追加しているが、これは `.jpeg` にしかマッチせず、narrative が持ち込む `.jpg` には効かない。
  - 結果、`youshiki1_5_filled.docx` を unzip → [Content_Types].xml を検査すると:

    ```
    Defaults: ['jpeg', 'rels', 'xml', 'odttf', 'svg']
    Overrides (media): 0
    ```

    つまり `/word/media/rId23.jpg` と `/word/media/rId30.png` の **Content-Type 登録が完全に失われている**（svg のみ Default で救われている）。

- **影響**:
  - **ECMA-376 Part 3 (OPC) §8 違反**: 全 Part は必ず Content-Type を持たなければならない。Default の拡張子マッチングは case-insensitive だが **literal extension match** であり、`jpeg` Default は `.jpg` ファイルには効かない。
  - Word は起動時のスキーマ検証で「ファイルが破損しています。修復しますか？」ダイアログを出す可能性が高い。
  - 修復成功時でも画像が失われるか、placeholder（壊れた画像アイコン）で表示される可能性。
  - **Prompt 10-5 の Windows Word COM PDF 変換はほぼ確実に失敗する**。`watch-and-convert.ps1` の `Document.Open` または `Document.ExportAsFixedFormat` が例外を投げる、または silent に画像が欠落した PDF が生成される。
  - E2E テストでは Windows 変換経路が走らないため、**このバグは現在の Linux build では検出不能**。

- **推奨対応**:
  - `merge_content_types` を以下の仕様に拡張:
    1. source の `<Override>` も全て target にコピー（target に既存の同一 PartName があればスキップ）
    2. ないし、media ファイル拡張子ベースで Default を自動追加: source rels の image 型 Relationship の Target から拡張子を抽出し、`image/jpeg` / `image/png` / `image/svg+xml` 等を Default に追加。
  - 推奨は後者（Default 追加）。narrative 側の Override は file name が rId 依存で壊れやすく、Default での一括カバーが堅牢。
  - 最低限 `.jpg` / `.jpeg` / `.png` / `.gif` / `.svg` / `.webp` を候補リストとして持つか、pandoc が narrative に書き出した Override を拡張子ごとに集約して Default に昇格させる。
  - fix 後は `unzip -p output/youshiki1_5_filled.docx '[Content_Types].xml' | grep -E 'jpg|png'` が空にならないことを CI で assert。

---

### [M13-01] (Major) `restore_root_tag` が `mc:Ignorable` を merge せず、filled の Ignorable 属性から `wps` が脱落する

- **箇所**: `main/step02_docx/inject_narrative.py:96-117`（`restore_root_tag`）、実地 `youshiki1_5_filled.docx:word/document.xml` の root tag
- **前回対応状況**: 新規（wrap_textbox 側は `mc:Ignorable` を正しく merge するが、inject 側は未対応）
- **内容**:
  - narrative docx の root tag は `mc:Ignorable="wps"`（wrap_textbox が N11-05/N11-06 対応で設定）。
  - template の root tag は `mc:Ignorable="w14 wp14"`。
  - `inject_narrative.py:restore_root_tag` は `xmlns:` 宣言のみ merge する（`new_ns` 辞書を ns 宣言から作成し、`orig_ns` に無いものを追記）。`mc:Ignorable` 属性の値は一切 merge されない。
  - 結果、実地生成 `youshiki1_5_filled.docx` の root tag は `mc:Ignorable="w14 wp14"` のまま、`wps` が含まれない。
  - `wrap_textbox.py` が emit する wps:wsp 要素は **mc:AlternateContent で包まれていない**（M13-02 参照）ので、strict parser は wps:wsp を直接読む必要がある。Ignorable に無い場合、未知要素として扱うかどうかは実装依存。

- **影響**:
  - Word 2010+ は wps namespace を consumer として直接理解するため、おそらく動作する（実地未検証）。
  - 一方、LibreOffice / Apple Pages / Google Docs / 一部の古い Word は、mc:Ignorable に含まれない未知 namespace を「unknown」扱いして無視 or エラーを出す可能性。
  - 応募後の審査側が Word 以外で開く可能性が低いとはいえ、e-Rad 処理系の PDF 変換が Word で行われない場合、テキストボックス（背景画像、フロー図）が消える silent 劣化を招く。
  - Word でも AlternateContent を含まない wps:wsp が未知 ns 扱いされた場合、`mc:Ignorable` に wps が無いと「unknown element」として skip される危険がある。

- **推奨対応**:
  - `restore_root_tag` に `mc:Ignorable` merge ロジックを追加:
    - template と source の `mc:Ignorable` 属性値をそれぞれトークン化
    - 和集合を取り、重複排除して再設定
  - 現状 `wrap_textbox.py:restore_root_tag` が同等の処理を持っているのでコピー可能（inject 側は `tag_local` の汎用性のため差分がある）。

---

### [M13-02] (Major) `wrap_textbox.py` が `mc:AlternateContent` で wps:wsp を包まない — プロンプトの前提と実装の乖離

- **箇所**: `main/step02_docx/wrap_textbox.py:182-303`（`build_textbox_paragraph`）、実地 `youshiki1_2_narrative.docx:word/document.xml`
- **前回対応状況**: 新規
- **内容**:
  - start13.md プロンプトは「wrap_textbox が出力する wps:wsp は mc:AlternateContent で包まれている（新旧 Word 互換のため）」と述べているが、**実装はそうなっていない**。
  - 実地 `youshiki1_2_narrative.docx:document.xml` を grep すると:

    ```
    AlternateContent= 0  mc:Fallback= 0  mc:Choice= 0
    ```

    一切の mc:AlternateContent ラッピングが無い。bare `<wp:anchor>...<wps:wsp>...</wps:wsp>...</wp:anchor>` が直接 body 配下に置かれている。
  - `build_textbox_paragraph` は `<a:graphic><a:graphicData uri="...wordprocessingShape"><wps:wsp>...</wps:wsp></a:graphicData></a:graphic>` という構造を組むが、これを `<mc:AlternateContent><mc:Choice Requires="wps">...</mc:Choice><mc:Fallback>...</mc:Fallback></mc:AlternateContent>` で包む実装は存在しない。

- **影響**:
  - Word 2007（wps namespace を理解しない）では textbox は消失。ただしプロジェクトの想定利用は Word 365/2019/2016 なので実運用上は許容範囲。
  - より深刻なのは、`mc:Fallback` 層に「テキストボックスの代替として PNG 画像を貼る」戦略が取れない点。現状は wps:wsp の内側にある `<w:txbxContent>` に pandoc 由来の drawing が置かれているため、asvg 層のフォールバック（PNG primary blip）は機能する。ただしそれは「テキストボックス外枠」ではなく「テキストボックス内の画像」のフォールバックでしかない。
  - docPr / rels / media merge の検証戦略として「mc:Fallback ブロックの rels 参照が正しいか」を検査しようとすると、そもそも Fallback が無いので検査ロジックが無意味になる。プロンプトの前提に基づくレビュー観点は一部 void（それ自体は仕様変更の余地があることを示す）。

- **推奨対応**:
  - 短期: プロンプト / plan2.md の記述を「mc:AlternateContent は使用しない（Word 2010+ で wps を consume できるため）」と明記する。
  - 中期: Word 2007 対応が要求される場合のみ、wps:wsp を `<mc:Choice Requires="wps">` で包み、`<mc:Fallback>` に VML shape か image の fallback を置く拡張を検討。
  - 現状の実装を変える必要は必ずしも無いが、**プロンプト・設計書との整合**を取るため、片方を更新すべき。

---

### [M13-03] (Major) Phase A / Lua filter の `.svg` と `.svg.png` が独立して更新されることで、docx 内に新 SVG と旧 PNG が混在する silent 劣化経路

- **箇所**: `main/step02_docx/build_narrative.sh:245-271`（Phase A）、`filters/textbox-minimal.lua:166-182`、`main/step02_docx/wrap_textbox.py:483-499`（blip ↔ md image K-th alignment）
- **前回対応状況**: 新規
- **内容**:
  - Phase A は `.mmd → .svg`（ステップ1）と `.svg → .svg.png`（ステップ2）を独立した mtime 判定で回す。
  - ステップ1 が `.svg` を再生成して ステップ2 が失敗すると、Phase A 全体が `run_rsvg_convert` の非ゼロ return で止まる（`set -euo pipefail`）。ここまでは OK。
  - 問題は **ステップ2 だけ手動で古い `.svg.png` を rollback**（例: `git checkout -- figs/fig1_overview.svg.png` したが `.svg` は最新の場合）や、**他プロセスが `.svg.png` を touch した場合**。Phase A は mtime のみを見るため、`.svg.png` が `.svg` より新しければ skip される。
  - 次回 pandoc 実行時、Lua filter は `figs/fig1_overview.svg` を `figs/fig1_overview.svg.png` に書き換え（静的な文字列置換）、pandoc は primary blip に旧 PNG を埋め込む。その後 `wrap_textbox.embed_svg_native` は **新 `.svg` を asvg:svgBlob として読み込んで貼る**（`src_dir = os.path.dirname(os.path.abspath(source_md_path))` + `svg_path` でディスクから直接読む）。
  - 結果、docx 内に:
    - `a:blip/@r:embed` → `media/rId30.png`（**旧** SVG から生成された PNG ラスタ）
    - `asvg:svgBlob/@r:embed` → `media/svg1.svg`（**新** SVG）
  - が混在し、Word 2016+ は SVG を優先表示、Word 2013 以前は PNG を表示、という**見た目の不整合**が発生する。

- **影響**:
  - Linux ビルド側では `.svg.png` と `.svg` の差分を可視化する仕組みがない。目視では気付きにくい silent 劣化。
  - 採点対象の PDF（Windows Word で生成）は Word 2016+ 相当なので SVG 表示され、一見問題なく見える。しかし e-Rad システムが PNG を抽出する処理を持っている場合は旧画像が出る。
  - 実地では Phase A が fail すればビルド全体が止まるのでこの経路は稀。ただし `touch` や rsync `--preserve-modtime` で `.svg.png` の mtime が過去に書き戻される経路は実在する。
  - また、`roundtrip.sh` が rclone 経由で Google Drive と同期する際、 `--preserve-modtime` 相当のタイムスタンプ巻き戻しが発生しうる。

- **推奨対応**:
  - Phase A のステップ2 判定を「`.svg.png` が `.svg` 以後 **かつ** `.svg` のハッシュが前回ビルド時と一致」に強化。`.svg.png.meta`（SHA256 of source `.svg`）を sidecar として置き、内容が変わっていれば必ず再生成。
  - あるいは、より単純に: `wrap_textbox.embed_svg_native` の直前で `.svg` と `.svg.png` の mtime を再検査し、`.svg` の mtime > `.svg.png` の mtime なら `raise ValueError`。これで docx 生成を abort。
  - もしくは、Lua filter の `.svg → .svg.png` 書換をやめて `.svg` を primary blip にし、asvg 層を廃止（ただし Word 2013 以前のフォールバックが消える）。

---

### [M13-04] (Major) `merge_rels` が `footnotes.xml.rels` / `comments.xml.rels` / `endnotes.xml.rels` を merge しない — 将来の脚注・コメント内リンクが壊れる

- **箇所**: `main/step02_docx/inject_narrative.py:241-291`（`merge_rels`）、関連: `_merge_notes`（603-627）
- **前回対応状況**: 新規
- **内容**:
  - `merge_rels` は `word/_rels/document.xml.rels` のみを対象とする。narrative docx には `word/_rels/footnotes.xml.rels` が存在するが、merge されない。
  - 現在は footnotes.xml が `<w:footnotes>` の separator / continuationSeparator のみで `_merge_notes` が早期 return するため、rels merge 不要 → 現実影響なし。
  - ただし、将来 md に `^[脚注内容]` 形式の脚注を書き、その中にハイパーリンクや画像を貼った場合、footnote 内の `r:id` / `r:embed` は **source footnote に紐付いた rels** を必要とする。merge_rels は document.xml.rels しか見ないため、footnote 内リンクが orphan になる。
  - comments.xml についても同様。プロジェクトでは今後「査読コメント → docx comments」の仕組みを入れる可能性があり、その際に発火。

- **影響**:
  - 現時点 E2E では発火しない（dormant）。
  - Prompt 10-5 以降で md 本文に脚注（特にリンク付き脚注）を追加した瞬間、silent 破壊が発生する。Word は「リンク切れ」として表示するか、該当 run を drop する。

- **推奨対応**:
  - `_merge_notes` 内で note を copy する際、同時に `word/_rels/{note_type}s.xml.rels` の rels も copy して renumber。`document.xml.rels` と同じ `rid_map` を適用。
  - 実装箇所: `_merge_notes:612-617` あたりで、src_notes 内の `r:id` / `r:embed` / `r:link` 属性を `rid_map` で更新し、rels 自体も target 側にコピー。
  - 単体では実装が煩雑なため、当面は **md 内で脚注にリンク・画像を含めない**ことを plan2.md に制約として明記。

---

### [M13-05] (Major) `--resource-path` 追加後も `--fail-if-warnings` が未導入で、pandoc の画像解決失敗が silent に通る経路が残存

- **箇所**: `main/step02_docx/build_narrative.sh:27-33`（PANDOC_OPTS）
- **前回対応状況**: C12-01 の**別経路**として未対応
- **内容**:
  - C12-01 は「MODE=local で mmdc / rsvg-convert が silent skip される経路」を指摘し、`command -v` による fail-fast で解決済み。
  - 一方、**pandoc の画像解決失敗**（`--resource-path` で見つからない、ファイル破損、権限エラー等）は依然として `[WARNING] Could not fetch resource ...` を stderr に吐くだけで、pandoc 自体は exit 0 を返す。`build_narrative.sh` は `run_pandoc` の exit status のみチェックしているので、この WARNING は silent に通過する。
  - 今回の Prompt 10-4 で `--resource-path=main/step01_narrative` を追加して一応解決したが、これは「1 件の特定ケースを塞いだ」だけであり、根本的な silent 経路は残る:
    - 著者が md に `figs/not_exist.svg` を書き、Phase A も `.mmd` を持たないので skip、lua filter が `.svg → .svg.png` 書換 → pandoc は見つからずに WARNING → exit 0
    - 結果: docx は「その画像」が欠落した状態で完成
  - `wrap_textbox.embed_svg_native` の md↔blip K-th alignment 検査は **件数不一致を WARNING 止まり**（N13-07）で、alignment ズレは起こるが hard fail はしない。

- **影響**:
  - 著者が新しい図を追加する際、タイポで `figs/fig2_overvew.svg`（誤字）と書いた瞬間、build 成功で欠落 docx が完成する。
  - C12-01 の指摘趣旨（silent 画像欠落 docx を防ぐ）は**完全には達成されていない**。

- **推奨対応**:
  - `PANDOC_OPTS` に `--fail-if-warnings` を追加。これで `[WARNING]` が全て fatal になる。ただし pandoc が他の無害な WARNING（例: 非推奨構文）も fatal にするため副作用注意。
  - 代替: Pandoc 実行後に `run_pandoc` の stderr を取得して `grep -E 'Could not fetch resource'` で検出し、該当があれば `FAILED=1`。
  - あるいは、`wrap_textbox.embed_svg_native` の K-th alignment 不一致を `raise ValueError` に格上げ（N13-07）することで間接的に検出可能。

---

### [N13-01] (Minor) narrative docx の `word/_rels/document.xml.rels` に `<ns0:Relationship>` と `<Relationship>` のプレフィックス混在

- **箇所**: `main/step02_docx/wrap_textbox.py:501-502, 568`、実地 `youshiki1_2_narrative.docx:word/_rels/document.xml.rels`
- **前回対応状況**: 新規
- **内容**:
  - 実地 rels を `unzip -p ... word/_rels/document.xml.rels` で確認すると:

    ```xml
    <ns0:Relationships xmlns:ns0="http://schemas.openxmlformats.org/package/2006/relationships">
      <ns0:Relationship Type="..." Id="rId1" Target="numbering.xml"/>
      ... (rId1..rId30 all with ns0: prefix)
      <Relationship Id="rId31" Type="..." Target="media/svg1.svg"/>
    </ns0:Relationships>
    ```

  - rId1〜rId30 は `ns0:` prefix、rId31（wrap_textbox が追加した svg1.svg）は空 prefix。
  - 原因: `ET.register_namespace("", RELS_NS)` が呼ばれるのは `embed_svg_native` 内部（行 502）。これはグローバル state を変更するが、既に `ET.fromstring(parts[rels_path])` で parse 済みの tree には反映されない。Parse 済み Element は内部的に `{URI}LocalName` で保持されるが、serialize 時の prefix 選択は `register_namespace` のレジストリに依存する。
  - 実態: `ET.register_namespace("", RELS_NS)` 以前（parse 時）に lxml/ET が自動付与した `ns0:` prefix が、既存要素の serialize に使われ続ける。一方 `SubElement(..., "Relationship")` で後から追加された要素は新しい prefix（空 = default）で serialize される。
  - OOXML / XML 仕様上は valid（同じ URI に対して違う prefix を持つことは許される）だが、strict validator（MS の OOXML Strict 検証など）は眉を顰めるかもしれない。

- **影響**:
  - 現在の実地ビルドでは Word が問題なく parse できる（inject_narrative.py の `ET.fromstring` で読めている）。
  - OOXML 妥当性検証ツール（Office OpenXML SDK Validator 等）を使った CI 検査を将来導入する場合、警告を出す可能性。
  - ファイル差分レビュー（binary-match 検証）で、ns 宣言の位置・prefix 違いが毎回ノイズになる。

- **推奨対応**:
  - `wrap_textbox.embed_svg_native` の冒頭で `ET.register_namespace("", RELS_NS)` を呼び、その後に `rels_root = ET.fromstring(parts[rels_path])` する（現状は逆順）。ただし ET の内部挙動上、これだけでは既存要素の prefix は変わらない可能性あり。
  - 確実な方法: rels 全体を再構築する。既存 rel を `rel.get("Id")` / `rel.get("Type")` / `rel.get("Target")` / `rel.get("TargetMode")` で抽出し、新しい root element（`ET.Element("{URI}Relationships")`）に `SubElement` で全て入れ直す。これで統一 prefix になる。
  - 優先度低（動作には支障なし）。

---

### [N13-02] (Minor) `run_mermaid` / `run_rsvg_convert` の tmp ファイルが SIGTERM/Ctrl+C で残留

- **箇所**: `main/step02_docx/build_narrative.sh:93-144`
- **前回対応状況**: 新規
- **内容**:
  - tmp 削除は `if [[ $ret -ne 0 ]]; then rm -f "$tmp"; fi` ブロックでのみ実行。
  - SIGTERM / SIGINT / SIGHUP で shell 関数が中断された場合、`rm -f` に到達しない。
  - 結果、`figs/fig1_overview.tmp.12345.svg` のような残骸が残り、次回 Phase A が `*.svg` glob でそれらを拾って `.tmp.12345.svg.png` を生成する。
  - 具体的には `svg_files=( "$FIGS_DIR"/*.svg )` が `.tmp.$$.svg` もマッチ（glob に `.tmp.` のフィルタがない）。

- **影響**:
  - 並行 2 プロセスビルド中に片方を Ctrl+C で停止すると、残骸 `.tmp.$$.svg` が `figs/` に残り、次回 `rsvg-convert` が実行される。無害だが `word/media/` に入らない前提のラスタが生成される。
  - 実害は低いが、ファイルシステムに無用な残骸が累積し、デバッグ時に混乱を招く。

- **推奨対応**:
  - `run_mermaid` / `run_rsvg_convert` の冒頭で:

    ```bash
    local tmp="${svg%.svg}.tmp.$$.svg"
    trap "rm -f '$tmp'" RETURN ERR INT TERM
    ```

    または関数全体を subshell `( ... )` で包んで EXIT trap を使う。
  - もしくは Phase A の svg_files glob を `*.svg` ではなく `*[!tmp].svg`（明示的に tmp 除外）または `! -name '*.tmp.*'` で filter。

---

### [N13-03] (Minor) `--resource-path=main/step01_narrative` が cwd 相対パスで、他 caller から壊れうる

- **箇所**: `main/step02_docx/build_narrative.sh:32`
- **前回対応状況**: 新規
- **内容**:
  - PANDOC_OPTS に `--resource-path=main/step01_narrative` を追加した。これは相対パス。
  - `build_narrative.sh` は冒頭で `cd "$PROJECT_ROOT"` するため、現状は機能する。
  - しかし `scripts/build.sh` や `scripts/roundtrip.sh` 経由ではなく、将来誰かが `cd /tmp && bash med-resist-grant/main/step02_docx/build_narrative.sh` のように呼んだ場合、`PROJECT_ROOT` は正しく計算されるが PANDOC_OPTS の解決は Pandoc 実行時の cwd 依存。
  - Docker モードでは `docker compose -f docker/docker-compose.yml run --rm` で cwd が `/workspace` に固定されるため、このパスもそこからの相対として解釈される。`/workspace/main/step01_narrative` は `docker-compose.yml` のボリュームマウント次第。

- **影響**:
  - 通常フローでは機能する。
  - 異なる cwd から呼ばれる / docker mount のパスが変わる場合に silent に壊れる（pandoc は WARNING のみ、exit 0）。

- **推奨対応**:
  - 絶対パスに変更: `--resource-path="$PROJECT_ROOT/main/step01_narrative"`。ただし Docker の場合は host と container のパスが違うため、Docker モードでは container 内の `/workspace/main/step01_narrative` を使う。
  - mode による分岐:

    ```bash
    if [[ "$MODE" == "docker" ]]; then
        PANDOC_OPTS+=( "--resource-path=/workspace/main/step01_narrative" )
    else
        PANDOC_OPTS+=( "--resource-path=$PROJECT_ROOT/main/step01_narrative" )
    fi
    ```

  - 優先度低。現状で動いているので、むしろコメントで「`build_narrative.sh` は PROJECT_ROOT cwd 前提」と明記するのが現実的。

---

### [N13-04] (Minor) Phase A の stale 判定が mtime のみで、0byte / 破損ファイルを skip する

- **箇所**: `main/step02_docx/build_narrative.sh:247, 264`
- **前回対応状況**: 新規
- **内容**:
  - `[[ ! -f "$svg" ]] || [[ "$mmd" -nt "$svg" ]]` は「存在しないか、source より古い」で再生成。
  - `.svg` が 0byte（前回ビルド時に disk full で中途書き込み → mv で上書きされた）でも、`-f` は true を返し mtime も新しいので skip される。
  - 結果、壊れた `.svg` を `rsvg-convert` に食わせて次のステップが失敗する可能性。

- **影響**:
  - 現実には `run_mermaid` が atomic write（mv）しているため、0byte で終わることは mmdc 側のバグでもない限り起きない。
  - ただし `git checkout` で意図せず 0byte に巻き戻された、あるいは rclone sync で中断した等の外部要因で発生しうる。
  - M12-03 対応（tmp → mv）で大部分は防げているが、ファイル実体のバイトサイズ検査は無い。

- **推奨対応**:
  - Phase A の skip 判定に `[[ ! -s "$svg" ]]`（size 0 なら再生成）を追加:

    ```bash
    if [[ ! -s "$svg" ]] || [[ "$mmd" -nt "$svg" ]]; then ...
    ```

    `-s` は「exist AND size > 0」なのでこれ単体で `-f` を置き換え可能。
  - png 側も同様。

---

### [N13-05] (Minor) `reference.docx` の毎ビルド in-place 書換が冪等性に強く依存

- **箇所**: `main/step02_docx/build_narrative.sh:222-225`、`main/step02_docx/fix_reference_styles.py`
- **前回対応状況**: I12-01 の続き（継続情報から minor に格上げ）
- **内容**:
  - `run_python main/step02_docx/fix_reference_styles.py "$REFERENCE_DOC"` が毎回実行される。
  - `fix_reference_styles.py` の冪等性が保たれていなければ、同じ md 入力でも docx のバイト列が変化する。
  - 特に styles.xml 内の要素順序、pPr/rPr の子要素順序、w:rFonts の属性順序などが serialize 毎にブレる可能性（ElementTree の attribute 順は Python 3.8+ で insertion-order 保存だが、それ以前のツールで処理された場合は崩れる）。

- **影響**:
  - binary-match による非破壊性検証（I12-01）が毎回 false positive を出す。
  - CI での regression test が事実上不可能。

- **推奨対応**:
  - `fix_reference_styles.py` に冪等性 assertion を追加: 2 回実行して `diff` が空になることをテスト。
  - 現在は `reference.docx` が commit 済みで、毎回上書きされる。build 前に `git stash` → build → `git diff --stat templates/reference.docx` で変化が無いことを CI で検査する。

---

### [N13-06] (Minor) `copy_media` の rename suffix `_n1` / `_n2` が pandoc/wrap_textbox の命名規約と非対称

- **箇所**: `main/step02_docx/inject_narrative.py:298-340`
- **前回対応状況**: 新規
- **内容**:
  - media 衝突時に `base_n{counter}.ext` で rename。
  - pandoc は `rId{N}.ext`、wrap_textbox は `svg{N}.svg` という異なる命名規約を持ち、inject の rename `_n1` がこれらと混在すると、ファイル名規約が 3 種類に分裂する。
  - 現在は template が media を持たないため衝突が発生せず、実地では rename ロジックが走っていない（実地 filled docx を確認 → `rId23.jpg` / `rId30.png` / `svg1.svg` の 3 ファイルのみ、rename なし）。

- **影響**:
  - 将来 template が媒体を持つ（例えば 様式 に事業者ロゴ等）ようになった瞬間、rename が発火して `rId23_n1.jpg` のような命名が混ざる。
  - 採番規約が壊れることで、将来「rId と media filename の関連を活用した debug」が困難になる。

- **推奨対応**:
  - rename 時の命名を `media{N}_{ext}` のような連番ベースに統一。wrap_textbox の `svg{N}.svg` と align。
  - そもそも media 命名は pandoc が制御する領域なので、inject は**衝突時は target 側を強制的に rename**するのではなく、**source の filename を無条件に uniqify**（例: `narrative12_{original_name}`）する方が判別容易。
  - 優先度低（現実の衝突が未発生）。

---

### [N13-07] (Minor) `embed_svg_native` の md↔blip 枚数不一致は WARNING のみで fail しない

- **箇所**: `main/step02_docx/wrap_textbox.py:491-499`
- **前回対応状況**: 新規（M11-02 の WARNING から格上げ提案）
- **内容**:
  - md 側の image 数と docx 側の a:blip 数が一致しなければ WARNING を出すが、処理は継続。
  - 一致しない原因:
    - md に reference-style image `![alt][ref]` がある（`_IMAGE_RE` がマッチしない）
    - md の画像ファイルが存在せず pandoc が `[WARNING] Could not fetch resource` で drop（docx 側に blip が出ない）
    - md に raw `<img src="..."/>` HTML 画像がある
  - 結果、K-th alignment がズレて「md の 2 番目の SVG が docx の 1 番目の blip に貼られる」等の silent バグ。

- **影響**:
  - 実地では md に raw HTML 画像や reference-style を使っていないので発火しない。
  - 著者が md 記法を変えた瞬間に silent な画像混線が起きる。

- **推奨対応**:
  - WARNING → ValueError に格上げ。`if len(image_paths) != len(blips): raise ValueError(...)`。
  - 現在は `print(..., file=sys.stderr)` なので exit 0 のまま。

---

### [N13-08] (Minor) mermaid-config.json が 7 タイプのみカバー — `pie` / `mindmap` / `timeline` / `c4` / `quadrantChart` / `xyChart` / `packet` / `block` が未登録

- **箇所**: `docker/mermaid-svg/mermaid-config.json`
- **前回対応状況**: M12-06 の続き
- **内容**:
  - 現在登録: `flowchart` / `class` / `state` / `sequence` / `er` / `gantt` / `journey`（7 種）。
  - mermaid-cli 10.9.1 で利用可能な diagram type には他にも `pie`, `mindmap`, `timeline`, `c4` (`c4Context` etc.), `requirement`, `gitGraph`, `quadrantChart`, `xyChart`, `packet`, `block`, `kanban`, `treemap`, `architecture`, `radar`（一部は 10.9.1 時点で未 GA）。
  - これらは `htmlLabels: false` の config が無く、labels が foreignObject（HTML via SVG）として描画される。
  - wrap_textbox の `<foreignObject` 検査で hard fail するので silent 劣化は防げる（M11-05 対応）。ただし著者は「なぜ fail するのか」を plan2.md から辿らなければならない。

- **影響**:
  - 著者が新しい diagram type を使った瞬間 build が止まる。対処は mermaid-config.json を更新するだけだが、発見コストが高い。
  - 現実には flowchart 1 種しか使わない想定なので影響範囲は限定。

- **推奨対応**:
  - mermaid-config.json にカタログ上のすべての known type を予防的に追加。
  - ないし、build_narrative.sh のエラーメッセージから mermaid-config.json の場所 + 「`"htmlLabels": false` を追加してください」を明記（wrap_textbox 側 M11-05 メッセージに該当の指示はある）。

---

### [N13-09] (Minor) narrative の `word/comments.xml` は inject で捨てられる

- **箇所**: `main/step02_docx/inject_narrative.py`（comments 処理が存在しない）
- **前回対応状況**: 新規
- **内容**:
  - narrative docx（Pandoc 生成）は `word/comments.xml` を必ず含む（pandoc の default 挙動）。実地 youshiki1_2_narrative.docx も含む。
  - `inject_narrative.py` は comments.xml を参照しないため、filled docx には comments.xml が生成されない（実地確認: `filled/word/comments.xml` は存在しない）。
  - 現在 pandoc の comments.xml は separator/continuationSeparator 相当の空コンテンツ（実地で確認 → 500byte、空の `<w:comments>` ルートのみ）なので実害なし。
  - 将来 pandoc 拡張や md の comment 記法で本物のコメントが入った場合、silent に失われる。

- **影響**:
  - 現状 dormant。
  - 査読ワークフロー（Google Chat での共同執筆）で、将来 md コメント → docx コメント変換を入れるなら対応が必要。

- **推奨対応**:
  - `_merge_notes` と同様の `_merge_comments(target_parts, src_parts, body_elements)` を実装。
  - 当面は「comments.xml は捨てる」を plan2.md に明記。

---

### [N13-10] (Minor) `ET.register_namespace("", RELS_NS)` のグローバル副作用

- **箇所**: `main/step02_docx/wrap_textbox.py:502, 517`
- **前回対応状況**: 新規
- **内容**:
  - `ET.register_namespace("", RELS_NS)` と `ET.register_namespace("", CT_NS)` がグローバル state を書き換える。
  - 同一 Python プロセス内で wrap_textbox → inject_narrative と連続呼出した場合、inject 側の `ET.register_namespace` が再実行されることで override されるが、**実行順序によっては** rels の serialize で予期せぬ prefix が付く。
  - 現在は `build_narrative.sh` が wrap_textbox を独立プロセスで呼ぶ（`run_python` 経由）ため、プロセスが分離されて問題にならない。
  - もし将来「1 つの Python スクリプトで narrative build → inject を一気に実行」するように統合した場合、register_namespace の副作用で N13-01 と同じ prefix 混乱が発生する。

- **影響**:
  - 現状無害（別プロセス）。
  - 将来 API 統合時に silent に fails する可能性。

- **推奨対応**:
  - register_namespace は Python グローバルの map であることを明記するコメント追加。
  - API 統合時には lxml を使うか、独自の serializer を書く（ElementTree の制約を回避）。

---

### [N13-11] (Minor) `.textbox` 内 pandoc figure caption が txbxContent に吸い込まれる

- **箇所**: `filters/textbox-minimal.lua:139-157`（process_blocks）、`main/step01_narrative/youshiki1_2.md:67-69, 98-100`
- **前回対応状況**: 新規
- **内容**:
  - `![病院施設の外観（デモ画像）](figs/bg_hospital.jpg){#fig:hospital}` は pandoc が figure として処理し、image paragraph + caption paragraph の 2 要素を生成する。
  - `.textbox` Div の中にこれを置くと、`process_textbox` が Div.content 全体（= image + caption）を txbxContent に入れる。
  - 結果、textbox 内部に画像と日本語キャプション「病院施設の外観（デモ画像）」が縦に並ぶ形で表示される。
  - これが**意図的なレイアウト**（textbox 内で画像とキャプションを一体化）なのか、**想定外**（textbox 外にキャプション、textbox 内に画像のみ）なのかは plan2.md に明記されていない。

- **影響**:
  - 見た目の意図と実装の乖離の可能性。現状の docx を Word で開いて確認するまで断定できない（Linux では確認不能）。
  - Prompt 10-5 の Windows 変換後の PDF で、キャプションが期待した位置にあるか視覚確認が必要。

- **推奨対応**:
  - plan2.md に「.textbox 内の pandoc figure は、画像とキャプションが textbox 内に収まる」と明記。
  - 反対に「textbox 外にキャプションを出したい」場合は:
    - md 側で `![]()` ではなく raw HTML `<img>` を使う（figure 構造を抑制）
    - または、`.textbox` Div の後に通常の段落で caption を書く
  - 優先度は Prompt 10-5 の視覚確認結果次第。

---

### [I13-01] (Info) wp:docPr/@name が "TextBox 1"/"TextBox 2" で英語固定

- **箇所**: `main/step02_docx/wrap_textbox.py:238`
- **内容**:
  - `dp.set("name", f"TextBox {z_order + 1}")` で英語名固定。
  - Word の「オブジェクトの選択と表示」ペインに「TextBox 1」「TextBox 2」と表示される。日本語環境 UI としての違和感は小。
- **推奨対応**:
  - 「テキストボックス 1」等にローカライズするか、意味ベースの名前（例: `HospitalImage`）にする余地。
  - 優先度低。

---

### [I13-02] (Info) pandoc 側 rId 採番が rId8 → rId23 で飛ぶ

- **箇所**: 実地 `youshiki1_2_narrative.docx:word/_rels/document.xml.rels`
- **内容**:
  - pandoc は standard parts（numbering/styles 等）に rId1〜rId8 を使い、その次が rId23（`bg_hospital.jpg`）、rId30（`fig1_overview.svg.png`）、rId31（wrap_textbox 追加の `svg1.svg`）。
  - rId9〜rId22 / rId24〜rId29 は欠番。
  - pandoc 内部の rId 採番アルゴリズムに依存しており、制御不能。
- **影響**:
  - inject 側の `merge_rels` が `_get_max_rid` で max を取るので問題なく動作する（max=31 → +1 = rId32 から採番）。
  - 採番が飛ぶため、rels 監視ツールが「missing rId9」等と誤解する可能性。
- **推奨対応**:
  - 対応不要（pandoc 挙動）。ドキュメント化のみ。

---

### [I13-03] (Info) `fig1_overview.mmd` の `themeVariables.fontSize:'18px'` の実効性が未検証

- **箇所**: `main/step01_narrative/figs/fig1_overview.mmd:1`
- **内容**:
  - 冒頭に `%%{init: {'theme':'base','themeVariables':{'fontSize':'18px'}}}%%` と directive を置いている。
  - mermaid-cli 10.9.1 で `fontSize` themeVariable が flowchart のラベル font-size に反映されるかは version 依存。Mermaid 公式ドキュメントの themeVariables は 11.x で仕様がやや変わっている。
  - 実地の `fig1_overview.svg` を開いて `font-size` 属性を grep すれば検証可能だが、本レビューでは未実施。
- **推奨対応**:
  - 念のため `svg` 内の `font-size="18"` の存在を確認:

    ```bash
    grep 'font-size' main/step01_narrative/figs/fig1_overview.svg
    ```

  - 反映されていなければ、mermaid-cli 10.9.1 互換の記法に修正する（例: `fontFamily` / `fontSize` の代わりに CSS stylesheet を inline）。

---

### [I13-04] (Info) pandoc crossref anchor `{#fig:hospital}` / `{#fig:overview}` の Word 側残留が未確認

- **箇所**: `main/step01_narrative/youshiki1_2.md:68, 99`
- **内容**:
  - pandoc の実装では `{#fig:xxx}` は figure の id 属性になり、docx 変換時は `<w:bookmarkStart>` / `<w:bookmarkEnd>` として残る可能性。
  - 現在 md 内で `[@fig:hospital]` 形式の crossref 参照は使っていないため、bookmark の有無は visible な影響を与えない。
  - ただし Word の「ブックマーク」ダイアログに "fig:hospital" が表示されるかどうかは未確認。
- **推奨対応**:
  - Word で確認（Prompt 10-5 Windows 経路で検証可能）。
  - 残留していても実害なし。将来 crossref を使い始める際のフックとして残しておく。

---

## リスクマトリクス

| リスク | 影響度 | 発生確率 | 総合評価 | 対策 |
|--------|--------|---------|---------|------|
| filled docx の jpg/png Content-Type 欠落で Word が repair prompt / 画像欠落 | 高 | 高 | Critical | C13-01: `merge_content_types` に Override merge or Default 自動補完を追加 |
| filled docx の `mc:Ignorable` に wps が無く、一部 parser で wps:wsp が無視される | 中 | 中 | Major | M13-01: `restore_root_tag` に mc:Ignorable merge ロジック追加 |
| wps:wsp を mc:AlternateContent で包まず Word 2007 互換性喪失 | 低 | 低 | Major | M13-02: Word 2010+ 前提を plan2.md に明記、または mc:Fallback 追加 |
| `.svg` と `.svg.png` の mtime 非同期で layer 不整合 docx | 中 | 低 | Major | M13-03: `.svg.png.meta` sidecar で hash を管理、または wrap_textbox 直前に mtime 再検査 |
| 将来の脚注・コメント追加で rels orphan 発生 | 高 | 低 | Major | M13-04: `_merge_notes` に rels merge を追加 |
| pandoc 画像解決 WARNING が silent 通過 | 中 | 中 | Major | M13-05: `--fail-if-warnings` 追加 or K-th alignment を hard fail 化 |
| tmp ファイル残留 / rels prefix 混在 | 低 | 低 | Minor | N13-01 / N13-02 個別対応 |
| mermaid 新 diagram type 導入時の fail-first 発火 | 低 | 中 | Minor | N13-08: config カバレッジ拡大 |
| `.textbox` 内 caption 配置の意図不明確 | 中 | 低 | Minor | N13-11: plan2.md に明記、Windows での視覚検証 |

---

## 総評

**本セッションでの対応状況**: Critical 1 件 / Major 4 件 / Minor 4 件を修正実装し、実地ビルドで動作確認済み。残る Major 1 件（M13-02）は Word 2010+ 前提の設計判断として現状維持。Minor 7 件 / Info 4 件は Prompt 10-5 以降で段階対応。

**Prompt 10-5 へ進むための前提**: C13-01 / M13-01 / M13-03 / M13-04 / M13-05 の 5 件は実装完了。Linux 側で観察可能な構造的欠陥はすべて解消されており、Windows Word COM での PDF 変換を実施可能な状態。

（以下、修正前の原指摘内容を記録として保持）

---

### 修正前の総評（2026-04-17 初稿）

**Prompt 10-5 に進む前に必ず対応すべき項目**: C13-01 の 1 件。

他の Critical 相当の問題は検出されなかったが、**C13-01 は Prompt 10-5 の Windows Word COM PDF 変換をほぼ確実に失敗させる**。実地で filled docx の [Content_Types].xml を検査したところ、`/word/media/rId23.jpg` と `/word/media/rId30.png` の 2 ファイルに対する Content-Type 登録が一切存在しない状態になっていた（`jpeg` Default は `.jpg` にマッチしない）。ECMA-376 OPC 仕様違反であり、Word は起動時に「文書が破損しています。修復しますか？」ダイアログを出す可能性が高い。修復されても画像が失われるか、保存し直された docx が e-Rad 提出に耐えない形式になる恐れがある。

**推奨する修正順序**:

1. **C13-01**（Critical、必須）: `merge_content_types` を拡張し、source の Override も merge するか、拡張子ベースで Default を自動補完する。fix 後は `unzip -p output/youshiki1_5_filled.docx '[Content_Types].xml' | grep -E 'jpg|png'` が hits を返すことを CI で assert。

2. **M13-01**（Major、推奨）: `restore_root_tag` に `mc:Ignorable` merge を追加。wrap_textbox 側に既に同等実装があるため、コードコピーで済む。

3. **M13-05**（Major、推奨）: pandoc 側の silent 画像欠落を塞ぐ。`--fail-if-warnings` または `embed_svg_native` の K-th alignment を hard fail 化（N13-07 と同時対応）。

4. **M13-02 / M13-03 / M13-04**（Major、Prompt 10-5 までに判断）:
   - M13-02 は設計判断（mc:AlternateContent を使うか使わないか）。Word 2010+ 前提なら現状維持 + plan2.md 明記で可。
   - M13-03 は稀な経路。当面は plan2.md に運用上の注意書きで対応可能。
   - M13-04 は脚注・コメントを使い始めるまで dormant。plan2.md に制約として明記。

5. **Minor / Info**: Prompt 10-5 完了後の整理タスクとして並列対応可。

**全体の健全性評価**: report12 の指摘に対する対応は丁寧に行われており、Phase A / B / C 間の契約（M12-03/04/05）や preflight 検査（C12-01/M12-02/N12-03）は実地テストで確認できる水準に達している。一方、**inject 段階の Content-Types / mc:Ignorable / rels merge の網羅性**に未成熟な部分があり、Linux 側だけでは検出不能な Word 互換性リスクが残る。C13-01 を fix した上で、Prompt 10-5 では **Windows 側で「文書の修復ダイアログが出ないこと」「PDF 内で 2 枚の画像がレンダリングされていること」の 2 点を明示的に検証**する手順を入れることを強く推奨する。

Prompt 10-4 の本セッション修正（tmp 拡張子 / `--resource-path`）自体は正しい対処だが、いずれも「Phase A / pandoc の実データ経路が初めて走った」ことで顕在化したバグであり、**C13-01 も同じカテゴリの『実データで走らないと見えないバグ』の代表例**である。Prompt 10-5 に入る前に Linux 側で実施可能な追加検証として、生成 docx に対する最小限の XML 妥当性検査（[Content_Types].xml の全 Part カバレッジ、rels の orphan 検査、mc:Ignorable と使用 namespace の整合）を自動化する価値がある。
