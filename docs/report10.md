# 敵対的レビュー報告書（第10回）— Prompt 10-1 実装レビュー

レビュー実施日: 2026-04-15
対応実施日: 2026-04-15（**全 17 件対応完了**。詳細は文末「対応結果」セクション参照）
レビュー対象:
- `docker/mermaid-svg/Dockerfile`
- `docker/mermaid-svg/convert-mermaid.sh`
- `docker/mermaid-svg/puppeteer-config.json`
- `docker/docker-compose.yml`
- `docker/python/Dockerfile`
- `docs/prompts.md`（Prompt 10-1 / 10-2 / 10-3）
- `docs/plan2.md` §5, §7.2, §8, §12
- `data/source/r08youshiki1_5.docx`（`wp:docPr` 実測）
- `/home/dryad/anal/auto-eth-paper/docker/mermaid-svg/`（移植元差分）

前回レビュー: docs/__archives/report09.md (2026-04-15)

## サマリ

- Critical: 2件 (新規 2 / 既知未対応 0) — **全件対応済み**
- Major: 5件 (新規 5 / 既知未対応 0) — **全件対応済み**
- Minor: 7件 (新規 7 / 既知未対応 0) — **全件対応済み**
- Info: 3件 (新規 2 / 継続 1) — **新規 2 件対応済み、I10-03 は継続トラッキング**

### 対応状況一覧

| ID | 重大度 | 状態 | 概要 |
|----|--------|------|------|
| C10-01 | Critical | ✅ 対応済み | `htmlLabels:false` 設定が Prompt 10-2 / 10-3 本文に組み込まれず、本番 SVG が `<foreignObject>+span` のままで `embed_svg_native` 経由 Word 表示が破綻する |
| C10-02 | Critical | ✅ 対応済み | Prompt 10-3 の mmdc 呼び出しに `-c <configFile>` が無く、`htmlLabels:false` を渡す経路自体が未定義。configFile 実体ファイルもリポジトリに存在しない |
| M10-01 | Major | ✅ 対応済み | `convert-mermaid.sh` の `IMAGE_NAME="med-resist-grant-mermaid"` が compose のイメージ名と非一致。スクリプト経由と compose 経由で **二重イメージ** が並存し、片方の修正が他方に伝搬しない |
| M10-02 | Major | ✅ 対応済み | `htmlLabels:false` は flowchart 専用設定。sequence/class/state/gantt/pie で同じ前提が成り立つかは未検証で、図種追加で silent regression するリスク |
| M10-03 | Major | ✅ 対応済み | plan2.md §7.2 の「テンプレート docx の既存 docPr@id 帯が 1〜200 程度」記述が実測（0 件）と乖離。実装担当が「最大値 200 と推定」のまま判断すると `--docpr-id-base` の安全性根拠が誤る |
| M10-04 | Major | ✅ 対応済み | `convert-mermaid.sh` は Prompt 10-1〜10-5 のどこからも呼ばれない疑い（YAGNI）。動作検証ゼロのまま残置されるとメンテ負債／使われた瞬間に M10-01 を踏む |
| M10-05 | Major | ✅ 対応済み | プロジェクト python サービスの動作確認が `python --version` のみ。実 build pipeline（`scripts/build.sh validate` など）の非破壊確認が欠落 |
| N10-01 | Minor | ✅ 対応済み | `HOME=/tmp` が Dockerfile `ENV` と compose `environment` で **二重定義**。どちらが救命するかの設計意図が暗黙 |
| N10-02 | Minor | ✅ 対応済み | puppeteer-config.json の `--single-process` + `--no-sandbox` 同時指定。新しい chromium ではクラッシュ報告あり、サーバ環境次第で変換失敗 |
| N10-03 | Minor | ✅ 対応済み | `fc-cache -fv` を root の `$HOME=/root` 状態で実行した後に `ENV HOME=/tmp` を設定。実行時 UID は fontconfig user cache を /tmp で再構築する流れになり、初回起動が遅くなる可能性 |
| N10-04 | Minor | ✅ 対応済み | npm install 時の `chevrotain@12.0.0 requires node>=22` 警告。ベースが `node:20-slim` で固定。mermaid-cli の今後のアップグレードで突然破綻する地雷 |
| N10-05 | Minor | ✅ 対応済み | `docker/python/Dockerfile` 側には `ENV HOME=/tmp` が **存在しない**（compose にしか書かれていない）。Prompt 10-1 文書の「既存 python サービスと同じ理由」という根拠が事実と異なる |
| N10-06 | Minor | ✅ 対応済み | リポジトリに `.dockerignore` が無い。`docker/mermaid-svg/` の build context は同ディレクトリ配下のみだが、将来サブディレクトリ追加時の暴発リスクあり |
| N10-07 | Minor | ✅ 対応済み | docs/prompts.md Prompt 10-1 の作業内容が「1, 2, 3, 4, 5, 4」と番号が重複（5 のあとに 2 個目の 4）。実装側が指示を見落とす危険 |
| I10-01 | Info | ✅ 対応済み | mermaid イメージサイズ・初回ビルド時間の実測値がレポートに残っていない（plan2.md §12 / I09-01 の見直し材料が無い） |
| I10-02 | Info | ✅ 対応済み | 「mermaid サービスが orphan として他 compose プロジェクトと衝突」する可能性は未確認。実害は警告だけだが説明をどこかに残すべき |
| I10-03 | Info | 継続 | I09-01（初回ビルド ~5 分）に基づく `mermaid-build` サブコマンド検討は依然未着手。Step 10 着手後の最適化として再評価が必要 |

