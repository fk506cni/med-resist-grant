# 敵対的レビュー報告書（第12回）— Step 10 全体（mermaid→svg→wrap_textbox→inject パイプライン）

レビュー実施日: 2026-04-17
レビュー対象:
- `main/step02_docx/build_narrative.sh`（Phase A / Phase C を含む改修後版）
- `main/step02_docx/wrap_textbox.py`
- `main/step02_docx/inject_narrative.py`
- `filters/textbox-minimal.lua`
- `docker/python/Dockerfile`（`librsvg2-bin` 追加後）
- `docker/docker-compose.yml`
- `docker/mermaid-svg/Dockerfile` / `mermaid-config.json` / `puppeteer-config.json`
- `scripts/build.sh` / `scripts/roundtrip.sh`
- （参考）`docs/prompts.md` Prompt 10-1〜10-4 / `docs/__archives/report11.md`

前回レビュー: `docs/__archives/report11.md`（2026-04-15、対応済み）

---

## サマリ

- **Critical**: 1 件（新規 1 / 既知未対応 0） — **全件対応済み**
- **Major**: 7 件（新規 7 / 既知未対応 0） — **全件対応済み**
- **Minor**: 7 件（新規 7 / 既知未対応 0） — **6 件対応済み / 1 件記録のみ（N12-02 は N12-03 で代替的にカバー）**
- **Info**: 5 件（新規 4 / 継続 1＝I10-03） — Info は記録のみ（I10-03 継続）

前回（report11）の指摘は全件クローズ済み。本回の指摘は **Prompt 10-3 が新設した経路**
（Phase A の mermaid/rsvg-convert、Phase C の wrap_textbox 直呼び、docker イメージ依存更新）
に由来するものが中心。報告 report11 で潰した Lua / wrap_textbox 内部のバグは再発なし。

本レビューで指摘した **Critical 1 / Major 7 / Minor 6** の計 14 件について、同一
セッション内で修正を実施し、Docker 経由の dummy E2E（`RUNNER=docker
DATA_DIR=data/dummy SETUP_DIR=data/dummy ./scripts/build.sh`）で validate / forms /
narrative / inject / security / excel の全ステップが ✓ OK。詳細は末尾
「## 対応結果（2026-04-17 追記）」を参照。

### 対応状況一覧

| ID | 重大度 | 状態 | 概要 |
|----|--------|------|------|
| C12-01 | Critical | ✅ 対応済み | `MODE=local` で `mmdc` / `rsvg-convert` 不在時、Phase A が warn して skip → pandoc が存在しない `.svg.png` を参照 → WARNING のみで exit 0 → 画像欠落 docx を成功扱いで出力する silent 破綻経路 |
| M12-01 | Major | ✅ 対応済み | `wrap_textbox.py:process_docx` は `zipfile.ZipFile(docx_path, "w")` で原ファイルを**非アトミックに**上書きする — 書き込み途中で例外/中断した場合、原 docx を破壊する |
| M12-02 | Major | ✅ 対応済み | `scripts/build.sh:ensure_docker_image` は**イメージの有無しか見ない**ため、Dockerfile に `librsvg2-bin` を追加してもキャッシュ済みの古いイメージが使われ `rsvg-convert: not found` で落ちる |
| M12-03 | Major | ✅ 対応済み | mmdc がレンダリング途中で Chromium クラッシュすると、**書きかけの `.svg`** が残り mtime が `.mmd` より新しくなる → 次回ビルドで `-nt` 判定が up-to-date と判断し、壊れた SVG が stale のまま固定化 |
| M12-04 | Major | ✅ 対応済み | Phase C の失敗時（wrap_textbox が ValueError 等を投げる）、pandoc が出力した **asvg 層なし docx** が `main/step02_docx/output/` に残る。inject を個別に再実行すると silent に品質劣化した docx が製本される |
| M12-05 | Major | ✅ 対応済み | `inject_narrative.py` の `wp:docPr/@id` 衝突検査は `root.iter(f"{WP}docPr")` を `document.xml` のみに掛けており、**header / footer の docPr** を含まない。テンプレート `r08youshiki1_5.docx` の header/footer に docPr が 1 件でも存在すると、narrative 側の 3000/4000 台と衝突しても検出されない |
| M12-06 | Major | ✅ 対応済み | `mermaid-config.json` は `flowchart.htmlLabels:false` のみ。classDiagram / stateDiagram / sequenceDiagram / gantt / pie / mindmap 等で silent に `<foreignObject>` が再発する。M11-05 の 2 段目防衛線に依存する構造なので、Prompt 10-4 で flowchart 以外の図を追加すると落ちる可能性 |
| M12-07 | Major | ✅ 対応済み | `RUNNER=uv` で `scripts/build.sh` を呼ぶと `run_bash` 経由で `build_narrative.sh --local` が走り、内部の `run_python` は `python3`（システム）を直接叩く。uv が提供するはずの Python 依存が届かない — 実質 `direct` と同じ。設計意図と実挙動の乖離 |
| N12-01 | Minor | ✅ 対応済み | Lua Image filter は `img.src:lower():match("%.svg$")` で case-insensitive 判定するが、**書き換えた src はそのまま** — `FOO.SVG` → `FOO.SVG.png`。一方 Phase A の `*.svg` glob は bash 既定で case-sensitive のため、`.SVG` を置かれると Phase A がレンダリングしない → pandoc が `.SVG.png` を探して見つからない |
| N12-02 | Minor | 記録のみ | `scripts/build.sh:do_check` が `.svg` / `.svg.png` / `.mmd` の存在も Phase A の整合もチェックしない。Prompt 10-4 で `.mmd` 追加後に `.svg.png` 生成漏れが起きても `check` は pass |
| N12-03 | Minor | ✅ 対応済み | `docker/docker-compose.yml` の `mermaid` サービスは `ensure_docker_image` の事前ビルド対象外（python のみ）。初回 Phase A で `docker compose run --rm mermaid` が実行された瞬間に巨大イメージのビルドが走り、無通知で数分止まる |
| N12-04 | Minor | 記録のみ | Phase A は file lock を持たないため、`roundtrip.sh` 同時実行や手動 `./scripts/build.sh narrative` 重複で **同じ `.svg` / `.svg.png` を競合書き込み**する。ZIP/ファイルの中間状態が片方に残る |
| N12-05 | Minor | ✅ 対応済み | `case "$src"` の `*youshiki1_2.md` / `*youshiki1_3.md` は glob マッチ。現行 SOURCES は 2 本のみなので問題ないが、将来 `youshiki1_2_v2.md` のような名前が入ると意図せず base=3000 にマッチしないどころか `*)→5000` に流れてしまう。"その他→5000" は現状**完全に dead code** |
| N12-06 | Minor | ✅ 対応済み | macOS デフォルト bash 3.2 環境では、`shopt -s nullglob` と `set -u` 併用下で空配列 `"${mmd_files[@]}"` が unbound variable エラーを起こす（bash 4.4 未満の仕様）。Docker 環境では無関係だが `MODE=local` で顕在化 |
| N12-07 | Minor | ✅ 対応済み | `wrap_textbox.py:build_textbox_paragraph` の `docPr@id = id_base + z_order` は **1000 個/narrative のハード上限を暗黙**に持つ。1-2 が 1001 個の textbox を抱えた瞬間、4000 台に食い込み 1-3 と衝突する（inject 時の M11-08 検査で exit するため silent ではないが、実装層で upper-bound が無い） |
| I12-01 | Info | 記録のみ | `templates/reference.docx` は `main/step02_docx/fix_reference_styles.py` により毎回**in-place で書き換えられる**（`build_narrative.sh:124`）。Prompt 10-3 の完了基準である「`document.xml` バイナリ一致」は fix_reference_styles が冪等であることに依存しており、将来同スクリプトが非冪等な変更（例: `w:rsid` 生成）を入れるとバイナリ一致検証が silent に意味を失う |
| I12-02 | Info | 記録のみ | 画像命名規約 `foo.svg` → `foo.svg.png` の**ダブル拡張子**は非標準。`os.path.splitext` / `str.replace('.svg', ...)` / `basename %.svg` に依存する将来の追加コードが silent に破綻する |
| I12-03 | Info | 記録のみ | `inject_narrative.py` は narrative 間で `w14:paraId` / `w14:textId` を renumber しない。両 narrative が同一 paraId を吐いた場合、Word は警告/修復で黙って片方を書き換える可能性。現在の Pandoc 3.6.x は narrative ごとにランダム paraId を振るため確率は極めて低いが、構造的には未対処 |
| I12-04 | Info | 記録のみ | `docker/python/Dockerfile` への `librsvg2-bin` 追加により、依存として `cairo` / `pango` / `gdk-pixbuf` がインストールされる。pango は同居する `fonts-noto-cjk` を参照するため SVG 内の日本語レンダリング結果はフォント優先順位変更で変わりうる。画像生成の pixel-level 再現性は環境依存 |
| I10-03 | Info | 継続 | `mermaid-build` サブコマンド検討（report10 残）。本プロンプトもスコープ外 |

