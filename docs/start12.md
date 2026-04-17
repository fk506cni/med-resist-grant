# セッション開始プロンプト: 敵対的レビュー（第12回）— Step 10 全体（mermaid→svg→wrap_textbox→inject パイプライン）

以下の指示に従い、**Step 10 全体パイプライン**（mermaid コンテナ → Lua フィルタ →
`wrap_textbox.py` 後処理 → `inject_narrative.py` 統合）の一貫性と潜在破綻点について
敵対的レビューを行ってください。レビュー結果は `docs/report12.md` に出力してください。

## レビュー方針

- **実装を開始しないでください。** レビューと指摘のみを行います。
- **研究計画書の内容（`youshiki1_2.md` / `youshiki1_3.md` の論旨・学術的妥当性）はレビュー対象外です。**
  ただし Markdown 構文・画像参照・YAML front-matter などパイプラインに影響する形式的要素は対象に含みます。
- **焦点は「Step 10 全体パイプラインの一貫性と潜在破綻点」です。**
  - Prompt 10-1（mermaid-svg コンテナ）
  - Prompt 10-2（Lua フィルタ + `wrap_textbox.py`）
  - Prompt 10-3（`build_narrative.sh` への統合 + `librsvg2-bin` 追加）
  の 3 成果物が**契約的に整合しているか**、**片方が将来変わったときに silent に壊れないか**を
  検証してください。
- **敵対的に検証してください。** 「うまくいきそう」ではなく「どこで壊れるか」を探してください。
  特に以下の観点を重視:
  - **インクリメンタルビルド**での stale 出力（mtime 比較の盲点、`.svg.png` と `.svg` の依存関係）
  - **glob / 正規表現 / パス解決**の edge case
  - **docker / local モード分岐**の非対称性・ホスト依存性
  - **exit コード伝播**（中間ステップの失敗が最終 FAILED に反映されない可能性）
  - **namespace / ID 空間の衝突**（`wp:docPr/@id`、OOXML 名前空間）
  - **dummy data と実データの差**（E2E が通っても本番で壊れる構造）
- **`docs/__archives/report11.md` を読まずに**独立してレビューを行い、レポート作成時に
  `report11.md` と突き合わせて所見を統合してください。
- レビュー結果は `docs/report12.md` に、重大度（Critical / Major / Minor / Info）付きで
  出力してください。
- 前回レビューとの差分（新規発見 / 既知だが未対応 / 前回から改善済み）を明示してください。

## 前回（`docs/__archives/report11.md`）からの主な変化

Prompt 10-3 が完了し、以下が実装されました（commit 未反映、作業ツリー上の変更）:

- **`main/step02_docx/build_narrative.sh`**（約 +94 行の改修）:
  - **Phase A** 追加（md ループの外で 1 回のみ実行）:
    - `.mmd → .svg`: `shopt -s nullglob` で囲んだ配列 + `mtime` 比較で変換、
      `docker compose ... mermaid mmdc -p /etc/puppeteer-config.json -c /etc/mermaid-config.json`
    - `.svg → .svg.png`: 同じく nullglob 配列 + mtime 比較で `rsvg-convert -d 300 -p 300`
      （pandoc に primary blip として PNG を渡すための前処理）
    - `MODE=local` 時は `mmdc` / `rsvg-convert` がホストに無ければ警告してスキップ
  - `PANDOC_OPTS` に **`--lua-filter=filters/textbox-minimal.lua`** を追加
  - **Phase C** 追加（pandoc 変換後、md ごとに実行）:
    - `case "$src"` で `--docpr-id-base` を分離（`youshiki1_2.md`→3000 /
      `youshiki1_3.md`→4000 / その他→5000）
    - `run_python main/step02_docx/wrap_textbox.py --source "$src" --docpr-id-base "$base" "$out"`
    - 失敗時は `FAILED=1` でビルド失敗扱い（非ゼロ exit）
  - `run_mermaid` / `run_rsvg_convert` ヘルパー関数を追加
- **`docker/python/Dockerfile`**:
  - `apt-get install` に **`librsvg2-bin`** を追加（`rsvg-convert` を使うため）
- **`docs/prompts.md`**:
  - Prompt 10-3 の完了チェックボックス 7 項目を `[x]` に更新

**変更後の検証済み内容**:
- `./scripts/build.sh narrative` が通ること
- `document.xml` が改修前と**バイナリ一致**すること（非破壊性、`.mmd` / `.textbox` なし前提）
- `RUNNER=docker DATA_DIR=data/dummy SETUP_DIR=data/dummy ./scripts/build.sh` が通ること

