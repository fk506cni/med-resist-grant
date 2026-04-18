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
- /home/dryad/anal/auto-eth-paper/docker/mermaid-svg/puppeteer-config.json
- docker/docker-compose.yml（既存 python サービスの記述）
- CLAUDE.md / SPEC.md

## 作業内容

1. 新規ディレクトリ `docker/mermaid-svg/` を作成し、以下のファイルを配置:
   - `Dockerfile` — auto-eth-paper 版をベースに後述の改修を適用
   - `puppeteer-config.json` — auto-eth-paper 版をそのままコピー
   - `mermaid-config.json` — **新規追加**。内容: `{"flowchart":{"htmlLabels":false}}`。
     mermaid-cli の既定では flowchart ラベルが `<foreignObject>+HTML span` で出力され、
     wrap_textbox.py の `embed_svg_native`（lxml で SVG をパースし DrawingML に注入）が
     Word 上で空白の四角になる。`htmlLabels:false` を強制することで `<text>/<tspan>`
     出力に切り替え、Word DrawingML との互換を確保する。Dockerfile で
     `/etc/mermaid-config.json` に COPY する

2. `docker/mermaid-svg/Dockerfile` の改修ポイント（auto-eth-paper 版から変更）:
   - **`inkscape` を apt-get install から除外**（SVG 出力では不要、イメージサイズ削減）
   - **`ENV HOME=/tmp` を追加**（任意 UID 実行時に puppeteer/chromium が `$HOME/.config` に
     書き込めるようにするため。compose の `environment` でも同値を入れるが、`docker run`
     単体実行・スクリプト経由実行で救命するため Dockerfile にも書く）
   - **`mermaid-cli` のバージョンを `@10.9.1` にピン留め**。mermaid-cli 11.x（mermaid v11
     flowchart-v2 renderer）は `flowchart.htmlLabels:false` 設定を **無視して常に
     `<foreignObject>` を出力する** ため、wrap_textbox.embed_svg_native との互換が崩れる
     （実測済み）。10.x 系はこの設定が機能する
   - **`COPY mermaid-config.json /etc/mermaid-config.json`** を追加