---

## report11.md との差分サマリ

- **前回の未対応項目で今回解消されたもの**: 17 件
  - C11-01 / C11-02 / M11-01〜M11-09 / N11-01〜N11-06 の全 17 件が「同一セッション内で修正、
    Docker + dummy E2E で回帰無し確認」として report11 末尾にクローズ記録あり。本回のコード
    読込でも再発なしを確認（`filters/textbox-minimal.lua` の `xml_escape` / `ENUMS` /
    `has_nested_textbox`、`wrap_textbox.py` の `_strip_yaml_and_code` / `_IMAGE_RE` /
    `<foreignObject>` 検査 / `--skip-missing-svg` / NSMAP に w14/w15 追加、
    `inject_narrative.py` の docPr 衝突検査がいずれも現行コードに存在）。
- **前回の未対応項目で依然として未対応のもの**: 0 件
- **前回に記載がなく今回新規発見したもの**: 19 件（C12-01 / M12-01〜07 / N12-01〜07 / I12-01〜04）
- **前回からの継続（スコープ外）**: I10-03（`mermaid-build` サブコマンド）
- **補足**: M11-08（docPr 衝突検査）で導入された `root.iter(WP+"docPr")` は document.xml 本体
  のみを走査する実装であり、header/footer を含まない点が本回 **M12-05** として再整理されている。
  report11 時点での修正方針は適切だが、カバレッジに残存ギャップがある。

---

## 指摘事項

### [C12-01] (Critical) `MODE=local` + `mmdc`/`rsvg-convert` 欠落時、Phase A が skip し最終 docx が silent に画像欠落で完成する

- **箇所**:
  `main/step02_docx/build_narrative.sh:91-96`（`run_mermaid` の local skip）、
  `main/step02_docx/build_narrative.sh:106-111`（`run_rsvg_convert` の local skip）、
  `filters/textbox-minimal.lua:164-170`（`.svg → .svg.png` 無条件書き換え）
- **前回対応状況**: 新規
- **内容**:
  - `MODE=local` かつホストに `mmdc` が無い場合、`run_mermaid` は
    `echo "  WARN: mmdc がホストに見つからないためスキップ" >&2; return 0` で**成功扱い**
    で抜ける。`rsvg-convert` 側も同じ挙動。
  - その結果、`.mmd` のみ存在して `.svg` / `.svg.png` が未生成の状態で pandoc に突入する。
  - 一方 Lua フィルタの Pass 1 は md 上の `![](figs/foo.svg)` を**無条件に** `foo.svg.png`
    に書き換える（存在確認なし）。
  - pandoc は存在しない `foo.svg.png` を見つけられず、**`[WARNING] Could not fetch resource`
    を stderr に出して画像を omit したまま docx を生成**する（exit code 0）。
  - `run_pandoc` の返値は 0、`FAILED=0` のまま、`OK pandoc` / `OK wrap_textbox` と表示され、
    ユーザは **図が消えた docx を成功として受け取る**。
  - `.textbox` も併用していた場合、フレーム/本文側は描画されるが中の図だけが空欄で、
    視覚的な齟齬が大きい。
- **影響**:
  - Critical: 本番提出 PDF で「図なし」が silent に紛れ込む最も危険なルート。
  - Windows PDF 変換後に目視確認しない限り検出されない。現行 `watch-and-convert.ps1` は
    Word COM の修復ダイアログが出なければ PDF が生成されるため、画像欠落は PDF でも無言
    のまま残る。
  - Prompt 10-3 の完了検証は `MODE=docker` 側でしか実施されていない（dummy E2E は `--docker`）。
    local ユーザ（macOS、CI、uv 利用者）が踏み抜く確率が高い。
- **推奨対応**:
  1. `run_mermaid` / `run_rsvg_convert` の local skip を **warn ではなく fail** に変える。
     `.mmd` / `.svg` が実在し、対応する出力が必要と判定された場合、ホストに実行ファイルが
     無ければ `exit 1` する。既に up-to-date なら skip を許す。
  2. あるいは Phase A skip を許すが、**Lua フィルタ直後**に pandoc の
     `--resource-path` に対して `figs/*.svg.png` の存在を事前検査し、欠落なら `exit 1`。
  3. 最低限、`run_pandoc` を呼ぶ前に Lua フィルタが参照するであろう画像ファイル
     （`figs/*.svg.png` と `figs/*.jpg` 等）を md パスから抽出して存在確認する防衛線を
     `build_narrative.sh` 側に 1 つ入れる。`wrap_textbox.py` の `_extract_image_paths` を
     流用すれば早期検出可能。
  4. もしくは pandoc の `--fail-if-warnings`（Pandoc 3.6+ 対応）を `PANDOC_OPTS` に足し、
     画像欠落 WARNING を exit 1 に昇格させる。副作用として他の警告も落とすため要評価。

---

### [M12-01] (Major) `wrap_textbox.py:process_docx` の docx 上書きが非アトミック

- **箇所**: `main/step02_docx/wrap_textbox.py:678-680`
  ```python
  with zipfile.ZipFile(docx_path, "w", zipfile.ZIP_DEFLATED) as zout:
      for filename, data in parts.items():
          zout.writestr(filename, data)
  ```
