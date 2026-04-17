# セッション開始プロンプト: 敵対的レビュー（第13回）— Prompt 10-4 成果物と Prompt 10-5 着手前の健全性

以下の指示に従い、**Prompt 10-4（デモ図表の挿入と単体確認）で初めて実データを通した
`.mmd → .svg → .svg.png → .docx` の 4 段パイプラインと、同セッションで追加された
`build_narrative.sh` の修正点**について敵対的レビューを行ってください。
レビュー結果は `docs/report13.md` に出力してください。

## レビュー方針

- **実装を開始しないでください。** レビューと指摘のみを行います。
- **研究計画書の論旨・学術的妥当性はレビュー対象外です。**
  ただし Markdown 構文・画像参照・YAML front-matter・`.textbox` Div 記述など
  パイプラインに影響する形式的要素は対象に含みます。
- **焦点は「Prompt 10-4 成果物と Prompt 10-5 着手前の健全性」です。** 次の 4 領域を
  重点的に検証してください:
  - 領域 A: `build_narrative.sh` への本セッション修正（tmp 拡張子 / --resource-path）
  - 領域 B: インクリメンタルビルドの stale 挙動（`.mmd → .svg → .svg.png → .docx`）
  - 領域 C: 生成された docx 内 OOXML の整合性（wp:anchor / wps:wsp / asvg:svgBlob / docPr@id）
  - 領域 D: Prompt 10-5（inject 連携 + Windows Word PDF E2E）着手前の潜在リスク
- **敵対的に検証してください。** 「うまくいきそう」ではなく「どこで壊れるか」を探してください。
  特に以下の観点を重視:
  - **本セッション修正**の副作用（`${svg%.svg}.tmp.$$.svg` の拡張子マッチング、
    `--resource-path` による resource 解決の変化）
  - **実データで初めて顕在化する経路**（今回までは `.mmd` / `.textbox` 不在で
    skip されていた処理が本格稼働し始めた）
  - **Phase A / B / C 間の契約**（Lua フィルタ書換、mtime 判定、wrap_textbox 採番）
  - **OOXML の相互参照**（`a:blip/@r:embed` → rels → media、`asvg:svgBlob` → rels →
    `svg1.svg`、`wp:docPr/@id` の 3000 台採番と既存空間の非衝突）
  - **inject 前の中間成果物**（narrative docx の構造がテンプレートに食わされたときの
    merge 挙動：media 名衝突、rels 再採番、Content_Types 重複、mc:AlternateContent 保全）
- **`docs/__archives/report12.md` を読まずに**独立してレビューを行い、レポート作成時に
  `report12.md` と突き合わせて所見を統合してください。
- レビュー結果は `docs/report13.md` に、重大度（Critical / Major / Minor / Info）付きで
  出力してください。
- 前回レビューとの差分（新規発見 / 既知だが未対応 / 前回から改善済み）を明示してください。

## 前回（`docs/__archives/report12.md`）からの主な変化

Prompt 10-4 完了に伴い以下の変更を実施しました（commit 未反映、作業ツリー上の変更）:

### 新規ファイル

- **`main/step01_narrative/figs/fig1_overview.mmd`** — Mermaid flowchart（5 ノード、
  日本語ラベル含む。`DPC/NDB/レセプト → 需給推定器 → 地域医療シミュレータ`、
  `サイバー攻撃シナリオ → 地域医療シミュレータ`、`地域医療シミュレータ →
  インパクト評価レポート`）

### 既存ファイルへの変更

- **`main/step01_narrative/youshiki1_2.md`** — 以下 2 件の `.textbox` Div を追加:
  - §1（本研究の背景）末尾: `bg_hospital.jpg`（90mm×60mm、anchor-h=column、
    anchor-v=paragraph、wrap=square、behind=false）
  - §3（最終目標）冒頭: `fig1_overview.svg`（120mm×70mm、同上 anchor 設定）
  - 本文（章構成・論旨）は改変していない

- **`.gitignore`** — `main/step01_narrative/figs/*.svg` と `*.svg.png` を除外
  （plan2.md §3 方針: .mmd は管理、.svg / .svg.png はビルド成果物）