3. `docker/docker-compose.yml` に `mermaid` サービスを追加（既存 python サービスは
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
       - HOME=/tmp                                      # puppeteer の $HOME 書き込み対策
       - PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
       - PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium
   ```

4. 動作確認用コマンド（README や CLAUDE.md には追記しない。本 Prompt 内で実行のみ）:
   - 仮の .mmd ファイルを作成（`main/step01_narrative/figs/_smoke_test.mmd`）。
     **必ず日本語ラベルを含める**（フォント埋込確認のため）:
     ```mermaid
     flowchart LR
         A[日本語ラベル] --> B[テスト]
     ```
   - `docker compose -f docker/docker-compose.yml run --rm -u $(id -u):$(id -g) mermaid \
      mmdc -i main/step01_narrative/figs/_smoke_test.mmd \
           -o main/step01_narrative/figs/_smoke_test.svg \
           -p /etc/puppeteer-config.json \
           -c /etc/mermaid-config.json`
     **`-c /etc/mermaid-config.json` の指定は必須** — 省略すると `<foreignObject>` 出力に
     なり後段の wrap_textbox 経由 Word 表示が壊れる
   - 出力 SVG に `<foreignObject>` が **0 件** で、日本語テキスト（「日本語ラベル」「テスト」）が
     `<text>/<tspan>` 要素に入っていることを `grep` で確認
   - 同じ configFile で `sequenceDiagram` の最小例も変換し、`<foreignObject>` 0 件を確認
     （flowchart 以外で htmlLabels 設定が有効か検証）
   - 動作確認後、`_smoke_test*.mmd` と `_smoke_test*.svg` は削除

5. **テンプレート docPr@id 帯の確認**（M09-01/M09-02 対策）:
   - `data/source/r08youshiki1_5.docx` を unzip し、`word/document.xml` 内の
     `wp:docPr/@id` 値の最大値を grep で取得
   - 値が 1000 未満であれば、wrap_textbox.py の `--docpr-id-base 3000` で安全
   - 結果を Prompt 10-2 実装担当に申し送る（docs/plan2.md §7.2 の前提確認）

6. 既存 python サービスへの副作用がないことを確認:
   - `docker compose -f docker/docker-compose.yml run --rm python python --version`
     が引き続き通る
   - `./scripts/build.sh validate` が引き続き成功する（YAML バリデーションが通る）
   - `docker compose -f docker/docker-compose.yml config` の python サービス箇所が
     mermaid サービス追加前後で差分ゼロ

## 非機能要件
- 初回ビルドには数分かかる可能性あり（chromium/node_modules ダウンロード）
- image 名はデフォルト（`<project>_mermaid`）のままで良い
- ホスト上に mmdc / node をインストールしないこと

## 出力
- docker/mermaid-svg/Dockerfile
- docker/mermaid-svg/puppeteer-config.json
- docker/mermaid-svg/mermaid-config.json
- docker/docker-compose.yml（mermaid サービス追加）
````

#### 完了チェック

- [x] `docker/mermaid-svg/` 配下の 3 ファイル（Dockerfile / puppeteer-config.json /
      mermaid-config.json）が配置されている
- [x] Dockerfile から `inkscape` が除外されている
- [x] Dockerfile に `ENV HOME=/tmp` が設定されている
- [x] Dockerfile で mermaid-cli が **`@10.9.1` にピン留め** されている
      （11.x は `htmlLabels:false` を無視するため使えない — 実測済み）
- [x] Dockerfile で `mermaid-config.json` を `/etc/mermaid-config.json` に COPY
- [x] `docker/docker-compose.yml` に mermaid サービスが追加され、`environment: HOME=/tmp`
      を含み、既存 python サービスは無変更
- [x] `docker compose -f docker/docker-compose.yml build mermaid` が成功する
- [x] スモークテストの .mmd → .svg 変換が動作し、`-c /etc/mermaid-config.json` 指定下で
      出力 SVG の `<foreignObject>` が 0 件、日本語が `<text>/<tspan>` に埋込まれる
      （flowchart と sequenceDiagram の両方で実測確認）
- [x] テンプレート `r08youshiki1_5.docx` の既存 `wp:docPr/@id` 最大値を確認し、
      Prompt 10-2 の `--docpr-id-base 3000` で安全であることを記録
      （結果: `wp:docPr` 要素は 0 件＝既存 ID 帯と完全に非衝突）
- [x] 既存 python サービスの動作に副作用がない（`python --version` → 3.12.13、
      `./scripts/build.sh validate` 成功、compose config 差分ゼロ）

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

- 保持:
  - `to_emu()`, `textbox_marker()`, `process_textbox()` とその呼び出し
  - **Pass 1 の `.svg → .svg.png` リネーム**（pandoc に primary blip = PNG を強制し、
    Word の primary blip 形式不安定問題を回避。詳細は plan2.md §6 参照）
- **削除**: JSEK本文 による全 Para ラップ、OrderedList 手動番号化、
  .grid/GRID_TABLE マーカー
- 結果として Pass 2 の `Pandoc` ハンドラは `.textbox` Div のみを START/END マーカーで囲み、
  それ以外のブロックは完全にそのまま通す

lua フィルタの返り値は移植元と同じ 2 パス構成（Image リネーム → Pandoc ブロック処理）。
分量は 80〜100 行程度を見込む。

### B. main/step02_docx/wrap_textbox.py（新規）

next-gen-comp-paper の wrap-textbox.py から以下を移植:

- 保持:
  - 名前空間定義・register_namespace（**`asvg` を必ず含める**。詳細下記）
  - `extract_root_tag` / `restore_root_tag`
  - `is_textbox_marker` / `get_marker_text` / `parse_attrs`
  - `resize_images_in_content`（テキストボックス幅に合わせて画像縮小）
  - `build_textbox_paragraph`
  - `embed_svg_native`（Office 2016+ の asvg:svgBlob による SVG ネイティブ埋込）—
    **ただしパス解決バグを修正**。詳細下記
  - `process_docx` のメインフロー
- **削除**:
  - `apply_booktabs_borders` とセル罫線ユーティリティ一式
  - `resize_tables_in_content`（テキストボックス内テーブルのユースケースが現状ないため削除）
  - `relocate_textbox_by_page`（本プロジェクトでは不要）
- 変更:
  - `process_docx()` は `no_relocate=True` 相当を**既定**にする（`--no-relocate` フラグは残すがデフォルト True）
  - CLI 引数: `docx`（位置引数）, `--source`（Markdown ソース）, **`--docpr-id-base`（int, 既定 3000）**
  - `wp:docPr/@id` は **`id_base + z_order` で採番**。`id_base` は `--docpr-id-base` で外部から
    指定可能。build_narrative.sh は narrative ごとに別の base を渡す（1-2=3000, 1-3=4000）
    ことで inject 後の docPr@id 重複を防ぐ

## 重要な実装ポイント（C09-01 / M09-04 対策）

### `embed_svg_native` のパス解決修正（**Critical**）

移植元のコードは Markdown 内の image path を CWD 基準でオープンしているため、
`build_narrative.sh` が `cd "$PROJECT_ROOT"` した状態で wrap_textbox を呼ぶと
**全 SVG が見つからず silent fail** する。必ず以下のように修正:

```python
# 移植元 — CWD 依存で壊れる
# svg_full_path = svg_path