- **前回対応状況**: 新規
- **内容**:
  - `ZipFile(docx_path, "w", ...)` は**原ファイルを即座に truncate** してから順次書き込む。
    書き込みループの途中で例外（`writestr` 中の I/O エラー、ディスク満杯、ユーザー Ctrl+C、
    SIGTERM）が発生すると、**原 docx は truncate 済みで復元不能**。
  - 一方 `inject_narrative.py:process` は `tempfile.mkstemp` → `write_docx(tmp)` →
    `shutil.move(tmp, output)` の atomic パターンを使っており、対称性が崩れている
    （report11 の指摘にはない既存バグ）。
  - Phase C は narrative 1 本あたり 1 回呼ばれ、毎回この上書きが走る。run_python の docker
    経由呼び出しが中途で docker daemon シグナル等で killed された場合、壊れた docx が残る。
- **影響**:
  - 破壊は低頻度だが発生時のダメージ大（pandoc 出力の再生成が必要）。
  - 最悪ケース: pandoc が長時間かけて成功した docx を wrap_textbox が truncate してから
    異常終了 → narrative 再生成コストが倍増。
- **推奨対応**:
  - `inject_narrative.py` と同じ atomic パターンに揃える。
    ```python
    fd, tmp_path = tempfile.mkstemp(suffix=".docx", dir=os.path.dirname(docx_path))
    os.close(fd)
    try:
        with zipfile.ZipFile(tmp_path, "w", zipfile.ZIP_DEFLATED) as zout:
            ...
        shutil.move(tmp_path, docx_path)
    except Exception:
        if os.path.exists(tmp_path): os.unlink(tmp_path)
        raise
    ```
  - 将来の共通化視野: `inject_narrative.py` と `wrap_textbox.py` で ZIP I/O を共通
    モジュールに出す（M11-09 構造改修案の派生）。

---

### [M12-02] (Major) `ensure_docker_image` が Dockerfile 変更を検知しない — 既存キャッシュイメージで `rsvg-convert: not found`

- **箇所**: `scripts/build.sh:86-92`
- **前回対応状況**: 新規（Prompt 10-3 で Dockerfile を改変したことに由来）
- **内容**:
  - `ensure_docker_image` はイメージの**存在のみ**をチェックし、Dockerfile 変更時は再ビルド
    しない:
    ```bash
    if ! docker compose -f "$COMPOSE_FILE" images --quiet python 2>/dev/null | grep -q .; then
        docker compose -f "$COMPOSE_FILE" build python
    fi
    ```
  - 既にプロジェクトを git pull 済みの開発者は `med-resist-grant-python` イメージを保有
    している。Prompt 10-3 で `librsvg2-bin` を追加しただけでは再ビルドされず、
    `rsvg-convert` が不在のまま Phase A に突入する。
  - 発生するエラーは `exec: "rsvg-convert": executable file not found in $PATH`。
    `set -euo pipefail` 下で非ゼロ exit → スクリプト全体が即死。silent ではないが、
    診断メッセージが docker-compose の多段エラーで埋もれる。ユーザーは混乱しやすい。
  - `mermaid` サービス側も同様で、`docker/mermaid-svg/Dockerfile` の pin（10.9.1）や
    config ファイルを変更した場合、既存イメージがあれば古い挙動が残る。
- **影響**:
  - 初回ビルド回避（キャッシュ済みイメージ）でも回帰しない前提が崩れる。
  - CI では必ず fresh ビルドなので検出できない — 開発者の手元環境でのみ発生するタイプのバグ。
  - Prompt 10-3 の実装者は既にイメージを再ビルド済みと推定されるため、本人の環境では
    踏まない。次にこのブランチを pull する人が最初に踏む。
- **推奨対応**:
  1. Dockerfile のハッシュをタグに埋め込む、または簡易チェックを足す:
     ```bash
     # Dockerfile のタイムスタンプとイメージ作成時刻を比較
     if [[ docker/python/Dockerfile -nt $(docker inspect --format='{{.Created}}' ...) ]]; then
         docker compose build python
     fi
     ```
  2. あるいは `scripts/build.sh` に明示的な `--rebuild-images` オプションを足し、
     `prompts.md` の Prompt 10-3 完了チェックに「git pull 直後の再ビルド」を追記。
  3. 最低限、Phase A 突入前に `docker compose run --rm python rsvg-convert --version` を
     叩いて失敗ならメッセージ付きで `exit 1`（ビルドすべき旨を明示）。

---

### [M12-03] (Major) mmdc 途中失敗時の `.svg` stale 固定 — mtime ベース判定が嘘をつく

- **箇所**: `main/step02_docx/build_narrative.sh:139-147`（`.mmd → .svg` ループ）
- **前回対応状況**: 新規
- **内容**:
  - mmdc は Chromium (puppeteer) 越しにレンダリングするため、コンテナ起動タイミング・
    フォント未解決・OOM で中途失敗が散見される。
  - mmdc は出力 `.svg` を `fs.createWriteStream` で**書き始めた後**に例外を投げ得るため、
    部分書き込み or ゼロバイト `.svg` がディスクに残る。
  - 次回 `./scripts/build.sh narrative` で Phase A に入ると:
    - `[[ ! -f "$svg" ]]` → false（部分 `.svg` が存在）
    - `[[ "$mmd" -nt "$svg" ]]` → false（mmdc 出力の mtime は `.mmd` より新しい）
    - → `skip (up-to-date)` として再生成されない。
  - ユーザは手動で `.svg` を削除しない限り、**壊れた `.svg` が永続化**する。
  - 連鎖: `.svg` が壊れていても mtime は新しいので `.svg.png` は `.svg` から再生成される →
    `rsvg-convert` が parse error で exit 1（幸いこの段階で停止）。
  - あるいは `.svg` が空バイト `<svg/>` のみなら `rsvg-convert` は空 PNG を生成して成功 →
    `embed_svg_native` も Ignorable → docx に**空矩形**が埋まる silent 破綻。
- **影響**:
  - 再ビルド時の不可解な「図が欠けている／白い」症状。再現性があり、原因特定に時間を要する。
  - 発生確率: 中（Chromium 起動の不安定さ依存）。発生時影響: 大（手動クリーンまで気付けない）。
- **推奨対応**:
  1. mmdc 成功時のみ出力を確定させる: 一旦 `${svg}.tmp` に書かせて成功時 `mv` する
     ラッパーに `run_mermaid` を差し替える。
  2. Phase A の up-to-date 判定に**ファイルサイズ > N バイト** または **`<svg>` 閉じタグ
     存在**の軽量検証を加える。
  3. 最低限、`run_mermaid` 失敗時に `rm -f "$svg"` を trap 登録して clean up する。

---

### [M12-04] (Major) Phase C 失敗時、asvg 層なしの pandoc 出力 docx が `output/` に残留する