- **`main/step02_docx/build_narrative.sh`** — 以下 2 件の修正を追加（Prompt 10-4
  の実地実行で顕在化したバグへの対応）:
  1. `run_mermaid` の tmp ファイル名を `${svg}.tmp.$$` → `${svg%.svg}.tmp.$$.svg`
     に変更。mmdc は出力拡張子で形式判定するため、元の tmp 名では
     `Output file must end with ".md"/".markdown", ".svg", ".png" or ".pdf"` で
     失敗していた
  2. `run_rsvg_convert` も同様に `${png}.tmp.$$` → `${png%.png}.tmp.$$.png` に変更
  3. `PANDOC_OPTS` に `--resource-path=main/step01_narrative` を追加。pandoc は
     プロジェクトルート cwd で実行されるため、md 内の `figs/*.jpg` 等が解決できず
     silent に画像欠落（WARNING のみ）していた

### 実地検証結果

- `./scripts/build.sh narrative` が成功し、`fig1_overview.svg` と `.svg.png` が生成
- `main/step02_docx/output/youshiki1_2_narrative.docx`（100KB）内:
  - `wp:anchor` 開始/終了タグ = 4（＝ 2 アンカー）
  - `wps:wsp` 開始/終了タグ = 4（＝ 2 テキストボックス）
  - `a:blip/@r:embed` = 3 件（rId23=bg_hospital.jpg、rId30=fig1_overview.svg.png、
    rId31=svg1.svg）
  - `asvg:svgBlob` = 1 件（Mermaid SVG のネイティブ埋込）
  - `word/media/`: `rId23.jpg`、`rId30.png`、`svg1.svg`
  - `word/_rels/document.xml.rels`: 対応する image rels が存在
  - `[Content_Types].xml`: `<Default Extension="svg" ContentType="image/svg+xml"/>` 含む
- 非破壊性: `RUNNER=docker DATA_DIR=data/dummy SETUP_DIR=data/dummy ./scripts/build.sh`
  全 6 ステップ ✓ OK（validate / forms / narrative / inject / security / excel）

**注意**: `inject_narrative.py` を介した `youshiki1_5_filled.docx` 生成までは実行済み
だが、**Windows Word COM での実 PDF 変換は未実施**（Prompt 10-5 本体のスコープ）。
本レビューでは Linux docx 構築時点で観察できる構造的リスクの列挙が中心となる。

## レビュー対象

### 領域 A: `build_narrative.sh` への本セッション修正

具体的に検証してほしい観点:

- **`run_mermaid` / `run_rsvg_convert` の tmp ファイル名変更**
  - `${svg%.svg}.tmp.$$.svg` の `%.svg` は最後に現れる `.svg` を削除する bash
    パラメタ展開。入力が `foo.svg` なら `foo.tmp.$$.svg` になる。これは OK。
    ただし **入力が `.SVG`（大文字）だった場合は `%.svg` がマッチしないため
    `foo.SVG.tmp.$$.svg` というダブル拡張子が残る**。同様のケースが将来発生しないか。
  - 並行実行時の `.tmp.$$` 衝突: `$$` は同プロセス内で不変。`roundtrip.sh` を 2
    プロセス同時実行する場合は別 PID なので衝突しないが、**シェル関数を同プロセス内で
    連続呼出した場合**（リトライ等）の tmp 名が同一になり、前回の残骸を上書きする
    リスク。mv 成功前に失敗すると残骸が再利用される。
  - `run_mermaid` の return 非ゼロ時の tmp 削除パス（`rm -f "$tmp"` が
    `if [[ $ret -ne 0 ]]` の内側で行われる）が、SIGTERM / Ctrl+C 等で関数途中の
    kill を受けた場合には実行されず、部分書き込み `.tmp.$$.svg` が残る可能性。
    trap による EXIT cleanup は導入されていない。

- **`PANDOC_OPTS` への `--resource-path=main/step01_narrative` 追加**
  - pandoc の `--resource-path` は **画像だけでなく CSS / include files / link
    references** 等の解決にも使われる。将来 md に `<link>` や `include` 系を
    足した場合、予期せぬファイルが拾われるリスク。
  - pandoc 3.6.x では resource-path は **最初に一致したファイルを使う**。同名の
    画像（例: `figs/foo.png`）が別ディレクトリにあった場合、どちらが解決されるか
    はパス順依存。現状は `main/step01_narrative` 1 つだが、将来 `data/dummy/figs`
    を追加したくなった場合の設計余白が無い。
  - cwd が変わると挙動が変わる可能性: `build_narrative.sh` は `cd "$PROJECT_ROOT"`
    後に pandoc を呼ぶが、相対パス `main/step01_narrative` は cwd に依存する。
    将来 `roundtrip.sh` 等から呼出順序が変わった場合に壊れないか。
  - `.textbox` Div 内の `![](figs/...)` は pandoc が解決するが、Lua フィルタの
    `.svg → .svg.png` 書換は src 文字列に対する string replace で、物理ファイル
    存在は見ていない。書換後のパス `figs/fig1_overview.svg.png` が resource-path
    で解決される前提が成り立たない環境（例: `.svg.png` だけ別ディレクトリにある）
    での挙動。