**注意**: `main/step01_narrative/figs/` には `bg_hospital.jpg` のみ存在。`.mmd` / `.svg` は未配置で、
Phase A は実質スキップ状態で検証済み。**`.mmd` / `.textbox` を含むシナリオは Prompt 10-4 で
初めて実行される**ため、本レビューでは「未実行経路に潜むバグ」を重点的に探してください。

## レビュー対象

### 1. `main/step02_docx/build_narrative.sh` の改修

具体的に検証してほしい観点:

- **Phase A の nullglob 運用**
  - `shopt -s nullglob` / `shopt -u nullglob` のスコープが関数 / サブシェル境界を越えても
    期待通りか。他のスクリプトから source された場合に nullglob 状態が漏れないか。
  - `for mmd in "${mmd_files[@]}"` で配列が空 (`set -u`) の場合に bash バージョン依存で
    `unbound variable` エラーにならないか（bash 4.4 未満で顕在化）。
- **mtime 比較 `[[ "$mmd" -nt "$svg" ]]` の落とし穴**
  - `svg` が存在しない場合は `-nt` は true になるが、ファイルシステム（rclone 経由の Google Drive
    同期、rsync 経由）で mtime が保存されないケースで stale / over-regenerate が発生しないか。
  - `.svg` だけ手動で差し替えた場合に `.svg.png` が再生成されない可能性。
    （`.mmd` が `.svg` より新しければ `.svg` は再生成されるが、`.svg` が手動差し替えで
    mtime が更新されても `.mmd` の mtime と比較するのは二段目の `.svg → .svg.png` 判定のみ）
  - 並行 build で同一 figs/ を触る race（roundtrip.sh 複数同時実行）。
- **`-c /etc/mermaid-config.json` の必須性**
  - Prompt 10-1 申し送り通りこのオプションは必須だが、将来 mermaid-svg Dockerfile が
    config パス変更した場合に silent に `<foreignObject>` フォールバックする可能性。
  - `/etc/puppeteer-config.json` も同様の暗黙依存。これらがコンテナに存在することを
    **build_narrative.sh 側から検証する仕組みはない**。
- **Phase A と local モードのフォールバック**
  - `MODE=local` かつ `mmdc` / `rsvg-convert` 不在時の「警告してスキップ」は、
    実際には `set -euo pipefail` 下で `return 0` で続行する設計。
    しかし `.svg` / `.svg.png` が**一度も生成されていない**まま後段 pandoc に進むと、
    Lua フィルタの `.svg → .svg.png` 置換が**存在しない PNG パス**を吐く → pandoc が
    `[WARNING]` で silent に通す可能性。ユーザーは「成功」と誤認する。
  - local モードで `mmdc` はあるが `rsvg-convert` は無いといった**部分的欠落**の扱い。
- **Phase C の失敗伝播**
  - `FAILED=1` は最終 exit には反映されるが、**次の `src` は continue せず進む**。これは
    意図通りか（エラー複数表示のため）？ ただし `set -e` ではなく if/else で扱っているため
    `run_python` 内部で例外が起きても外には非ゼロ exit しか伝わらない。Python 側の
    traceback が埋もれる可能性。
  - `wrap_textbox.py` の `No TextBoxMarker regions found` は `print` + `return` で終了し
    exit 0 だが、`.textbox` を書き忘れた場合に silent success になる運用リスク。
- **`--docpr-id-base` 分離値 (3000 / 4000 / 5000)**
  - `wrap_textbox.py` が 1 ファイル内で生成する docPr 数が**各 base の空間を食い潰さない上限**は？
    3000〜3999 = 1000 個の余地があるが、`.textbox` 内の **画像・図形・shape 1 つ = 1 docPr** で
    消費されるなら 1000 個は過剰か妥当か。
  - `inject_narrative.py` がテンプレート既存 `docPr@id` を使う場合、3000 未満を使っていれば
    衝突しないが、**将来テンプレート側が変更されれば衝突**する。モニタリングは？
  - 「その他→5000」の分岐は現状どの md にマッチするか不明。デッドコード化リスク。
- **`set -euo pipefail` と `run_pandoc`/`run_python`/`run_mermaid` の pipefail**
  - `run_pandoc "$src" "${PANDOC_OPTS[@]}" --output="$out"` が `docker compose ... run --rm`
    経由の場合、Docker コンテナが途中で OOM 等で殺されたときの exit コード伝播。
  - docker compose の warn / stderr が混ざって実際の pandoc stderr が埋没する可能性。