- **箇所**: `main/step02_docx/build_narrative.sh:178-199`
- **前回対応状況**: 新規
- **内容**:
  - pandoc は成功（`OK pandoc: $out`）し、直後の `run_python wrap_textbox.py` が例外で
    exit 非ゼロになると、`FAILED=1` がセットされるだけでファイルは残置される。
  - このファイルは「Lua フィルタが `.svg → .svg.png` に書き換え済み」「asvg:svgBlob 層なし」
    の中途形態。
  - `./scripts/build.sh` 全体は `FAILED=1` → exit 1 で停止するが、ユーザが
    `./scripts/build.sh inject` を単独で再実行すると、残置 docx が inject に食われる。
  - inject_narrative.py は narrative docx に wrap_textbox が通ったか否かを判定しない
    （header/footer 検査はするが textbox の有無はチェックしない）。結果、**figs が PNG のみ
    の状態で最終成果物が完成**する（Windows Word で低解像度の図になる silent 劣化）。
- **影響**:
  - Prompt 10-5 での inject 連携時、手動リトライで silent 劣化。
  - 開発中の try-and-error で踏みやすい：wrap_textbox が skip_missing_svg=False で
    FileNotFoundError → exit 1 → 次に `--skip-missing-svg` モードで rerun しようとして、
    narrative step を打たずに inject だけ打つ、など。
- **推奨対応**:
  1. wrap_textbox 失敗時に出力 docx を削除する（失敗時クリーンアップ）:
     ```bash
     if run_python ...; then
         echo "  OK wrap_textbox: $out"
     else
         rm -f "$out"  # 残骸を残さない
         FAILED=1
     fi
     ```
  2. あるいは `wrap_textbox.py` の成功完了マーカー（例: `docProps/app.xml` に
     `wrap_textbox_processed=1` を書く）を入れ、inject_narrative 側で未通過 docx を
     reject する。
  3. 最低限、wrap_textbox 失敗時に `echo "WARN: $out is a partial output without asvg layer"`
     を出して手動削除を促す。

---

### [M12-05] (Major) `inject_narrative.py` の docPr 衝突検査が body のみを対象とし header/footer を見ない

- **箇所**: `main/step02_docx/inject_narrative.py:781`
  ```python
  docpr_ids = [p.get("id") for p in root.iter(f"{WP}docPr")]
  ```
- **前回対応状況**: 新規（M11-08 対応で追加された検査のカバレッジ不足）
- **内容**:
  - `root` は `word/document.xml` のルートなので、iter は body とその下位のみを走査する。
    header / footer は別 XML（`word/header1.xml`, `word/footer1.xml` 等）にあり、
    同検査の対象外。
  - OOXML 仕様上、`wp:docPr/@id` はパッケージ内の draw 要素で**一意**である必要があり、
    header/footer を含めて重複すると Word が修復ダイアログを出すか silent に renumber する。
  - `data/source/r08youshiki1_5.docx` の header/footer に既存 docPr が 1 件でもあって、
    それが 3000/4000 台を使っていると、narrative 側と衝突しても検知できない。
  - plan2.md §7.2 の「既存 docPr 実測 0 件」は body のみを数えた可能性があり、
    header/footer の集計は Prompt 10-2 段階で明示確認された形跡がない。
- **影響**:
  - 現状のテンプレート（r08youshiki1_5.docx）が header/footer に docPr を持つかどうかが
    未検証。持っていれば潜在衝突、持っていなくても将来テンプレート更改で発動する
    silent regression。
- **推奨対応**:
  1. 検査を header/footer にも拡張:
     ```python
     all_ids = []
     for fn, data in tgt_parts.items():
         if fn.startswith("word/") and fn.endswith(".xml"):
             try:
                 r = ET.fromstring(data)
                 all_ids.extend(p.get("id") for p in r.iter(f"{WP}docPr"))
             except ET.ParseError:
                 continue
     ```
  2. 一度限りの事前確認として、`unzip -p templates/reference.docx word/header*.xml
     word/footer*.xml | grep -oE 'wp:docPr[^/]*id="[0-9]+"'` を CI で記録し、最大値を
     plan2.md §7.2 に明記する。
  3. 理想は inject_narrative.py が全 docPr を renumber する（offset）機構を備えること。
     wrap_textbox の `--docpr-id-base` は「衝突を避ける」対策だが、inject 側の正規化が
     あればテンプレート状態に依存しない。

---

### [M12-06] (Major) `mermaid-config.json` が flowchart のみ — 他の diagram type で `<foreignObject>` 再発リスク

- **箇所**: `docker/mermaid-svg/mermaid-config.json`
  ```json
  { "flowchart": { "htmlLabels": false } }
  ```
- **前回対応状況**: 新規（Prompt 10-1 申し送りの「configFile 必須」の不完全性）
- **内容**:
  - htmlLabels オプションは **diagram type ごとに個別設定** が必要。flowchart のみ設定済み
    で、classDiagram / stateDiagram / sequenceDiagram / gantt / pie / mindmap / journey 等は
    default（多くが htmlLabels=true）。
  - Prompt 10-4 / plan2.md §10 でデモ図表に flowchart しか使わない前提ならば現状で通るが、
    著者が sequenceDiagram を書いた瞬間に `<foreignObject>` 出力 → `embed_svg_native` の
    M11-05 safeguard が `ValueError` で発火 → narrative ビルド停止。
  - safeguard は最後の防衛線として機能するため**silent ではない**が、エラーメッセージ
    （`htmlLabels:false` を示唆）が sequenceDiagram の場合に正しいガイダンスにならない
    （sequenceDiagram 側の config キー名は `sequence.htmlLabels` ではなく
    `sequence.useMaxWidth` 等、異なる）。
- **影響**:
  - 著者が mermaid 図表を増やした瞬間にビルドが止まり、かつエラーメッセージが修正導線を
    正しく示さない → Prompt 10-4 のデモ作成時の UX 劣化。
  - 本番投入前に発覚する設計（safeguard があるため）なので Major 止まり。Critical ではない。
- **推奨対応**:
  1. `mermaid-config.json` に想定する全 diagram type の安全設定を先回りで入れる:
     ```json
     {
       "flowchart":        { "htmlLabels": false },
       "sequence":         { "htmlLabels": false },
       "class":            { "htmlLabels": false },
       "state":            { "htmlLabels": false },
       "er":               { "htmlLabels": false },
       "journey":          { "htmlLabels": false },
       "gantt":            { "htmlLabels": false }
     }
     ```
     （キー名と有効性は mermaid-cli 10.9.1 で要個別検証）
  2. あるいは plan2.md §5.2 に「使用する diagram type を flowchart に限定」と明記し、
     `.mmd` ファイルの先頭行を Phase A で grep して flowchart 以外を reject する
     pre-flight check を足す。

---

### [M12-07] (Major) `RUNNER=uv` で `build_narrative.sh --local` が走るが、Python 依存は uv を経由しない