- **これら 2 件の修正は本来 Prompt 10-3 で検出されるべきものだった**
  - Prompt 10-3 の完了基準「document.xml バイナリ一致（.mmd / .textbox 不在時）」
    では、実際に `.mmd` / 画像を使うパスが検証されなかったため顕在化しなかった。
  - report12 に **「C12-01: MODE=local で画像欠落が silent に通る」** の指摘があり、
    その対応で `--fail-if-warnings` または事前画像存在チェックの選択肢が提示されていた。
    今回のバグ（`--resource-path` 不足で `[WARNING] Could not fetch resource`）は
    まさに C12-01 の予言した経路であり、report12 の修正（run_mermaid / run_rsvg_convert
    を fail に変更）だけでは pandoc 側の WARNING 経由の画像欠落は**別経路として残った**。
    Prompt 10-4 の本セッション修正で `--resource-path` は追加したが、
    `--fail-if-warnings` は未採用。今後 resource-path でも解決できないケース
    （破損 JPG、存在しない SVG）で再び silent 欠落が発生しうる。

### 領域 B: インクリメンタルビルドの stale 挙動

具体的に検証してほしい観点:

- **4 段依存（`.mmd → .svg → .svg.png → .docx`）**
  - Phase A は `.mmd → .svg` と `.svg → .svg.png` の 2 段のみを mtime 比較で判定。
    **docx は pandoc が毎回フル実行**するため、`.svg.png` が古くても docx は更新される。
    ただし **ユーザが `.svg` だけ手動差し替え**した場合、`.mmd` の mtime が `.svg` より
    古ければ `.svg` は再生成されないが、`.svg.png` は `.svg` の mtime が新しくなった
    ことで再生成される。この経路は OK だが、ドキュメントに明示されていない。
  - **Phase A の skip 判定** `[[ ! -f "$svg" ]] || [[ "$mmd" -nt "$svg" ]]` で、
    mv 成功直後の `.svg` は **現在時刻の mtime** を持つ。次回ビルド時に `.mmd` が
    `.svg` より古ければ skip されるのは期待通り。ただし `touch -r` や rclone
    `--preserve-modtime` で `.svg` の mtime が過去に巻き戻される場合に毎回再生成される。
  - **`.svg.png` が壊れた（0 バイトなど）ケース**の検出欠落。Phase A の up-to-date
    判定はファイルの**存在と mtime のみ**。ファイルサイズや内容検証はしない。

- **Lua フィルタの `.svg → .svg.png` 書換**
  - Lua フィルタは src 文字列を単純置換する。Phase A が skip された場合でも、
    pandoc は `.svg.png` が存在すれば解決してしまう（古い `.svg.png` を使う）。
    ユーザが `.mmd` を編集して `.svg` が再生成されても `.svg.png` が同期されないと
    古いラスタが docx に入る silent 劣化。
  - 逆に Phase A が `.svg` を更新したが `.svg.png` への再生成が何らかの理由で失敗した
    場合、Lua フィルタは書換後のパスを docx に埋め込み、pandoc は古い `.svg.png` を
    解決する。結果、SVG（新）と PNG（旧）が **docx 内で食い違う**（`a:blip` の
    primary PNG と `asvg:svgBlob` の SVG が別バージョン）。

- **`reference.docx` の毎回上書き**
  - `fix_reference_styles.py` は毎回 `templates/reference.docx` を in-place で
    書き換える。これが冪等でないと、同じ md 入力でも docx のバイト列が変化し、
    non-destructive（binary-match）検証が意味を失う。

### 領域 C: 生成された docx 内 OOXML の整合性

具体的に検証してほしい観点:

- **`wp:anchor` / `wps:wsp` の 2 件**
  - 1 つ目（bg_hospital.jpg）は JPG のみ、2 つ目（fig1_overview.svg）は PNG + SVG
    の 2 層構成。**wps:wsp 内の a:blip 解決順序**（primary PNG → fallback SVG）が
    Word 2013 以前で正しくフォールバックするか。
  - `wp:anchor/@docPr/@id` が 3000 / 3001 と採番されているか（wrap_textbox の
    `--docpr-id-base=3000` + `z_order` 0/1）。テンプレート既存の docPr@id と
    衝突していないか。report12 M12-05 で header/footer も含めた検査が導入された
    が、narrative docx 単体では header/footer は持たないため、
    衝突検査は **inject 後** に走る。narrative docx 単体の検証だけでは不十分。

- **`a:blip/@r:embed` の 3 件参照**
  - rId23（bg_hospital.jpg）、rId30（fig1_overview.svg.png）、rId31（svg1.svg）の
    採番が pandoc / wrap_textbox のどちらに由来するか。**pandoc は rId20 台を
    広く使う**傾向があり、wrap_textbox が svg1.svg 用に rId31 を後付けしている可能性。
    この採番ロジックが narrative docx → inject 時に再採番される際に**順序が保たれるか**。
  - `asvg:svgBlob/@r:embed="rId31"` が `media/svg1.svg` を指し、primary blip
    `<a:blip r:embed="rId30"/>` が `media/rId30.png` を指す 2 層構成。Word が
    svgBlob を優先表示するかどうかは Office 2016+ 仕様で、2013 では PNG fallback。

- **`word/media/` の命名規約**
  - `rId23.jpg` / `rId30.png` は **rId ベース命名**（pandoc 流儀）。
  - `svg1.svg` は **連番ベース命名**（wrap_textbox 流儀）。
  - この非対称は **wrap_textbox がファイル名衝突を避けるため**だが、将来 pandoc が
    `svg1.png` を吐いた場合に衝突する。
  - inject_narrative.py が media を merge する際、**同名ファイル衝突を防ぐ
    renaming 機構**が存在するか。report11 の M11-xx 系指摘で何かあった気がするが
    確認必要。

- **`[Content_Types].xml` の Default / Override 方針**
  - `<Default Extension="svg" ContentType="image/svg+xml"/>` は wrap_textbox が
    追加。既存の Default `xml` / `rels` / `odttf` と重複していないか。
  - jpg / png は `<Override PartName="/word/media/rId23.jpg" ...>` で個別定義される
    （pandoc が採番ベースで Override を張る流儀）。SVG は Default で jpg/png は
    Override、の非対称。inject 時に Default 同士が merge されるか、Override に
    変換されるか。

- **日本語キャプションの扱い**
  - `![病院施設の外観（デモ画像）](figs/bg_hospital.jpg){#fig:hospital}` は pandoc が
    figure caption 付きの構造で docx に落とす。ただし `.textbox` Div 内の Image は
    wrap_textbox が `wp:anchor` 化する際、**caption を別段落に分離**してしまう可能性。
    現在の docx で caption が「画像の下に別枠」として見えるか、「画像の alt text」
    として埋もれるかを確認。
  - `{#fig:hospital}` のアンカーは pandoc の crossref 用だが、今回は crossref を
    使っていない。docx 内にブックマークとして残るか、捨てられるか。

### 領域 D: Prompt 10-5（inject 連携）着手前の潜在リスク

具体的に検証してほしい観点:

- **`inject_narrative.py` の merge で起きうる衝突**
  - **media 名衝突**: テンプレート `r08youshiki1_5.docx` が既に `word/media/rId23.jpg`
    を持っていた場合、narrative 由来の `rId23.jpg` と衝突。inject 側は rename 機構
    を持つか？ plan2.md / report11 / report12 を参照して整合性を確認。
  - **rels Id 衝突**: テンプレートが既に rId23 / rId30 / rId31 を本文で使っていた
    場合の renumber 挙動。
  - **Content_Types の Default 重複**: テンプレートに既に `<Default Extension="svg"/>`
    が無い前提で wrap_textbox が追加している。inject 時にテンプレートの
    `[Content_Types].xml` に merge される際の重複排除。
  - **`<mc:AlternateContent>` / `<mc:Fallback>` ブロック**: wrap_textbox が出力する
    wps:wsp は mc:AlternateContent で包まれている（新旧 Word 互換のため）。inject
    側が `<w:body>` を merge する際、mc ブロックを正しく保持するか。破壊すると
    Word で修復ダイアログが出る。

