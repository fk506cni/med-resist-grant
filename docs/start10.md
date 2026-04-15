# セッション開始プロンプト: 敵対的レビュー（第10回）— Prompt 10-1 実装レビュー

以下の指示に従い、Prompt 10-1（mermaid-svg コンテナ追加）の実装結果と、
スモークテストで判明した申し送り事項が Prompt 10-2 以降の Step 10 設計と
整合するかについて、敵対的レビューを行ってください。
レビュー結果は `docs/report10.md` に出力してください。

## レビュー方針

- **実装を開始しないでください。** レビューと指摘のみを行います。
- **焦点は「Prompt 10-1 実装結果」** — mermaid-svg コンテナ実装品質、
  既存 python サービスへの副作用の有無、そしてスモークテストで発覚した
  `<text>` 化の前提 / `wp:docPr` 実測値 0 が Prompt 10-2 以降と矛盾しないか。
- **レビュー対象外は特に設けません。** Step 10 全体の整合性に関わる
  指摘であれば Prompt 10-2〜10-5 や plan2.md にまたがっても可。
- **敵対的に検証してください。** 「うまくいきそう」ではなく「どこで壊れるか」を
  探してください。特に:
  - Docker ビルド・実行が別環境・別 UID・別 CWD で再現するか
  - `<text>` 化しない経路（sequenceDiagram / classDiagram / 既定設定の残存）で
    ビルドした場合に Prompt 10-2 の SVG 埋込が silent fail しないか
  - compose 経由 mmdc 直叩きと `convert-mermaid.sh` 経由の二経路が
    誰が・いつ使うのか曖昧になっていないか
- **`docs/__archives/report09.md` を読まずに**独立してレビューを行い、
  レポート作成時に report09.md と突き合わせて所見を統合してください。
- レビュー結果は `docs/report10.md` に、重大度（Critical / Major / Minor / Info）
  付きで出力してください。
- 前回レビューとの差分（新規発見 / 既知だが未対応 / 前回から改善済み）を
  明示してください。

## 前回（__archives/report09.md）からの主な変化

### 実装面
- **Prompt 10-1 完了**: 新規ディレクトリ `docker/mermaid-svg/` 配下に
  `Dockerfile` / `convert-mermaid.sh` / `puppeteer-config.json` を配置。
  `docker/docker-compose.yml` に `mermaid` サービスを追加（既存 `python`
  サービスは無変更）。
- Dockerfile の実装差分（auto-eth-paper 版から）:
  - `inkscape` を apt-get install から除外（SVG 出力では不要）
  - `ENV HOME=/tmp` を追加（任意 UID 実行時の puppeteer `$HOME/.config` 書込対策）
- compose の `mermaid` サービスで `HOME=/tmp` `PUPPETEER_*` 環境変数を設定
- `docker compose build mermaid` 成功、`docker compose run python python --version`
  も副作用なし（3.11.15 確認）

### スモークテストで判明した実測事項（Prompt 10-2 以降の実装者への申し送り）

1. **mermaid-cli は既定で `foreignObject` + HTML span を出力する**。
   flowchart の日本語ラベルは `<foreignObject>` の中の `<span class="nodeLabel">`
   として出力され、`<text>` 要素には現れない。
   Prompt 10-1 完了チェックが要求する「`<text>` 要素への日本語埋込」を満たすには、
   configFile に `{"flowchart":{"htmlLabels":false}}` を `-c` オプションで明示
   指定する必要がある。
   - mmd ファイル冒頭の `%%{init: ...}%%` 指定は**効かなかった**（実測）
   - 指定後は `<text>/<tspan class="text-inner-tspan">` に「日本語ラベル」「テスト」
     が埋込まれることを確認
   - **重要な未解決事項**: この前提が Prompt 10-2 の `embed_svg_native` /
     `wrap_textbox.py` / Prompt 10-3 の `build_narrative` 統合で明示されているか、
     また sequence/class 図で同じフラグが効くかは未検証

2. **`data/source/r08youshiki1_5.docx` の `wp:docPr` 要素は 0 件**。
   `word/document.xml` を unzip+grep した結果、`wp:docPr` は 1 件も存在しない
   （既存の埋込画像・図形ゼロ）。
   - plan2.md §7.2 の `--docpr-id-base 3000` は完全に安全
   - M09-01 / M09-02 対策の前提条件は実測で強化された
   - plan2.md / prompts.md の記述が「最大値 < 1000」のような推定値のままなら
     「実測 0 件」への更新が必要

### ドキュメント面
- `docs/prompts.md` Prompt 10-1 の完了チェック 8 項目全てに `[x]` を付与
- 上記 2 点の申し送りを Prompt 10-1 完了チェック欄にインライン備考として追記済み
  （ただし Prompt 10-2 の作業内容本体には未反映 — 指摘の余地あり）

## レビュー対象

### A. docker/mermaid-svg/ の実装品質

#### A-1. Dockerfile
- `inkscape` を外したことで librsvg 系・rsvg-convert・fontconfig 連携が
  壊れていないか（plan2.md §5.4 で `librsvg2-bin` 追加が予定されているなら
  それは **python サービス側** であるはず — mermaid 側に必要な代替はないか）