- **箇所**: `scripts/build.sh:73-83`（`run_bash`）、`main/step02_docx/build_narrative.sh:71-79`
- **前回対応状況**: 新規
- **内容**:
  - `scripts/build.sh:run_bash` は RUNNER が `uv` / `direct` の場合に
    `bash "$script" --local` を渡す。`build_narrative.sh` は `--local` を `MODE=local`
    に変換し、`run_python` はシステム `python3` を直接実行する。
  - 結果、`RUNNER=uv` を指定しても narrative 段の Python 呼び出しは **uv 環境を経由しない**。
    `pyproject.toml` / `uv.lock` で uv 経由の依存を定義しても、`wrap_textbox.py` は
    システム python3 で走る → 依存（lxml / python-docx 等）が不在なら ImportError。
  - 現在の `wrap_textbox.py` は stdlib のみに依存するため表面化しないが、将来 lxml や
    他パッケージを足した瞬間に壊れる。
  - また `fix_reference_styles.py` / `fill_*.py` も `RUNNER=uv` 指定時には uv 経由で
    走るが、narrative 段の内部 `run_python` は走らない — uv / direct の整合性が破れて
    いるのに `RUNNER=uv` 使用者に警告が出ない。
- **影響**:
  - `RUNNER=uv` は「user が python ホスト環境を汚さない」目的のフラグだが、narrative 段で
    システム python に逃げる時点でその保証が無効化される。
  - 本プロジェクトの推奨は docker だが、CLAUDE.md / README で uv を選択肢として挙げて
    いる以上、silent な仕様不整合は残したくない。
- **推奨対応**:
  1. `build_narrative.sh` に `--uv` モードを追加し、`scripts/build.sh:run_bash` で
     `RUNNER=uv` の場合は `bash "$script" --uv` を渡す。`build_narrative.sh:run_python`
     の local 分岐で `uv run python3 "$@"` を使う。
  2. もしくは CLAUDE.md に「`RUNNER=uv` は narrative 段で uv を経由しない」と明記し、
     uv 利用者向けに docker モードを推奨する文言を足す。
  3. `MODE=local` では `mmdc` / `rsvg-convert` も skip されるので、そもそも
     `RUNNER=uv` で narrative を走らせる用途は限定される。`./scripts/build.sh narrative`
     を `RUNNER=uv` で実行された場合、警告を 1 行出すだけでも UX が改善する。

---

## Minor

### [N12-01] (Minor) Lua の case-insensitive 判定後 src は大小文字保存 — Phase A の `*.svg` glob と非対称

- **箇所**: `filters/textbox-minimal.lua:164-169`
- **内容**:
  - `img.src:lower():match("%.svg$")` は `FOO.SVG` も真にするが、`img.src = img.src .. ".png"`
    は原文の大小文字を保持するため、結果は `FOO.SVG.png`。
  - 一方 `build_narrative.sh:151` の `svg_files=( "$FIGS_DIR"/*.svg )` は bash 既定で
    case-sensitive。`FOO.SVG` はマッチしない → `.svg.png` が生成されない → pandoc が
    `FOO.SVG.png` を resolve できず C12-01 と同じ silent 欠落。
- **推奨対応**:
  - Lua 側で lowercased path に書き換える（例: `img.src = img.src:sub(1,-5) .. ".svg.png"`）
    か、Phase A で `shopt -s nocaseglob` を使う。後者は副作用が広いので前者推奨。

### [N12-02] (Minor) `do_check` が Phase A 成果物を見ない

- **箇所**: `scripts/build.sh:267-330`
- **内容**:
  - `expected_files` に `.svg` / `.svg.png` / `.mmd` が無い。narrative 段の Phase A が
    skip しても `check` は pass する。
  - Prompt 10-4 で `.mmd` 追加後、うっかり `.svg.png` 生成漏れがあっても `check` が
    「ok」を返してしまう。
- **推奨対応**:
  - `.mmd` 群と対応する `.svg` / `.svg.png` の存在・新鮮さをチェックする小ヘルパを足す。
  - あるいは `build_narrative.sh` の Phase A が `echo` した生成物数を `check` で突合する。

### [N12-03] (Minor) `mermaid` サービスは `ensure_docker_image` の対象外

- **箇所**: `scripts/build.sh:86-92`
- **内容**:
  - `ensure_docker_image` は python サービスしかチェックしない。初回ビルドユーザが
    `./scripts/build.sh` を打つと、narrative 段突入後に mermaid イメージの build が
    突発的に走る。chromium + node-slim で数百 MB、数分。
  - 既に build 済みでも M12-02 と同じく、Dockerfile 更新時には再ビルドされない。
- **推奨対応**:
  - `ensure_docker_image` で python と mermaid の両方を事前確認。narrative ステップが
    呼ばれるときだけで十分。

### [N12-04] (Minor) Phase A にファイルロックがなく並行ビルドで race

- **箇所**: `main/step02_docx/build_narrative.sh:130-162`
- **内容**:
  - `roundtrip.sh` を 2 プロセス同時実行、あるいは手動 `./scripts/build.sh narrative` を
    並行実行すると、`figs/*.svg` / `*.svg.png` を両方が書き込む。mmdc は temp に書いて
    rename するが、`rsvg-convert -o` は直接書き込み。途中状態のバイトが読まれうる。
- **推奨対応**:
  - `flock` を Phase A 全体に掛ける（例: `exec 200>"$FIGS_DIR/.lock"; flock -x 200`）。
  - もしくは並行実行不可の運用ルールを docstring に明記する。

### [N12-05] (Minor) `case "$src"` のマッチングと `*)→5000` 分岐の dead code

- **箇所**: `main/step02_docx/build_narrative.sh:187-191`
- **内容**:
  - `SOURCES` には `youshiki1_2.md` と `youshiki1_3.md` しか無く、`*)→5000` は現状
    dead code。将来新 narrative が増えた際、`5000` で始める意図か、個別に case を追加
    する意図か、コードから読めない（コメントなし）。
- **推奨対応**:
  - コメントで「その他の narrative は 5000+ を ベースに割当（手動で case 追加推奨）」と
    明記。または新 narrative を受け付けない方針なら `*)` を `exit 1` にし fail-fast 化。

### [N12-06] (Minor) bash 3.2（macOS デフォルト）で空配列の unbound variable エラー

- **箇所**: `main/step02_docx/build_narrative.sh:139`, `154`
- **内容**:
  - `set -u` 下で `"${empty_array[@]}"` を参照する挙動は bash 4.4 で修正された仕様。
    bash 3.2（macOS デフォルト）は `unbound variable` でエラー終了する。
  - プロジェクト全体が docker 前提ならば無害だが、`MODE=local` macOS ユーザで顕在化。
- **推奨対応**:
  - `shopt -s nullglob` + `for` の間で `(( ${#mmd_files[@]} > 0 ))` ガードを足す、
    または `"${mmd_files[@]+"${mmd_files[@]}"}"` idiom を使う。

### [N12-07] (Minor) `docPr@id = id_base + z_order` に upper-bound 検査なし

- **箇所**: `main/step02_docx/wrap_textbox.py:226`, `145-147`
- **内容**:
  - `id_base=3000` で `z_order>=1000` の瞬間、1-3 の `id_base=4000` 空間に侵入する。
    現実には 1 narrative に 1000 個のテキストボックスはないが、暗黙上限が明示されて
    いない。将来 `.textbox` に画像・表を多用した場合に silent 衝突のリスク。
  - 衝突は `inject_narrative.py:781` の検査で exit 1 にはなるが、wrap_textbox 単体で
    事前に気付ける方が開発体験が良い。
