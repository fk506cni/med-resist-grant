# 実装プロンプト集

令和8年度 安全保障技術研究推進制度（委託事業）申請書類作成システムの実装手順。
各セクションを順にClaudeに依頼して実装する。

## 前提文脈（全ステップ共通）

すべてのプロンプトを実行する際、エージェントは以下を把握しておく必要がある:

### プロジェクト概要

- **応募先**: 防衛装備庁 令和8年度 安全保障技術研究推進制度（委託事業）
- **研究テーマ**: (23) 医療・医工学に関する基礎研究（サイバー攻撃×地域医療シミュレーション）
- **応募タイプ**: Type A（総額最大5200万円/年 ＝ 直接経費4,000万円 + 間接経費1,200万円、最大3年）
- **提出期限**: 2026年5月20日(水) 正午 e-Rad経由
- **提出物**: Word→PDF（様式1-5結合PDF + 別紙5 PDF + 別添PDF×人数分）、Excel（様式6,7,8）

### 読むべきドキュメント

| ファイル | 読むタイミング | 内容 |
|---------|--------------|------|
| `CLAUDE.md` | 毎回 | プロジェクト構成、提出書類一覧、Tech Stack、制約 |
| `SPEC.md` | 毎回 | 入出力仕様、パイプライン、制約条件 |
| `data/source/募集要項.pdf` | テーマ・審査基準を参照する時 | 公募要領全文（44p + 別紙） |

### 絶対的な制約

1. **data/source/ のファイルは絶対に変更しない** — 常にコピーしてから操作
2. **ホストPythonを汚さない** — Docker or uv 経由でのみ実行
3. **提出ファイルサイズ**: 各10MB以下、目標3MB
4. **様式1-2は最大15ページ**

### data/dummy/ の位置づけ

- `data/dummy/` はパイプラインのE2Eテスト用ダミーデータの配置場所
- YAML 4ファイル + スタブ docx/xlsx 6ファイルを配置済み
- `RUNNER=docker DATA_DIR=data/dummy SETUP_DIR=data/dummy ./scripts/build.sh` でE2Eテスト実行可能

### Step番号とディレクトリの対応

| prompts.md Step | 内容 | 状態 | 対応ディレクトリ |
|----------------|------|------|---------------|
| Step 0 | Docker/uv環境構築 | 完了 | docker/, pyproject.toml |
| Step 1 | メタデータYAML定義 | 完了 | main/00_setup/ |
| Step 2 | Markdown本文執筆環境 | 完了 | main/step01_narrative/ |
| Step 3 | Word文書生成 | 完了 | main/step02_docx/ |
| Step 4 | Excel文書生成 | 完了 | main/step03_excel/ |
| Step 5 | ビルド統合・パッケージング | 完了 | main/step04_package/ + scripts/build.sh |
| Step 6 | Google Drive同期設定 | 完了 | scripts/sync_gdrive.sh, scripts/roundtrip.sh |
| Step 7 | Windows側Word修復・PDF変換 | 完了 | scripts/windows/ |
| Step 8 | 共同執筆環境 | 完了 | scripts/collab_watcher.sh |
| Step 9 | 様式1-2/1-3 統合（ナラティブ挿入） | 完了 | main/step02_docx/inject_narrative.py |
| **Step 10** | **図表挿入（Mermaid→SVG + テキストボックス）** | 計画中 | **docker/mermaid-svg/, filters/textbox-minimal.lua, main/step02_docx/wrap_textbox.py** |

※ Steps 0-9 のプロンプト詳細は `docs/prompts_trash.md` に退避済み
※ Step 10 の設計計画は `docs/plan2.md` を参照

### 現在のパイプライン全体像

```
[main/00_setup/*.yaml] + [main/step01_narrative/*.md] + [data/source/*]
                        │
              ./scripts/build.sh
                        │
              [main/step02_docx/output/*.docx]
              [main/step03_excel/output/*.xlsx]
                        │
              ./scripts/roundtrip.sh
                        │
              rclone push → Google Drive → Windows watch-and-convert.ps1 → PDF
                        │
              rclone pull → data/products/*.pdf
                        │
              e-Rad提出
```

### 参考プロジェクト

類似のMarkdown→Word変換システムが `/home/dryad/anal/jami-abstract-pandoc/` にある。

---

<!-- Steps 0-9 は完了済み。docs/prompts_trash.md に退避。 -->