- `ENV HOME=/tmp` の宣言位置（mmdc install の前後どちらでも副作用なしか、
  キャッシュレイヤに不要なものを載せていないか）
- npm 警告の実害: `chevrotain@12.0.0` が `node>=22` を要求し、ベースは
  `node:20-slim`。mermaid-cli の現バージョンで実際に使われるコードパスに
  chevrotain が入っているか、将来 mermaid-cli アップグレードで破綻するか
- `fonts-noto-cjk` + `fonts-ipafont` + `fonts-liberation` の組合せで
  `<text>` 化した SVG の `font-family` 属性に何が入るか（埋込ではなく
  参照の場合、Word COM 側で代替フォントに置換され、PDF 化時にグリフが
  欠落するリスク）
- `fc-cache -fv` の後に HOME 変更しているが、次回 UID ゼロ以外での実行時に
  fontconfig キャッシュが読めない問題はないか
- イメージサイズ、初回ビルド時間（plan2.md §12 リスク I09-01 の
  `mermaid-build` サブコマンド検討の再評価要否）

#### A-2. convert-mermaid.sh
- **使用文脈が不明瞭**: Prompt 10-1 の作業内容 #4 はスモークテストを
  `docker compose run mermaid mmdc ...` で行っており、`convert-mermaid.sh` を
  **全く使っていない**。Prompt 10-3 の build_narrative 統合も compose 経由の
  mmdc 直叩きなら、このスクリプトは永久に使われない可能性がある（YAGNI）
- `IMAGE_NAME="med-resist-grant-mermaid"` はスクリプト独自で docker build する
  ハードコード名。compose が付けるデフォルト名（`docker-mermaid` 等）と
  一致しないため、スクリプト経由と compose 経由で**異なるイメージが並存する**
- `-f` (pdfFit) フラグを落としたが、SVG 出力では別のサイズ問題が出ないか
  （Word 貼付時に意図しないサイズ / overflow）
- `HOME=/tmp` を `-e HOME=/tmp` で明示渡ししているが、これは Dockerfile の
  `ENV HOME=/tmp` と重複。どちらか一方を消した場合の失敗モード

#### A-3. puppeteer-config.json
- `--single-process` と `--no-sandbox` を併用している — seccomp / AppArmor の
  ある環境で落ちる可能性
- auto-eth-paper 版からのベタコピーで、med-resist-grant 固有の要件
  （例: 長い chart のタイムアウト）が無視されていないか

### B. docker/docker-compose.yml 追加部

- 既存 python サービス記述が完全に無改変か（空行・インデント含む）
- mermaid サービスの `environment: HOME=/tmp` と Dockerfile の `ENV HOME=/tmp` が
  二重定義。compose の environment が優先される前提で Dockerfile 側を削れば
  より DRY だが、スクリプト単体実行時に Dockerfile 側が救命する設計か明示せよ
- `volumes: - ..:/workspace` のパスは compose ファイルからの相対。
  `docker/` 直下で `docker compose -f docker/docker-compose.yml` 実行と、
  `docker/` 内 CWD で実行で差が出るか
- orphan containers 警告（他プロジェクトと名前空間を共有）が実害を生むか
- service 名 `mermaid` が Prompt 10-3（build_narrative 統合スクリプト）から
  参照される前提との整合 — plan2.md § 8 や prompts.md 10-3 でこの名前が
  使われているか

### C. `<text>` 化申し送り事項の影響分析（最重要）

- **Prompt 10-2 の embed_svg_native() は SVG を lxml パースして DrawingML の
  graphicData にそのまま注入する**（plan2.md §7.1）。`foreignObject` + HTML span の
  ままだと、Word は HTML を理解できず、開いた時に**ラベルが消える / 空四角表示 /
  エラー**になる可能性が高い。この前提は Step 10 全体の**必須条件**であり、
  Prompt 10-1 の備考に閉じ込めるのは危険ではないか
- Prompt 10-2 の作業内容、Prompt 10-3 の build_narrative 統合、どこで
  `-c config.json` を渡すのか。**現在の prompts.md には `-c` 指定が
  書かれていない可能性が高い**
- `htmlLabels: false` は flowchart 専用設定。sequenceDiagram / classDiagram /
  stateDiagram / gantt / pie などで同じ挙動になるかは mermaid のソース／
  ドキュメント確認が必要。将来 Markdown に他図表を追加すると前提が崩れる
- mermaid 初期化設定の JSON をリポジトリに入れるなら置き場所（`docker/mermaid-svg/`
  配下か `main/step01_narrative/figs/` 配下か、`.mermaid/`等か）
- `<text>` 化した場合のフォント指定が SVG 属性として正しく出るか、Word COM が
  それを解釈できるか（noto-cjk → IPAexGothic 等への自動代替）

### D. plan2.md ↔ prompts.md ↔ 実装 の整合

- plan2.md §5.1 の Dockerfile 仕様と、実装された Dockerfile の 1 行単位の差分
- plan2.md §5.3 の環境変数一覧に `HOME=/tmp` が含まれているか
- plan2.md §7.2 の `--docpr-id-base 3000` の根拠記述（「既存 docPr < 1000」等）を
  実測「0 件」へ更新する必要の有無