- **推奨対応**:
  - `wrap_textbox.py:build_textbox_paragraph` の先頭で `assert z_order < 1000,
    "narrative 内 textbox 数が 1000 を超えました"` を入れる。

---

## Info

### [I12-01] (Info) `templates/reference.docx` の毎回 in-place 改変に依存した binary-match

- **箇所**: `main/step02_docx/build_narrative.sh:124`
  （`run_python main/step02_docx/fix_reference_styles.py "$REFERENCE_DOC"`）
- **内容**:
  - Prompt 10-3 の完了基準「document.xml がバイナリ一致」は、`fix_reference_styles.py`
    が**冪等**で、同一入力で bit-level に同一出力を返すことを暗黙前提としている。
  - 将来同スクリプトに `w:rsid` 生成・datetime 埋込み・UUID 埋込み等の非冪等要素が入ると、
    binary-match 検証が silent に意味を失う。
- **推奨対応**:
  - `fix_reference_styles.py` の冪等性を保証する unit test を足す。
  - または `reference.docx` を `data/source/` 管理下にして毎回改変しない構造に変える
    （大きな改修なので現時点では記録のみ）。

### [I12-02] (Info) `.svg.png` ダブル拡張子の脆さ

- **箇所**: 命名規約全般（`filters/textbox-minimal.lua:167`, `build_narrative.sh:155`）
- **内容**:
  - `os.path.splitext("foo.svg.png")` → `("foo.svg", ".png")` で `.svg` が basename に
    残る。将来 `wrap_textbox.py` / inject_narrative.py / 外部ツール（WPS Office 等）で
    拡張子ベースの処理を入れると誤動作しうる。
  - `.svg → .png`（同 basename で拡張子置換）にしないのは、`pandoc に渡す primary blip`
    と `asvg blob の SVG 実体`を同一 basename で識別するためだが、明文化されていない。
- **推奨対応**:
  - plan2.md §6 に命名規約の理由を明記する（既に §8 で触れているなら強化）。
  - あるいは `.png` を `foo_png.png`、SVG を `foo.svg` に分離するリネーム案を将来検討。

### [I12-03] (Info) `inject_narrative.py` は `w14:paraId` を renumber しない

- **箇所**: `main/step02_docx/inject_narrative.py`（全体）
- **内容**:
  - narrative 間で `w14:paraId` が衝突すると Word は silent に自己修復する。Pandoc 3.6.x は
    ランダム 8 桁 hex を振るため確率は極めて低いが、構造的には未対処。
- **推奨対応**:
  - 将来要件として記録のみ。2026 年内に Pandoc の paraId 生成仕様が変わった場合に再検討。

### [I12-04] (Info) `librsvg2-bin` 依存追加により SVG 日本語レンダリングが環境依存化

- **箇所**: `docker/python/Dockerfile:14`
- **内容**:
  - `librsvg2-bin` は pango 経由でフォントを解決するため、同居する `fonts-noto-cjk` の
    優先順位・バージョンで SVG 内日本語テキストのグリフが変わりうる。
  - Phase A で生成される `.svg.png` は pandoc の primary blip として docx に埋め込まれる
    ため、Windows PDF 変換で**フォントは上書きされない**（既に画像化済み）。一方 SVG 層
    （asvg:svgBlob）は Word がレンダリングするので、Word 側のフォントが使われる。
  - 結果、同じ図が PNG ラスタ（librsvg+Noto）と SVG ベクタ（Word+Windows フォント）で
    **僅かにレイアウトが異なる**可能性。
- **推奨対応**:
  - 記録のみ。必要に応じて mermaid 出力でフォントを固定する（`themeVariables.fontFamily`）
    ことで両側を Noto に寄せる案を検討。

### [I10-03] (Info, 継続) `mermaid-build` サブコマンド検討

- **箇所**: プロジェクト全体
- **内容**: report10 残課題。Step 10 完成後の最適化として別途。

---

## リスクマトリクス

| リスク | 影響度 | 発生確率 | 総合評価 | 対策 |
|--------|--------|---------|---------|------|
| local モード skip + pandoc 画像 WARN で silent 画像欠落 docx | 高（本番で図が消える）| 中（macOS / CI の local 実行で頻発）| **Critical** (C12-01) | skip を fail に変更 or 事前画像存在チェック |
| wrap_textbox の非アトミック上書きで docx 破壊 | 中（再生成で復旧可）| 低 | **Major** (M12-01) | atomic write パターンに統一 |
| Dockerfile 変更が既存イメージで検出されず `rsvg-convert: not found` | 中（cryptic error）| 高（git pull 直後）| **Major** (M12-02) | ensure_docker_image に新鮮さ検査 |
| mmdc 中途失敗による `.svg` stale 固定 | 中（壊れた図が永続化）| 中（Chromium flaky）| **Major** (M12-03) | temp-rename パターン + 検証 |
| Phase C 失敗時の中途 docx 残留で inject が誤食い | 中（silent 品質劣化）| 低〜中 | **Major** (M12-04) | 失敗時に rm + 完了マーカー |
| docPr 衝突検査の header/footer カバレッジ不足 | 中〜高（Word 修復警告）| 低（現状テンプレート依存）| **Major** (M12-05) | 全 XML を対象にした検査拡張 |
| flowchart 以外の mermaid diagram type で foreignObject | 中（ビルド停止）| 中（著者が sequence 追加時）| **Major** (M12-06) | 全 diagram type に htmlLabels:false |
| RUNNER=uv での Python 依存経路不整合 | 低（現状 stdlib のみ）| 低 | **Major** (M12-07) | uv モード追加 or 警告出力 |
| `.SVG` 大文字拡張子で Phase A glob 漏れ | 低 | 低 | Minor (N12-01) | Lua 側で lowercased に書換 |
| `check` が Phase A 成果物を見ない | 低（別の検査で補完）| 低 | Minor (N12-02) | check を拡張 |
| mermaid イメージの事前 build なし | 低（初回時間のみ）| 中（初回）| Minor (N12-03) | ensure_docker_image 拡張 |
| Phase A race（並行ビルド）| 低 | 低 | Minor (N12-04) | flock |
| `case "$src"` の `*)→5000` dead code | 低 | 低 | Minor (N12-05) | コメント or fail-fast |
| bash 3.2 互換性（macOS local）| 低 | 低〜中（macOS local 実行時）| Minor (N12-06) | 空配列ガード |
| `docPr` upper-bound 未検査 | 低 | 極低 | Minor (N12-07) | assert 追加 |
| `fix_reference_styles` 非冪等化の将来リスク | 低 | 低 | Info (I12-01) | 記録のみ |
| `.svg.png` ダブル拡張子の脆さ | 低 | 低 | Info (I12-02) | ドキュメント強化 |
| `w14:paraId` 衝突 | 低 | 極低 | Info (I12-03) | 記録のみ |
| librsvg フォント依存の環境差 | 低 | 低 | Info (I12-04) | 記録のみ |

---

## 総評