- **docPr@id 衝突検査の実地動作**
  - report12 M12-05 の対応で body + header + footer を含めた検査が導入された。
    Prompt 10-5 で実際に inject を走らせたとき、narrative 側 3000/3001 と
    テンプレート側の既存 docPr@id（テンプレート本体には本文 docPr が無いはずだが
    header/footer には不明）が衝突しないか。
  - 衝突検出時の動作: Abort か、renumber か、silent pass か。

- **Windows Word COM での実 PDF 変換**
  - これは Prompt 10-5 本体のスコープだが、Linux 側で観察可能な**構造的リスク**を
    列挙:
    - `asvg:svgBlob` が Office 2016+ でのみ解釈される（Word 2013 では primary PNG が
      表示される）。現行 watch-and-convert.ps1 が使う Word のバージョン確認。
    - `fonts-noto-cjk` + librsvg で生成された `.svg.png` は Noto フォント埋込。
      Word 側で Noto が無い場合、**PNG は画像なので問題ないが SVG 側は Word が
      再レンダリング**する可能性（Office 2016+ の svgBlob 解釈仕様）。フォント不一致で
      日本語が豆腐化するリスク。

- **非破壊性回帰**
  - `.textbox` ブロック 2 件を youshiki1_2.md から一時的に削除してビルドし直した場合に、
    document.xml から wp:anchor / asvg:svgBlob が完全に消えるか（残骸のコメントや
    空 Div が残らないか）。
  - Phase A は `.mmd` を見つけた時点で `.svg` を生成する。`.textbox` を削除しても
    `.mmd` は残るため、`.svg` と `.svg.png` は残存する。これは plan2.md 方針通りだが、
    `.textbox` 削除での非破壊性検証の文脈では「figs/ に残る成果物も含めて差分ゼロ」
    ではない点に注意。

### 領域 E（補助）: `fig1_overview.mmd` と `.textbox` Div の Markdown 記法

具体的に検証してほしい観点:

- **Mermaid 記法の妥当性**
  - `%%{init: {'theme':'base','themeVariables':{'fontSize':'18px'}}}%%` はマーメイド
    directive で先頭行に置く必要がある。現状は先頭 YAML frontmatter のような扱い。
    mermaid-cli 10.9.1 で正しく解釈されるか。
  - `flowchart LR` 以外（例: `graph TD`、`sequenceDiagram`、`classDiagram`）を
    著者が追加した場合、report12 M12-06 の対応で flowchart 以外にも htmlLabels:false
    が追加済みだが、**本当に全 type で <foreignObject> が出ないか**の実地検証は
    flowchart だけで終わっている。

- **`.textbox` Div の属性セット**
  - `width="90mm" height="60mm" pos-x="0mm" pos-y="0mm" anchor-h="column"
    anchor-v="paragraph" wrap="square" behind="false"` の各属性が
    wrap_textbox.py の parser と一致するか。特に `anchor-h` / `anchor-v` の
    列挙値（column / margin / page / paragraph / line 等）の妥当性。
  - `pos-x="0mm"` が 0 の場合、Word のどこに配置されるか（段落左端？ アンカーの
    基準点？）。デフォルトレイアウトが「段落内流し込み」に近いか「アンカー固定」か。

## 参照すべき資料