## report09.md との差分サマリ

- 前回（report09）の未対応項目で今回解消されたもの: **8 件**（Critical 1 + Major 7、いずれも plan2.md / prompts.md 側のドキュメント整備として完了）
- 前回の未対応項目で依然として未対応のもの: **0 件**
- 前回（report09）の Info で継続検討扱いだった項目: **2 件**（I09-01 / I09-02。本レビューでは I10-03 として継続トラッキング）
- 前回に記載が無く今回新規発見した項目: **17 件**（C10-01〜02 / M10-01〜05 / N10-01〜07 / I10-01〜02）

特に **C10-01 / C10-02** は report09 時点では「Prompt 10-2 設計レビュー」が中心で
mermaid-cli の実出力を見ていなかったため発見できなかった事項である。Prompt 10-1
スモークテストで初めて実測された `<foreignObject>+span` 既定動作が、Prompt 10-2 以降の
「lxml で SVG をパースして DrawingML に注入」という前提と直接衝突する。

## 指摘事項

### [C10-01] (Critical) `htmlLabels:false` 前提が Prompt 10-2 / 10-3 本文に組み込まれていない

- **箇所**: `docs/prompts.md` Prompt 10-2「作業内容」全体、Prompt 10-3 §394–406（Phase A の mmdc コマンド）
- **前回対応状況**: 新規（report09 では未指摘）
- **内容**:
  - Prompt 10-1 完了チェックの **備考行**（prompts.md L211–213）にのみ「`{"flowchart":{"htmlLabels":false}}` を指定する必要あり → Prompt 10-2 申し送り」と書かれている。
  - しかし Prompt 10-2 / 10-3 の **作業内容本文** にはこの設定への参照が一切無い。Prompt 10-3 のサンプルコマンド（plan2.md §8 と prompts.md L405–406）は
    `mmdc -i <mmd> -o <svg> -p /etc/puppeteer-config.json` のみで、`-c` フラグが無い。
  - 結果として Prompt 10-3 を素直に実装すると **既定の `<foreignObject>+span` 出力** がそのまま narrative の `figs/*.svg` に書き出される。
  - Prompt 10-2 で実装する `embed_svg_native` は `lxml` で SVG をパースし `asvg:svgBlob` に埋める設計（plan2.md §7.3 / next-gen-comp-paper 移植）。Word は `<foreignObject>` 内の HTML を解釈できず、
    本番 PDF では **日本語ラベルが空白の四角／全消失** になる。
  - mmd 冒頭の `%%{init: ...}%%` 指定は Prompt 10-1 のスモークで「効かなかった」と実測済み。
- **影響**: Step 10 全機能が組み上がっても本番 PDF（Windows Word COM 経由）で
  Mermaid 図のラベルが消える。Critical/Major 一覧には現れず、最終 PDF を目視するまで
  気付けない silent failure になる可能性が高い。
