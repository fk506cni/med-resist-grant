# 敵対的レビュー報告書（第09回）— Step 10 設計レビュー

レビュー実施日: 2026-04-15
最終更新: 2026-04-15（指摘事項 全件対応完了）
レビュー対象:
- `docs/plan2.md`
- `docs/prompts.md`（Step 10 セクション）
- `main/step02_docx/inject_narrative.py`
- `main/step02_docx/build_narrative.sh`
- `docker/docker-compose.yml`, `docker/python/Dockerfile`
- `/home/dryad/anal/next-gen-comp-paper/filters/jami-style.lua`
- `/home/dryad/anal/next-gen-comp-paper/scripts/wrap-textbox.py`
- `/home/dryad/anal/auto-eth-paper/docker/mermaid-svg/`

前回レビュー: `docs/__archives/report8.md`（2026-04-06）

## 対応状況サマリ

**全 20 件（Critical 1 / Major 7 / Minor 9 / Info 3）に対応完了**。Critical/Major は
plan2.md, prompts.md（Step 10 セクション）, inject_narrative.py への修正で全て
解消済み。Info 3 件のうち 2 件は Prompt 10-1 の事前ビルドサブコマンド検討と Word
バージョン確認の継続タスクとして残置、1 件は将来最適化として記載のまま。

## サマリ

- Critical: 1件（新規1 / 既知未対応0 / **対応済み 1**）
- Major: 7件（新規7 / 既知未対応0 / **対応済み 7**）
- Minor: 9件（新規9 / 既知未対応0 / **対応済み 9**）
- Info: 3件（**継続検討 2 / 受容 1**）

### 対応状況一覧