## Step 10: 図表挿入（Mermaid→SVG + テキストボックス）

### 文脈

- 研究計画本文（様式1-2）に図表を埋め込みたい。扱う形式は (1) Mermaid 図をビルド時に SVG 変換したもの、(2) 既存画像（.jpg/.png/.svg）。配置方式はテキストボックス（`wp:anchor + wps:wsp`）
- 参考プロジェクト:
  - **`/home/dryad/anal/next-gen-comp-paper/`** — テキストボックス挿入の Lua フィルタ + post-process スクリプトを保持（`filters/jami-style.lua`, `scripts/wrap-textbox.py`）。これを簡略化して移植する
  - **`/home/dryad/anal/auto-eth-paper/`** — Mermaid→SVG 変換用の docker コンテナ（`docker/mermaid-svg/`）を保持。これをそのまま移植し、出力を .pdf → .svg に切り替える
- 既存の `inject_narrative.py` は画像 rId 統合・メディアコピー・Content_Types マージを既に実装済みのため、テキストボックス付き narrative docx を**そのまま運搬可能**な見込み（非改修前提）
- 設計・リスク・ファイル構成の詳細は **`docs/plan2.md`** にまとめ済み

### 参照すべき資料（全 Prompt 共通）

| ファイル | 用途 |
|---------|------|
| `docs/plan2.md` | Step 10 の全体設計（必読） |
| `docs/prompts.md`（本ファイル） | ステップ構成と完了チェック |
| `CLAUDE.md` | プロジェクト構成・制約 |
| `SPEC.md` | 入出力仕様 |
| `/home/dryad/anal/next-gen-comp-paper/filters/jami-style.lua` | Lua フィルタのオリジナル |
| `/home/dryad/anal/next-gen-comp-paper/scripts/wrap-textbox.py` | post-process のオリジナル |
| `/home/dryad/anal/auto-eth-paper/docker/mermaid-svg/` | Mermaid docker コンテナのオリジナル |
| `main/step02_docx/inject_narrative.py` | 既存の narrative 挿入（改修不要の見込み） |
| `main/step02_docx/build_narrative.sh` | 改修対象（Lua フィルタ + mmd 前処理 + wrap_textbox 後処理を追加） |

### 絶対的な制約（Step 10 固有）

1. **既存パイプラインを破壊しない** — デモ挿入を除去すれば `./scripts/build.sh` と `DATA_DIR=data/dummy` E2E が従来通り通過すること
2. **ホスト Python を使わない** — mermaid も python も Docker 経由で実行
3. **inject_narrative.py は原則無改修** — 必要な場合は理由を明記して最小限の変更に留める
4. **SPEC.md の参考プロジェクト記述は `jami-abstract-pandoc` のまま**だが、本ステップでは `next-gen-comp-paper` / `auto-eth-paper` を参照する。混乱を避けるため docs/plan2.md に明記済み

---

### Prompt 10-1: mermaid-svg コンテナの追加

````
Mermaid 図（.mmd）を SVG に変換するための docker コンテナを追加してください。

## 文脈
research 本文に Mermaid 図を埋め込めるようにするため、.mmd → .svg のビルド時変換を
docker コンテナで実行できるようにします。auto-eth-paper の mermaid-svg コンテナを
ほぼそのまま移植し、出力を .pdf ではなく .svg に切り替えます。

## 参照すべき資料
- docs/plan2.md §5, §12（設計とリスク）
- /home/dryad/anal/auto-eth-paper/docker/mermaid-svg/Dockerfile
- /home/dryad/anal/auto-eth-paper/docker/mermaid-svg/convert-mermaid.sh
- /home/dryad/anal/auto-eth-paper/docker/mermaid-svg/puppeteer-config.json
- docker/docker-compose.yml（既存 python サービスの記述）
- CLAUDE.md / SPEC.md

## 作業内容

1. 新規ディレクトリ `docker/mermaid-svg/` を作成し、以下のファイルを配置:
   - `Dockerfile` — auto-eth-paper 版をそのままコピー（イメージ名は無関係、compose が管理）
   - `puppeteer-config.json` — auto-eth-paper 版をそのままコピー
   - `convert-mermaid.sh` — auto-eth-paper 版をコピーし、末尾の mmdc 呼び出しを
     `mmdc -i 'FILENAME' -o 'BASE.svg' -p /etc/puppeteer-config.json`
     に変更（.pdf → .svg）。コメント・メッセージ文字列も svg に合わせて修正