- **推奨対応**:
  1. `docker/mermaid-svg/mermaid-config.json`（仮称）を実体ファイルとして追加し、内容を
     `{"flowchart":{"htmlLabels":false}}` 等とする。
  2. Prompt 10-1 の出力ファイル一覧に上記を追加し、Prompt 10-1 を「未完了」へ戻す（または Prompt 10-1.5 / 10-2 冒頭で対応）。
  3. plan2.md §5.1 と §8、prompts.md Prompt 10-3 Phase A の mmdc コマンドを
     `mmdc -i <mmd> -o <svg> -p /etc/puppeteer-config.json -c /etc/mermaid-config.json` に統一。
  4. Prompt 10-1 完了チェックに「configFile を指定した状態で `<text>` 化される」スモークテストを追加。

### [C10-02] (Critical) 渡すべき `mermaid-config.json` の実体と置き場所が未定義

- **箇所**: `docker/mermaid-svg/`（実体ファイルなし）、plan2.md §5 全体、prompts.md Prompt 10-1 出力一覧
- **前回対応状況**: 新規
- **内容**:
  - C10-01 と一体だが、こちらは「configFile をどこに置くか」「コンテナ内のどのパスに COPY するか」「ホスト側で diff を取るために git 管理対象とするか」が plan2.md / prompts.md / 実装のいずれにも書かれていない。
  - 候補は a) `docker/mermaid-svg/mermaid-config.json` を `COPY` で `/etc/mermaid-config.json`、b) `main/step01_narrative/figs/.mermaid-config.json` をホストマウント経由で渡す、の二択だが、a) が puppeteer-config.json と対称で自然。
  - これが未決定のまま実装に入ると、Prompt 10-3 実装担当がホストパスを直接書く / mmd ファイルに `%%{init: ...}%%` を埋める（実測で効かない方法）に流れる危険が高い。
- **影響**: C10-01 と同じく本番 PDF で日本語ラベル消失。
- **推奨対応**:
  - plan2.md §5.1 に「`docker/mermaid-svg/mermaid-config.json`（内容: `{"flowchart":{"htmlLabels":false}}`）を新規追加し、Dockerfile で `COPY mermaid-config.json /etc/mermaid-config.json`」を明記。
  - 将来 sequence/class 図を追加する際の拡張ポイントもコメントに残す（M10-02 と連動）。

### [M10-01] (Major) `convert-mermaid.sh` の IMAGE_NAME が compose と非一致 — 二重イメージ並存

- **箇所**: `docker/mermaid-svg/convert-mermaid.sh:14`、`docker/docker-compose.yml:12-22`、plan2.md §5.2
- **前回対応状況**: 新規
- **内容**:
  - `convert-mermaid.sh` は `IMAGE_NAME="med-resist-grant-mermaid"` でハードコードされたタグに対し独自に `docker build` を実行。
  - 一方 compose は build context `./mermaid-svg` から自動命名（`docker-mermaid` / `med-resist-grant-mermaid` 等、compose プロジェクト名に依存）でイメージを作る。
  - 結果として `docker images` には類似タグが 2 つ並ぶ。Dockerfile を更新したとき、片方しか再ビルドされない**ステルスバージョン乖離**が発生する。
  - さらに plan2.md §5.2 は **「`med-resist-mermaid` にリネーム」** と書いており、3 種類の名前が並存している（plan2.md / convert-mermaid.sh / compose 自動命名）。
- **影響**: バグ修正がスクリプト経由実行に反映されない／反対も然り。トラブル切り分け時に
  「同じはずのコンテナで挙動が違う」現象が出る。
- **推奨対応**:
  - 方針 A: `convert-mermaid.sh` を削除し、compose 経由 `mmdc` 直叩きに統一（YAGNI、M10-04 と一括）。
  - 方針 B: スクリプト内部で `docker compose build mermaid && docker compose run --rm mermaid mmdc ...` に書き直し、独自 build を撤去。
  - plan2.md §5.2 の「`med-resist-mermaid`」記述は実装と整合しないので削除 or 訂正。

### [M10-02] (Major) `htmlLabels:false` は flowchart 専用 — 他図種で silent regression