### 2. `scripts/build.sh` 連携

具体的に検証してほしい観点:

- **narrative フェーズの呼出**
  - `build_narrative` 関数は `run_bash "$script"` 経由で呼ぶ。`run_bash` が docker / uv / direct
    の RUNNER 分岐をどう処理するか。`build_narrative.sh` 自身も `MODE=docker/local` を持つため
    **二段の分岐**になる。両者の整合性は？
  - `RUNNER=uv` で `build_narrative.sh` を呼んだときに内部の `docker compose ... mermaid` が
    実行されるのは意図通りか。
- **`check` サブコマンドの対象ファイル**
  - 現状 `youshiki1_2_narrative.docx` / `youshiki1_3_narrative.docx` を見ているが、
    `.svg` / `.svg.png` / `.mmd` の生成物はチェック対象外。Phase A の成果は「存在チェック」
    されない → Prompt 10-4 で `.mmd` を追加しても `check` は通ってしまう。
- **dummy data E2E の成功条件**
  - dummy には `.mmd` / `.textbox` を入れない前提だが、**入っていないことを保証する仕組みはない**。
    将来誰かが `data/dummy/figs/foo.mmd` を置けば検証経路が変わる。
  - `DATA_DIR=data/dummy` は template 参照先の切替だが、`main/step01_narrative/figs/` は
    `DATA_DIR` と無関係。dummy build でも**実データの figs/ を参照する**のは意図通りか。
- **`DATA_DIR` / `SETUP_DIR` 環境変数との整合**
  - Phase A / C は `main/step01_narrative/figs/` を直接参照するため、`DATA_DIR` を変えても
    figs/ は共通。これは YAML 設定との非対称性を生む。

### 3. wrap_textbox 統合

具体的に検証してほしい観点:

- **`--source "$src"` 引数による SVG パス解決**
  - `wrap_textbox.py` の `embed_svg_native` は SVG パスを `source_md_path` の親ディレクトリ
    基準で解決する。`src=main/step01_narrative/youshiki1_2.md` なら
    `main/step01_narrative/figs/*.svg` が解決される。これは正しいか。
  - `.svg.png` と `.svg` の両方が pandoc の `a:blip`（PNG）と `asvg:svgBlob`（SVG）に
    分離して入るが、**順序保証**（K 番目の画像 = K 番目の blip）は Pandoc 内部仕様に依存。
    report11 の C11-01 / M11-01 / M11-02 で対応済みとのことだが、**実際に `.mmd` を含む
    md でまだ一度も通していない**ため、対応が実シナリオで機能するかは未検証。
- **`--docpr-id-base` と `inject_narrative.py` の既存 docPr ID 空間との衝突**
  - `inject_narrative.py` は body 内の既存 docPr ID をどう扱うか。
  - テンプレート `data/source/r08youshiki1_5.docx` の本文・ヘッダ・フッタ内の docPr ID の
    最大値は？ 3000 / 4000 を使えば安全という根拠は？
  - inject 後の最終 docx 内で `wp:docPr/@id` の一意性を検証する仕組みはあるか。
- **`run_python` 経由の exit 伝播**
  - `wrap_textbox.py` の Python traceback は `docker compose ... run --rm` のコンテナ
    stderr から出るが、build.sh / build_narrative.sh のどこまで伝わるか。
  - SIGPIPE / 終了時クリーンアップ失敗で exit 141 などになった場合の扱い。
- **エラー時の `FAILED` フラグ挙動**
  - pandoc 失敗時は `continue` で次 md に進むが、wrap_textbox 失敗時は `continue` しない。
    この非対称性は意図通りか。wrap_textbox が壊れた docx を残したまま次の md 処理に進むと、
    ユーザーが**中間成果物を見て成功と誤認**する可能性。

### 4. Step 10 パイプライン一貫性

具体的に検証してほしい観点:

- **10-1 mermaid-svg コンテナ ↔ 10-2 filter / wrap_textbox ↔ 10-3 build_narrative.sh**
  - `.svg` の Mermaid 出力フォーマット（viewBox, width/height 属性, `<foreignObject>` 有無）が
    mermaid-cli のバージョンアップで変わった場合、wrap_textbox.py の
    `embed_svg_native` / lxml 解析が silent に失敗するか。
  - `.svg.png` の DPI（300）と `.svg` の viewBox のピクセル比が一致しないと、Word で
    PNG と SVG のサイズが食い違う可能性。