2. `docker/docker-compose.yml` に `mermaid` サービスを追加（既存 python サービスは
   一切変更しない）:
   ```yaml
   mermaid:
     build:
       context: ./mermaid-svg
       dockerfile: Dockerfile
     volumes:
       - ..:/workspace
     working_dir: /workspace
     environment:
       - PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
       - PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium
   ```

3. 動作確認用コマンド（README や CLAUDE.md には追記しない。本 Prompt 内で実行のみ）:
   - 仮の .mmd ファイルを作成（`main/step01_narrative/figs/_smoke_test.mmd`、簡単な flowchart）
   - `docker compose -f docker/docker-compose.yml run --rm -u $(id -u):$(id -g) mermaid \
      mmdc -i main/step01_narrative/figs/_smoke_test.mmd \
           -o main/step01_narrative/figs/_smoke_test.svg \
           -p /etc/puppeteer-config.json`
   - 出力 SVG が生成され、`<svg` で始まり日本語テキストが `<text>` 要素に入っていることを確認
   - 動作確認後、`_smoke_test.mmd` と `_smoke_test.svg` は削除

4. 既存 `docker compose -f docker/docker-compose.yml run --rm python python --version`
   が引き続き通ることを確認（既存 python サービスへの副作用なし）

## 非機能要件
- 初回ビルドには数分かかる可能性あり（chromium/node_modules ダウンロード）
- image 名はデフォルト（`<project>_mermaid`）のままで良い
- ホスト上に mmdc / node をインストールしないこと

## 出力
- docker/mermaid-svg/Dockerfile
- docker/mermaid-svg/puppeteer-config.json
- docker/mermaid-svg/convert-mermaid.sh
- docker/docker-compose.yml（mermaid サービス追加）
````

#### 完了チェック

- [ ] `docker/mermaid-svg/` 配下の 3 ファイルが配置されている
- [ ] `docker/docker-compose.yml` に mermaid サービスが追加され、既存 python サービスは無変更
- [ ] `docker compose -f docker/docker-compose.yml build mermaid` が成功する
- [ ] スモークテストの .mmd → .svg 変換が動作する
- [ ] 既存 python サービスの動作に副作用がない

---

### Prompt 10-2: Lua フィルタと wrap_textbox.py の移植

````
次に、Pandoc 側のテキストボックスマーカー挿入（Lua フィルタ）と、docx 側のテキストボックス
実体化（wrap_textbox.py）を作成してください。

## 文脈
Markdown 本文中の `::: {.textbox ...}` Div ブロックを、Pandoc 経由では `TextBoxMarker`
スタイルの隠し段落（START/END）で囲まれた通常段落に変換し、その後 Python スクリプトで
START/END 区間を DrawingML テキストボックス（wp:anchor + wps:wsp）に置換します。

## 参照すべき資料
- docs/plan2.md §6, §7（設計）
- /home/dryad/anal/next-gen-comp-paper/filters/jami-style.lua
- /home/dryad/anal/next-gen-comp-paper/scripts/wrap-textbox.py
- main/step02_docx/inject_narrative.py（名前空間定数・ルートタグ処理の参考）
- CLAUDE.md / SPEC.md

## 作業内容

### A. filters/textbox-minimal.lua（新規）

next-gen-comp-paper の jami-style.lua から**最小限**を抽出して新規作成:

- 保持: `to_emu()`, `textbox_marker()`, `process_textbox()` とその呼び出し
- **削除**: JSEK本文 による全 Para ラップ、OrderedList 手動番号化、
  .grid/GRID_TABLE マーカー、Pass 1 の .svg → .svg.png リネーム
- 結果として `Pandoc` ハンドラは `.textbox` Div のみを START/END マーカーで囲み、
  それ以外のブロックは完全にそのまま通す

lua フィルタの返り値は 1 パスのみ（Pandoc フィルタを 1 つ返す形）にする。

### B. main/step02_docx/wrap_textbox.py（新規）

next-gen-comp-paper の wrap-textbox.py から以下を移植:

- 保持:
  - 名前空間定義・register_namespace
  - `extract_root_tag` / `restore_root_tag`
  - `is_textbox_marker` / `get_marker_text` / `parse_attrs`
  - `resize_images_in_content`（テキストボックス幅に合わせて画像縮小）
  - `build_textbox_paragraph`
  - `embed_svg_native`（Office 2016+ の asvg:svgBlob による SVG ネイティブ埋込）
  - `process_docx` のメインフロー
- **削除**:
  - `apply_booktabs_borders` とセル罫線ユーティリティ一式
  - `resize_tables_in_content`（保持でも可。複雑化を避けるなら削除）
  - `relocate_textbox_by_page`（本プロジェクトでは不要）
- 変更:
  - `process_docx()` は `no_relocate=True` 相当を**既定**にする（`--no-relocate` フラグは残すがデフォルト True）
  - CLI 引数: `docx`（位置引数）, `--source`（Markdown ソース）
  - `wp:docPr/@id` は 2000 番台から採番して、inject 先の docPr と衝突しにくくする

## 技術的注意事項

- Python 標準ライブラリのみ使用（zipfile, xml.etree.ElementTree, re, os, io, argparse）
- ホスト Python に新規パッケージを入れない
- `inject_narrative.py` と**同じ名前空間定数を使用**（コピーで可）

## エッジケース

- `::: {.textbox}` が 0 個の場合は `No TextBoxMarker regions found` を stdout に出して
  exit 0。既存本文（youshiki1_2.md / youshiki1_3.md）に影響を与えないことを保証
- `--source` が省略された場合は SVG ネイティブ埋込をスキップ（textbox 実体化のみ行う）
- `extract_root_tag` / `restore_root_tag` は document.xml のルートのみを対象にすること

## 出力先
- filters/textbox-minimal.lua
- main/step02_docx/wrap_textbox.py

## 動作確認（単体）
- 本 Prompt 内では build_narrative.sh の改修は行わない。以下のスモーク確認のみ:
  - 手で一時的に `pandoc main/step01_narrative/youshiki1_2.md \
     --lua-filter=filters/textbox-minimal.lua --to docx \
     --reference-doc=templates/reference.docx -o /tmp/tb_smoke.docx`
  - 未変更の本文で正常に docx が生成され、unzip → document.xml に `TextBoxMarker`
    が現れない（`.textbox` ブロック未使用のため）
  - `python main/step02_docx/wrap_textbox.py /tmp/tb_smoke.docx` が `No TextBoxMarker
    regions found` を出して正常終了すること
````

#### 完了チェック

- [ ] `filters/textbox-minimal.lua` が作成され、100 行以下の最小構成
- [ ] `main/step02_docx/wrap_textbox.py` が作成され、booktabs / relocate 部分が削除済み
- [ ] 既存の youshiki1_2.md を Lua フィルタ経由で pandoc 変換しても崩れない
- [ ] `.textbox` ブロック未使用時に wrap_textbox.py が副作用なく終了する
- [ ] ホスト Python に新規パッケージ追加なし

---

### Prompt 10-3: build_narrative.sh への統合

````
build_narrative.sh に mmd→svg 前処理と Lua フィルタ + wrap_textbox 後処理を統合してください。

## 文脈
Prompt 10-1 で作成した mermaid コンテナと、Prompt 10-2 で作成した Lua フィルタ /
wrap_textbox.py をパイプラインに組み込みます。

## 参照すべき資料
- docs/plan2.md §8
- main/step02_docx/build_narrative.sh（現行）
- scripts/build.sh（narrative / inject フェーズ）
- docker/docker-compose.yml（Prompt 10-1 で mermaid サービス追加済み）
- CLAUDE.md / SPEC.md

## 変更内容

### main/step02_docx/build_narrative.sh

1. `reference.docx` 生成の直後に **Phase A: mermaid → svg** を追加:
   - `main/step01_narrative/figs/*.mmd` を glob で探索
   - 各 .mmd について、対応する .svg が存在しないか .mmd の mtime が新しい場合に変換
   - 変換コマンドは `docker compose -f docker/docker-compose.yml run --rm \
      -u $(id -u):$(id -g) mermaid mmdc -i <mmd> -o <svg> -p /etc/puppeteer-config.json`
   - `MODE=local` の場合は mmdc がホストに存在しないため警告を出して変換をスキップ
     （.svg が既存なら続行）

2. `PANDOC_OPTS` に **`--lua-filter=filters/textbox-minimal.lua`** を追加