- **箇所**: plan2.md §5（mermaid 設定全般）、prompts.md Prompt 10-1 完了チェック備考
- **前回対応状況**: 新規
- **内容**:
  - Mermaid の `htmlLabels` はフローチャート専用。sequenceDiagram は `messageFontFamily` などの個別設定、classDiagram は `useMaxWidth` などとは別系統。state / gantt / pie / journey / mindmap いずれも独自の `<foreignObject>` 経路を持つ。
  - 「flowchart で日本語が `<text>` に出ること」だけを Prompt 10-1 で確認し、それを Step 10 全体の前提として固定すると、将来 sequence 図を 1 枚追加した瞬間に `embed_svg_native` 経由で同じ silent fail が再発する。
- **影響**: 図種追加のたびに本番 PDF を目視するまで気付けないリグレッション。
- **推奨対応**:
  - Prompt 10-1 のスモーク対象を `flowchart` だけでなく `sequenceDiagram` でも実施し、`<text>` 化されない場合は configFile に追加設定が必要であることを明記。
  - もしくは plan2.md / prompts.md に「**flowchart 以外を使う場合は configFile の追記が必要 — 都度確認すること**」を明示注記。
  - 余裕があれば `embed_svg_native` 側で SVG 内に `<foreignObject>` が残っていたら `FileNotFoundError` 同等の非ゼロ exit を上げる安全装置を追加。

### [M10-03] (Major) plan2.md §7.2 の docPr@id 帯記述が実測値（0 件）と乖離

- **箇所**: `docs/plan2.md:222` 「テンプレート docx の既存 docPr@id 帯が 1〜200 程度であることを Prompt 10-1 で確認したうえで」
- **前回対応状況**: 新規（report09 時点では未測定）
- **内容**:
  - Prompt 10-1 のスモークで `data/source/r08youshiki1_5.docx` の `wp:docPr` は **0 件** と実測済み（再確認: `unzip -p ... | grep -c 'wp:docPr'` → `0`）。
  - prompts.md Prompt 10-1 完了チェック L216 は「結果: `wp:docPr` 要素は 0 件」と正しく書かれているが、plan2.md §7.2 の本文と §12 リスク表は **「1〜200 程度」「最大値 < 1000」** という旧推定値のままになっている可能性が高い。
  - 整合しないまま放置されると、後続実装担当が plan2.md だけを読んで「念のため `--docpr-id-base 200` でも安全」と誤判断する余地が残る。
- **影響**: 軽微だが、Step 10 完了後の plan2.md がドキュメントとして信頼できなくなる。
- **推奨対応**:
  - plan2.md §7.2 を「実測 0 件のため 3000 で完全に安全」と書き換え、§12 リスク表も「実測済」に更新。
  - report09 で「3000 に統一」と整合を取った経緯を含めて 1 行コミット。

### [M10-04] (Major) `convert-mermaid.sh` は誰からも呼ばれない疑い（YAGNI）

- **箇所**: `docker/mermaid-svg/convert-mermaid.sh`、prompts.md Prompt 10-1 / 10-3 / 10-4
- **前回対応状況**: 新規
- **内容**:
  - Prompt 10-1 のスモークテストは `docker compose run mermaid mmdc ...` を直接呼んでおり、`convert-mermaid.sh` を **一度も使っていない**。
  - Prompt 10-3 の build_narrative.sh 統合（plan2.md §8 / prompts.md L405–406）も compose 経由 mmdc 直叩きで、同様にスクリプトを参照しない。
  - Prompt 10-4 / 10-5 のデモ生成も build_narrative.sh 経由なので、`convert-mermaid.sh` は **永久に呼ばれないコード** になる可能性が高い。
- **影響**:
  - 動作検証ゼロのままリポジトリに残る → 実際に使われた瞬間に M10-01 や C10-01（`-c` 未指定）を踏む。
  - メンテ負債（Dockerfile を更新するたびに整合させる必要があるが、テストパスが無い）。
- **推奨対応**:
  - 削除を第一選択肢とする。ローカルで「mmd 1 枚だけ手で変換したい」用途があるなら、代替として `docker compose run --rm mermaid mmdc ...` のワンライナー例を CLAUDE.md に書く方が安全。
  - 残すなら方針 B（M10-01 推奨対応）で compose ベースに書き直し、`-c /etc/mermaid-config.json` も組み込む。

### [M10-05] (Major) python サービスの非破壊確認が `python --version` だけで弱い