# 修正版 — source_md の親ディレクトリ基準で resolve
src_dir = os.path.dirname(os.path.abspath(source_md_path))
svg_full_path = os.path.normpath(os.path.join(src_dir, svg_path))
if not os.path.isfile(svg_full_path):
    raise FileNotFoundError(
        f"SVG referenced in {source_md_path} not found: {svg_full_path}")
```

未検出時は warning ではなく **`FileNotFoundError` を上げて非ゼロ exit** にすること。
CI / build.sh が確実に異常を捕捉できるようにする。

### NSMAP の名前空間（**Major**）

`inject_narrative.py` の NSMAP には asvg/a14 が追加済み（M09-04 対応）。wrap_textbox 側
でも以下を必ず登録すること:

```python
NSMAP = {
    # ... 既存の名前空間（w, r, wp, wp14, wps, a, mc, m, o, v, w10, pic, wpc）...
    "asvg": "http://schemas.microsoft.com/office/drawing/2016/SVG/main",
    "a14":  "http://schemas.microsoft.com/office/drawing/2010/main",
}
```

inject_narrative.py の NSMAP を「コピーで可」だが、**コピー後に asvg/a14 が含まれて
いることを必ず確認**する。

## 技術的注意事項

- Python 標準ライブラリのみ使用（zipfile, xml.etree.ElementTree, re, os, io, argparse）
- ホスト Python に新規パッケージを入れない

## エッジケース

- `::: {.textbox}` が 0 個の場合は `No TextBoxMarker regions found` を stdout に出して
  exit 0。既存本文（youshiki1_2.md / youshiki1_3.md）に影響を与えないことを保証
- `--source` が省略された場合は SVG ネイティブ埋込をスキップ（textbox 実体化のみ行う）
- `--source` が指定されているが SVG が存在しない場合は `FileNotFoundError`（非ゼロ exit）
- `extract_root_tag` / `restore_root_tag` は document.xml のルートのみを対象にすること

## 出力先
- filters/textbox-minimal.lua
- main/step02_docx/wrap_textbox.py

## 動作確認（単体）
- 本 Prompt 内では build_narrative.sh の改修は行わない。以下のスモーク確認のみ。
  **すべて Docker 経由で実行**（ホスト pandoc / python は使わない）:
  - pandoc を Docker 経由で実行:
    ```bash
    docker compose -f docker/docker-compose.yml run --rm -u $(id -u):$(id -g) python \
      pandoc main/step01_narrative/youshiki1_2.md \
        --lua-filter=filters/textbox-minimal.lua --to docx \
        --reference-doc=templates/reference.docx -o /tmp/tb_smoke.docx
    ```
  - 未変更の本文で正常に docx が生成され、unzip → document.xml に `TextBoxMarker`
    が現れない（`.textbox` ブロック未使用のため）
  - wrap_textbox.py も Docker 経由で実行:
    ```bash
    docker compose -f docker/docker-compose.yml run --rm -u $(id -u):$(id -g) python \
      python3 main/step02_docx/wrap_textbox.py /tmp/tb_smoke.docx
    ```
    が `No TextBoxMarker regions found` を出して正常終了すること
````

#### 完了チェック

- [x] `filters/textbox-minimal.lua` が作成され、100 行以下の最小構成
- [x] Lua フィルタに **Pass 1（`.svg → .svg.png` リネーム）** が含まれる
- [x] `main/step02_docx/wrap_textbox.py` が作成され、booktabs / relocate / resize_tables
      部分が削除済み
- [x] wrap_textbox.py の NSMAP に `asvg` と `a14` が含まれる
- [x] `embed_svg_native` が `source_md` 親ディレクトリ基準で SVG パスを resolve し、
      未検出時は `FileNotFoundError` を上げる
- [x] CLI 引数に `--docpr-id-base`（既定 3000）が追加され、`build_textbox_paragraph`
      内の docPr@id 採番に反映される
- [x] 既存の youshiki1_2.md を Lua フィルタ経由で pandoc 変換しても崩れない
- [x] `.textbox` ブロック未使用時に wrap_textbox.py が副作用なく終了する
- [x] ホスト Python / ホスト pandoc を使っていない（Docker 経由のみ）

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

1. `reference.docx` 生成の直後（**md ループの外**）に **Phase A: mermaid → svg → svg.png**
   を追加:
   - **`shopt -s nullglob` で囲んだ配列**を使い、`.mmd`/`.svg` ゼロ件時にリテラル glob が
     渡らないようにする（`set -euo pipefail` 環境下の必須対策）:
     ```bash
     shopt -s nullglob
     mmd_files=( main/step01_narrative/figs/*.mmd )
     shopt -u nullglob
     for mmd in "${mmd_files[@]}"; do ... done
     ```
   - 各 .mmd について、対応する .svg が存在しないか .mmd の mtime が新しい場合に変換
   - 変換コマンドは `docker compose -f docker/docker-compose.yml run --rm \
      -u $(id -u):$(id -g) mermaid mmdc -i <mmd> -o <svg> \
      -p /etc/puppeteer-config.json -c /etc/mermaid-config.json`
     （**`-c /etc/mermaid-config.json` は必須** — Prompt 10-1 申し送り。省略すると
     `<foreignObject>` 出力になり embed_svg_native が silent fail する）
   - **Phase A 後段**: `figs/*.svg` を nullglob 配列で列挙し、各 svg について同名の
     `<svg>.png`（命名規約: `foo.svg` → `foo.svg.png`、Lua フィルタの Pass 1 と一致）を
     `rsvg-convert -d 300 -p 300` で生成。これは pandoc に primary blip = PNG を渡すため
     の必須前処理（plan2.md §6 参照）。実行は `run_python` ではなく
     `docker compose ... python rsvg-convert ...` で行う（`librsvg2-bin` を
     docker/python/Dockerfile に追加すること）
   - `MODE=local` の場合は mmdc / rsvg-convert がホストに存在しないため警告を出して
     変換をスキップ（.svg / .svg.png が既存なら続行）

2. `PANDOC_OPTS` に **`--lua-filter=filters/textbox-minimal.lua`** を追加

3. pandoc 変換の直後に **Phase C: wrap_textbox 後処理** を追加:
   - 変換に成功した各 docx について、**narrative ごとに `--docpr-id-base` を分離**して
     `wrap_textbox.py` を呼ぶ:
     ```bash
     case "$src" in
         *youshiki1_2.md) base=3000 ;;
         *youshiki1_3.md) base=4000 ;;
         *)               base=5000 ;;
     esac
     run_python main/step02_docx/wrap_textbox.py \
         --source "$src" --docpr-id-base "$base" "$out"
     ```
   - wrap_textbox の失敗はビルド失敗として扱う（非ゼロ exit）

### docker/python/Dockerfile

- `apt-get install` に **`librsvg2-bin`** を追加（`rsvg-convert` を使うため）。
  既存の `fonts-noto-cjk fontconfig wget ca-certificates` の隣に追記

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

- [x] build_narrative.sh に Phase A（mmd→svg→svg.png）が **md ループの外** で 1 回だけ
      実行されるよう追加されている
- [x] Phase A の glob は `shopt -s nullglob` で囲まれており、.mmd / .svg ゼロ件でも
      失敗しない
- [x] docker/python/Dockerfile に `librsvg2-bin` が追加され、コンテナ内で
      `rsvg-convert --version` が実行できる
- [x] PANDOC_OPTS に `--lua-filter=filters/textbox-minimal.lua` が追加されている
- [x] 変換後 wrap_textbox.py が **`--docpr-id-base` を narrative 別に分離して** 自動実行される
- [x] 現行本文（textbox なし）で `./scripts/build.sh narrative` が通り、document.xml diff
      が想定内
- [x] E2E テスト `RUNNER=docker DATA_DIR=data/dummy SETUP_DIR=data/dummy ./scripts/build.sh`
      が通る（dummy には .mmd / .textbox を入れない前提）

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

- [x] fig1_overview.mmd が作成されている
- [x] youshiki1_2.md に 2 つの .textbox ブロックが追加されている
- [x] build_narrative で fig1_overview.svg が生成される
- [x] narrative docx 内に wp:anchor と asvg:svgBlob が埋め込まれる
- [x] word/media/ に bg_hospital.jpg と SVG が含まれる
- [x] dummy E2E が通る

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
   - `word/media/` に bg_hospital.jpg と PNG（svg.png）と SVG が存在（衝突時は `*_nN.*` にリネーム）
   - `[Content_Types].xml` に svg の Default extension が含まれる
3. **primary blip / asvg 二段構成の検証**（M09-07 対策）:
   - `a:blip/@r:embed` が指す rels の Target が PNG（`media/*.png`）であること
   - `asvg:svgBlob/@r:embed` が指す rels の Target が SVG（`media/*.svg`）であること
   - これにより Word 2013 でも primary PNG でフォールバック表示できる
4. **docPr@id 一意性**（M09-02 対策）:
   - `xmllint --xpath '//*[local-name()="docPr"]/@id' word/document.xml` の結果を
     `sort -u | wc -l` し、`grep -c` の総件数と一致すること（重複なし）
   - 1-2 と 1-3 の両方に図を追加した特別テスト分岐でも検査
5. **LibreOffice レンダリング**（**早期失敗検知用、本番判定ではない**）:
   - `libreoffice --headless --convert-to pdf main/step02_docx/output/youshiki1_5_filled.docx`
   - 生成 PDF を `pdfimages -list` で確認し、少なくとも 2 個のラスタ / ベクタ画像が
     含まれていること
   - `pdftotext -layout` でテキスト化し、様式ヘッダや本文が崩れていないこと
6. **Windows Word COM レンダリング**（**本番合否判定の主軸**、M09-05 対策）:
   - `./scripts/roundtrip.sh` を実行し、Google Drive 経由で Windows
     `watch-and-convert.ps1` → Word COM → PDF を生成
   - `data/products/youshiki1_5_filled.pdf` を目視確認し、以下を満たすこと:
     - bg_hospital.jpg がラスタ画像として表示される
     - fig1_overview.svg がラスタ画像（300 dpi 相当の primary PNG 経由）として
       鮮明に表示される。**ベクタ保持は Word COM `SaveAs2 wdFormatPDF` の仕様により
       達成できないため受容する**（M14-03 決定、report14）。primary PNG は
       `rsvg-convert -d 300 -p 300` で生成済みなので印刷品質は確保される。
     - テキストボックスの位置が本文との関係で崩れていない
     - 様式ヘッダ・脚注・ページ番号など既存要素が破壊されていない
   - LO 検証（5）が通っても Win 検証（6）で崩れる場合があるため、両方を必ず実行
7. **ページ数**: 様式1-2 部分のページ数が 15 ページ以内（デモ 2 図込み）
8. **ファイルサイズ**: 最終 docx が 10MB 未満、目標 3MB 未満
9. **非破壊**: デモ `.textbox` ブロックを **youshiki1_2.md から一時的に削除** して
   ビルドし直した場合に、以下が成立:
   - document.xml に wp:anchor / asvg:svgBlob が現れない
   - 既存 E2E `DATA_DIR=data/dummy` が引き続き通過
   - （削除を戻してから本 Prompt を完了させる）

## 改修が必要な場合の判断基準
- inject 後に画像が欠落する → `merge_rels` の `_COPY_REL_TYPES` にテキストボックス特有の
  関係タイプが必要か確認 / NSMAP に asvg/a14 が登録されているか確認
- docPr@id 重複によるオフセットずれ → `wrap_textbox.py --docpr-id-base` の narrative 別
  分離が build_narrative.sh で正しく適用されているか確認
- LO で OK だが Win で NG → 多くは primary blip が SVG のままになっている。Lua フィルタ
  Pass 1 と rsvg-convert PNG の生成チェーンを再確認
- 画像の配置崩れ → plan2.md §12 のリスク表に沿って `anchor-h`/`anchor-v` の調整

## 出力
- 検証結果レポート（コンソール出力で十分、docs への書き出しは不要）
- 問題があれば最小限のコード修正
````

#### 完了チェック

- [x] フルビルドで youshiki1_5_filled.docx に 2 つの図が運搬されている
- [x] `a:blip/@r:embed` が PNG を、`asvg:svgBlob/@r:embed` が SVG を指す二段構成
      （Word 2016+ UI 表示用。PDF 化では primary PNG のみ使用される）
- [x] `wp:docPr/@id` が全件ユニーク
- [x] LibreOffice PDF 化で画像が視認できる（早期失敗検知用）
- [x] **roundtrip.sh 経由の Windows Word PDF で図がラスタ画像として鮮明に表示される**
      （本番判定。primary PNG は `rsvg-convert -d 300 -p 300` で生成済みのため
      印刷品質を確保。ベクタ保持は SaveAs2 の仕様で不可、M14-03 で受容）
- [x] docx 内の Content_Types / rels / media が正しく更新されている
- [x] 様式1-2 が 15 ページ以内
- [x] デモを外した状態で既存 E2E が通る（非破壊性）

---

### Prompt 11: textbox 内テーブル機能（A→B→C 段階実装）

````
.textbox 機構を画像専用から拡張し、Pandoc Markdown のテーブルを位置指定付きで
書式に挿入できるようにしてください。既存の画像 textbox 機能を**絶対に破壊しない**
ことを最優先とし、A→B→C の 3 段階で進めてください。

## 文脈

med-resist-grant では既に `.textbox` Div で画像（fig1_overview.svg / bg_hospital.jpg）
を配置しています（Prompt 10-4 / 10-5 で完成）。content type 自体は lua filter 上で
制限されておらず、Pandoc Table ブロックも構造的には受容可能です。

ただし `wrap_textbox.py` の内部処理は画像中心の最適化（resize_images_in_content /
embed_svg_native）が組み込まれているため、テーブル含有時には画像専用ロジックを
スキップする分岐が必要です。

参考プロジェクト `next-gen-comp-paper` では同じ pandoc 構文で textbox 内テーブルを
実用しており（`Patient Distribution` 比較表など）、最終的にはこのレベルの「小綺麗な
テーブル」を med-resist-grant の様式1-2/1-3 に挿入できる状態を目指します。

## 参照すべき資料

| ファイル | 確認ポイント |
|---|---|
| `/home/dryad/anal/next-gen-comp-paper/src/paper.md` L117-145, L149-180 | textbox 内 Markdown table の実用例（Patient Distribution / Cancer comparison） |
| `/home/dryad/anal/next-gen-comp-paper/filters/jami-style.lua` | 参考プロジェクトの style filter（テーブルセル装飾の参考） |
| `/home/dryad/anal/next-gen-comp-paper/templates/` | 参考プロジェクトの reference.docx スタイル定義 |
| `filters/textbox-minimal.lua` | 既存 textbox 検出 lua（content type 制限なし、L100-110） |
| `main/step02_docx/wrap_textbox.py` | content collection / 画像最適化（L128 resize_images_in_content / L468 embed_svg_native） |
| `main/step02_docx/inject_narrative.py` | inject 時の table 含有 narrative マージ影響 |
| `main/step01_narrative/youshiki1_2.md` L67-99 | 既存の textbox 使用例（画像のみ） |
| `templates/reference.docx` | テーブルスタイル定義（C 案で参照） |
| `docs/plan2.md` §6, §7, §11, §12 | 既存設計・リスク表（textbox-minimal.lua / wrap_textbox.py の責務分担） |
| `docs/__archives/report15.md` | 直前のレビュー（残課題と本機能の位置付け確認） |

## 段階実装

### A 案: smoke test（コード改修なし、半日）

目的: 既存実装が pandoc table を textbox 内で受容するか実地確認。

1. `main/step01_narrative/youshiki1_3.md` の末尾に最小例を追加:

   ```markdown
   ::: {.textbox width="120mm" height="60mm" pos-x="40mm" pos-y="100mm" anchor-h="page" anchor-v="page"}
   | 項目 | 値 |
   |:-----|---:|
   | A    | 100 |
   | B    | 200 |
   :::
   ```

2. `RUNNER=docker ./scripts/build.sh` で全 6 ステップ通過確認
3. 出力 docx を unzip して構造検証:
   - `unzip -p main/step02_docx/output/youshiki1_3_narrative.docx word/document.xml | grep -cE 'w:tbl|wp:anchor|wps:txbx'`
   - `w:tbl` が `wps:txbx`（textbox content）の中に配置されているか
   - inject 後の `youshiki1_5_filled.docx` でも同構造が保持されているか
4. LibreOffice PDF / Windows Word PDF（roundtrip.sh 経由）で実描画確認
5. デモ追加例を削除して既存 E2E（dummy）が引き続き通過することを確認

判定基準:
- ✅ 表示 OK → A 案で完結、B/C 案は将来課題化可能
- ⚠ docx 構造は OK だが Word 描画で崩れ（列幅・配置） → B 案へ
- ❌ ビルド失敗 / 構造破壊 / 既存画像 textbox に副作用 → B 案必須

### B 案: content type 分岐（軽微改修、1-2 日）

目的: テーブル含有 textbox を画像とは別ロジックで扱う分岐を導入。

1. `filters/textbox-minimal.lua` を拡張:
   - div.content をスキャンし、Table を含む場合 `kind="table"` 属性を marker に追加
   - 画像のみは `kind="image"`、混在は `kind="mixed"`

   ```lua
   local kind = "image"
   for _, c in ipairs(div.content) do
     if c.t == "Table" then kind = "table" break end
   end
   -- marker 文字列に kind=... を追記
   ```

2. `main/step02_docx/wrap_textbox.py` を分岐:
   - `parse_attrs` で kind を読む
   - `kind == "table"` のときは `resize_images_in_content` をスキップ
   - `embed_svg_native` も画像 path が無いときは早期 return
   - content collection は table の `w:tbl` element を pass through

3. 非破壊性回帰テスト:
   - 既存画像 textbox（youshiki1_2.md 内 2 箇所）の出力が pre-B 案と完全一致
   - dummy E2E で 6 ステップ通過

判定基準:
- 既存画像 textbox の挙動に bit-level 差分がない（diff で確認）
- 新規 table textbox が docx で「最低限読める」品質（列幅・border 出る）

### C 案: テーブル装飾の本格拡充（3-5 日、最終段階）

目的: next-gen-comp-paper レベルの「小綺麗なテーブル」を実現。

1. textbox 属性 `table-style="bordered"|"minimal"|"banded"` を追加
2. `templates/reference.docx` に対応する `w:tblStyle` を定義（または既存スタイル
   を活用）
3. wrap_textbox.py で kind=table 時にテーブルへ `w:tblStyle` を注入
4. テーブル幅を textbox 幅に合わせて自動調整（`w:tblW w:type="dxa" w:w="..."` 計算）
5. `: Caption {#tbl:foo}` の crossref が textbox 越しに番号付け・参照される
   ことを確認（pandoc-crossref が textbox Div の中まで降りるか検証）
6. 列ごとの数値右寄せ（`|--:|`）が docx に伝搬することを確認

判定基準:
- 表示が「小綺麗」基準（next-gen-comp-paper の Patient Distribution と並ぶ品質）
- crossref 番号が本文中で正しく解決
- 様式1-2 のページ制限（15p）と docx サイズ（10MB）の維持

## 共通の確認事項

- 既存 E2E (`RUNNER=docker DATA_DIR=data/dummy SETUP_DIR=data/dummy ./scripts/build.sh`)
  が全 6 ステップ通過
- inject 後の `youshiki1_5_filled.docx` 内でも `w:tbl` が `wps:txbx` 内に保持される
  （`unzip -p` + grep で件数確認）
- `wp:docPr/@id` 一意性が table 含有で崩れない（M09-02 対策の継続）
- ファイルサイズ・ページ数制約の維持
- 画像 textbox との混在 docx で wp:anchor の z-order 衝突がない
- Windows Word PDF / LibreOffice PDF の両方で表示確認

## 段階間の判断ポイント

| 進行 | Go 条件 | No-Go 条件 |
|---|---|---|
| A → B | A 案で何らかの描画崩れ or 構造異常 | A 案で完全に綺麗に出る → B/C 不要 |
| B → C | B 案でロジック分岐が動くが見た目が「最低限」止まり | B 案で十分実用的 → C 案は提出後 |

## 提出期限の制約

提出期限 2026-05-20 までの残日数を踏まえ:
- A 案 = 半日（リスク 0）
- B 案 = 1-2 日（軽微）
- C 案 = 3-5 日（中規模）

提出前は **A → B 完了** を目標、C 案は提出後 or 余裕があれば踏み込む方針が安全。

## 改修が必要な場合の判断基準

- inject 後にテーブルが消える → `inject_narrative.py:inject_section` の body 要素
  コピーが `w:tbl` を含む block も拾えているか確認
- テーブルが textbox の外に出る → `build_textbox_paragraph` の content_elements
  ラッピング順序が wps:txbx に正しく入っているか確認
- 画像 textbox が壊れる → B 案の kind 分岐が画像 path を画像処理にルーティング
  しているか、resize ロジックの side effect 確認
- crossref が解決しない（C 案）→ pandoc-crossref のフィルタ順序、または textbox
  Div の attr が pandoc-crossref に見えているか確認

## 出力

- A 案: 動作検証ログ（コンソール出力）、必要に応じて youshiki1_3.md からデモ削除
- B 案: lua filter / wrap_textbox.py の最小改修
- C 案: lua filter / wrap_textbox.py / reference.docx の拡張
- 各案完了時に本プロンプトの完了チェックを `[x]` 化
````

#### 完了チェック

- [x] **A 案**: 最小例 textbox-table が docx に出力されビルド通過
- [x] **A 案**: Windows Word PDF / LibreOffice PDF で表示確認（破綻なし）
      ※ LibreOffice で構造確認。pandoc 既定の full-page 幅により右列が
      textbox 外にクリップされたため B 案で width 再計算を実装。
- [x] **A 案**: 既存画像 textbox の挙動が変化していない（dummy E2E 通過）
- [x] **B 案**: lua filter で kind 属性の自動判定が機能
- [x] **B 案**: wrap_textbox.py で kind に応じた処理分岐が機能
- [x] **B 案**: 画像のみの textbox で pre-B 案と bit-level diff なし
      （差分は `docProps/core.xml` の build timestamp のみ）
- [ ] **B 案**: 画像/テーブル混在 textbox でも崩れない
      （現状プロダクション本文に混在ケースがないため未実証。kind="mixed"
      分岐は実装済み・fit_tables_to_textbox_width は iter で全テーブルを
      走査する設計のため構造的には対応済み）
- [x] **C 案**: table-style 属性で見た目を制御
      minimal (booktabs 3 本線) / bordered (full grid) / banded (header 網掛け)
      / none (装飾無し) の 4 種を `apply_table_style` で実装。kind=table/mixed
      のときの既定は `minimal`。
- [ ] **C 案**: crossref `{#tbl:foo}` が機能
      → 本リポジトリは pandoc-crossref 未搭載（docker/python/Dockerfile に
      binary 追加 + version 整合性確認が必要）。提出後スコープに繰り延べ。
- [x] **C 案**: テーブル列幅が textbox 幅に自動フィット
      （B 案の `fit_tables_to_textbox_width` で実現。C 案では追加の個別列制御
      は入れず、pandoc の `|--:|` 右寄せ指定は docx に伝搬することを PDF で
      確認済）
- [x] **C 案**: next-gen-comp-paper レベルの描画品質達成
      Windows Word PDF 実レンダ（2026-04-18 roundtrip）で minimal/bordered/
      banded の 3 style が期待どおりに描画されることを画像で確認。
- [x] 全案共通: 様式1-2 が 15 ページ以内、docx <10MB
      （filled docx 136K、merged PDF 33p / 724KB、1-2 単独ページ数は C 案で
      変動なし）
- [x] 全案共通: inject 後の filled docx で `w:tbl` が `wps:txbx` 内に保持
      （smoke test で filled docx 内の 5 wp:anchor / 3 tables-in-txbx を確認）
- [x] 全案共通: `wp:docPr/@id` の一意性が崩れない
      （3 table + 2 image textbox で 3000/3001/4000/4001/4002 が衝突無し）

---

