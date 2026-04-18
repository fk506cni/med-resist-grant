# 敵対的レビュー報告書（第11回）— Prompt 10-2 成果物

レビュー実施日: 2026-04-15
レビュー対象:
- `filters/textbox-minimal.lua`（94 行）
- `main/step02_docx/wrap_textbox.py`（568 行）
- （統合点検証のため参照）`main/step02_docx/inject_narrative.py`

前回レビュー: `docs/__archives/report10.md`（2026-04-15、対応結果含む）

---

## サマリ

- **Critical**: 2 件（新規 2 / 既知未対応 0） — **全件対応済み**
- **Major**: 9 件（新規 8 / 既知未対応 1＝M10-02 連動安全装置の未実装） — **9 件対応済み**
- **Minor**: 6 件（新規 6） — **6 件対応済み**
- **Info**: 3 件（新規 2 / 継続 1＝I10-03） — Info は記録のみ（I10-03 継続）

本レビューで指摘した **Critical 2 / Major 9 / Minor 6 の計 17 件すべて**について、
同一セッション内で修正を実施し Docker 経由のスモーク + dummy データ E2E（`./scripts/build.sh`）
で回帰無しを確認した。詳細は末尾「## 対応結果（2026-04-15 追記）」を参照。

### 対応状況一覧

| ID | 重大度 | 状態 | 概要 |
|----|--------|------|------|
| C11-01 | Critical | ✅ 対応済み | `_strip_yaml_and_code` の fenced-code 正規表現が壊れており、SVG blip のインデックス対応が崩れて Word 表示破綻 |
| C11-02 | Critical | ✅ 対応済み | `textbox_marker()` が `params` 文字列を `<w:t>` に**未エスケープ**で連結 — 属性値に XML 特殊文字が混入すると `document.xml` が parse error で Word が開けない |
| M11-01 | Major | ✅ 対応済み | `embed_svg_native` の画像パス抽出正規表現が reference-style / angle-bracket URL / HTML コメント内 / inline code 内を区別せず、K 番目対応がズレる |
| M11-02 | Major | ✅ 対応済み（カウント検証導入） | `embed_svg_native` の K 番目対応は `md_text` 順と `root.iter(a:blip)` 順が一致する前提だが、Pandoc の figure 生成（図番化）や captioned image 展開でインデックスが容易にズレる |
| M11-03 | Major | ✅ 対応済み | `FileNotFoundError` での hard-fail に `--skip-missing` の逃げ道が無く、執筆中途（SVG 未生成）の `./scripts/build.sh` 全体がストップする運用リスク |
| M11-04 | Major | ✅ 対応済み | `process_blocks` が top-level のみ走査するため、将来 `.textbox` を blockquote / ordered list / 別 Div に入れ子にした瞬間 silent pass-through になりデバッグ困難 |
| M11-05 | Major | ✅ 対応済み (旧 M10-02 連動メモ) | `embed_svg_native` 内での `<foreignObject>` 検出時の安全装置が**未実装**。report10 の残課題として明記されていたもの |
| M11-06 | Major | ✅ 対応済み | `--no-relocate` は `action="store_true", default=True` で常に True、off にする手段が無い**デッド引数**（UX バグ） |
| M11-07 | Major | ✅ 対応済み | `reference.docx` に `TextBoxMarker` 段落スタイルが未定義 — Word は未定義 styleId を silent で Normal にフォールバックするが、`vanish` が run にしか載っておらず**段落マーク分の高さが残る**可能性 |
| M11-08 | Major | ✅ 対応済み | `inject_narrative.py` は body 内の `wp:docPr/@id` を renumber しない。`--docpr-id-base` を narrative ごとに分けてあっても、Step 10 で **テンプレート既存 docPr 0 件**という前提が将来崩れたら即衝突する（モニタ無し） |
| M11-09 | Major | ✅ 対応済み | `wrap_textbox.NSMAP` に `w14 / w15` が無い。`extract_root_tag` → `restore_root_tag` 経由で原文の `w14 / w15` 宣言は保存されるが、ET の再シリアライズで body 内の `w14:paraId` 等が `ns0:` prefix で吐き直される可能性 |
| N11-01 | Minor | ✅ 対応済み | Lua Image filter の `.svg$` 判定は `.svg.png` に 2 度目を当てないが、`.SVG`（大文字）は素通し。将来の移植時の罠 |
| N11-02 | Minor | ✅ 対応済み | Lua フィルタが空 `.textbox`（`div.content == {}`）でもマーカー対だけ emit し、`wrap_textbox` が zero-content anchor を作り `cx=0 / cy=0` の空テキストボックスを生成可能 |
| N11-03 | Minor | ✅ 対応済み | `resize_images_in_content` は `a:ext` を全 `iter` するため `a:extLst > a:ext`（URI ベースの拡張 ext）を巻き込む可能性。現状は `cx` 属性を持たず無害だが堅牢性低 |
| N11-04 | Minor | ✅ 対応済み | `_strip_yaml_and_code` の front-matter 除去が `\n` 固定。CRLF（BOM 付き Windows 保存）で silent ミス |
| N11-05 | Minor | ✅ 対応済み | `extract_root_tag`/`restore_root_tag` は `mc:Ignorable` という**文字列**で検索しており、既存 tag のコメント等に同名文字列があると誤検出の余地（極めて低確率） |
| N11-06 | Minor | ✅ 対応済み | `restore_root_tag` が最終的に `wp14` を常に Ignorable に追加するが、`wp14` は実際には Ignorable 対象として適切でない（Word は `wp14` を通常 consuming namespace として扱う）。無害だが semantic には不正確 |
| I11-01 | Info | 記録のみ | `build_textbox_paragraph` 内で `l_ins / r_ins` が 45720、`t_ins / b_ins` が 0 と**ハードコード**。テキストボックスの `margin-*` 属性を将来入れるなら明記が必要 |
| I11-02 | Info | 記録のみ | `wp:anchor` の `distL / distR = 114300` も固定値。`.textbox` 属性から受けられるようにすべき |
| I10-03 | Info | 継続 | `mermaid-build` サブコマンド（report10 残）— 本プロンプトではスコープ外 |