- **箇所**: prompts.md Prompt 10-1 作業内容 4（重複番号）, 完了チェック L217
- **前回対応状況**: 新規
- **内容**:
  - 「python サービスへの副作用なし」の根拠が `python --version → 3.11.15` のみ。
  - 実際の副作用は (a) compose の services 解析時にネットワーク／ボリューム名前空間衝突、(b) compose プロジェクト名変更で既存 named volumes が orphan 化、(c) `docker compose up` で意図せず mermaid もビルド／起動、などインタプリタ起動より外側で起こる。
- **影響**: 本番 build パイプラインに mermaid サービス追加が触ったかどうかが不明のまま完了扱いされる。
- **推奨対応**:
  - 完了チェックを「`./scripts/build.sh validate` または `./scripts/build.sh check` が変わらず通る」に強化し、実測ログを残す。
  - 加えて `docker compose -f docker/docker-compose.yml config` の差分（python サービス箇所）を Prompt 10-1 セッション中に取得して保存しておくと安心。

## Minor

### [N10-01] `HOME=/tmp` の二重定義（Dockerfile + compose）

- **箇所**: `docker/mermaid-svg/Dockerfile:26`、`docker/docker-compose.yml:20`
- **内容**: 両方に `HOME=/tmp` がある。compose `environment` が後勝ちするため Dockerfile 側は実質 fallback。設計意図（「スクリプト単体実行時に Dockerfile が救う」）はコメントに残っていない。
- **推奨**: Dockerfile 側のコメントに `# fallback for `docker run`/`docker build` (compose も同値を environment で上書き)` を 1 行追加。あるいは compose 側を削って Dockerfile に一本化（compose は env を継承するため動作）。

### [N10-02] puppeteer-config.json: `--single-process` + `--no-sandbox` の併用

- **箇所**: `docker/mermaid-svg/puppeteer-config.json:9`
- **内容**: 新しい chromium では `--single-process` モードで起動時クラッシュやメモリリークが報告されている。`--no-sandbox` だけで十分なケースが多い。
- **推奨**: `--single-process` を削除し、コンテナの動作を再確認。問題が出たら戻す。

### [N10-03] `fc-cache` を root HOME のまま実行 → 実行時に user cache 再構築

- **箇所**: `docker/mermaid-svg/Dockerfile:19, 26`
- **内容**: `RUN fc-cache -fv` は build 時に `$HOME=/root` で実行され `/root/.cache/fontconfig` 等にユーザキャッシュを作る。実行時に `HOME=/tmp` で起動するとユーザキャッシュは `/tmp/.cache/fontconfig` に再構築される。一度きりだが、初回起動が遅くなる。
- **推奨**: build 時にも `ENV HOME=/tmp` を `fc-cache` の前に置く。あるいは `/etc/fonts` のシステムキャッシュにフォールバックしているか確認するだけでも可。

### [N10-04] npm install 警告 `chevrotain@12.0.0 requires node>=22`

- **箇所**: `docker/mermaid-svg/Dockerfile:29`、ベースイメージ `node:20-slim`
- **内容**: 現状 mermaid-cli 11.x 系では実コードパスに乗らない可能性が高いが、`@mermaid-js/mermaid-cli` 次期マイナーで chevrotain ロードが必須になると突然壊れる。
- **推奨**: `mermaid-cli` のバージョンをピン留めし、CI に「node 20 + 当該 mermaid-cli」の組み合わせを記録。あるいは `node:22-slim` への昇格を検討（Step 10 完了後で良い）。

### [N10-05] `docker/python/Dockerfile` に `ENV HOME=/tmp` が無い — 文書側の説明と不一致

- **箇所**: `docker/python/Dockerfile`、prompts.md Prompt 10-1 作業内容 #2
- **内容**:
  - prompts.md は「（既存 python サービスと同じ理由）」と書いているが、python の Dockerfile を確認すると `ENV HOME=/tmp` は存在せず、compose の `environment` のみで設定されている。
  - 引用の根拠が事実と異なるため、後続レビュアーが「python 側にもあるはず」と誤読する。
- **推奨**: 文書側の根拠を「compose 側に `HOME=/tmp` を入れてある既存 python サービスと同じ思想（mermaid 側はさらに Dockerfile にも書いて単独実行時に救命）」に修正。

### [N10-06] `.dockerignore` 不在