- **Lua フィルタの契約**
  - `filters/textbox-minimal.lua` が emit する START/END マーカーの styleId / 文字列は
    `wrap_textbox.py` と**両側で同一定義**されているか、あるいは一方が定数としてインポート
    しているか。マーカー文字列が 1 バイトでも食い違うと silent pass-through。
  - Lua filter が `.svg` → `.svg.png` のパス置換を行うなら、`rsvg-convert` 出力命名規約
    （`foo.svg` → `foo.svg.png`）と**文字列レベルで一致**している必要がある。Prompt 10-3
    説明では「Pass 1 の Image walker と一致」とあるが、ダブルドット `.svg.png` 命名は
    非標準で `.png` で終わる glob や `replace('.svg', '.png')` と両立しない罠。
- **インクリメンタル build の安全性**
  - `.mmd` 編集 → `.svg` 再生成 → `.svg.png` 再生成 → `.docx` 再生成の 4 段依存だが、
    mtime 比較は隣接ステップのみ。**3 段目の `.docx` は `.svg.png` だけ見て `.svg` の変化に
    気付かない**。例: `.svg` を手動で触ったが `.svg.png` は古いまま → docx は古い PNG を
    参照する。
  - pandoc は自身でキャッシュしないが、`reference.docx` のスタイル設定は毎回上書きされる。
    これが実行ごとに異なる docx を生むと **document.xml バイナリ一致**の前提が崩れる。
- **Windows 側 PDF 変換（`roundtrip.sh`, `watch-and-convert.ps1`）への影響**
  - wrap_textbox 後の docx を Word が開けることは Docker 内で検証できない。Word COM で
    `<asvg:svgBlob>` や `<wps:wsp>` の特殊要素が OOXML エラーを起こさないか。
  - `roundtrip.sh` が `build.sh` → rclone push → ... の順で動くなら、Phase A の
    `.svg.png` 生成が遅いと push タイミングで不整合が起きる可能性。
- **`MODE=local` の実用性**
  - `build_narrative.sh --local` では docker なし pandoc / Python を使うが、`mmdc` / `rsvg-convert` は
    skip 前提。つまり**local モードで `.mmd` を含む md は build できない**という暗黙制約。
    エラーメッセージではなく警告のみで続行するため、ユーザーが気付かない。

### 5. `docker/python/Dockerfile` 変更の副作用

具体的に検証してほしい観点:

- **`librsvg2-bin` の依存と互換性**
  - Debian slim での librsvg2-bin のバージョンは安定しているか。Debian bookworm と
    bullseye で `rsvg-convert` のフラグ (`-d` / `-p`) の挙動に差はないか。
  - SVG に `<foreignObject>` が残っていた場合、`rsvg-convert` は**何をレンダリング**するか。
    空 PNG、エラー、警告の違いによって Phase A 成否が変わる。
- **イメージサイズ / キャッシュ無効化**
  - `apt-get install` 行に 1 パッケージ追加したことで、pip install 以前のレイヤキャッシュは
    保たれるが **apt レイヤは再ビルド**。CI / 開発者のリビルドコストへの影響。
  - librsvg2-bin 依存でインストールされる追加ライブラリ（cairo, pango, gdk-pixbuf 等）の
    サイズ影響。
- **既存 Python ステップへの影響**
  - fill_forms / fill_security / fill_excel / inject_narrative は `rsvg-convert` を使わないが、
    共用イメージなので無害か。
  - `fonts-noto-cjk` と `librsvg2-bin` の**フォント解決の衝突**は無いか（librsvg は pango 経由で
    フォントを使う）。日本語フォントの fallback チェーンが変わると SVG レンダリング結果が
    変わる可能性。

## 参照すべき資料