- Prompt 10-2 の「作業内容」本体に `htmlLabels: false` の configFile 指定が
  **明記されているか**（Prompt 10-1 の完了チェック備考だけでは、Prompt 10-2
  実装時に確実に拾われる保証がない）
- plan2.md §12 リスク表の I09-01（初回イメージビルド ~5 分）が Prompt 10-1
  実測と整合するか（更に悪化・改善）
- `convert-mermaid.sh` は plan2.md / prompts.md のどこで使われる想定か。
  compose 経由でしか呼ばれないなら削除候補か

### E. その他（敵対的視点）

- 既存 python サービスの動作確認が `python --version` のみ。副作用は
  pip パッケージ / ビルドキャッシュ / イメージ共有レイヤ / ネットワーク等に
  潜み得る。より強い確認として `./scripts/build.sh validate` 等が通るか
- docker-compose.yml に `mermaid` サービスを足したことで、`docker compose up`
  系コマンドで意図せず mermaid がビルド／起動されるシーン
- mermaid-cli がイメージビルド時に **インターネット接続を要求する** — オフライン
  環境での再ビルド可能性
- `.dockerignore` 等の設定漏れでビルドコンテキストが肥大化していないか
  （`docker/mermaid-svg/` にサブディレクトリを増やした影響）

## 参照すべき資料

| ファイル | 確認ポイント |
|---------|------------|
| `docker/mermaid-svg/Dockerfile` | inkscape 除外、HOME=/tmp、フォント、npm 警告 |
| `docker/mermaid-svg/convert-mermaid.sh` | 使用文脈、IMAGE_NAME、compose との重複 |
| `docker/mermaid-svg/puppeteer-config.json` | sandbox フラグ、auto-eth-paper からの差分 |
| `docker/docker-compose.yml` | mermaid サービス追加、既存 python 無改変、environment 二重定義 |
| `docs/prompts.md` (Prompt 10-1, 10-2, 10-3) | 完了チェック備考と本文の整合、`htmlLabels:false` の反映 |
| `docs/plan2.md` §5, §7.2, §8, §12 | Dockerfile 仕様、docPr@id 帯、build_narrative、リスク表 |
| `data/source/r08youshiki1_5.docx` | `wp:docPr` 実測 0 件の再確認 |
| `/home/dryad/anal/auto-eth-paper/docker/mermaid-svg/` | 移植元との差分妥当性 |
| `main/step02_docx/inject_narrative.py` | `embed_svg_native` 実装と `<text>` 前提 |
| `docs/__archives/report09.md` | レポート執筆時に突き合わせ（レビュー中は見ない） |

## 出力フォーマット

`docs/report10.md` に以下の形式で出力してください:

```markdown
# 敵対的レビュー報告書（第10回）— Prompt 10-1 実装レビュー

レビュー実施日: YYYY-MM-DD
レビュー対象: （上記「参照すべき資料」のうち実際にレビューしたファイル）
前回レビュー: docs/__archives/report09.md (2026-04-15)

## サマリ

- Critical: N件 (新規N / 既知未対応N)
- Major: N件 (新規N / 既知未対応N)
- Minor: N件 (新規N / 既知未対応N)
- Info: N件

### 対応状況一覧

| ID | 重大度 | 状態 | 概要 |
|----|--------|------|------|
| C10-01 | Critical | 新規 | ... |
| ... | ... | ... | ... |

## report09.md との差分サマリ

- 前回の未対応項目で今回解消されたもの: N件
- 前回の未対応項目で依然として未対応のもの: N件
- 前回に記載がなく今回新規発見したもの: N件

## 指摘事項

### [C10-01] (Critical) タイトル

- **箇所**: ファイル名:行番号 or セクション名
- **前回対応状況**: 新規 / report09.md [XXX-NN] 対応済み / 未対応
- **内容**: 具体的な問題の説明
- **影響**: この問題が放置された場合に起きること
- **推奨対応**: 修正方針

（以下、Major → Minor → Info の順に列挙）

## リスクマトリクス

| リスク | 影響度 | 発生確率 | 総合評価 | 対策 |
|--------|--------|---------|---------|------|
| ... | 高/中/低 | 高/中/低 | Critical/Major/Minor | ... |
```

### 重大度の基準

- **Critical**: 実装がブロックされる、または成果物に致命的欠陥が生じる
- **Major**: 実装に手戻りが発生する、または成果物の品質に重大な影響がある
- **Minor**: 修正すべきだが実装を進めながら対応可能
- **Info**: 改善推奨だが現状でも問題なく進められる

## 制約

- ID 採番は `C10-NN` / `M10-NN` / `N10-NN` / `I10-NN`（重大度文字 + 回 + 連番）を推奨
- レビュー実施中は `docs/__archives/report09.md` を**読まない**。レポート作成段階で
  のみ突き合わせて差分サマリを書く
- 実装を開始しない（修正提案のみ）
- 京大の組織的性質上「有事」等の表現を避ける（本レビューでは通常出ないが念のため）