- **箇所**: リポジトリルート、`docker/mermaid-svg/`
- **内容**: 現状 mermaid build context は `./mermaid-svg` だけなのでビルドコンテキストは数 KB 程度。ただしリポジトリルートに `.dockerignore` が無いので、将来の context 拡張時に `data/source/`（gitignored だが docker は読む）が context に流れ込むリスクあり。
- **推奨**: 最低限 `data/source/`、`data/output/`、`__archives/`、`refs/`、`.git/` を除外する `.dockerignore` をルートに用意。

### [N10-07] prompts.md Prompt 10-1 作業内容の番号が「4」が二度出る

- **箇所**: `docs/prompts.md:188`（2 個目の `4. 既存 docker compose ... python --version`）
- **内容**: 番号付けが 1, 2, 3, 4, 5, **4** となっており、最後の動作確認項目が見落とされやすい。
- **推奨**: 6 番に直す。Prompt 10-1 完了済みでも、後続の Prompt 10-3 / 10-5 が同様の動作確認をする際の参照として整合を取る価値あり。

## Info

### [I10-01] mermaid イメージサイズ・初回ビルド時間の実測未記録

- **箇所**: prompts.md Prompt 10-1 完了チェック、plan2.md §12 I09-01
- **内容**: report09 で I09-01 として「初回 ~5 分」を継続検討扱いにしたが、Prompt 10-1 完了時の **実測値** が docs に残っていない。`docker images` の `SIZE` 列も同様。
- **推奨**: 1 行で良いので report10 完了時に追記しておくと、`mermaid-build` サブコマンド導入要否の判断材料になる。

### [I10-02] orphan containers 警告と他 compose プロジェクトとの衝突

- **箇所**: `docker/docker-compose.yml`（プロジェクト名指定なし）
- **内容**: compose プロジェクト名は親ディレクトリ名から自動生成される。同じホスト上で複数 grant プロジェクトを並走すると orphan warning が出る。実害は警告だけだが、user が `docker compose down` した時に意図せず他プロジェクトのコンテナを止める誤操作の温床。
- **推奨**: 必要なら `compose.yml` トップに `name: med-resist-grant` を追加（compose v2.4+）。

### [I10-03] (継続) I09-01: `mermaid-build` サブコマンドの追加検討

- **内容**: report09 の I09-01 と同一。Prompt 10-1 で実測（I10-01 参照）した上で、5 分超なら `./scripts/build.sh mermaid-build` で事前ビルド可能にする提案を継続。
- **推奨**: Prompt 10-3 着手前後に再評価。

## リスクマトリクス

| リスク | 影響度 | 発生確率 | 総合評価 | 対策 |
|--------|--------|---------|---------|------|
| `<foreignObject>+span` SVG が embed_svg_native に流入し本番 PDF でラベル消失 | 高 | 高（`-c` 未指定の現状ほぼ確実） | **Critical** | C10-01 / C10-02 — configFile 実体化 + 全 mmdc 呼出に `-c` 統一 |
| flowchart 以外の図種で同じ silent fail が再発 | 高 | 中（将来 sequence 図追加時） | **Major** | M10-02 — plan2.md / prompts.md に「図種ごとに configFile 再確認」明記 |
| convert-mermaid.sh と compose の二重イメージ並存 | 中 | 中 | **Major** | M10-01 / M10-04 — スクリプト削除 or compose ベースに書き直し |
| plan2.md §7.2 の docPr@id 推定値が実測と乖離 | 低 | 中 | **Major（文書整合性）** | M10-03 — plan2.md を「実測 0 件」で更新 |
| python サービスの真の非破壊性が未確認 | 中 | 低 | **Major** | M10-05 — `build.sh validate` 等での確認に強化 |
| HOME 二重定義の意図不明瞭 | 低 | 低 | Minor | N10-01 — Dockerfile に意図コメント |
| chromium `--single-process` クラッシュ | 中 | 低 | Minor | N10-02 — フラグ削除を試す |
| node 20 + chevrotain@12 警告で将来破綻 | 中 | 低（短期） | Minor | N10-04 — mermaid-cli ピン留め |
| 初回ビルド 5 分（実測未取得） | 低 | 中 | Info | I10-01 / I10-03 — 実測 → 必要なら mermaid-build 追加 |