3. pandoc 変換の直後に **Phase C: wrap_textbox 後処理** を追加:
   - 変換に成功した各 docx について
     `run_python main/step02_docx/wrap_textbox.py --source <md> <docx>` を実行
   - wrap_textbox の失敗はビルド失敗として扱う（非ゼロ exit）

### scripts/build.sh

- `narrative` フェーズの定義は既存のまま（内部で build_narrative.sh を呼ぶので自動で
  新フェーズが走る）
- `check` サブコマンドの対象ファイルリストに変更なし

### 非破壊性チェック

- `.textbox` ブロックを 1 つも含まない現行本文で:
  - Phase A は .mmd が無ければスキップ
  - Lua フィルタは `.textbox` を見つけないのでマーカーを追加しない
  - wrap_textbox.py は `No TextBoxMarker regions found` を出して exit 0
  - 最終的な docx 内容は Step 10 導入前と差分ゼロであること（バイナリ diff 或いは
    unzip 後の document.xml diff で確認）

## 出力
- main/step02_docx/build_narrative.sh（改修）
````

#### 完了チェック

- [ ] build_narrative.sh に Phase A（mmd→svg）が追加されている
- [ ] PANDOC_OPTS に `--lua-filter=filters/textbox-minimal.lua` が追加されている
- [ ] 変換後 wrap_textbox.py が自動実行される
- [ ] 現行本文（textbox なし）で `./scripts/build.sh narrative` が通り、document.xml diff が想定内
- [ ] E2E テスト `RUNNER=docker DATA_DIR=data/dummy SETUP_DIR=data/dummy ./scripts/build.sh` が通る

---

### Prompt 10-4: デモ図表の挿入と単体確認

````
デモ画像と Mermaid 図を youshiki1_2.md に挿入し、build_narrative → wrap_textbox の
範囲で図が埋め込まれることを確認してください。

## 文脈
既存ワークフローを破壊しないまま、画像挿入機能が動作することを実証します。Prompt 10-5 で
inject_narrative.py 連携まで含めた E2E を行うため、本 Prompt では narrative docx 生成
までで止めます。

## 参照すべき資料
- docs/plan2.md §10
- main/step01_narrative/figs/bg_hospital.jpg（デモ画像、既に配置済み）
- main/step01_narrative/youshiki1_2.md（編集対象）

## 作業内容

1. `main/step01_narrative/figs/fig1_overview.mmd` を新規作成（内容は下記の例）:

   ```mermaid
   %%{init: {'theme':'base','themeVariables':{'fontSize':'18px'}}}%%
   flowchart LR
       A[DPC/NDB/レセプト] --> B[需給推定器]
       B --> C[地域医療シミュレータ]
       D[サイバー攻撃シナリオ] --> C
       C --> E[インパクト評価レポート]
   ```

2. `main/step01_narrative/youshiki1_2.md` の適切な見出し配下（例: 「１．本研究の背景」末尾
   または「３．本研究の最終目標および要素課題」冒頭）に、以下 2 ブロックを追加:

   - デモ画像（病院写真）:
     ```
     ::: {.textbox width="90mm" height="60mm" pos-x="0mm" pos-y="0mm" anchor-h="column" anchor-v="paragraph" wrap="square" behind="false"}
     ![病院施設の外観（デモ画像）](figs/bg_hospital.jpg){#fig:hospital}
     :::
     ```

   - Mermaid 図:
     ```
     ::: {.textbox width="120mm" height="70mm" pos-x="0mm" pos-y="0mm" anchor-h="column" anchor-v="paragraph" wrap="square" behind="false"}
     ![医療需給動態モデルの処理フロー（概念図）](figs/fig1_overview.svg){#fig:overview}
     :::
     ```

   既存の章構成・本文は改変しないこと。追加する段落・キャプション文を最小限に抑え、
   15 ページ制限に影響しないよう配慮。

3. `./scripts/build.sh narrative` を実行し、以下を確認:
   - `main/step01_narrative/figs/fig1_overview.svg` が生成されている
   - `main/step02_docx/output/youshiki1_2_narrative.docx` が生成されている
   - unzip して `word/document.xml` を grep し、以下を確認:
     - `wp:anchor` が 2 個以上存在
     - `wps:wsp` が 2 個以上存在
     - `a:blip` の `r:embed` 参照が存在
     - SVG ネイティブ埋込: `asvg:svgBlob` 要素が 1 個以上
   - `word/media/` に bg_hospital.jpg と fig1_overview.svg（または svgN.svg）が含まれる
   - `word/_rels/document.xml.rels` に対応する image rels が存在