| ID | 重大度 | 状態 | 概要 | 対応箇所 |
|----|--------|------|------|---------|
| C09-01 | Critical | ✅ 対応済み | `embed_svg_native` の SVG パス解決が CWD 依存で全 SVG 埋込が silent fail | plan2.md §7.1, prompts.md Prompt 10-2「重要な実装ポイント」 |
| M09-01 | Major | ✅ 対応済み | docPr@id 採番値が 1000 vs 2000 で不一致 | plan2.md §7.2 で 3000 に統一, prompts.md 10-1 完了チェックで template 値確認 |
| M09-02 | Major | ✅ 対応済み | 1-2/1-3 narrative 間で docPr@id 重複 | plan2.md §7.2/§8/§9.1, prompts.md 10-2/10-3 で `--docpr-id-base` を narrative 別に分離 |
| M09-03 | Major | ✅ 対応済み | mermaid サービスに HOME 未設定 | plan2.md §5.1/§5.3, prompts.md Prompt 10-1 で `HOME=/tmp` を Dockerfile/compose 両方に設定 |
| M09-04 | Major | ✅ 対応済み | inject_narrative.py NSMAP に asvg 未登録 | `main/step02_docx/inject_narrative.py:48-49` に asvg / a14 追加（実装済み） |
| M09-05 | Major | ✅ 対応済み | LO 検証のみで Windows Word COM が未検証 | plan2.md §11 検証8, prompts.md 10-5 検証6 で `roundtrip.sh` 経由 Win Word PDF を本番判定主軸に |
| M09-06 | Major | ✅ 対応済み | bash glob ゼロ件失敗 | plan2.md §8, prompts.md 10-3 で `shopt -s nullglob` + 配列で囲む |
| M09-07 | Major | ✅ 対応済み | Lua フィルタ Pass 1 削除による primary blip 不整合 | plan2.md §6/§7.3, prompts.md 10-2 で svg→svg.png リネームを保持、§5.4 で `librsvg2-bin` 追加 |
| N09-01 | Minor | ✅ 対応済み | 行数目標の不整合 | plan2.md §6「80〜100 行程度」に統一 |
| N09-02 | Minor | ✅ 対応済み | NSMAP コピー指示が asvg を落とす | prompts.md 10-2「NSMAP の名前空間」セクションで明示 |
| N09-03 | Minor | ✅ 対応済み | smoke test に日本語指示なし | prompts.md 10-1 作業内容 #4 に日本語ラベル必須を追記 |
| N09-04 | Minor | ✅ 対応済み | smoke test がホスト pandoc | prompts.md 10-2 動作確認を Docker 経由に変更 |
| N09-05 | Minor | ✅ 対応済み | anchor-h 既定が doc 間で不一致 | plan2.md §2.2 で「本文フロー: column / 余白逃がし: margin」と用途別に整理 |
| N09-06 | Minor | ✅ 対応済み | .gitignore 方針が未記載 | plan2.md §3 に「figs/*.svg はビルド成果物として除外、.mmd は管理」を明記 |
| N09-07 | Minor | ✅ 対応済み | Phase A 実行回数が曖昧 | plan2.md §8, prompts.md 10-3 で「md ループの外で 1 回だけ実行」と明記 |
| N09-08 | Minor | ✅ 対応済み | inkscape 不要導入 | plan2.md §3/§5.1, prompts.md 10-1 作業内容 #2 で除外を明記 |
| N09-09 | Minor | ✅ 対応済み | resize_tables 保持/削除が曖昧 | plan2.md §7 移植表で「削除」に確定 |
| I09-01 | Info | 継続検討 | 初回 mermaid イメージビルド ~5 分 | plan2.md §12 のリスク表に残置。`mermaid-build` サブコマンド追加は Step 10 着手後の最適化 |
| I09-02 | Info | 継続検討 | Word 2016 未満フォールバック | plan2.md §7.3 で primary=PNG / 拡張=SVG 二段構成により Word 2013 でも表示可能（実質的に解消）。実 Word バージョンは Step 10 実装時に確認 |
| I09-03 | Info | 受容 | コンテナ起動オーバヘッド | plan2.md §12 リスク表に「当面は許容、将来ラッパ化検討」と記載 |

## report8.md との差分サマリ

- 前回の未対応項目で今回解消されたもの: **5件**
  - M08-01（copy_media 衝突時の rels Target 未更新）: `inject_narrative.py:326-337` でリネーム後に rels Target を書き換える処理が追加され解消。
  - C08-03（endnotes 未実装）: `_merge_notes()` を汎用化し `merge_endnotes()` が実装済み。
  - C08-02, C08-04, C08-05（ドキュメント表記）: Step 9 実装完了時にドキュメント整理されたと推定（report08 は「新規」指摘で、現在の prompts.md / SPEC.md に当該記述は見当たらず）。
- 前回の未対応項目で依然として未対応のもの: **0件**
- 前回に記載がなく今回新規発見したもの: **20件**

---

## 指摘事項

### [C09-01] (Critical) `embed_svg_native` の SVG パス解決が CWD 依存で、既定 CWD では全 SVG 埋込が失敗する

- **箇所**: `/home/dryad/anal/next-gen-comp-paper/scripts/wrap-textbox.py:703-708`（移植元）, `docs/plan2.md §7`, `main/step02_docx/build_narrative.sh`
- **前回対応状況**: 新規
- **内容**:
  移植元の `embed_svg_native()` は Markdown から抽出した image path をそのまま CWD 基準でオープンする:

  ```python
  image_paths = re.findall(r'!\[.*?\]\(([^)\s]+)', md_text)  # e.g. "figs/bg_hospital.jpg"
  svg_full_path = svg_path                                    # そのまま使う
  if not os.path.isfile(svg_full_path):
      print(f"  Warning: SVG file not found: {svg_full_path}")
      continue
  ```

  `build_narrative.sh:16` は `cd "$PROJECT_ROOT"` を実行するため、wrap_textbox が呼ばれる時点の CWD は `med-resist-grant/` プロジェクトルートである。一方 Markdown 内の画像参照は `figs/fig1_overview.svg`（youshiki1_2.md 基準の相対パス）。プロジェクトルートから見た実体は `main/step01_narrative/figs/fig1_overview.svg` なので **`os.path.isfile("figs/fig1_overview.svg")` は必ず False を返し、`asvg:svgBlob` 埋込は全件スキップされる**。

  警告は stdout に出るだけで exit 0 のため、CI も smoke test もパスしてしまう。デモを挿入した Prompt 10-4〜10-5 でも「asvg:svgBlob が生成されていない」ことが発見されるのは grep 時で、原因究明に時間がかかる。
- **影響**: Step 10 の中核機能（SVG ネイティブ埋込）が本番パイプラインで全く動かない。気付かずに提出 PDF を生成すると、Word では SVG が表示できない（a:blip の primary blip だけ残るため、pandoc が作った PNG フォールバックに頼ることになる。LibreOffice は primary を表示するため Linux 側で検出できない）。
- **推奨対応**:
  1. `wrap_textbox.py` の `embed_svg_native(source_md, ...)` で、各 image path を **`source_md` の親ディレクトリ基準** で `os.path.normpath(os.path.join(os.path.dirname(source_md), svg_path))` に解決する。
  2. SVG 未検出時は警告ではなく **非ゼロ exit**（または collector が件数を数えて最後に fail）として CI で検知可能にする。
  3. Prompt 10-5 の検証項目に「`word/media/svg*.svg` がコピーされているか」を加え、`grep asvg:svgBlob` の結果件数を明示的に検査する。

---

### [M09-01] (Major) docPr@id 採番値の不一致（plan2.md 1000 vs prompts.md 2000）

- **箇所**: `docs/plan2.md §12` の「wrap_textbox は 1000 番台を使用」vs `docs/prompts.md` Prompt 10-2「`wp:docPr/@id` は 2000 番台から採番」
- **内容**: 設計段階で既に矛盾している。移植元の `wrap-textbox.py:329`（`dp.set("id", str(1000 + z_order))`）は 1000 番台なので、移植元のまま使えば plan2.md と一致するが prompts.md と不一致。Prompt 10-2 を先に実装する担当者が 2000 台に書き換えると、plan2.md §12 のリスク表にある「template が同帯を使っていないか Prompt 10-1 前に確認」という検証計画がそもそも 1000 番台前提で立てられているため空回りする。
- **影響**: 方針がドキュメント間で一致しておらず、後日の「なぜこの番号？」という根拠追跡が困難。
- **推奨対応**: plan2.md と prompts.md で同じ値に揃える。テンプレート docx の既存 `wp:docPr/@id` を grep で確認したうえで、十分離れた帯（例: 3000 台）に確定させるのが安全。

---

### [M09-02] (Major) 様式1-2 と 様式1-3 を両方に図を置くと inject 後に docPr@id が重複する

- **箇所**: `main/step02_docx/inject_narrative.py:238-288 (merge_rels)`, 移植元 `wrap-textbox.py:329`
- **内容**: `wrap_textbox.py` は narrative docx 単位で 1000 + z_order（または 2000+）から採番する。現在は 様式1-2 にしか図を置かない予定だが、将来 様式1-3 にも `.textbox` を追加した場合、**両 narrative docx が同じ 1000 番台を独立採番する**。`inject_narrative.py` は rels の rId は renumber するが、`w:drawing/wp:docPr/@id` や `wp:docPr/@name` は触らない。結果として最終 `youshiki1_5_filled.docx` の body に同一 `id="1000"` を持つ docPr が複数存在し、**Word の DrawingML スキーマ制約（id 一意）に違反**する。

  Word はこの種の重複に対して「ファイルは開くが一部の図が表示されない」「『修復が必要』ダイアログが出る」のいずれかになるのが典型。LibreOffice でのテストではほぼ検出できない。
- **影響**: 2026 年 5 月の提出直前に「1-2 に加えて 1-3 にも図を入れたい」という要求が出た瞬間に、検出困難な形で壊れる。
- **推奨対応**:
  1. `inject_narrative.py` に「body 配下の `wp:docPr/@id` を再採番する」処理を追加し、narrative 1-2, 1-3 から注入される docPr@id を順にユニーク化する。
  2. あるいは `wrap_textbox.py` に `--docpr-id-base` 引数を追加し、build_narrative.sh 側で 1-2 は 3000、1-3 は 4000 から振るように分離する。
  3. plan2.md §9 の「inject 改修不要の見込み」を「1-2 にのみ図を置く前提での見込み」と明記する。

---

### [M09-03] (Major) mermaid サービスに `HOME` 未設定で puppeteer/chromium が任意 UID 実行時に起動しない可能性

- **箇所**: `docs/plan2.md §5.3` のサンプル compose 定義, `auto-eth-paper/docker/mermaid-svg/Dockerfile`
- **内容**: 既存 `python` サービスは `environment: HOME=/tmp` を持つ（`docker/docker-compose.yml:10`）。ホストユーザ UID で走るとコンテナ内に `$HOME` が存在しないため、pandoc/python にとっては多くの場合問題ないが、**puppeteer / chromium は `$HOME/.config` や `$HOME/.cache` への書き込みを行う**。`-u $(id -u):$(id -g)` で起動した場合、UID に対応するホーム（`/root` ではない）が存在せず、chromium 起動時に `ENOENT` や `EACCES` が出る。

  plan2.md §5.3 の mermaid サービス定義サンプルには `HOME` 環境変数の設定がない。既存 python サービスが HOME=/tmp で回避しているのと同じ配慮が必要。
- **影響**: Prompt 10-1 のスモークテストで「なぜか chromium が起動しない」症状に遭遇し、原因特定に時間がかかる。
- **推奨対応**: mermaid サービスに `environment: - HOME=/tmp` を明記。また `/tmp` は tmpfs の場合書き込み可能なので puppeteer cache の永続化は諦めてよい。Dockerfile 側で `ENV HOME=/tmp` を追加するとさらに堅い。

---

### [M09-04] (Major) `inject_narrative.py` の NSMAP に `asvg` 名前空間が未登録

- **箇所**: `main/step02_docx/inject_narrative.py:32-48 (NSMAP)`
- **内容**: inject_narrative.py の NSMAP は `w, r, wp, wp14, wps, a, mc, m, o, v, w10, pic, wpc, w14, w15` を持つが、`asvg = http://schemas.microsoft.com/office/drawing/2016/SVG/main` が含まれていない。narrative docx を `ET.fromstring` で読み込むと asvg URI を持つ要素が `{asvg-uri}svgBlob` として格納され、再シリアライズ時に ET は未登録 URI に自動 prefix（`ns0` 等）を割り当てる。

  `restore_root_tag()` は新規 xmlns 宣言を取り込むので **名前空間バインディング自体は有効**（Word は URI ベースで解決するため動作する）。ただし:
  1. 文書の可読性・Microsoft 標準 prefix との乖離により Windows Word 上での再保存・差分比較・検証が難しくなる。
  2. `mc:AlternateContent` の `Requires="asvgN"` が Python 生成コードに現れると、prefix がリネームされた場合 Word が解決できなくなる（現在の wrap-textbox.py は `mc:AlternateContent` で asvg を包まないので直接の問題はないが、将来の拡張でリスクあり）。
- **影響**: 現状では動作するが、将来の Word 連携で「プレフィクスが原因で破損扱い」される可能性。plan2.md §9 の「inject 改修不要」という大前提が崩れる境界線にある。
- **推奨対応**: `inject_narrative.py` の NSMAP に `asvg` を追加し、`ET.register_namespace("asvg", "http://schemas.microsoft.com/office/drawing/2016/SVG/main")` を呼ぶ（1 行の最小変更）。併せて `a14`（drawingML 2010 extensions, `http://schemas.microsoft.com/office/drawing/2010/main`）も現代の Word 出力で頻出するので追加を検討。

---

### [M09-05] (Major) 検証計画が LibreOffice のみで Windows Word COM 互換を検証していない

- **箇所**: `docs/plan2.md §11 検証計画 #5`, `docs/prompts.md` Prompt 10-5 検証項目 #3
- **内容**: 検証計画の PDF 化は `libreoffice --headless --convert-to pdf` を使っているが、**本番パイプラインは `scripts/roundtrip.sh` 経由で Google Drive → Windows `watch-and-convert.ps1` → Word COM → PDF** である（CLAUDE.md §Workflow 参照）。LibreOffice は primary blip（PNG フォールバック）を表示する一方、Windows Word は `asvg:svgBlob` を解釈する。つまり:
  - LibreOffice で見えている画像は SVG ではなく PNG フォールバック
  - Windows Word で見える画像は SVG
  - 両者の表示不一致（フォントレンダリング、ベクタ線の太さ、ラスタ解像度）は LinuxCI では検知できない

  さらに Windows Word が `mc:AlternateContent` や `asvg:svgBlob` のまわりで `wp:anchor` 属性（`anchor-v="paragraph"`, `anchor-h="column"`）と組み合わさった時の実挙動は検証計画に含まれていない。
- **影響**: 「LibreOffice で通ったから OK」と判断して提出 PDF を作ると、Windows 側で想定外のレイアウトずれやアイコン欠落が発生し得る。
- **推奨対応**:
  1. `scripts/roundtrip.sh` を用いた Windows PDF 経由の検証を Prompt 10-5 の完了チェックに明記する。
  2. 少なくとも「1 回は `roundtrip.sh` を通して Windows 側 PDF で図が視認できることを確認する」手順を追加。
  3. LibreOffice での結果は参考扱いとし、本番合否判定には使わない旨 plan2.md §11 に注記。

---

### [M09-06] (Major) build_narrative.sh Phase A の unquoted glob + `set -euo pipefail` で .mmd ゼロ件時に失敗

- **箇所**: `docs/plan2.md §8` Phase A の擬似コード
  ```bash
  for mmd in main/step01_narrative/figs/*.mmd; do
      svg="${mmd%.mmd}.svg"
      ...
  done
  ```
- **内容**: 既存 `build_narrative.sh:11` は `set -euo pipefail`。デフォルトの bash では nullglob が無効なので、`figs/*.mmd` にマッチが無いとリテラル文字列 `main/step01_narrative/figs/*.mmd` がループ変数に入り、`[[ ! -f "$svg" ]]` が true になり mmdc にリテラル glob を渡す。mmdc は ENOENT で非ゼロ終了。

  特に **dummy E2E（`DATA_DIR=data/dummy`）では .mmd が 1 つも無い場合に .textbox 機能を使わない運用が許容されるため**、Phase A はこの状況でフェイルしてはいけない。
- **影響**: Prompt 10-3 完了チェックの「dummy E2E が通る」を実装時に満たせず、手戻り発生。
- **推奨対応**:
  ```bash
  shopt -s nullglob
  for mmd in main/step01_narrative/figs/*.mmd; do
      ...
  done
  shopt -u nullglob
  ```
  または `compgen -G` / `find ... -print0 | while read` への書き換え。

---

### [M09-07] (Major) Lua フィルタから `.svg → .svg.png` Pass 1 を落とすことで pandoc のフォールバック挙動が前提から外れる可能性

- **箇所**: `docs/plan2.md §6`「**削除**: Pass 1 の `.svg → .svg.png` リネーム」, `filters/jami-style.lua:122-130`
- **内容**: 移植元の Pass 1 は SVG 参照を `.svg.png` に書き換え、pandoc には PNG のみを primary blip として入れさせる設計だった（一次画像は必ず PNG、SVG は `asvg:svgBlob` で添付）。新設計ではこれを削除し、pandoc に SVG を直接参照させる。

  **pandoc 3.6.x の docx writer は SVG 画像を受け取ると内部的に `wp:inline > a:graphic > pic:pic` の primary blip に SVG を使う**。ただし pandoc のバージョンや内部オプション次第で「SVG 入力時は rsvg-convert で PNG 化してから埋め込む」実装になっているケースもあり、挙動が pandoc のビルドに依存する。

  さらに Word にとって `a:blip` の primary が SVG だと、`asvg:svgBlob` 拡張なしに SVG が直接展開されるケースがあり、**LibreOffice では表示できるが Word では `unknown blip format` となる**実例が報告されている。
- **影響**: Lua フィルタの最小化に伴う前提崩れ。`embed_svg_native` が補填しようとしても primary blip が既に SVG / PNG のどちらなのか wrap_textbox 側が知らないため、二重埋込みや素 SVG のまま残るパターンが発生しうる。
- **推奨対応**:
  1. docker/python/Dockerfile に `librsvg2-bin`（`rsvg-convert`）を追加し、build_narrative.sh に **"svg → svg.png" 事前変換フェーズ** を移植する。一次画像は必ず PNG、`asvg:svgBlob` は追加情報、という構成を維持する。
  2. あるいは Prompt 10-5 の検証で「primary blip が PNG であること（`word/media/image*.png` の有無）」を明示的に確認する。

---

## Minor 指摘

### [N09-01] plan2.md §6 と Prompt 10-2 完了チェックの行数目標が異なる
- **箇所**: plan2.md §6「40〜60 行程度」vs prompts.md Prompt 10-2「100 行以下の最小構成」
- **推奨対応**: どちらかに統一（おそらく 100 行以下のほうが現実的）。

### [N09-02] Prompt 10-2「inject_narrative.py と同じ名前空間定数を使用（コピーで可）」が asvg を落とす
- **箇所**: prompts.md Prompt 10-2「技術的注意事項」
- **内容**: M09-04 と連動。inject_narrative.py の NSMAP には asvg が無いので、その表現どおりに「コピー」すると wrap_textbox.py が asvg 名前空間を register できず、`embed_svg_native` が `{http://schemas.microsoft.com/office/drawing/2016/SVG/main}svgBlob` を自動 prefix で吐く。
- **推奨対応**: プロンプトで「asvg を追加したうえでコピー」と明記。

### [N09-03] Prompt 10-1 スモークテストが日本語 `<text>` 要素の存在を確認するが、.mmd に日本語の指示がない
- **箇所**: prompts.md Prompt 10-1 作業内容 #3「日本語テキストが `<text>` 要素に入っていることを確認」
- **推奨対応**: `_smoke_test.mmd` に `A[日本語ラベル] --> B[テスト]` を含める指示を追加。

### [N09-04] Prompt 10-2 スモークテストがホスト pandoc を直接呼び出している
- **箇所**: prompts.md Prompt 10-2 動作確認「`pandoc main/step01_narrative/youshiki1_2.md --lua-filter=... -o /tmp/tb_smoke.docx`」
- **内容**: Docker-only 方針と矛盾。ホスト pandoc が存在するとは限らない。
- **推奨対応**: `docker compose -f docker/docker-compose.yml run --rm -u $(id -u):$(id -g) python pandoc ...` に統一。

### [N09-05] plan2.md §2.2 と Prompt 10-4 でデモの anchor-h 既定が異なる
- **箇所**: plan2.md §2.2「`anchor-h` / `anchor-v` は `margin` / `paragraph` を既定にする」vs prompts.md Prompt 10-4「anchor-h=column anchor-v=paragraph」
- **影響**: wrap_textbox の既定値と Markdown デモの指定値が不一致。実質はブロック属性で上書きするので壊れないが、設計意図の追跡が困難。
- **推奨対応**: plan2.md §2.2 で「本文フロー内なら column、欄外に逃がすなら margin」と用途別に整理。

### [N09-06] Prompt 10-4 が「.gitignore 方針は plan2.md で再確認」を指示するが、plan2.md に該当記述なし
- **箇所**: prompts.md Prompt 10-4「fig1_overview.svg（ビルド生成物、.gitignore 方針は plan2.md で再確認）」, plan2.md 全編
- **推奨対応**: plan2.md §3 または §12 に「`figs/*.svg` は .gitignore 済み（生成物）/ not-ignored（確定版をコミット）」の方針を 1 行追加。Prompt 10-4 実装前に決める。

### [N09-07] build_narrative.sh の Phase A 実行回数が曖昧
- **箇所**: plan2.md §8 Phase A
- **内容**: Phase A の mmd→svg 変換は narrative ソースと独立（どの md がどの svg を使うかを解析していない）。書きぶりが「pandoc 変換の直前に 1 回まとめて走る」のか「md ごとに走る」のか曖昧。後者だと同一 svg を 2 回ビルドする非効率。
- **推奨対応**: Phase A は `reference.docx 生成` の直後、md ループの外で 1 回のみ実行、と明記する。

### [N09-08] auto-eth-paper Dockerfile の `inkscape` が不要
- **箇所**: auto-eth-paper/docker/mermaid-svg/Dockerfile:12
- **内容**: inkscape は SVG→PDF 変換用で、.mmd→.svg の出力では不要。イメージ肥大化と初回ビルド時間の悪化。
- **推奨対応**: med-resist-grant にコピーする際に `inkscape` を除外。

### [N09-09] plan2.md §7 の `resize_tables_in_content` 保持/削除方針が曖昧
- **箇所**: plan2.md §7「保持でも可。複雑化を避けるなら削除」
- **推奨対応**: どちらかに確定。テキストボックス内にテーブルを置くユースケースが無いなら削除で単純化。

---

## Info

### [I09-01] 初回 mermaid イメージビルド約 5 分が dummy E2E に影響
- **箇所**: plan2.md §12
- **内容**: CI や共同執筆環境（Step 8 で構築した collab_watcher.sh）で dummy ビルドが毎回 5 分遅くなるのは許容しがたい。`./scripts/build.sh mermaid-build` のような事前ビルドサブコマンドで一度だけビルドし、`docker image ls` キャッシュに依存する運用が妥当。
- **提案**: Prompt 10-1 の完了チェックに「mermaid-build サブコマンドの追加」を加えるか、plan2.md §12 の「事前ビルドを提供」を具体化する。

### [I09-02] Word 2016 未満フォールバックの投入時期が未確定
- **箇所**: plan2.md §12 最下段、§7「フォールバック用に rsvg-convert で 300dpi PNG を同時生成」
- **内容**: 将来 enhancement として記述されているが、実際に Word 2013 が使われる可能性（防衛装備庁の審査端末環境）を知らない段階で「将来」扱いにするのはリスク。
- **提案**: 募集要項またはヘルプデスクに Word のバージョン指定があるか確認する Info タスクを追加。

### [I09-03] Phase A を毎回 `docker compose run` で回すとコンテナ起動オーバヘッドが N 倍
- **内容**: mmdc 自体は高速だが、`docker compose run --rm` は都度 1〜3 秒のオーバヘッド。図が 10 個になると 30 秒。
- **提案**: 将来的には 1 回のコンテナで複数 .mmd を処理するラッパ `convert-mermaid.sh` を用意（auto-eth-paper のスクリプトはむしろこの形に近い）。短期的には許容。

---

## リスクマトリクス（plan2.md §12 への追加項目）

| リスク | 影響度 | 発生確率 | 総合評価 | 対策 |
|--------|--------|---------|---------|------|
| `embed_svg_native` の CWD パス解決ずれ | 高 | 高（ほぼ確実） | **Critical** | source_md 親ディレクトリ基準で resolve（C09-01） |
| docPr@id の narrative 間重複（1-2 & 1-3） | 高 | 中（将来 1-3 に図を追加したら発現） | **Major** | inject_narrative.py で renumber or docpr-id-base 分離（M09-02） |
| mermaid puppeteer HOME 未設定 | 高 | 中（UID 次第） | **Major** | compose に HOME=/tmp（M09-03） |
| Windows Word 側レンダリングの未検証 | 中 | 中 | **Major** | roundtrip.sh 経由での合否判定を必須化（M09-05） |
| Lua フィルタ最小化による primary blip 不整合 | 中 | 中 | **Major** | svg→svg.png 事前変換を復活させるか検証項目追加（M09-07） |
| bash glob ゼロ件失敗 | 中 | 高（実装時に必ず踏む） | **Major** | shopt -s nullglob（M09-06） |
| asvg 名前空間 prefix リネーム | 低 | 低（Word は URI 解決するのでほぼ通る） | Minor | NSMAP に asvg 追加（M09-04） |
| 初回イメージビルド 5 分 | 低 | 中 | Minor | 事前ビルドサブコマンド |
| inkscape 不要導入 | 低 | 高 | Info | Dockerfile から除外 |

---

## 総評

Step 10 の設計は全体として妥当で、`inject_narrative.py` の現在の実装（rels/media/content-types/root-tag 保存）は確かにテキストボックスと SVG を「原則透過的に」運搬できる。plan2.md §2.1 の主張は概ね正しい。

初版レビューで Critical 1 件・Major 7 件・Minor 9 件・Info 3 件を発見した。**特に C09-01（embed_svg_native のパス解決バグ）は LibreOffice 検証では発見できない silent fail で、Step 10 の中核機能を完全に無効化する致命傷だった**。他にも M09-02（docPr@id 重複）と M09-05（Windows Word での検証欠落）は「plan2.md §9 の "inject 改修不要" という楽観的前提」の裏面で、前提を少し崩すと再帰的に発現する設計上の脆弱点だった。

## 対応結果（2026-04-15 追記）

ユーザ承認のうえ、上記指摘を重要度順に修正完了:

1. **コード修正 1 件**: `main/step02_docx/inject_narrative.py:48-49` に `asvg` / `a14` 名前空間を追加（M09-04）。
2. **設計ドキュメント修正**: `docs/plan2.md` を §2.2 / §3 / §5.1 / §5.3 / §5.4 / §6 / §7 / §7.1 / §7.2 / §7.3 / §8 / §9 / §9.1 / §10 / §11 / §12 にわたり全面更新。
3. **プロンプト修正**: `docs/prompts.md` Step 10（Prompt 10-1, 10-2, 10-3, 10-5）を作業内容・完了チェック含めて更新。

この結果 **Critical/Major 全 8 件と Minor 全 9 件は対応完了**、Info 3 件のうち 2 件は実装フェーズへの継続検討（Word バージョン確認、`mermaid-build` サブコマンド追加）、1 件はリスク受容として記載。

**Step 10 の実装着手は安全に進められる状態**になった。Prompt 10-1 から順に着手してよい。