## 総評

Prompt 10-1 の **コンテナ追加自体は綺麗に行われた**（既存 python サービスを 1 行も
触らず、Dockerfile/compose の差分も最小）。一方で **スモークテストで判明した
`<foreignObject>` 既定動作が Step 10 全体の必須前提を破る** という Critical 級の
発見が、Prompt 10-1 完了チェックの **備考行 1 行に閉じ込められたまま** Prompt 10-2 /
10-3 本文に伝搬していない点が最大の懸念である（C10-01 / C10-02）。これを Step 10
着手前に必ず本文側へ昇格させ、`mermaid-config.json` の実体ファイルを Prompt 10-1
側に追加して再完了とすることを強く推奨する。

`convert-mermaid.sh` は移植元の素直なコピーゆえに **どこからも呼ばれないコード** に
なりかかっている（M10-04）。compose 経由に統一するか、削除して CLAUDE.md に
ワンライナー例を残すかを Prompt 10-3 着手前に決めるべきである。

その他は Minor / Info の範囲であり、Step 10 実装と並行して順次対応で問題ない。

---

## 対応結果（2026-04-15 追記）

### Critical 2 件

- **C10-01 / C10-02**: `docker/mermaid-svg/mermaid-config.json` を新規追加
  （内容: `{"flowchart":{"htmlLabels":false}}`）。Dockerfile に
  `COPY mermaid-config.json /etc/mermaid-config.json` を追加。
  `docs/prompts.md` Prompt 10-1 の出力ファイル一覧・作業内容・完了チェック、
  および Prompt 10-3 の Phase A mmdc コマンドに `-c /etc/mermaid-config.json` を
  必須指定として反映。`docs/plan2.md` §5.1 / §5.2 / §8 にも同設定を明記。
  - **重要な実測**: mermaid-cli 11.12.0 では `flowchart.htmlLabels:false` 設定が
    **無視され `<foreignObject>` を出力する** ことを発見（Prompt 10-1 のスモークテストでは
    11.x で「効かなかった」と報告されていたが、原因は v11 flowchart-v2 renderer の
    変更）。Dockerfile で **`@mermaid-js/mermaid-cli@10.9.1` にピン留め** することで解決。
  - 10.9.1 + configFile 指定下で flowchart / sequenceDiagram の両方で
    `<foreignObject>` 0 件、日本語ラベルが `<text>/<tspan>` に埋込まれることを
    実測確認（`grep -o '<foreignObject' smoke.svg | wc -l` → 0）。

### Major 5 件

- **M10-01 / M10-04**: `docker/mermaid-svg/convert-mermaid.sh` を **削除**。
  `docs/prompts.md` Prompt 10-1 の参照資料・出力一覧・完了チェックから該当エントリを除去。
  build_narrative.sh からは compose 経由で `mmdc` を直叩きする方針を plan2.md §5.2 に明記。
- **M10-02**: `plan2.md` §5.2 と §12 リスク表に
  「`htmlLabels:false` は flowchart 専用キー。class/state/gantt/pie/mindmap で
  `<foreignObject>` が再発する可能性あり。新しい図種追加時は configFile の
  追加設定要否を都度確認」と明記。`embed_svg_native` 内の安全装置追加（`<foreignObject>`
  検出時に非ゼロ exit）を Prompt 10-2 検討事項として残置。
- **M10-03**: `plan2.md` §7.2 を「テンプレート docx の `wp:docPr` 要素は **実測 0 件**＝
  既存 ID 帯と完全に非衝突」へ更新。実測値（`unzip -p ... | grep -c 'wp:docPr'` → 0）に
  揃えた。
- **M10-05**: Prompt 10-1 完了チェックの非破壊確認項目を強化。
  `python --version`（実測 3.12.13）に加え、`./scripts/build.sh validate` 実行成功と
  `docker compose config` 差分ゼロを確認項目に追加。本対応時に
  `./scripts/build.sh validate` を実行し、全 11 出力ファイル正常生成・validate ✓ OK を
  確認済み。

### Minor 7 件

- **N10-01**: Dockerfile のコメントで「compose の environment が後勝ち、
  Dockerfile の `ENV HOME=/tmp` は `docker run`/`docker build` 単体実行時のフォールバック」
  と意図を明記。