4. 既存 E2E の非破壊性:
   - `RUNNER=docker DATA_DIR=data/dummy SETUP_DIR=data/dummy ./scripts/build.sh` が通る
     （dummy にはデモ .textbox ブロックを入れない）

## 出力
- main/step01_narrative/figs/fig1_overview.mmd（新規）
- main/step01_narrative/figs/fig1_overview.svg（ビルド生成物、.gitignore 方針は plan2.md
  で再確認）
- main/step01_narrative/youshiki1_2.md（デモブロック追記）
````

#### 完了チェック

- [ ] fig1_overview.mmd が作成されている
- [ ] youshiki1_2.md に 2 つの .textbox ブロックが追加されている
- [ ] build_narrative で fig1_overview.svg が生成される
- [ ] narrative docx 内に wp:anchor と asvg:svgBlob が埋め込まれる
- [ ] word/media/ に bg_hospital.jpg と SVG が含まれる
- [ ] dummy E2E が通る

---

### Prompt 10-5: inject 連携と E2E 検証

````
narrative docx から youshiki1_5_filled.docx へ図が正しく運搬されることを検証し、
PDF 化まで含めたエンドツーエンドテストを実施してください。

## 文脈
inject_narrative.py は画像 rels マージ・Content_Types 更新・ルートタグ保存に対応済み
のため、原則として改修は不要の見込みです。本 Prompt で実地検証し、必要があれば最小限の
パッチを当てます。

## 参照すべき資料
- docs/plan2.md §9, §11
- main/step02_docx/inject_narrative.py（merge_rels / copy_media / merge_content_types）

## 検証項目

1. **フルビルド**: `./scripts/build.sh` が全ステップ通過
2. **inject 後の構造**: `main/step02_docx/output/youshiki1_5_filled.docx` を unzip し
   以下を確認:
   - `word/document.xml` 内に Prompt 10-4 で追加した wp:anchor / asvg:svgBlob が存在
   - `word/_rels/document.xml.rels` に対応する image rels が存在
   - `word/media/` に bg_hospital.jpg と SVG が存在（衝突時は `*_nN.*` にリネーム）
   - `[Content_Types].xml` に svg の Default extension が含まれる
3. **LibreOffice レンダリング**:
   - `libreoffice --headless --convert-to pdf main/step02_docx/output/youshiki1_5_filled.docx`
   - 生成 PDF を `pdfimages -list` で確認し、少なくとも 2 個のラスタ / ベクタ画像が
     含まれていること
   - `pdftotext -layout` でテキスト化し、様式ヘッダや本文が崩れていないこと
4. **ページ数**: 様式1-2 部分のページ数が 15 ページ以内（デモ 2 図込み）
5. **ファイルサイズ**: 最終 docx が 10MB 未満、目標 3MB 未満
6. **非破壊**: デモ `.textbox` ブロックを **youshiki1_2.md から一時的に削除** して
   ビルドし直した場合に、以下が成立:
   - document.xml に wp:anchor / asvg:svgBlob が現れない
   - 既存 E2E `DATA_DIR=data/dummy` が引き続き通過
   - （削除を戻してから本 Prompt を完了させる）

## 改修が必要な場合の判断基準
- inject 後に画像が欠落する → `merge_rels` の `_COPY_REL_TYPES` にテキストボックス特有の
  関係タイプが必要か確認
- docPr id 衝突によるオフセットずれ → wrap_textbox.py の docPr id 開始番号を調整
- 画像の配置崩れ → plan2.md §12 のリスク表に沿ってフォールバック（PNG 同時埋込等）

## 出力
- 検証結果レポート（コンソール出力で十分、docs への書き出しは不要）
- 問題があれば最小限のコード修正
````

#### 完了チェック

- [ ] フルビルドで youshiki1_5_filled.docx に 2 つの図が運搬されている
- [ ] LibreOffice PDF 化で画像が視認できる
- [ ] docx 内の Content_Types / rels / media が正しく更新されている
- [ ] 様式1-2 が 15 ページ以内
- [ ] デモを外した状態で既存 E2E が通る（非破壊性）
- [ ] inject_narrative.py 側の改修が不要（または最小限で説明付き）

---