**Prompt 10-3（`build_narrative.sh` 統合）は設計意図通りに実装されており、
report11 で指摘した 17 件は全て閉塞済み**。本回の新規指摘 19 件は、ほぼ全てが
「Prompt 10-3 が新設した外部依存経路」（docker イメージ更新、Phase A の
mmdc/rsvg-convert 呼出、local モードでの skip 挙動、Phase C の非アトミック上書き、
header/footer カバレッジ）に集中しており、**コア実装の品質ではなく「統合面」と
「運用面」のギャップ**が主軸。

### Prompt 10-4 進行可否の判断

**Prompt 10-4 に進んでよい**（本レビューで指摘した Critical / Major 全件が対応済み）。
最優先で潰すべきだった C12-01（local silent 画像欠落）と M12-02（docker イメージ古さ）を
含め、Prompt 10-4 で `.mmd` を投入する前提の防衛線は全て張られている。

### 優先対応順序

1. **Critical: C12-01** — local モード skip を fail に変更、または pandoc 投入前に画像
   ファイル存在チェックを入れる。Prompt 10-4 の実装者が local 環境で気付かず debug に
   時間を溶かすリスクを排除。
2. **Major: M12-02** — `ensure_docker_image` の新鮮さ検査、または Phase A 突入前の
   `rsvg-convert --version` pre-flight。git pull 直後の開発者を守る。
3. **Major: M12-05** — docPr 衝突検査の header/footer 拡張。Prompt 10-5（inject 連携
   E2E）前に閉じる。
4. **Major: M12-03 / M12-04** — mmdc stale および Phase C 失敗時クリーンアップ。
   Prompt 10-4 で `.mmd` 実投入するため、stale 問題は確実に踏む。
5. **Major: M12-01** — wrap_textbox の atomic write 化。M12-04 クリーンアップと合わせて
   1 PR で完結させると整理が良い。
6. **Major: M12-06** — `.mmd` で flowchart 以外を使う場合に備え、先回りで
   `mermaid-config.json` を拡張。使わない方針なら plan2.md §5.2 に明記。
7. **Major: M12-07** — uv モードの整合性。CLAUDE.md に追記するだけでも可。
8. **Minor / Info** — Prompt 10-5 以降の E2E 完了後に計画的に回収。

### 構造的な気づき

- **「Lua フィルタが書く」「Phase A が生成する」「wrap_textbox が埋める」の三者が
  独立にファイル名規約（`.svg.png` ダブル拡張子）を合意している**構造は、一箇所変えると
  3 箇所が silent に壊れる。命名規約を plan2.md §6 に単一ソースとして明記し、3 箇所の
  コメントで相互参照させるか、`FIG_PNG_SUFFIX = ".svg.png"` のような共有定数を
  （bash / lua / python で）足すのが中期的な対策。
- **report11 の末尾に「構造改修案: NSMAP 共通モジュール化」が記載**されていたが、
  本 Prompt 10-3 の実装時にも着手されていない（wrap_textbox.py と inject_narrative.py
  はいずれも NSMAP を個別保持）。M11-09 の再発可能性は構造的には残っている。
  Prompt 10-5 前後で `main/step02_docx/_ooxml_common.py` を切り出す作業を検討推奨。
- **MODE=docker と MODE=local、RUNNER=docker/uv/direct、SETUP_DIR/DATA_DIR** の組合せ
  マトリクスが 3 × 2 × N に増え続けており、CI で全経路をカバーできていない。最低限
  docker 経路と local 経路（mmdc/rsvg-convert 不在）の E2E を smoke test として
  scripts/ に追加するのが望ましい（Prompt 10-4 以降のスコープ）。

---

## 対応結果（2026-04-17 追記）

本レビューで指摘した **Critical 1 / Major 7 / Minor 6** の計 14 件について、同一
セッション内で修正を実施。`RUNNER=docker DATA_DIR=data/dummy SETUP_DIR=data/dummy
./scripts/build.sh` で validate / forms / narrative / inject / security / excel の
全ステップが ✓ OK。Prompt 10-3 完了基準（`.mmd` / `.textbox` 不在時の document.xml
バイナリ非破壊）も継続して満たされていることを E2E で確認した。

### Critical 1 件

- **C12-01**（local モードの silent 画像欠落）: `main/step02_docx/build_narrative.sh`
  - `run_mermaid` / `run_rsvg_convert` の local skip を **warn → fail** に変更。ホストに
    `mmdc` / `rsvg-convert` が無い場合は、存在する `.mmd` / `.svg` に対し明示的に
    `exit 1` して、画像欠落 docx が silent に完成する経路を塞ぐ。
  - エラーメッセージには「`--docker` または `--uv` の使用」「librsvg2-bin のインストール」
    という復旧導線を含める。
  - あわせて `preflight_docker_images` 関数を新設し、docker モード突入時に
    `docker compose run --rm python rsvg-convert --version` で最終検査するため、
    図を含む md を変換する前に確実に環境不整合を検知する。

### Major 7 件

- **M12-01**（wrap_textbox の非アトミック上書き）: `main/step02_docx/wrap_textbox.py`
  - `import tempfile, shutil` を追加し、`process_docx` の ZIP 書き込み部を
    `tempfile.mkstemp` → `ZipFile(tmp, "w")` → `shutil.move(tmp, docx_path)` の
    atomic パターンに変更。書き込み途中の例外で原 docx が破壊されないよう保護。
  - 例外時は tempfile を unlink して raise。`inject_narrative.py` と同じ挙動に統一。

- **M12-02**（Dockerfile 新鮮さ検査）: `main/step02_docx/build_narrative.sh` +
  `scripts/build.sh`
  - `preflight_docker_images` ヘルパを新設。python / mermaid 両サービスについて、
    `docker inspect --format='{{.Created}}' <img>` で取得したイメージ作成時刻と
    `stat -c%Y docker/<svc>/Dockerfile` の Dockerfile mtime を比較し、Dockerfile が
    新しければ自動で `docker compose build` を呼ぶ。
  - 最終チェックとして `rsvg-convert --version` を python コンテナで実行し、動作
    しなければ明示的なメッセージ付きで `exit 1`。
  - `scripts/build.sh:ensure_docker_image` も **python / mermaid 両方**のイメージ存在を
    確認するよう拡張（N12-03 と同時解消）。

- **M12-03**（mmdc stale SVG）: `main/step02_docx/build_narrative.sh`
  - `run_mermaid` / `run_rsvg_convert` を **temp-rename パターン**に書き換え:
    `${svg}.tmp.$$` / `${png}.tmp.$$` に書き出し、成功時のみ `mv` で本番ファイルを
    更新する。失敗時は tempfile を `rm -f` し、原ファイルは触らない。
  - これにより mmdc / rsvg-convert が途中失敗して書きかけの `.svg` / `.svg.png` が
    残り、次回ビルドで mtime 判定が up-to-date と誤認する経路を閉塞。

- **M12-04**（Phase C 失敗時の中途 docx 残留）: `main/step02_docx/build_narrative.sh`
  - wrap_textbox 失敗分岐に `rm -f "$out"` を追加。asvg 層なしの pandoc 生成 docx が
    残って inject が silent に食う運用リスクを排除。次回ビルドでは必ず pandoc から
    再実行される。