| ファイル | 確認ポイント |
|---------|------------|
| `main/step02_docx/build_narrative.sh` | Phase A / C、`shopt -s nullglob`、mtime 比較、`run_mermaid` / `run_rsvg_convert`、`--docpr-id-base` 分離値、FAILED フラグ |
| `main/step02_docx/wrap_textbox.py` | `process_docx`、`embed_svg_native`、`--source` / `--docpr-id-base` / `--skip-missing-svg` 引数、NSMAP、`No TextBoxMarker regions found` の exit 挙動 |
| `main/step02_docx/inject_narrative.py` | body merge 後の `wp:docPr/@id` 既存空間、NSMAP に `asvg` / `a14` / `w14` / `w15` の追加状況 |
| `filters/textbox-minimal.lua` | `.textbox` Div の START/END マーカー emit、Image walker の `.svg → .svg.png` 置換ロジック、大文字拡張子扱い |
| `docker/python/Dockerfile` | `librsvg2-bin` の追加位置、apt レイヤ、pandoc deb インストール順、`fonts-noto-cjk` との共存 |
| `docker/docker-compose.yml` | `python` / `mermaid` サービス定義、`volumes: ..:/workspace`、`HOME=/tmp`、`PUPPETEER_*` 環境変数 |
| `docker/mermaid-svg/Dockerfile` | mermaid-cli バージョン、`/etc/mermaid-config.json` / `/etc/puppeteer-config.json` の配置場所・内容 |
| `scripts/build.sh` | `build_narrative` / `build_inject` 関数、`run_bash`、`RUNNER` 変数、`check` サブコマンド、`DATA_DIR` / `SETUP_DIR` |
| `scripts/roundtrip.sh` | ビルド→push→pull フローと Phase A / C のタイミング整合性 |
| `docs/plan2.md` §6 / §8 / §10 | SVG 二重埋込（PNG + asvg）戦略、Phase A/B/C 設計、デモ図表の挿入計画 |
| `docs/prompts.md` Prompt 10-1〜10-4 | 完了チェック状態、10-4 でまだ実行されない経路の特定 |
| `CLAUDE.md` | プロジェクト制約（10MB 上限、15 ページ制限、host Python 不使用） |

## 出力フォーマット

`docs/report12.md` に以下の形式で出力してください:

```markdown
# 敵対的レビュー報告書（第12回）— Step 10 全体（mermaid→svg→wrap_textbox→inject パイプライン）

レビュー実施日: YYYY-MM-DD
レビュー対象:
- `main/step02_docx/build_narrative.sh`
- `main/step02_docx/wrap_textbox.py`
- `main/step02_docx/inject_narrative.py`
- `filters/textbox-minimal.lua`
- `docker/python/Dockerfile`
- `docker/docker-compose.yml`
- `docker/mermaid-svg/Dockerfile`
- `scripts/build.sh` / `scripts/roundtrip.sh`
- （参考）`docs/plan2.md` / `docs/prompts.md`

前回レビュー: `docs/__archives/report11.md`（2026-04-15）

## サマリ

- Critical: N件 (新規N / 既知未対応N)
- Major: N件 (新規N / 既知未対応N)
- Minor: N件 (新規N / 既知未対応N)
- Info: N件

### 対応状況一覧

| ID | 重大度 | 状態 | 概要 |
|----|--------|------|------|
| C12-01 | Critical | ... | ... |
| ... | ... | ... | ... |

## report11.md との差分サマリ

- 前回の未対応項目で今回解消されたもの: N件
- 前回の未対応項目で依然として未対応のもの: N件
- 前回に記載がなく今回新規発見したもの: N件

## 指摘事項

### [C12-01] (Critical) タイトル
- **箇所**: ファイル名:行番号 or セクション名
- **前回対応状況**: 新規 / report11.md [C11-XX] 対応済み / 未対応
- **内容**: 具体的な問題の説明
- **影響**: この問題が放置された場合に起きること
- **推奨対応**: 修正方針

### [M12-01] (Major) ...
...

### [N12-01] (Minor) ...
...

### [I12-01] (Info) ...
...

## リスクマトリクス

| リスク | 影響度 | 発生確率 | 総合評価 | 対策 |
|--------|--------|---------|---------|------|
| ... | 高/中/低 | 高/中/低 | Critical/Major/Minor | ... |

## 総評

（パイプライン全体としての健全性評価、Prompt 10-4 に進んでよいか、優先すべき対応順序）
```

### 重大度の基準

- **Critical**: 実装がブロックされる、または成果物に致命的欠陥が生じる
  （例: 本番で silent に誤った画像が埋め込まれる、docx が Word で開けない）
- **Major**: 実装に手戻りが発生する、または成果物の品質に重大な影響がある
  （例: インクリメンタル build で stale 出力、非対称な失敗伝播で中間成果物が放置）
- **Minor**: 修正すべきだが実装を進めながら対応可能
  （例: UX 改善、ログメッセージ不足、デッドコード）
- **Info**: 改善推奨だが現状でも問題なく進められる
  （例: 将来の設計提案、仕様の備忘メモ）

### 命名規則

- 指摘 ID: `C12-NN` (Critical) / `M12-NN` (Major) / `N12-NN` (Minor) / `I12-NN` (Info)
- NN は 2 桁ゼロパディング（01, 02, ...）