| ファイル | 確認ポイント |
|---------|------------|
| `main/step02_docx/build_narrative.sh` | `run_mermaid` / `run_rsvg_convert` の tmp 扱い、`PANDOC_OPTS` の `--resource-path`、Phase A / C の mtime 判定、preflight_docker_images / preflight_image_case |
| `main/step02_docx/wrap_textbox.py` | `embed_svg_native`、`--docpr-id-base=3000` + z_order 採番、rels Id 生成（svg1.svg 等）、atomic write（M12-01 対応） |
| `main/step02_docx/inject_narrative.py` | media / rels / Content_Types マージ、docPr 衝突検査（body + header/footer、M12-05 対応）、mc:AlternateContent 保全 |
| `filters/textbox-minimal.lua` | `.svg → .svg.png` 置換、`.textbox` Div の START/END マーカー emit、大小文字扱い（N12-01 対応、fail-fast） |
| `main/step01_narrative/youshiki1_2.md` | 追加された `.textbox` ブロック 2 件（Markdown 構文の妥当性、属性セットの妥当性のみ） |
| `main/step01_narrative/figs/fig1_overview.mmd` | mermaid 記法（init directive / flowchart LR）の妥当性、`fontSize:'18px'` 等 themeVariables の実効性 |
| `.gitignore` | `figs/*.svg` と `*.svg.png` の除外、`.mmd` が誤って除外されていないか、将来手書き SVG を追加する場合の余白 |
| `docker/mermaid-svg/mermaid-config.json` | flowchart / sequence / class / state / er / gantt / journey の htmlLabels:false（M12-06 対応） |
| `docker/python/Dockerfile` | `librsvg2-bin` 追加後のフォント依存、Debian slim での `rsvg-convert` バージョン、pango / cairo との共存 |
| `docs/plan2.md` §6 / §8 / §10 | 命名規約（`.svg.png` ダブル拡張子）、Phase A / B / C 設計、デモ図表の挿入計画 |
| `docs/prompts.md` Prompt 10-4 / 10-5 | 完了チェック状態、10-5 で未実行の経路 |
| `main/step02_docx/output/youshiki1_2_narrative.docx` | 実地生成された docx の OOXML 構造（unzip 後に document.xml / rels / media / Content_Types） |
| `main/step02_docx/output/youshiki1_5_filled.docx` | inject 後の最終形（Prompt 10-5 前の先行観察として構造を確認） |
| `scripts/build.sh` | `ensure_docker_image`（N12-03 対応、python + mermaid 両方）、narrative / inject フェーズ |
| `scripts/roundtrip.sh` | ビルド → push → pull フローと Phase A / C のタイミング整合性 |
| `CLAUDE.md` | プロジェクト制約（10MB 上限、15 ページ制限、host Python 不使用） |
| `docs/__archives/report12.md` | **先に読まずに**独立レビュー後、レポート作成時の突合用 |

## 出力フォーマット

`docs/report13.md` に以下の形式で出力してください:

```markdown
# 敵対的レビュー報告書（第13回）— Prompt 10-4 成果物と Prompt 10-5 着手前の健全性

レビュー実施日: YYYY-MM-DD
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

- Critical: N件 (新規N / 既知未対応N)
- Major: N件 (新規N / 既知未対応N)
- Minor: N件 (新規N / 既知未対応N)
- Info: N件

### 対応状況一覧

| ID | 重大度 | 状態 | 概要 |
|----|--------|------|------|
| C13-01 | Critical | ... | ... |
| ... | ... | ... | ... |

## report12.md との差分サマリ

- 前回の未対応項目で今回解消されたもの: N件
- 前回の未対応項目で依然として未対応のもの: N件
- 前回に記載がなく今回新規発見したもの: N件

## 指摘事項

### [C13-01] (Critical) タイトル
- **箇所**: ファイル名:行番号 or セクション名
- **前回対応状況**: 新規 / report12.md [C12-XX] 対応済み / 未対応
- **内容**: 具体的な問題の説明
- **影響**: この問題が放置された場合に起きること
- **推奨対応**: 修正方針

### [M13-01] (Major) ...
...

### [N13-01] (Minor) ...
...

### [I13-01] (Info) ...
...

## リスクマトリクス

| リスク | 影響度 | 発生確率 | 総合評価 | 対策 |
|--------|--------|---------|---------|------|
| ... | 高/中/低 | 高/中/低 | Critical/Major/Minor | ... |

## 総評

（パイプライン全体としての健全性評価、Prompt 10-5 に進んでよいか、優先すべき対応順序）
```

### 重大度の基準

- **Critical**: 実装がブロックされる、または成果物に致命的欠陥が生じる
  （例: 本番で silent に誤った画像が埋め込まれる、docx が Word で開けない、
  inject 後に figs が欠落する）
- **Major**: 実装に手戻りが発生する、または成果物の品質に重大な影響がある
  （例: インクリメンタルビルドで `.svg` と `.svg.png` が食い違う、`--resource-path`
  の副作用で関係ないファイルが拾われる、docPr@id 衝突）
- **Minor**: 修正すべきだが実装を進めながら対応可能
  （例: UX 改善、ログメッセージ不足、デッドコード、命名規約の非対称）
- **Info**: 改善推奨だが現状でも問題なく進められる
  （例: 将来の設計提案、仕様の備忘メモ）

### 命名規則

- 指摘 ID: `C13-NN` (Critical) / `M13-NN` (Major) / `N13-NN` (Minor) / `I13-NN` (Info)
- NN は 2 桁ゼロパディング（01, 02, ...）