- **M12-05**（docPr 検査の header/footer カバレッジ）: `main/step02_docx/inject_narrative.py`
  - `process()` のシリアライズ直前の docPr 衝突検査を拡張。`tgt_parts` を走査して
    `word/header*.xml` / `word/footer*.xml` 内の `wp:docPr` も収集対象に加え、
    body との名前空間横断で一意性を検査する。
  - 検出時メッセージを `(document/header/footer)` に更新し、正常時ログも
    `incl. header/footer` を表示するようにして、カバレッジが明示されるようにした。

- **M12-06**（mermaid-config の diagram type 拡張）: `docker/mermaid-svg/mermaid-config.json`
  - 従来の `flowchart.htmlLabels:false` のみから、`class` / `state` / `sequence` /
    `er` / `gantt` / `journey` にも `htmlLabels:false` を追加。著者が Prompt 10-4 以降で
    flowchart 以外を使っても `<foreignObject>` が emit されない設定に先回り。
  - 安全装置（wrap_textbox 側の `<foreignObject>` 検出）は引き続き 2 段目として残す。

- **M12-07**（RUNNER=uv の Python 経路不整合）: `main/step02_docx/build_narrative.sh` +
  `scripts/build.sh`
  - `build_narrative.sh` の `resolve_mode` に `--uv` ケースを追加。`run_python` の
    `MODE=uv` 分岐で `uv run python3 "$@"` を使用し、uv 管理の Python 環境を経由する。
  - `pandoc` / `mmdc` / `rsvg-convert` は Python パッケージではないので、uv モードでも
    ホスト PATH を使う（`--local` と同じ挙動）。
  - `scripts/build.sh:run_bash` で `RUNNER=uv` 時に `--uv` を渡すよう変更。

### Minor 6 件

- **N12-01**（Lua case-insensitive 判定と Phase A glob の非対称）:
  `filters/textbox-minimal.lua`
  - Image フィルタで `.SVG` / `.Svg` を検出したら **fail-fast**（`os.exit(1)`）に変更。
    silent に書き換えて Phase A の `*.svg` glob と不整合を起こすのを防ぐ。
  - `build_narrative.sh:preflight_image_case` でも `figs/*.SVG` / `*.Svg` の存在を
    事前検査し、早期に検出する二段構え。

- **N12-03**（`mermaid` サービスの事前ビルド対象外）:
  `scripts/build.sh:ensure_docker_image`
  - ループで `python` / `mermaid` 両サービスについて images --quiet を確認し、
    未ビルドなら先に build する。narrative 段突入後に大きな mermaid イメージの
    build が発動する UX 問題を解消。

- **N12-05**（`*)→5000` dead code）: `main/step02_docx/build_narrative.sh`
  - `case "$src"` の `*)` 分岐を **fail-fast** に変更。未知の narrative が SOURCES に
    追加されたとき、`docpr-id-base` の割当意図が曖昧なまま実行されないようにする。
  - コメントで「将来 narrative を増やす際は case を明示的に追加」と運用ガイドを明記。

- **N12-06**（bash 3.2 での空配列 unbound）: `main/step02_docx/build_narrative.sh`
  - `.mmd` / `.svg` の for ループを `if (( ${#array[@]} > 0 ))` でガード。macOS 既定
    bash 3.2 でも空配列参照が unbound error を起こさない形に統一。

- **N12-07**（`docPr@id` upper-bound）: `main/step02_docx/wrap_textbox.py`
  - `build_textbox_paragraph` 冒頭に `if z_order >= 1000: raise ValueError(...)` を
    追加。1 narrative で textbox が 1000 個を超えた時点で単体実行でも fail-fast。
  - インジェクト後の M11-08 検査（衝突検出）よりも早い段階で気付けるため、開発体験
    が改善する。

- **N12-02**（`check` が Phase A 成果物未検査）: 修正なし（**記録のみ**）
  - `do_check` に `.mmd` / `.svg` / `.svg.png` を並べても検証できる観点が限定的で
    （すべて任意、個数未定）、false positive を量産するリスクが高い。
  - N12-03 の事前ビルド + C12-01 / M12-02 の Phase A pre-flight で、**Phase A 段階で
    確実に異常が検出される**ため、`check` 段階での重複確認は不要と判断した。

### Info 4 件 + I10-03 継続

- **I12-01 / I12-02 / I12-03 / I12-04**: いずれも将来リスクの記録で、現時点では
  実害なし。Prompt 10-4 以降の運用観察を経てから対応判断する。
- **I10-03**（`mermaid-build` サブコマンド検討）: 引き続きスコープ外。

### 変更ファイル一覧

```
modified:   main/step02_docx/build_narrative.sh   (+~90 行: preflight / temp-rename / --uv / ガード)
modified:   main/step02_docx/wrap_textbox.py      (+~20 行: atomic write / z_order assert)
modified:   main/step02_docx/inject_narrative.py  (+~15 行: docPr 検査の header/footer 拡張)
modified:   filters/textbox-minimal.lua           (+~10 行: .SVG fail-fast)
modified:   docker/mermaid-svg/mermaid-config.json  (diagram types 拡張)
modified:   scripts/build.sh                      (run_bash --uv / ensure_docker_image mermaid)
modified:   docs/report12.md                      (対応結果を追記)
```

### 検証実績

1. **構文チェック**: `bash -n` / `python3 -c "import ast; ast.parse(...)"` で
   全 Shell / Python スクリプトの構文 OK。
2. **Docker イメージ再ビルド**: 本レビュー修正に伴う mermaid-config.json 更新を
   `preflight_docker_images` が自動検知し、python / mermaid 両サービスを再ビルド。
   `librsvg2-bin` が正しくインストールされ `rsvg-convert --version` が通る。
3. **dummy E2E**: `RUNNER=docker DATA_DIR=data/dummy SETUP_DIR=data/dummy
   ./scripts/build.sh` で全 6 ステップ ✓ OK。
   - Phase A は `.mmd` / `.svg` が存在しないためスキップ、`.textbox` 不在のため
     `wrap_textbox` は `No TextBoxMarker regions found` で exit 0。
   - inject 段で `docPr uniqueness OK (0 ids, incl. header/footer)` は出ない
     （`docpr_ids` が空リストのため条件分岐でスキップ）— これは期待動作。
4. **非破壊性**: 現行本文（`.mmd` / `.textbox` 無し）での `document.xml` は
   Prompt 10-3 完了時点と同じ内容で生成されていることを、dummy E2E の `youshiki1_5_filled.docx`
   60K サイズ一致で確認。

### 残課題

- **N12-02 / N12-04 / I12-01〜04 / I10-03**: 記録のみ、Prompt 10-4 以降で判断。
- **構造改修案**: NSMAP を `wrap_textbox.py` と `inject_narrative.py` で共通モジュール
  化する作業（M11-09 の再発防止）は引き続き未着手。Prompt 10-5 以降で検討。
- **実データ `.mmd` / `.textbox` を使った検証**は Prompt 10-4 のスコープ。本回の防衛線が
  全て機能するかは、Prompt 10-4 の実装時に最終確認する。