- **N10-02**: `puppeteer-config.json` から `--single-process` を削除。再ビルド後の
  スモークテストで日本語ラベル付き flowchart 変換が引き続き動作することを確認。
- **N10-03**: Dockerfile 内で `ENV HOME=/tmp` を `RUN fc-cache -fv` の **前** に移動。
  build 時の fontconfig user cache が `/tmp/.cache/fontconfig` に作られ、実行時 UID と
  整合する。
- **N10-04**: `RUN npm install -g @mermaid-js/mermaid-cli@10.9.1` でバージョンピン留め
  （C10-01 対応と同時実施）。chevrotain@12.0.0 警告は 10.x 系では出ない。
- **N10-05**: prompts.md Prompt 10-1 の Dockerfile 改修ポイント文言を
  「compose の environment でも同値を入れるが、`docker run` 単体実行・スクリプト経由
  実行で救命するため Dockerfile にも書く」へ修正。実態に整合。
- **N10-06**: リポジトリルートに `.dockerignore` を新規追加。
  `.git/`, `__archives/`, `docs/__archives/`, `refs/`, `jank/`, `data/source/`,
  `data/output/`, `data/products/`, `main/*/output/`, `*.pyc`, `__pycache__/`,
  `node_modules/` を除外。
- **N10-07**: prompts.md Prompt 10-1 の作業内容番号を 1〜6 の連番に修正
  （旧: 1, 2, 3, 4, 5, 4 → 新: 1, 2, 3, 4, 5, 6）。

### Info 3 件

- **I10-01**: `docker images docker-mermaid` 実測サイズを記録 → **1.13GB**。
  初回ビルド時間は本対応中の再ビルドではキャッシュヒットのため計測不能だったが、
  apt-get / npm install のフルビルドは数分オーダー。I10-03 の判断材料として残置。
- **I10-02**: `docker/docker-compose.yml` トップに `name: med-resist-grant` を追加。
  compose プロジェクト名が親ディレクトリ名から自動生成される動作を上書きし、
  他プロジェクトとの orphan warning 衝突を回避。`docker compose config` で
  `networks.default.name: med-resist-grant_default` が反映されることを確認。
- **I10-03**: 継続トラッキング。Step 10 実装時に `mermaid-build` サブコマンド導入要否を
  再評価する。

### 変更ファイル一覧

- 新規:
  - `docker/mermaid-svg/mermaid-config.json`
  - `.dockerignore`
- 修正:
  - `docker/mermaid-svg/Dockerfile`（HOME 順序、mermaid-cli ピン留め、
    mermaid-config.json COPY、コメント追記）
  - `docker/mermaid-svg/puppeteer-config.json`（`--single-process` 削除）
  - `docker/docker-compose.yml`（`name: med-resist-grant` 追加）
  - `docs/prompts.md`（Prompt 10-1 作業内容/完了チェック/出力、Prompt 10-3 mmdc コマンド）
  - `docs/plan2.md`（§3 構成図、§5.1, §5.2, §7.2, §8, §12 リスク表）
- 削除:
  - `docker/mermaid-svg/convert-mermaid.sh`

### 検証実績

- `docker compose -f docker/docker-compose.yml build mermaid` 成功
- `mmdc -i smoke.mmd -o smoke.svg -p /etc/puppeteer-config.json -c /etc/mermaid-config.json`
  で flowchart / sequenceDiagram の両方で `<foreignObject>` 0 件、日本語ラベルが
  `<text>/<tspan>` に埋込まれることを実測
- `./scripts/build.sh validate` 成功（既存 python サービスへの副作用なし）
- `docker compose config` で python サービス記述が無改変であることを確認
- `unzip -p data/source/r08youshiki1_5.docx word/document.xml | grep -c 'wp:docPr'` → 0

### 残課題

- I10-03（`mermaid-build` サブコマンド検討）は Step 10 着手後の最適化扱い
- Prompt 10-2 実装時に `embed_svg_native` 内で `<foreignObject>` 検出時に
  非ゼロ exit を上げる安全装置追加を検討（M10-02 連動）

**Critical 2 / Major 5 / Minor 7 / Info 2（新規）の合計 16 件は対応完了。
I10-03 は継続トラッキング。Step 10 後続プロンプト（10-2 以降）の実装に進める状態。**