---

## report10.md との差分サマリ

- **前回の未対応項目で今回解消されたもの**: 0 件（Prompt 10-2 成果物の新規実装であり、report10 段階では wrap_textbox.py / textbox-minimal.lua は未存在）
- **前回の未対応項目で依然として未対応のもの**: 1 件
  - M10-02 連動メモ: 「`embed_svg_native` 内で `<foreignObject>` 検出時に非ゼロ exit を上げる安全装置追加を検討」 → **未実装**。本報告で **M11-05** として再掲。
  - I10-03（`mermaid-build` サブコマンド）: 継続、スコープ外
- **前回に記載が無く今回新規発見したもの**: 19 件（C11-01/02, M11-01/02/03/04/06/07/08/09, N11-01〜06, I11-01/02）
- **前回の C10-01 / C10-02（`<foreignObject>` / configFile）との関係**: report10 で mmdc 側の configFile 化により `<foreignObject>` は 0 件に抑制済み。本件 M11-05 は**二段目の防衛線**（mmdc 側が将来壊れた場合に Word で silent drop されるのを embed 側で catch する）としての安全装置であり、Critical → Major に格下げ。

---

## 指摘事項

### [C11-01] (Critical) `_strip_yaml_and_code` の fenced-code 正規表現 `r'```[^`]*```'` が壊れている
- **箇所**: `main/step02_docx/wrap_textbox.py:344`
- **前回対応状況**: 新規
- **内容**:
  - 現行の正規表現 `r'\`\`\`[^`]*\`\`\`'` は「バッククォートを含まない本文」で囲まれた fenced code しか剥がせない。
  - 以下のケースが**全て**素通しになる:
    - 4-backtick fence（````md ... ```ネストした ```python ...``` ... ```` ```` ）
    - `~~~` fence（tilde fence はそもそも対象外）
    - inline code ``` `![](fake.svg)` ``` — 本文扱いで残り
    - HTML ブロック内の `<!-- ![](fake.svg) -->`（このクラスは一切除去していない）
  - 剥がし損ねた code block / comment 内の `![]()` は `re.findall(r'!\[.*?\]\(([^)\s]+)')` に **Markdown の画像として** 拾われ、`md_text` 側の image 順序に偽陽性が混入する。
  - 一方、`document.xml` 側の `a:blip` は pandoc がレンダリングした本物の画像のみ。
  - → K 番目対応（`svg_images` の `img_idx` ↔ `blips[img_idx]`）が**オフバイ N** でズレ、別画像の blip に `asvg:svgBlob` を注入する、もしくは `Warning: no matching blip` で SVG が埋まらない。
- **影響**: 本文中に 1 つでも `~~~` fence / inline code / コメントで `![]()` に見える文字列が混じった瞬間、SVG 埋込み先が別画像に付く。Word 上では**誤った画像の位置にベクタ描画**が表示され、最悪本番提出で図が崩壊する。ユニットテストでは気づきにくい（ホスト pandoc / Word 非表示では silent）。
- **推奨対応**:
  - 根本策: md 本文の画像抽出は正規表現をやめ、**同じ pandoc フィルタ（Pass 1 の Image walker）で順序付きリストを書き出させる**か、あるいは `asvg:svgBlob` を Lua 側で直接 RawInline として埋め込む（元の jami-style.lua に無い機能だが信頼性が高い）。
  - 妥協策: 最低限 `(?s)^\s*(~~~|\`\`\`+)[^\n]*\n.*?\n\1\s*$` のフェンス対応正規表現にし、inline code (`` ` ... ` ``) と HTML コメント `<!-- ... -->` も剥がす。`(?m)` と `re.MULTILINE` の使い分けも整える。

### [C11-02] (Critical) `textbox_marker()` が `params` 文字列を XML エスケープせずに `<w:t>` に連結
- **箇所**: `filters/textbox-minimal.lua:28-33`
- **前回対応状況**: 新規
- **内容**:
  - Lua 側で `'<w:t>' .. text .. '</w:t>'` と**単純連結**している。
  - `text` には `anchor-h / anchor-v / wrap / behind / valign` のユーザー指定文字列が埋まる（`process_textbox` で `attrs["wrap"] or "tight"` として流し込み）。
  - ユーザが Markdown 側で `.textbox wrap="tight<evil>"` や `anchor-h='page&other'` と書いた瞬間に `<`, `>`, `&`, `"` が生の OOXML に混入し、pandoc が吐く `document.xml` は XML として壊れる。
  - 同じリスクが `to_emu` 経由の数値にはない（`math.floor` 後の `string.format("%d")` で整数化されるため）が、文字列パラメータは全滅。
- **影響**:
  - `wrap_textbox.py` 側で `ET.fromstring(doc_xml)` が parse error で即死（スタックトレースを出して exit 1）。
  - 悪意ある Markdown でなく、単なる typo（二重ダブルクォート、HTML 風タグのコピペ）でも即死する。
  - 最悪ケース: 空白つき属性が `<w:t>` に埋まり**見た目は動くがマーカー検出が silent 破綻**する。例: `valign="top\"`。
- **推奨対応**:
  - `textbox_marker` の中で `text:gsub("&","&amp;"):gsub("<","&lt;"):gsub(">","&gt;"):gsub('"',"&quot;")` を掛ける。
  - あわせて `process_textbox` で許可済み enum 値（`top/bottom`、`tight/square/none`、`page/margin/paragraph`）以外を **fail-fast** させるホワイトリストを導入。

### [M11-01] (Major) `embed_svg_native` の画像パス抽出正規表現が脆弱
- **箇所**: `main/step02_docx/wrap_textbox.py:362`
- **前回対応状況**: 新規
- **内容**: 正規表現 `r'!\[.*?\]\(([^)\s]+)'` は以下のどれでも破綻する。
  1. **reference-style image** `![alt][ref]` … そもそも match しない（`svg_images` に入らない → インデックスがズレる）
  2. **angle-bracket URL** `![alt](<figs/my fig.svg>)` … `<figs/my` で止まる
  3. **escaped `)` をパス内に持つケース** `![](./a\).svg)` … `[^)]` で止まる
  4. **alt text 内の `]`**（CommonMark はエスケープを許容） … `.*?` が最短で止まる
  5. **改行を跨ぐ alt** `![line1\nline2](...)` … `.` は改行非マッチのため break
  6. **path に URL encode された space**（Pandoc 出力）は動くが、**生 space のパス**は動かない
- **影響**: C11-01 と同様、md_text 側の image 順序から SVG が欠落 or 誤検出され、`a:blip` との K 番目対応がズレる。
- **推奨対応**: 上述の C11-01 と合わせ、**正規表現による Markdown 解析をやめる**。Lua 側で `Image` を収集して `asvg`埋込みの手がかりを出すか、pandoc JSON AST を一度経由するなど。

### [M11-02] (Major) K 番目対応（`md_text` 画像順 ↔ `root.iter(blip)` 順）が Pandoc の内部挙動に依存
- **箇所**: `main/step02_docx/wrap_textbox.py:404-409`
- **前回対応状況**: 新規
- **内容**:
  - 「md の K 番目の画像」と「document.xml 内の K 番目の `a:blip`」が等しい保証は無い。
  - Pandoc は implicit_figure を有効にすると `![caption](img.svg)` を `Figure` に昇格するが、**figure 内にも通常の `a:blip` が 1 つだけ**入るので、**単純な画像だけの文書では** 実は 1:1。
  - ただし以下で崩れる:
    - `OrderedList` / `BulletList` の item 内画像（ネスト順 vs. body flat 順）
    - `.textbox` Div 内に画像がある場合、**wrap_textbox 実行前**の `embed_svg_native` 呼び出しでは body 直下の inline drawing として扱われるため順序は維持されるが、**Markdown 側が `.textbox` 外で別の画像を挟んでいる**と順序が崩れうる
    - Pandoc の lua filter で Image が書き換えられた場合（今回は `.svg → .svg.png` なので src 変更のみ）
    - 将来、inject_narrative.py 経由で複数 narrative を結合した後に `embed_svg_native` を掛けるような運用に変わった場合
- **影響**: **2 枚以上の SVG を同一 md に置いた瞬間に順序崩壊のリスクが顕在化**。md 上の 1 枚目 SVG が document.xml の 2 枚目 blip に注入されるなど、誤った位置に vector 化が起きる。LibreOffice / Windows Word でレンダリング差が出るまで気付かない可能性がある。
- **推奨対応**:
  - **Pandoc の lua filter 側で Image に `asvg-src` 属性を書き込み**、wrap_textbox は document.xml を走査して `pic:pic` の `pic:cNvPr@name` か `docPr@descr` と突き合わせる。
  - 代替: `a:blip/@r:embed` の rId から `rels` → `Target`（`media/imageN.png` ファイル名）を辿り、**同じ basename の `.svg` ソースファイル**を探す方式にすれば、md 順への依存が消える。

### [M11-03] (Major) `FileNotFoundError` に skip-missing の逃げ道が無い
- **箇所**: `main/step02_docx/wrap_textbox.py:413-415`
- **前回対応状況**: 新規（Prompt 10-2 仕様で意図的に hard-fail 化した C09-01 対応の副作用）
- **内容**:
  - `svg_full_path` が無い場合に `FileNotFoundError` で即死する設計は CI 上は正しいが、**執筆中（まだ `figs/fig3.svg` を作っていない段階でコンパイル確認したい）の UX が極端に悪化**する。
  - `.textbox` Div 以外の普通の `![]()` も同じ経路で拾われるため、「1 枚 SVG が欠けると `./scripts/build.sh` 全体が落ちる」状況になる。
  - 開発中の try-and-error で `--skip-missing` 相当の緩和がない。
- **影響**: 運用ストレス、PR ブランチでの中間ビルド不可、`data/dummy/` E2E でダミー SVG を用意し忘れると CI 落ち。
- **推奨対応**:
  - `--skip-missing-svg` フラグを追加し、デフォルト False（CI 動作）・`./scripts/build.sh` 経由で開発時だけ True にする。
  - 緩和時は `print(f"  SKIP: {svg_path} (missing, asvg layer skipped)")` を STDERR に出す。

### [M11-04] (Major) `process_blocks` が top-level のみ走査 — ネスト `.textbox` が silent pass-through
- **箇所**: `filters/textbox-minimal.lua:65-75`
- **前回対応状況**: 新規
- **内容**:
  - `process_blocks` は `doc.blocks` の直下しか見ない。`.textbox` Div が以下の内側にあると検出されず、単なる Div として素通しされる。
    - `Blockquote` 内
    - `Div` 内（custom-style / class 付きの上位 Div）
    - `OrderedList / BulletList / DefinitionList` 内
  - 一方、upstream `jami-style.lua:72-95` は相互再帰で子 Div にも降りる。該当コードを削ったのが本プロンプト。
- **影響**:
  - 執筆者が `> ::: {.textbox ...} ... :::` と書くと**何のエラーも出ずに**素通しされ、`wrap_textbox.py` では `No TextBoxMarker regions found` と出るだけ。ミスに気付けない。
  - Prompt 10-2 の現時点では `.textbox` 未使用のためスモークテストでは検知不可能。
- **推奨対応**:
  - `process_blocks` を**再帰化**する（top-level 以外の位置で `.textbox` を検出したら `warn` を emit し top-level に持ち上げる or error にする）。
  - もしくは最低限、`doc.blocks` walk 後に `pandoc.walk_block` で残存 `.textbox` を探し、見つかったら `io.stderr:write(...) os.exit(1)` で即死させる。

### [M11-05] (Major, 継続) `<foreignObject>` 検出時の安全装置が未実装（report10 残課題）
- **箇所**: `main/step02_docx/wrap_textbox.py:348-461`（embed_svg_native 全体）
- **前回対応状況**: report10 の M10-02 対応結果欄に「embed_svg_native 内の安全装置追加は Prompt 10-2 で検討」と明記されていた課題が**未着手**。
- **内容**:
  - mermaid-cli の `<foreignObject>` 出力抑制は configFile（`htmlLabels:false`）で flowchart / sequenceDiagram のみ確認済み。class/state/gantt/pie/mindmap 等で silent 再発する可能性が残る。
  - `embed_svg_native` は SVG を**バイナリのまま**読み込んで `parts[...]` に追加するだけで、中身の検査をしない。`<foreignObject>` が入ったまま Word に流れ込むと Windows 本番で空白四角表示になる。
  - 防衛線として「SVG を読み込んだ直後に `b"<foreignObject"` を substring 検索し、見つかったら `raise ValueError` で hard-fail」するコードが 2 行で書ける。
- **影響**:
  - Step 10 全体の定着後、新しい mermaid 図種（class/state 等）を追加した際に**本番 Word PDF だけで発覚**する silent regression を許す。
  - 対策の成否を roundtrip.sh 経由の Windows 目視確認でしか検出できない状況が続く。
- **推奨対応**:
  ```python
  if b"<foreignObject" in svg_data:
      raise ValueError(
          f"{svg_full_path}: SVG contains <foreignObject> — Word will render as "
          f"blank rectangles. Regenerate with htmlLabels:false / raw <text>."
      )
  ```
  を `svg_data = f.read()` 直後に追加。

### [M11-06] (Major) `--no-relocate` が `action="store_true", default=True` でデッド引数
- **箇所**: `main/step02_docx/wrap_textbox.py:557-558`
- **前回対応状況**: 新規
- **内容**:
  - `default=True` かつ `action="store_true"` だと、コマンドラインで `--no-relocate` を**指定しても**値は True、指定**しなくても** True。
  - 結果として `no_relocate=False` を表現する経路が存在せず、**「互換用に残した」と言っているフラグが実際には完全な dead code**。
  - `process_docx(..., no_relocate=True)` でも同じく、引数として受け取っているだけで内部で使っていない（全分岐が削除済み）。
  - upstream にあった `relocate_textbox_by_page()` を移植しないと決めたなら、**引数そのものを削除すべき**。残すとデッド/紛らわしさの両方でマイナス。
- **影響**:
  - Prompt 10-3 以降で `no_relocate=False` を渡す開発者が現れた場合に silent に効かない（upstream 挙動との認識差でバグ化する可能性）。
  - コードレビュー時の心理的ノイズ。
- **推奨対応**:
  - `--no-relocate` と `no_relocate` 引数を**完全削除**する、または `default=False` にして「指定時に relocate する旧機能を復活させる（ただし実装は削除済みなので ValueError）」に改修。
  - plan2.md §6.2 に「relocate は使わない」と明記しているので削除推奨。

### [M11-07] (Major) `reference.docx` に `TextBoxMarker` 段落スタイルが未定義 — vanish が run のみで段落高さが残る
- **箇所**: `filters/textbox-minimal.lua:30`, `templates/reference.docx`
- **前回対応状況**: 新規
- **内容**:
  - Lua 側は `<w:pStyle w:val="TextBoxMarker"/>` を出すが、`templates/reference.docx` の `styles.xml` には `TextBoxMarker` 定義が**存在しない**（`unzip -p ... word/styles.xml | grep styleId="TextBoxMarker"` で 0 件確認）。
  - Word は未定義 styleId を Normal にフォールバックする。結果、段落自体は hidden 属性を持たない。
  - `vanish` は**run レベル**にしか付与されていない（`<w:rPr><w:vanish/></w:rPr>`）。run の本文テキストは hidden になるが、**段落マーク自体は hidden にならない**ので、段落高さ分の空行が残る。
  - wrap_textbox.py が START/END マーカー段落を body から削除して anchor 段落を挿入するため、**正常系では空行は残らない**が、以下のケースで残留する:
    - `is_textbox_marker` は `w:pStyle` 参照で判定しているのでスタイル未定義でも検出自体は動く（styleId 文字列比較のため問題なし）。
    - しかし START だけあって END が見つからない異常系（途中で parse 失敗 / 誤った Markdown）では、START マーカー段落が body に残って空行として Word 上に出現する。
  - また、upstream では `reference.docx` に `TextBoxMarker` スタイル定義（vanish 属性付き）を入れてあったはず（要確認）。それを剥がした経緯が Prompt 10-2 にない。
- **影響**:
  - 異常系のみで発現するが、Word 側で気付きにくい無言の空行が紛れ込む。
  - 執筆者が reference.docx を更新した際に `TextBoxMarker` 定義の追加を忘れるリスクが残る。
- **推奨対応**:
  - `templates/reference.docx` の `styles.xml` に `TextBoxMarker` スタイル（`<w:style w:type="paragraph" w:styleId="TextBoxMarker"><w:pPr><w:rPr><w:vanish/></w:rPr></w:pPr><w:rPr><w:vanish/></w:rPr></w:style>`）を追加。
  - あわせて Lua 側の `textbox_marker` で段落にも `<w:pPr><w:rPr><w:vanish/></w:rPr>...</w:pPr>` を足し、段落マークごと hidden 化。

### [M11-08] (Major) `inject_narrative.py` は body 内の `wp:docPr/@id` を renumber しない
- **箇所**: `main/step02_docx/inject_narrative.py:643-664`（inject_section）, `main/step02_docx/wrap_textbox.py:208`
- **前回対応状況**: 新規（report10 の M10-03 は plan2.md §7.2 のドキュメント乖離であり、実装レベルの検査機構の不在は新規発見）
- **内容**:
  - plan2.md §7.2 は「テンプレート docx の既存 `wp:docPr` は実測 0 件」を根拠に 1-2=3000 / 1-3=4000 の分離で衝突を回避している。
  - しかし inject_narrative.py には `wp:docPr/@id` の衝突検査も renumber も存在しない。前提崩壊時の**防衛線がゼロ**。
  - 将来、別の人がテンプレート docx を別版にすり替えた場合、あるいは `reference.docx` 経由で Pandoc が `docPr` を出した場合、即衝突する。
  - さらに wrap_textbox.py の `id_base + z_order` 採番は 1 narrative 内で 1000 個を超える textbox があれば範囲を超える（現実味はないが hard limit 無し）。
- **影響**:
  - plan2.md §11 の検査 6「`docPr@id` 一意性」は xmllint で**実行時事後チェック**するだけで、自動リカバリは無い。CI ハンズオン運用では動くが、将来の silent regression リスク大。
- **推奨対応**:
  - `inject_narrative.py:inject_section` の直後に「body 全体を walk して `wp:docPr/@id` のユニーク化」を行うユーティリティを足す（素直な renumber：既存 max+1 から振り直し）。
  - もしくは `inject_narrative.py` の最後に「衝突検出 → 即 exit 1」するアサーションを入れる。2 行で書ける:
    ```python
    ids = [p.get("id") for p in root.iter("{http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing}docPr")]
    if len(ids) != len(set(ids)):
        sys.exit(f"ERROR: docPr/@id collision: {ids}")
    ```

### [M11-09] (Major) `wrap_textbox.NSMAP` に `w14 / w15` が無い
- **箇所**: `main/step02_docx/wrap_textbox.py:29-48`
- **前回対応状況**: 新規
- **内容**:
  - `inject_narrative.py:NSMAP` には `w14 / w15` が含まれる（M09-04 対応）が、`wrap_textbox.py` には入っていない。
  - `restore_root_tag` で原文 root tag をそのまま復元するため、**root レベルの `xmlns:w14` 宣言は残る**。
  - 問題は ET が body を**再シリアライズ**する時、Pandoc が body 内に出した `<w14:paraId>`（Pandoc 3.6.x の `--reference-doc` 経由で発生する可能性）を prefix なしで出力してしまい `ns0:paraId` 等に書き換わる可能性があること。
  - `ET.register_namespace("w14", ...)` が未登録なので、register map に無い URI の prefix は ET が `ns0` / `ns1` などの自動生成 prefix に置き換える。
  - upstream jami-abstract-pandoc の inject_narrative で同じ問題が発生し M09-04 で修正済みのはずだが、**wrap_textbox 側では未修正**。
- **影響**:
  - 現在の `youshiki1_2_narrative.docx` に `w14:paraId` が含まれるかは未確認だが、Pandoc 3.6.x + reference-doc ワークフローでは出る可能性が高い。
  - 出た場合、`ns0:paraId` に書き換わった XML は**XML 文法的には有効だが**、Word で開いた際の警告（修復動作）または silent な paraId ID ロストを引き起こす。
- **推奨対応**:
  - `wrap_textbox.NSMAP` に `w14`, `w15` を追加し `ET.register_namespace` に通す。
  - `inject_narrative.py:NSMAP` と**常に同じセット**になるよう、両ファイルで共通モジュールに分離する（将来の M09-04 と同種のドリフトを防ぐ）。

---

## Minor

### [N11-01] Lua Image filter の `.svg$` 判定が大文字拡張子を素通し
- **箇所**: `filters/textbox-minimal.lua:82`
- **内容**: `img.src:match("%.svg$")` は case-sensitive。`.SVG` / `.Svg` は素通しになる。移植元プロジェクトで `.svg` 固定運用だったため動いていたが、将来 macOS ユーザが `.SVG` 保存した瞬間に primary blip が生のままになりリスクあり。
- **推奨対応**: `img.src:lower():match("%.svg$")` に変更。

### [N11-02] 空 `.textbox`（`div.content == {}`）で `cx=0 / cy=0` の空テキストボックスが生成可能
- **箇所**: `filters/textbox-minimal.lua:56-60`, `main/step02_docx/wrap_textbox.py:127-246`
- **内容**: 属性未指定（`width / height` 省略）+ 空 content の場合、`parse_attrs` で EMU=0、`wp:extent cx="0" cy="0"` を吐く。Word は invalid / silent drop する挙動が観測されることがある。
- **推奨対応**: `process_textbox` 内で `attrs["width"] or "0"` が 0 の場合に `warn` + `os.exit(1)` 相当。あるいは wrap_textbox 側で `width == 0` を early-exit assertion にする。

### [N11-03] `resize_images_in_content` が `a:extLst > a:ext` を巻き込む
- **箇所**: `main/step02_docx/wrap_textbox.py:114-120`
- **内容**: `inline.iter(f"{A}ext")` は URI 付き `a:ext`（拡張メカニズム）も巻き込む。現状 `cx` 属性を持たないため `int(a_ext.get("cx", "0"))` → 0 で無害だが、将来 `a:ext` 形状が変わると silent regression する。
- **推奨対応**: `inline.iter` ではなく `inline.find(f"{A}graphic/{A}graphicData/{pic}pic/{pic}spPr/{A}xfrm/{A}ext")` の明示パスで取る。

### [N11-04] `_strip_yaml_and_code` の YAML front-matter 除去が `\n` 固定
- **箇所**: `main/step02_docx/wrap_textbox.py:343`
- **内容**: `r'^---\n.*?\n---\n'` は CRLF を想定せず。Windows 保存 md が silent で front-matter 残留 → 偽の `![]()` 拾いリスク。
- **推奨対応**: `r'^---\r?\n.*?\r?\n---\r?\n'` または `md_text = md_text.replace('\r\n','\n')` で正規化。

### [N11-05] `"mc:Ignorable" in merged_tag` は文字列一致で誤検出の余地
- **箇所**: `main/step02_docx/wrap_textbox.py:315`
- **内容**: root tag に他属性として "mc:Ignorable-Foo" のような名前が入ると誤検出する（ただし OOXML 仕様上はあり得ない）。
- **推奨対応**: `re.search(r'\bmc:Ignorable\s*=', merged_tag)` で boundary を明示。

### [N11-06] `wp14` を常に `mc:Ignorable` に追加しているのは semantic に不正確
- **箇所**: `main/step02_docx/wrap_textbox.py:312-326`
- **内容**: `wp14`（`http://schemas.microsoft.com/office/word/2010/wordprocessingDrawing`）は Word 2010 以降で実際に**解釈される** consuming namespace であり、Ignorable に入れると古い Word でスキップされる挙動を持つ。upstream からそのまま持ってきたコードだが、厳密には `wps` だけ Ignorable にすべき（`wp14` は Ignorable 不要）。
- **影響**: 無害（新旧 Word いずれも動く）。
- **推奨対応**: `ignorable` リストから `wp14` を外す。

---

## Info

### [I11-01] `l_ins / r_ins / t_ins / b_ins` ハードコード
- **箇所**: `main/step02_docx/wrap_textbox.py:144-147`
- **内容**: 内側マージンが 45720 / 0 / 45720 / 0 で固定。`.textbox` 属性に `margin-l` 等を受け付けないのは YAGNI 的に正しいが、plan2.md §6 で「執筆者が margin を指定したい場合」の導線が無い点は将来要件として記録しておくべき。

### [I11-02] `distL / distR = 114300` ハードコード
- **箇所**: `main/step02_docx/wrap_textbox.py:156-157`
- **内容**: テキストボックス外側の wrap distance（9pt ≒ 3.175mm）も固定。同上の理由で記録のみ。

### [I10-03] (継続) `mermaid-build` サブコマンド検討
- **箇所**: プロジェクト全体
- **内容**: report10 残。本プロンプトではスコープ外。Step 10 完成後の最適化として別途。

---

## リスクマトリクス

| リスク | 影響度 | 発生確率 | 総合評価 | 対策 |
|--------|--------|---------|---------|------|
| `_strip_yaml_and_code` の正規表現崩壊で SVG blip 誤注入 | 高（別画像位置にベクタ描画）| 中（`~~~` fence / inline code ``` ` ` ``` があれば即発）| **Critical** (C11-01) | フェンス対応正規表現 + HTML コメント除去、できれば Lua 側で画像収集 |
| `textbox_marker` の生文字列連結で `document.xml` が parse error | 高（ビルド即死 / 最悪 silent 破綻）| 中（属性 typo で発動）| **Critical** (C11-02) | Lua 側で XML エスケープ + enum ホワイトリスト |
| 画像パス正規表現の脆弱性（reference-style / angle-bracket / 改行）| 中（K 番目対応ズレ）| 中 | **Major** (M11-01) | C11-01 と統合対応 |
| `md_text` ↔ `a:blip` の K 番目対応が Pandoc 挙動依存 | 中（図が入れ替わる）| 低〜中 | **Major** (M11-02) | basename マッチ or Lua 注釈経由 |
| SVG 未生成時に build 全体がストップ | 低〜中（UX）| 高（執筆中頻発）| **Major** (M11-03) | `--skip-missing-svg` 追加 |
| ネスト `.textbox` の silent pass-through | 中（無言の誤生成）| 中 | **Major** (M11-04) | `process_blocks` 再帰化 or 残存検出 |
| `<foreignObject>` 検出時の安全装置欠落 | 高（Windows 本番で空白矩形）| 低（configFile が効いている限り）| **Major** (M11-05) | `embed_svg_native` に 2 行の検査 |
| `--no-relocate` デッド引数 | 低（認識差）| 高（使われた瞬間 silent no-op）| **Major** (M11-06) | 引数削除 |
| `TextBoxMarker` スタイル未定義 | 低（異常系のみ空行）| 低 | **Major** (M11-07) | reference.docx に定義追加 + 段落 vanish 化 |
| inject_narrative の docPr 衝突検査ゼロ | 高（silent 重複）| 低（現時点）| **Major** (M11-08) | 衝突アサーション追加 |
| w14/w15 NSMAP 欠落による prefix 再リネーム | 中（Word 警告）| 低〜中（Pandoc 出力次第）| **Major** (M11-09) | wrap 側の NSMAP に追加 + 共通化 |
| 大文字拡張子 `.SVG` 素通し | 低 | 低 | Minor (N11-01) | `lower()` 適用 |
| 空 `.textbox` で `cx=0` | 低 | 低 | Minor (N11-02) | early-exit assertion |
| `a:ext` iter 過多 | 低 | 低 | Minor (N11-03) | 明示パス |
| CRLF front-matter 残留 | 低 | 低 | Minor (N11-04) | `\r?\n` 対応 |
| `mc:Ignorable` 誤検出 | 極低 | 極低 | Minor (N11-05) | 正規表現境界 |
| `wp14` Ignorable 追加 | 無害 | — | Minor (N11-06) | 削除 |

---

## 総評

Prompt 10-2 の最小移植は「削除は適切、修正は C09-01 相当で正しい」方針で出発している。一方、
**正規表現ベースの脆弱な md 解析**（C11-01 / M11-01 / M11-02）、**Lua 側の未エスケープ RawBlock**（C11-02）、
そして **`--no-relocate` デッド引数**（M11-06）は、いずれも upstream からの単純移植の粗さ
（もしくは本プロジェクトで新たに導入した設計判断）が顕在化したもの。Step 10 の本番運用に入る前に
最低でも **C11-01 / C11-02 / M11-05 / M11-06 / M11-08** は閉じる必要がある。

特に C11-01 と C11-02 は「1 枚の md に 2 枚以上 SVG を置く」「`.textbox` 属性に typo が混入する」という
自然な使い方で発動するため、**Prompt 10-3（build_narrative.sh 統合）実装前の手当てが必須**。
また M11-05 は report10 で「Prompt 10-2 で検討」と明記されながら未実装のまま残っており、**report10
→ report11 の継続課題**として優先して潰すべき。

M11-08（inject 側 docPr 衝突検査欠落）は plan2.md §7.2 の「既存 docPr 0 件」という**現状事実**に依存した
実装で、将来 reference.docx やテンプレート更新で前提が崩れた瞬間 silent に壊れる。2 行のアサーションで
防衛線を引いておくべき。

M11-09（w14/w15 NSMAP 欠落）は M09-04 の時に片側だけ塞いだことによる再発候補。
**両ファイルで NSMAP を共通モジュール化**して将来のドリフトを構造的に潰すことを推奨。

---

## 対応結果（2026-04-15 追記）

本レビューで指摘した **Critical 2 / Major 9 / Minor 6 の計 17 件すべて**について、
同一セッション内で修正を実施。Docker 経由のスモーク + `data/dummy/` E2E
（`RUNNER=docker DATA_DIR=data/dummy SETUP_DIR=data/dummy ./scripts/build.sh`）で
validate / forms / narrative / inject / security / excel の全ステップが ✓ OK。

### Critical 2 件

- **C11-01** / **M11-01** / **M11-02**（画像抽出の脆弱性群）: `main/step02_docx/wrap_textbox.py`
  - `_strip_yaml_and_code` を完全リライト。
    - CRLF → LF 正規化（N11-04 同時解消）
    - HTML コメント除去（`<!--.*?-->`）
    - **行ベースの fence 追跡**により ``` / ~~~ の両方、および変長 fence（4-backtick 以上のネスト）に対応
    - inline code 除去（`` `...` ``）
  - 画像抽出を `_IMAGE_RE` モジュール定数 + `_extract_image_paths()` ヘルパに分離。
    - non-greedy alt with escape handling + `re.DOTALL` で複数行 alt に対応
    - `<angle-bracket URL>` を名前付きキャプチャで正式サポート
    - reference-style image は**意図的に非対応**（K 番目対応を壊さないため。将来必要ならプリパス追加）
  - `embed_svg_native` に **md 画像数 ↔ a:blip 数のカウント検査**を追加。ズレ検出時は
    `stderr` に WARNING を出して処理は継続（silent mis-embed を防ぐ最小限の防衛線）。
  - 単体テスト（`python3 -c "from wrap_textbox import ...; ..."`）で以下が通過:
    - 4-backtick fence 内の `![fake](fake.svg)` が除去される
    - inline code `` `![inline](inline.svg)` `` が除去される
    - HTML コメント `<!-- ![hidden](hidden.svg) -->` が除去される
    - tilde fence `~~~ ... ~~~` 内の画像が除去される
    - angle-bracket URL `![alt](<figs/fig3 with space.svg>)` が正しく取得される

- **C11-02**（Lua RawBlock の XML 未エスケープ）: `filters/textbox-minimal.lua`
  - 先頭に `xml_escape(s)` ヘルパを追加（`&` 優先で 5 文字エスケープ: `& < > " '`）。
  - `textbox_marker(text)` 内で `xml_escape(text)` を通してから `<w:t>` に埋込み。
  - 併せて **enum ホワイトリスト** `ENUMS` を導入し、`anchor-h / anchor-v / wrap /
    behind / valign` が許可値以外なら `io.stderr:write(...) os.exit(1)` で即死。
  - `<w:t>` は `xml:space="preserve"` 付与。
  - スモーク: `.textbox wrap="foo<bar>"` を書いた md を pandoc に食わせると
    `ERROR: .textbox attribute wrap="foo<bar>" is not one of {tight, square, none}`
    を出して exit 1（`<` が OOXML に到達しない）。

### Major 9 件

- **M11-03**（skip-missing の逃げ道）: `wrap_textbox.py`
  - `embed_svg_native(..., skip_missing=False)` 引数追加。
  - `process_docx(..., skip_missing_svg=False)` → `embed_svg_native` に流し込み。
  - CLI に `--skip-missing-svg` フラグ追加（default False = CI 厳格動作）。
  - skip 時は `stderr` に `SKIP: <path> (missing; asvg layer skipped)` を出して継続。

- **M11-04**（`process_blocks` の nested silent pass-through）: `filters/textbox-minimal.lua`
  - `has_nested_textbox(block)` ヘルパを追加。pandoc の `Div:walk{...}` API で
    子孫全体を走査し `.textbox` 残存を検査。
  - `process_blocks` は top-level 非 `.textbox` ブロックを挿入する前に必ず
    `has_nested_textbox` を通し、True なら `os.exit(1)` で即死。
  - スモーク: `> ::: {.textbox ...} ... :::`（blockquote 内）を書いた md で
    `ERROR: .textbox Div found below document top level. ...` を出して exit 1。

- **M11-05**（`<foreignObject>` 安全装置）: `wrap_textbox.py`
  - `embed_svg_native` 内で SVG バイナリを読み込んだ直後に
    `if b"<foreignObject" in svg_data: raise ValueError(...)` を挿入。
  - メッセージには「Word でラベルが空白矩形になる」「`htmlLabels:false` を
    再確認せよ」の具体的な復旧導線を含める。
  - これにより report10 M10-02 連動メモで明示されていた残課題を閉塞。

- **M11-06**（`--no-relocate` デッド引数）: `wrap_textbox.py`
  - `--no-relocate` フラグと `no_relocate` パラメータを**完全削除**。
  - `process_docx` のシグネチャから除去し、docstring を「page-based relocation
    は意図的に未移植」と明記する方向に差し替え。
  - 既存呼び出し側は本ファイル内の CLI のみ（build_narrative.sh は Prompt 10-3 で
    新規に書くため現時点で呼び出しなし）。

- **M11-07**（TextBoxMarker スタイル未定義）: `filters/textbox-minimal.lua`
  - `textbox_marker` の出力を `<w:pPr><w:pStyle .../><w:rPr><w:vanish/></w:rPr></w:pPr>`
    に変更し、**段落マーク run properties にも vanish を付与**。これで
    `reference.docx` に `TextBoxMarker` スタイルが未定義でも、Word は段落マーク
    そのものを hidden として扱う（異常系で START/END マーカー段落が body に
    残った場合も空行として見えない）。
  - `templates/reference.docx` 本体には手を入れない（バイナリ改変を回避）。

- **M11-08**（inject 側 docPr 衝突検査ゼロ）: `main/step02_docx/inject_narrative.py`
  - NSMAP 直下に `WP = "{...wordprocessingDrawing}"` を追加。
  - `process()` のシリアライズ直前に body 全体を `root.iter(f"{WP}docPr")` で
    走査し、`@id` に重複があれば `ERROR: wp:docPr/@id collision detected in
    merged body: [...]. Re-run wrap_textbox.py with distinct --docpr-id-base`
    を stderr に出して `sys.exit(1)`。
  - 2026-04-15 時点の dummy E2E ではテンプレート既存 docPr 0 件が実測確認済み
    （現状は通過メッセージを出さないだけで、将来 1 件でも混入すれば発火する）。

- **M11-09**（`wrap_textbox.NSMAP` に w14/w15 欠落）: `wrap_textbox.py`
  - NSMAP に `w14` / `w15` を追加（`inject_narrative.py:NSMAP` と同一セットに揃える）。
  - `ET.register_namespace` ループは既存構造を流用するため自動的にカバーされる。
  - **将来課題**: 両ファイルで NSMAP を共通モジュール化する構造改修は本プロンプトの
    スコープ外。Prompt 10-3 以降で検討。

### Minor 6 件

- **N11-01**（大文字 `.SVG` 素通し）: `filters/textbox-minimal.lua`
  - `img.src:match("%.svg$")` を `img.src:lower():match("%.svg$")` に変更。

- **N11-02**（空 `.textbox` で `cx=0`）: `filters/textbox-minimal.lua`
  - `process_textbox` 先頭で `width <= 0 or height <= 0` を検出したら
    `ERROR: .textbox requires positive width and height` を出して `os.exit(1)`。

- **N11-03**（`a:ext` iter 過多）: `wrap_textbox.py`
  - `PIC = "{...picture}"` 定数を追加。
  - `resize_images_in_content` から `inline.iter(f"{A}ext")` を廃し、
    `{A}graphic/{A}graphicData/{PIC}pic/{PIC}spPr/{A}xfrm/{A}ext` の**明示パス**
    で xfrm 内の次元専用 `a:ext` のみをターゲットに。これにより将来 `a:extLst > a:ext`
    が cx 属性を持つ派生を含んでいても副作用なし。
  - 判定ロジックも整理（早期 continue で入れ子深度を下げる）。

- **N11-04**（CRLF front-matter）: `wrap_textbox.py`
  - `_strip_yaml_and_code` の冒頭で `md_text.replace('\r\n', '\n').replace('\r', '\n')`。
  - C11-01 修正と同時に解消。

- **N11-05**（`mc:Ignorable` 誤検出の余地）: `wrap_textbox.py`
  - `restore_root_tag` の検出を `"mc:Ignorable" in merged_tag` → 正規表現
    `re.compile(r'\bmc:Ignorable\s*=\s*"([^"]*)"').search(...)` に変更。

- **N11-06**（`wp14` Ignorable 追加の不正確性）: `wrap_textbox.py`
  - `restore_root_tag` で Ignorable に追加するのを `wps` のみに限定。
  - `wp14` は consuming namespace として Word 2010+ が直接解釈するため Ignorable 不要。
  - 本修正後、スモーク検証で `mc:Ignorable="wps"` が出力されることを確認済み。

### 変更ファイル一覧

```
modified:   filters/textbox-minimal.lua        (94 → 178 行)
modified:   main/step02_docx/wrap_textbox.py   (568 → 629 行)
modified:   main/step02_docx/inject_narrative.py (+24 行: docPr 衝突検査)
modified:   docs/report11.md                   (対応結果を追記)
```

### 検証実績

1. **構文チェック**: `python3 -c "import ast; ast.parse(...)"` で
   `wrap_textbox.py` / `inject_narrative.py` の Python 構文 OK。

2. **単体テスト**（C11-01 / M11-01）:
   ```python
   from wrap_textbox import _strip_yaml_and_code, _extract_image_paths
   # 4-backtick fence / inline code / HTML comment / tilde fence の
   # 全 false-positive が除去され、本物の .svg だけが抽出される。
   # angle-bracket URL も正しく取得される。
   ```

3. **Docker スモーク**（`docker compose ... run --rm python ...`）:
   - `.textbox` 無し md → pandoc OK / `No TextBoxMarker regions found` で wrap OK
   - 正常 `.textbox` md → anchor=1 / docPr@id=['3000'] / `mc:Ignorable='wps'`
   - `.textbox wrap="foo<bar>"` → enum rejection で exit 1
   - `> ::: {.textbox ...} :::`（blockquote 内） → nested 検出で exit 1
   - `::: {.textbox} ... :::`（幅高さ無し） → positive width/height 要求で exit 1

4. **dummy E2E**: `RUNNER=docker DATA_DIR=data/dummy SETUP_DIR=data/dummy ./scripts/build.sh`
   で validate / forms / narrative / inject / security / excel の全ステップ ✓ OK。
   既存の `youshiki1_2.md` / `youshiki1_3.md`（図なし）への影響ゼロを実測確認。

### 残課題

- **I10-03**（継続）: `mermaid-build` サブコマンド検討。Step 10 着手後の最適化扱い、
  本報告でも触れない。
- **I11-01 / I11-02**（記録のみ）: `l_ins / r_ins / t_ins / b_ins` および
  `distL / distR` のハードコードは将来の UX 拡張要件として記録し、本プロンプトでは
  修正しない（YAGNI）。
- **構造改修案**: NSMAP を `wrap_textbox.py` と `inject_narrative.py` で共通モジュール化
  する作業は Prompt 10-3 以降で検討（M09-04 / M11-09 の再発構造を潰す）。
