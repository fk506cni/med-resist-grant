# 敵対的レビュー報告書（第15回）— 提出前の最終健全性チェック

レビュー実施日: 2026-04-17
修正反映日: 2026-04-18（本ファイル末尾の「2026-04-18 修正セッション」を参照）
レビュー対象:
- `CLAUDE.md`（本セッションで未コミット差分あり）
- `scripts/build.sh` / `scripts/roundtrip.sh` / `scripts/create_package.sh` /
  `scripts/sync_gdrive.sh` / `scripts/collab_watcher.sh` / `scripts/validate_yaml.py`
- `scripts/windows/watch-and-convert.ps1`
- `main/step02_docx/fill_forms.py`（未コミット差分あり、L894）
- `main/step02_docx/fill_security.py` / `inject_narrative.py` / `wrap_textbox.py` /
  `build_narrative.sh`
- `main/step03_excel/fill_excel.py`
- `main/step01_narrative/youshiki1_2.md` / `youshiki1_3.md`（textbox / fig 構文のみ）
- `main/00_setup/*.yaml`（実データ進捗観点）
- `data/dummy/*.yaml`（本セッションで未コミット差分あり）
- `data/output/` / `data/products/` の現状残存物
- `.gitignore`、`docker/python/Dockerfile`、`pyproject.toml` / `uv.lock`（未追跡）
- `docs/prompts.md` / `docs/plan2.md` / `docs/step4plan.md`
- `docs/__archives/report14.md`（差分突合用）

前回レビュー: `docs/__archives/report14.md` (2026-04-17 前半)
提出期限: 2026-05-20 正午（残 33 日）

## サマリ

- Critical: 2 件（新規 2 / 既知未対応 0） → **2/2 対応済**
- Major: 7 件（新規 7 / 既知未対応 0） → **7/7 対応済**
- Minor: 10 件（新規 10 / 既知未対応 0） → **8/10 対応済（N15-04 / N15-06 は他指摘で連動解消）**
- Info: 6 件（新規 4 / report14 から継続 2） → **0/6（提出後の継続課題として保留）**

### 対応状況一覧

| ID | 重大度 | 状態 | 概要 |
|----|--------|------|------|
| C15-01 | Critical | ✅ 対応済 | `create_package.sh` に `PACKAGE_MODE=submission|interview` 分離を実装。submission では betten/besshi5 を含めず、interview では様式1-5/様式6-8 を含めない |
| C15-02 | Critical | ✅ 対応済（PDF 結合の足場） | `merge_pdfs.py` (pypdf) + `package.yaml` 駆動の結合パイプラインを実装。CLAUDE.md / create_package.sh のチェックリストに `submission_merged.pdf` を明記 |
| M15-01 | Major | ✅ 対応済 | `roundtrip.sh` Phase 2 で `data/output/` の `*.docx` / `*.xlsx` を集約前に削除（ステイル混入防止）。`build.sh clean` も従来通り対称 |
| M15-02 | Major | ✅ 対応済（実装拡充） | `fill_consent_forms` を 5 系統 placeholder fill（signer 行 / PI / Co / 課題名 / 代表機関名 / 元号年）に拡充。分担機関 signer は機関毎に異なるため手動運用維持 |
| M15-03 | Major | ✅ 対応済 | `fill_forms.py:894` を `DocxTable(new_tbl, tables["4-2"]._parent)` に修正。`_parent.part` アクセスが正しく解決される |
| M15-04 | Major | ✅ 対応済（検出機構） | `validate_yaml.py` に placeholder 検出（○○/△△/□□/XX/ＸＸ）を追加。dummy E2E 用に `--allow-placeholder` フラグも実装し build.sh から自動付与 |
| M15-05 | Major | ✅ 対応済 | `delete_sections` の補助金検出を「（参考様式 …補助金…）」厳密一致に変更、削除範囲を次の `（参考様式` / `承諾書` / `（様式` 見出しまでに制限。様式5 deletion も同手法で安全化 |
| M15-06 | Major | ✅ 対応済 | `pyproject.toml` / `uv.lock` を git 管理対象に。pypdf 6.10.2 が `uv sync` で解決済 |
| M15-07 | Major | ✅ 対応済（コメント記録） | `data/dummy/researchers.yaml` の `□□ □□` に「2-co_investigator E2E テスト」「同姓ハンドリング検証」の意図コメントを追加 |
| N15-01 | Minor | ✅ 対応済 | `build.sh check` に betten 件数 vs researchers.yaml 照合、`asvg:svgBlob` marker 検査、`submission_merged.pdf` 存在確認を追加 |
| N15-02 | Minor | ✅ 対応済 | `validate_yaml.py` REQUIRED_FIELDS に `lead_institution.type` / `authorized_signer.{name,title}` / `project.period_end` / `pi.{name_en,department,position}` を追加。`INST_TYPE_ENUM` 検査も追加 |
| N15-03 | Minor | ✅ 対応済 | `.gitignore` に `.claude/` を追加（settings.local.json 誤コミット防止） |
| N15-04 | Minor | ✅ 連動解消 | 本セッションの最終 commit で全変更を整理して履歴化 |
| N15-05 | Minor | ✅ 対応済 | `.gitignore` の `docs/__archives/*` 除外を削除し、レビュー履歴を git 管理に復活 |
| N15-06 | Minor | ✅ 連動解消 | M15-01 の `data/output/` クリーンで根本解消 |
| N15-07 | Minor | ✅ 対応済 | `fill_security.py` の `main()` で姓衝突を検出し、衝突時のみ `_pi` / `_co1` / `_co2` suffix を付与（衝突なしは従来命名を維持） |
| N15-08 | Minor | ✅ 対応済 | `build.sh check` で `unzip -p` を使い `wp:anchor|asvg:svgBlob` marker 数を検証 |
| N15-09 | Minor | ✅ 対応済 | `collab_watcher.sh` が `.env` 不在時に `.env.example` を fallback として読み込み警告で続行 |
| N15-10 | Minor | ✅ 対応済（N15-02 と同時） | `lead_institution.type` が REQUIRED_FIELDS 入り＋ `INST_TYPE_ENUM` 検査により typo 即座 fail-fast |
| I15-01 | Info | 継続 | lxml 移行は提出後の中期課題 — 33 日では着手非推奨 |
| I15-02 | Info | 継続 | wp:docPr 英語名 / pandoc rId 飛び番 / mermaid fontSize / crossref anchor — 提出に影響なし |
| I15-03 | Info | 継続 | `data/original/` の用途未文書化 — 提出に影響なし、提出後に整理 |
| I15-04 | Info | 部分対応 | N15-05 で docs/__archives/ を git 管理に戻したことで履歴共有経路は確立 |
| I15-05 | Info | 連動解消 | N15-04 の最終 commit で `docs/start15.md` も含めて履歴化 |
| I15-06 | Info | 継続 | `build.sh validate` の Direct fallback 提供は提出後の改善 |

## report14.md との差分サマリ

- 前回の未対応項目で今回解消されたもの: 0 件（report14 は Major 5 / Minor 6 のうち
  10 件解消、N14-02 のみ実地 inactive 化として残置 → 本レビューでも状態変化なし）
- 前回の未対応項目で依然として未対応のもの: 2 件（I14-01 lxml 移行、I14-02 細目）
  ともに Info、提出 33 日前の優先度として継続が妥当
- 前回に記載がなく今回新規発見したもの: 23 件（Critical 2 / Major 7 / Minor 10 / Info 4）
- 前回の判断が本セッションの状態変化により陳腐化したもの: 0 件
  - report14 までは「Prompt 10-5 の inject / textbox / Word PDF 化」の局所健全性に
    レビュー軸が集中していた。本レビューは「提出書類一式を 5/20 までに e-Rad へ
    上げきれるか」の運用視点に転じたため、対象範囲そのものが拡張され新規発見が
    集中した（既存の局所判断は陳腐化していない）

---

## 指摘事項

### [C15-01] (Critical) `create_package.sh` が応募時パッケージに別添 (betten_*) を一律含める

- **箇所**: `scripts/create_package.sh:103-115, 149-153, 228-242`
- **前回対応状況**: 新規
- **内容**:
  - `create_package.sh` は `for f in "$DOCX_OUTPUT"/betten_*.docx` を機械的に拾い、
    `betten_files` として `$PACKAGE_OUTPUT` にコピーし、最終チェックリストにも
    `☑ 別添: betten_XX_<name>.docx` の行で表示する。
  - CLAUDE.md「提出書類一覧」では別添（自己申告書）は **面接選出後 (7月中旬) 提出**と
    明記、応募時提出物には含まれない。公募要領上もそのように規定されている。
  - 現状 `data/output/` には実際 `betten_01_fukuyama.docx`〜`betten_04_kusuda.docx`
    までと、ステイルの `betten_03_○○.docx` が並存している（M15-01 / M15-04）。
    create_package.sh はこれらを区別せず全部応募パッケージに入れる。
  - 別添は研究者個人の経歴・国籍・処分歴等を含む **機微情報**。応募時に誤って
    e-Rad へアップロードすると、(a) 提出書類取り違えとして審査で不利、(b) 機微
    情報の不要な事前開示、の両方が同時に発生。

- **影響**:
  - 提出書類の不適切な混入（応募フェーズに面接フェーズの書類）。
  - 審査員が「応募者は提出書類を理解していない」と判断するリスク。
  - 機微情報（研究者の生年月日・国籍・処分歴等）が応募段階で開示される。
  - e-Rad の添付件数上限・サイズ制限に意図せず抵触する可能性。

- **推奨対応**:
  - 短期: `create_package.sh` に応募時 / 面接時のモード分離を導入。例:
    ```bash
    PACKAGE_MODE="${PACKAGE_MODE:-submission}"   # submission | interview
    case "$PACKAGE_MODE" in
        submission)
            # 様式1-1〜5 + 参考様式 + 様式6/7/8 のみコピー
            # betten_*.docx と besshi5_filled.docx は除外
            ;;
        interview)
            # 別紙5 + 別添 を集約
            ;;
    esac
    ```
  - チェックリスト出力も同様に分岐させ、CLAUDE.md 提出書類一覧の応募時/面接時の
    区分と機械的に対応させる。
  - 現在の create_package.sh の冒頭に「応募時には別添を含めない」コメントを必須
    として明示し、デフォルトモード変更時の事故も塞ぐ。

---

### [C15-02] (Critical) 様式1-1〜5＋参考様式を 1 PDF に結合するスクリプトが存在しない

- **箇所**: `scripts/` 全体（該当スクリプト無し）/ `CLAUDE.md` の提出書類一覧
- **前回対応状況**: 新規
- **内容**:
  - CLAUDE.md「提出書類一覧」末尾に明文化:
    > ※ 様式1-1〜5 + 参考様式は **1つのPDF** に結合して提出（未記入の様式は削除すること）
  - 実態: `data/products/youshiki1_5_filled.pdf` (29 ページ、1.35 MB) は既に
    `youshiki1_5_filled.docx` を Windows Word PDF 化したもので、これ自体が
    「様式1-1〜5＋参考様式」を統合した docx の単一 PDF。**`youshiki1_5_filled` 1 枚で
    要件を満たしているように見える**。
  - しかし、CLAUDE.md の表は 17 行に渡って様式1-1 / 1-2 / 1-3 / 2-1 / 2-2 / 3-1 / 3-2
    / 4-1 / 4-2 / 5 / 参考様式 を別行扱い、提出形式 PDF と書き並べている。
  - つまり「ビルドパイプラインが既に統合 PDF を 1 個生成しているのか」「PDF 結合
    スクリプトを別途必要としているのか」が **CLAUDE.md と実装で乖離**。create_package.sh
    のチェックリストは 1 行 `☑ 様式1-1〜5: youshiki1_5_filled.docx (...) （様式1-2/1-3
    本文 統合済み）` だけだが、PDF (data/products/) には触れていない。
  - 別紙5 と別添は応募時には不要（C15-01）であり、応募時の最終提出物は
    「`youshiki1_5_filled.pdf` 1 個 + 様式6/7/8.xlsx 3 個」で完結すると思われるが、
    この認識が文書化されていない。提出 33 日前で運用手順未確立。

- **影響**:
  - 提出当日に「様式1-1〜5 と 参考様式を別々の PDF にして添付すべきか、`youshiki1_5_filled.pdf`
    1 個で十分か」が不明瞭で、判断ミスで提出形式違反になる。
  - PDF 結合が手動運用なら、Adobe Acrobat 等の有償ツール準備・操作手順が必要。
    Linux 環境では `pdftk` / `qpdf` / `gs` 等を使うが、どれを採用するかも未定。
  - そもそも `youshiki1_5_filled.pdf` 1 PDF で完結する設計なら、その旨を CLAUDE.md
    と create_package.sh のチェックリストで明示すべき。

- **推奨対応**:
  - **第一優先**: 設計意図を確定し CLAUDE.md を更新。「様式1-1〜5＋参考様式は
    `youshiki1_5_filled.pdf` 1 個で要件を満たす」と明記するか、別途 PDF 結合
    スクリプト（例: `scripts/merge_pdf.sh` で qpdf 使用）を追加する。
  - `create_package.sh` の `--- 手動確認項目 ---` を更新し、PDF (data/products/) も
    `$PACKAGE_OUTPUT` にコピーする処理を追加。応募時の最終提出物リストを
    docx/xlsx だけでなく PDF まで含めて完結させる。
  - 提出 1 週間前までに dry-run（社内提出シミュレーション）を実施。

---

### [M15-01] (Major) `roundtrip.sh` Phase 2 が `data/output/` をクリアせず、ステイル成果物が並存

- **箇所**: `scripts/roundtrip.sh:117-139` (`phase_collect`)
- **前回対応状況**: 新規
- **内容**:
  - `phase_collect` は `cp "$f" "$OUTPUT_DIR/"` で上書きコピーするだけで、
    `$OUTPUT_DIR` の既存ファイルを削除しない。
  - 結果、研究者構成・命名規約・図表構成が変わると過去ビルドの docx が残り続ける。
  - 実例（2026-04-17 23:05 時点 `data/output/`）:
    ```
    betten_01_fukuyama.docx   (37 KB, 22:47)  ← 現行ビルド
    betten_01_yamada.docx     (37 KB, 22:47)  ← 現行ビルド
    betten_02_kuroda.docx     (25 KB, 22:47)  ← 現行ビルド
    betten_02_suzuki.docx     (37 KB, 22:47)  ← 現行ビルド
    betten_03_tanaka.docx     (37 KB, 22:47)  ← 現行ビルド (dummy 経由)
    betten_03_○○.docx        (25 KB, 22:47)  ← 過去ビルド残存（本番 placeholder）
    betten_04_kusuda.docx     (25 KB, 22:47)  ← 現行ビルド
    ```
    `betten_03_○○.docx` は本番 `main/00_setup/researchers.yaml` 由来（M15-04）、
    他は dummy 由来。**両方 22:47 に 同時タイムスタンプで残っている**。
  - `data/products/` も同様に `betten_03_○○.pdf` (298 KB) が存続。
  - これらが `roundtrip.sh` 経由で全部 gdrive に上がり、Windows 側で `processed/`
    に移動、`products/` に PDF として戻ってきた状態。**現状は「正解の betten」と
    「誤った placeholder の betten」が並んで動いている**。
  - C15-01 と組み合わさり、create_package.sh が両方ともパッケージに含めて出力する
    と、最終提出物に `betten_03_○○.pdf` という placeholder 名のファイルが入る。

- **影響**:
  - 提出物の取り違え（C15-01 と複合）。
  - PDF 変換 cost の浪費（Windows Word COM が無駄に PDF 化する）。
  - ステイル PDF の存在で Phase 4 expected_pdfs が水増しされタイムアウト誤動作（N15-06）。
  - 研究者を入れ替えた / 削除した際の旧ファイル残存も同じ機構で起きる。

- **推奨対応**:
  - `phase_collect` 冒頭で `data/output/` を一旦クリーン:
    ```bash
    log_info "data/output/ をクリーン..."
    rm -f "$OUTPUT_DIR"/*.docx "$OUTPUT_DIR"/*.xlsx
    ```
    あるいは `rsync --delete` 相当の動作にする。
  - 同時に `data/products/` 側にも対称の clean フローを入れる（gdrive 上の
    `__archives/` にバックアップしてから削除）。
  - `build.sh clean` のスコープを `data/output/` / `data/products/` まで拡張。

---

### [M15-02] (Major) `fill_consent_forms` が事実上未実装、placeholder 自動 fill が手動運用

- **箇所**: `main/step02_docx/fill_forms.py:665-698`
- **前回対応状況**: 新規（auto-memory `project_consent_form_autofill.md` で
  「future task」として既知だったが、提出 33 日前で残置）
- **内容**:
  - 関数本体は in_consent flag で承諾書セクションを scan するが、置換対象は
    `R8～R\u3000`（全角空白の placeholder 1 種類）のみ。
  - 機関名・代表者氏名・職名・課題名・受託期間・所在地などの主要 placeholder は
    全く埋まらない。Word で開いて手動入力する設計。
  - 出力ログに `✓ 参考様式 (best-effort)` と表示されるため、「埋まったように見える」
    錯覚を起こす。
  - data/products/youshiki1_5_filled.pdf (29 ページ) には承諾書の placeholder が
    生のまま残っている可能性が高い（本レビューで PDF テキスト抽出による定量検証は
    時間制約から未実施）。
  - Type A は委託事業のため「委託・代表機関」「委託・分担機関」両方の承諾書が
    必要、機関名・氏名等は YAML から導出可能なはずなのに、完全な手動運用。

- **影響**:
  - 提出当日に手動入力したまま Word PDF 化を再度走らせる必要がある。
  - 手動入力箇所の網羅性が個人記憶に依存。
  - 「自動生成パイプラインで全書類を生成する」という本プロジェクトの核となる
    アーキテクチャ目標と矛盾する穴。

- **推奨対応**:
  - 提出までに以下を実装:
    1. `data/products/youshiki1_5_filled.pdf` から承諾書ページを目視抽出し、
       placeholder の正確なテキストパターンを列挙する（`pdftotext` で分析）。
    2. config.yaml の `lead_institution.authorized_signer.{name,title}`、
       `lead_institution.name`、`project.title_ja`、`project.period_end` を
       配置すべき箇所を特定。
    3. `fill_consent_forms` を「best-effort 1 placeholder」から「網羅的な置換
       テーブル方式」へリファクタ。最低 5-10 placeholder の自動 fill。
  - 並行して、最終 PDF を目視して残存 placeholder（`R　`、空欄、`○○○○`等）の
    検出を `pdftotext + grep` で半自動化（提出前 sanity check）。

---

### [M15-03] (Major) `fill_forms.py:894` `DocxTable(new_tbl, doc.element.body)` 変更が未コミット・テスト記録なし

- **箇所**: `main/step02_docx/fill_forms.py:894`
- **前回対応状況**: 新規（本セッション開始時点で diff 1 行のみ未コミット）
- **内容**:
  - 変更前: `wrapped = DocxTable(new_tbl, doc)`
  - 変更後: `wrapped = DocxTable(new_tbl, doc.element.body)`
  - python-docx の `Table.__init__(self, tbl, parent)` は `parent` を保持し、後段で
    `parent.part`（→ `Document` の `part` プロパティ）を辿るパスがある。
    - 変更前の `doc` は `Document` インスタンスで `.part` を持つ。
    - 変更後の `doc.element.body` は `CT_Body`（lxml 要素）で、`.part` 属性は
      python-docx の context 上 `Body._part` 経由で expose される設計。**素の lxml
      要素には `.part` がない**。
  - この修正は (a) cell.text の単純更新では問題が出ない、(b) 段落追加で `runs[i]
    .part`、image insertion、cross-reference 等で例外、という挙動になる。fill_4
    は cell の text 更新が主体なので「動く」が、内部で何かの拡張パスを踏むと壊れる。
  - **commit message も無く、なぜ変更したのかの記録なし**。Linus 的に言えば
    「直感的でない、説明されていない、そして検証されていない 1 行」が本番直前に
    動いている。
  - 4-2 テーブル duplicate は分担者人数 ≧ 2 で発火する。本番 setup の co=3 の場合
    2 回発火する。dummy（co=2）でも 1 回発火する。

- **影響**:
  - 4-2 テーブル duplicate 経路で fill_4 内の特定操作（runs.add_picture / cell に
    画像追加 / cross-ref 解決）が走った瞬間に AttributeError で fail。
  - 現状 fill_4 はテキスト only の操作なので潜在 bug として隠れている。
  - 将来 fill_4 を機能拡張した瞬間に bug が顕在化、原因特定に時間がかかる。

- **推奨対応**:
  - 短期: なぜこの変更が必要だったかを git log / 開発記録から復元。理由が
    思い出せない場合は `DocxTable(new_tbl, doc)` に revert（M14 までの実地
    動作実績がある）。
  - 中期: 4-2 duplicate の正しい parent は実は `tables["4-2"]` の `_parent`
    （元 4-2 の親、通常は `_Body`）が型・参照ともに正しい。
    ```python
    wrapped = DocxTable(new_tbl, tables["4-2"]._parent)
    ```
  - いずれにせよ、commit 時に「なぜ変更したか」を必ず message に残す。

---

### [M15-04] (Major) 本番 `main/00_setup/researchers.yaml` に `○○ ○○` placeholder が co_investigators に残存

- **箇所**: `main/00_setup/researchers.yaml:177` (co_investigators[1])
- **前回対応状況**: 新規
- **内容**:
  - 本番 researchers.yaml の `co_investigators` 3 名のうち 1 名 (`○○ ○○`) が
    placeholder のまま。生成される betten ファイル名は
    `betten_03_○○.docx`（`_family_name("Unknown UNKNOWN")` のような fallback で
    `○○` が入る）。
  - 提出 33 日前で 3 名中 1 名が空欄は十分間に合う水準だが、**この placeholder の
    存在に対する明示的な warning が build パイプラインに無い**。`validate_yaml.py`
    の REQUIRED_FIELDS にも `name_ja` の存在チェックしかなく、placeholder 文字列
    （`○○`）の検出は無い。
  - また、`security.yaml` の `researchers` には `○○ ○○` のキーが存在することを
    前提に validate されるため、研究者を確定せず security.yaml を埋め忘れると
    build が通らない。これは事故防止に働く一方、確定が遅れた場合は連動修正が
    必要。
  - dummy/researchers.yaml にも `△△ △△` / `□□ □□` の placeholder が入って
    おり、E2E テストでは検出されない。

- **影響**:
  - 実データ確定の「タイムリミット」がドキュメント化されていない。
  - 提出 1 週間前の最終 build で `betten_03_○○.docx` が混入し、create_package.sh
    が出力するチェックリストにそのまま `☑ 別添: betten_03_○○.docx` と表示される
    （C15-01 で別添除外したとしても、別の経路で気づかない可能性あり）。

- **推奨対応**:
  - `validate_yaml.py` に「`○○` / `△△` / `□□` / `XX` などの全角・半角 placeholder
    マーカーが researchers.yaml の必須テキストフィールド (name_ja / affiliation /
    department / position) に含まれていたら ERROR」をルールとして追加。
  - 提出 1 週間前マイルストーンとして「全 researcher 確定」を明示。
  - 手動の最終 sanity check として `pdftotext data/products/youshiki1_5_filled.pdf
    | grep -E '○○|△△|□□|XX'` を提出前 checklist に組み込む。

---

### [M15-05] (Major) `delete_sections` の `_find("補助金")` 誤一致リスク — 削除範囲がチェックリストまで及ぶ

- **箇所**: `main/step02_docx/fill_forms.py:747-756`
- **前回対応状況**: 新規
- **内容**:
  - Type A（委託事業）では補助金参考様式を削除する。実装:
    ```python
    if proj_type in ("S", "A", "C"):
        hi = _find("補助事業")
        if hi < 0:
            hi = _find("補助金")
        if hi >= 0:
            end = ci if (ci >= 0 and ci > hi) else len(children)
            for i in range(hi, end):
                ...
    ```
  - `_find` は body の段落中に部分一致する **最初** の位置を返す。
  - テンプレート `data/source/r08youshiki1_5.docx` 内の出現:
    ```
    Counter({'補助金': 3, 'チェックリスト': 3, '補助事業': 1})
    ```
    「補助金」が 3 回、「補助事業」が 1 回出現。`_find("補助事業")` がまず 1 回目
    の出現に当たるが、それが「補助金参考様式の冒頭」である保証はない。
  - 例えば、委託参考様式の本文に「（補助事業の場合は別紙）」のような注釈テキストが
    あった場合、その段落以降〜チェックリスト直前まで（数十段落）が削除される。
    その範囲には委託参考様式の本文も含まれ、**本来削除すべきでない承諾書まで
    巻き込む致命的な誤削除**になる。
  - 「補助金」3 回出現の中身も、(1) 補助金参考様式タイトル、(2) 委託本文中の
    「補助金事業ではなく」のような対比言及、(3) チェックリスト「補助金の場合
    記入」のような項目、と複数あり得る。`if hi < 0` で fallback すると
    順序によっては正しく動くが脆い。
  - 現在の `youshiki1_5_filled.pdf` 29 ページが「期待通りか」は本レビューでは
    定量検証していないが、**削除範囲が肥大して提出書類に重要セクション欠落が
    起きていれば致命的**。

- **影響**:
  - 委託参考様式（承諾書）が誤削除された状態で提出 → 提出書類欠落。
  - 様式5、様式4-2 等の deletion ロジックも同じ `_find()` を使っており、同種の
    誤一致リスク。

- **推奨対応**:
  - 「補助金参考様式の冒頭」を **段落タイトル全文一致** で検出するように修正:
    ```python
    hi = _find_exact("（参考様式）（委託・補助金）承諾書")
    # or 太字 pPr style 等で見出し段落を識別
    ```
  - 削除範囲も `(参考様式）（委託・代表機関）` のような次の見出しまでに限定し、
    `len(children)` を fallback にしない。
  - `delete_sections` 適用前後の rels / sectPr 件数差を assert する unit test を
    追加し、想定外の構造破壊を CI で検知。
  - 提出 1 週間前に `youshiki1_5_filled.docx` の見出し階層をダンプして「全期待
    セクションが残存しているか」を目視確認。

---

### [M15-06] (Major) `pyproject.toml` / `uv.lock` が untracked — uv モード再現性が個人 PC 限定

- **箇所**: リポジトリルート、`.gitignore`
- **前回対応状況**: 新規
- **内容**:
  - `pyproject.toml` (project = med-resist-grant, deps: python-docx / openpyxl /
    pyyaml / ruamel.yaml / Jinja2) と `uv.lock` (lxml 6.0.2 等のピン解決済み)
    が untracked、`git status` の `??` セクションに残置。
  - `.gitignore` を確認したが pyproject.toml / uv.lock の除外は無い。
    `.venv/` は除外されている。
  - `RUNNER=uv ./scripts/build.sh` で動かすには両者が必要。共同研究者が clone
    した直後の環境では `uv sync` 不可。`RUNNER=docker` のみが実用的だが、Docker
    が無い予備機（共同執筆者の Mac 等）でのリカバリ手段が消える。
  - 両ファイルが個人 PC 限定で存在 → PC が壊れた瞬間に依存ピン情報が失われる。

- **影響**:
  - 提出当日に Docker が動かないトラブルが発生した場合、uv フォールバックも
    再現不能。リカバリ手段の選択肢が docker 1 本に縮小。
  - 共同研究者が build を試みる際にも uv モードが選べない（共同執筆経路で
    Linux 機 1 台に依存）。

- **推奨対応**:
  - 即座に `pyproject.toml` と `uv.lock` を git add → commit。
  - `.gitignore` に明示的に「`pyproject.toml` と `uv.lock` は管理対象である」と
    コメントを残す（将来の誤除外防止）。
  - Dockerfile にも `pyproject.toml` を COPY して `pip install -e .` 相当に
    切り替えるリファクタを検討（依存定義の単一情報源化）。

---

### [M15-07] (Major) `data/dummy/researchers.yaml` に `□□ □□` が追加された変更意図が未記録

- **箇所**:
  - `data/dummy/researchers.yaml:189`
  - `data/dummy/security.yaml:205`
  - `data/dummy/other_funding.yaml:84`
- **前回対応状況**: 新規（本セッション開始時点で未コミット）
- **内容**:
  - dummy YAML 3 ファイルに新しい co_investigator `□□ □□` (Jiro TANAKA) が
    追加されている。`age: XX`, `year: 20XX` 等の placeholder が混入。
  - 変更意図は「co_investigator 2 名以上の場合の E2E テスト網羅」と推察できるが、
    コミットメッセージなし、どの prompt / report で要求されたかも追跡できない。
  - dummy 側の変更だが、`name_en="Jiro TANAKA"` で `_family_name` が `tanaka` を
    返し、本番 `data/dummy/researchers.yaml` の co=2 構成を変えてしまう。
    既存 E2E テスト（dummy で `betten_*` を 3 → 4 件にする）の期待値変動が
    docs に残っていない。
  - また、`age: XX` のような integer フィールドに非整数文字列が入る例を作って
    しまい、validate_yaml.py の YAML パース通過を要件として固定してしまう。

- **影響**:
  - 「dummy E2E テストが何を保証していたか」の境界が曖昧化。
  - 本番が co=3 → dummy が co=2 のままで「dummy が本番より弱い」状態（M15-04 と
    複合）。

- **推奨対応**:
  - 変更を commit するなら必ず「なぜ追加したか」を message に明記。
  - dummy/researchers.yaml の placeholder（`□□ □□` 等）を実用上テストに必要な
    最小構成（例: 2 名で十分なら `□□ □□` 削除）に縮小、または本番 co=3 と
    完全一致させる方針を決定。
  - placeholder 値（`age: XX`、`year: 20XX`）が validate を通っているのは現在の
    REQUIRED_FIELDS に型検査がないため。N15-02 と合わせて schema 検査を強化。

---

### [N15-01] (Minor) `build.sh check` の網羅性不足

- **箇所**: `scripts/build.sh:301-364` (`do_check`)
- **前回対応状況**: 新規
- **内容**:
  - `expected_files` は固定 7 個のみ。betten は `for f in main/step02_docx/output/
    betten_*.docx` で「1 つでもあれば OK」扱い、件数照合なし。
  - 研究者数（PI + co_investigators）と betten 件数の一致を検査していない。
  - inject 適用状態（asvg:svgBlob marker の存在等）の検査なし。
  - 様式1-5 統合 PDF（`youshiki1_5_filled.pdf`）の検査もなし（PDF は
    data/products/ 経由で別管理）。
  - 承諾書 fill 状態（C15-02 / M15-02）の検査もなし。

- **影響**:
  - 提出直前の sanity check で「全部緑」と表示されるが、実は betten 件数が
    違っていた / PDF が古い / 承諾書が空欄、というケースを検出できない。

- **推奨対応**:
  - betten 件数を `len(researchers.yaml の pi + co_investigators)` と照合。
  - PDF 存在 / サイズ / mtime のチェックを追加。
  - inject 適用 marker の検査（M14-04 と同等のロジックで `asvg:svgBlob` 存在 → OK）。
  - placeholder 残存の検査（`pdftotext ... | grep -E '○○|△△|□□|XX'`）。

---

### [N15-02] (Minor) `validate_yaml.py` REQUIRED_FIELDS が最小限

- **箇所**: `scripts/validate_yaml.py:33-56`
- **前回対応状況**: 新規
- **内容**:
  - 必須フィールドが各 YAML で 3-8 個のみ。例えば config.yaml の
    `lead_institution.type`（M15-05 の様式5 deletion に直結）、
    `lead_institution.authorized_signer.name`（承諾書 fill）、
    `project.period_end`（承諾書 fill）はチェックなし。
  - security.yaml は `researchers` キーの存在のみ、各 researcher の中身は無検査。
  - placeholder 値の検出（M15-04 で要望）も無し。

- **影響**:
  - 提出直前に YAML が壊れていても build がエラーで止まらず、最終 PDF 段階で
    初めて発覚。

- **推奨対応**:
  - REQUIRED_FIELDS に以下を追加:
    - `config.yaml`: `lead_institution.type`, `lead_institution.authorized_signer.name`,
      `lead_institution.authorized_signer.title`, `project.period_end`
    - `researchers.yaml`: `pi.name_en`, `pi.affiliation`, `pi.department`, `pi.position`,
      各 co_investigator の同等フィールド
  - placeholder 検出ルール（M15-04）を追加。
  - 値の type 検査（`age` は int、`year` は int）を追加。

---

### [N15-03] (Minor) `.claude/settings.local.json` が `.gitignore` 未記載

- **箇所**: `.gitignore`、`.claude/settings.local.json`（11.7 KB）
- **前回対応状況**: 新規
- **内容**:
  - `.gitignore` に `.claude/` の記載なし。`git status` で `?? .claude/` と表示。
  - `.claude/settings.local.json` には MCP サーバ設定 / API トークン / プロジェクト
    固有の権限設定が含まれる可能性。
  - `git add .` を実行すると無自覚に commit されるリスク。

- **影響**:
  - 機微情報の意図しない公開。

- **推奨対応**:
  - `.gitignore` に追加:
    ```
    # Claude Code local settings
    .claude/
    ```

---

### [N15-04] (Minor) 本セッション開始時点で大量の未コミット変更が累積

- **箇所**: `git status`
- **前回対応状況**: 新規
- **内容**:
  - 修正: 7 ファイル（CLAUDE.md / dummy YAML 3 / docs/prompts.md / docs/step4plan.md
    / fill_forms.py / templates/reference.docx）
  - 削除: 13 ファイル（docs/report1-6, report14, start1-2, 5-6, 14）
  - 追加: 4 ファイル（.claude/, data/original/, docs/start15.md, pyproject.toml,
    uv.lock）
  - **本セッションの開始時点で既に存在**。前セッション終了時の最終状態と
    本セッション開始時の状態に差分が大きいまま、現セッションを進めている。
  - report14 では「全 Major 5 件対応済」とまとめられているのに、対応の証跡となる
    変更が一部 unコミット のまま放置。

- **影響**:
  - 何が「対応済」で何が「対応中」かの境界が曖昧化。
  - レビューサイクルで「ある勧告に対する修正 commit」を再現追跡しにくい。
  - 共同研究者が clone した瞬間に build が異なる結果になる可能性
    （reference.docx 等のバイナリ変更が伝わらない）。

- **推奨対応**:
  - 提出までの残 33 日で必ず以下を整理:
    - report14 対応の commit を分離して履歴に残す
    - 本セッションの dummy YAML 変更 / fill_forms.py 変更を理由付きで commit
    - `pyproject.toml` / `uv.lock` を commit（M15-06）
    - 削除した docs を `git rm` で正式に削除し履歴を整理

---

### [N15-05] (Minor) `docs/__archives/` が gitignore — レビュー履歴が clone に伝播しない

- **箇所**: `.gitignore:12-13`
- **前回対応状況**: 新規
- **内容**:
  - `.gitignore`:
    ```
    docs/__archives/*
    !docs/__archives/.gitkeep
    ```
  - 削除した report1-14 / start1-14 は `docs/__archives/` に手動で移動されているが、
    そのアーカイブ自体が git 管理外。共同研究者が clone した環境にはレビュー履歴が
    伝わらない。
  - レビュー履歴は提出後の振り返り・提出失敗時の原因究明に重要だが、現状は
    レビュー実施者の個人 PC 限定。

- **影響**:
  - 共同研究者・将来のメンテナーがレビュー履歴を参照できない。
  - もし開発者の個人 PC が壊れたら全レビュー履歴が失われる。

- **推奨対応**:
  - レビュー履歴は git 管理に戻す（gitignore の除外パターン削除）。
  - or 別 repo に履歴を pin する（例: `med-resist-grant-docs-archive`）。
  - 提出後にレビュー履歴を参照したくなる場面（次年度応募・継続応募・改善 PDCA）
    があるため、保存方針の確立を提出前に済ませる。

---

### [N15-06] (Minor) `roundtrip.sh` Phase 4 `expected_pdfs` がステイル docx も計上

- **箇所**: `scripts/roundtrip.sh:194-198`
- **前回対応状況**: 新規
- **内容**:
  - `expected_pdfs` は `for f in "$OUTPUT_DIR"/*.docx; do expected_pdfs=$((+1)); done`
    で計算。M15-01 のステイル docx も計上される。
  - 例: 現状 docx 13 個（betten 7 個 + besshi5 1 個 + youshiki1_2/1_3_narrative 2 個 +
    youshiki1_5_filled 1 個 + xlsx 3 個 = docx 11 個 + xlsx 3 個）が
    `data/output/` にあるが、`betten_03_○○.docx` 1 個がステイル。
  - watch-and-convert はそれを既に PDF 化済み（products に PDF が残存）なので、
    実際の動的 expected は変わらないが、新規ビルド側で docx が増えると
    expected と found の整合が崩れる。

- **影響**:
  - PDF が全部できているのにタイムアウト末まで待つ→無駄な待機時間。
  - 提出当日にこの待機で焦りが生じる。

- **推奨対応**:
  - M15-01 の `data/output/` クリーンと併せて解決。

---

### [N15-07] (Minor) `_family_name` が同姓衝突を非対称に扱う

- **箇所**: `main/step02_docx/fill_security.py:446-452`
- **前回対応状況**: 新規
- **内容**:
  - 例: PI = `Jiro TANAKA` (tanaka) / co[0] = `Hanako TANAKA` (tanaka) → ファイル名は
    `betten_01_tanaka.docx` と `betten_02_tanaka.docx` で **idx prefix で区別**。
    機械的には衝突しないが、視認性が低い（提出時に「PI 用」「分担者用」が間違える）。
  - 大文字 part が無い name_en（例: `福山 啓太` のように name_en が `Keita
    FUKUYAMA` 等で揃っていない場合、`parts[-1].lower()`）で fallback。

- **影響**:
  - 提出時の視認性低下。

- **推奨対応**:
  - 同姓衝突時に `betten_01_tanaka_pi.docx` / `betten_02_tanaka_co1.docx` のように
    role suffix を付与するか、`given_family` の order を入れ替えるなど対応。

---

### [N15-08] (Minor) `build.sh check` が inject 適用状態を検査せず

- **箇所**: `scripts/build.sh:301-364`
- **前回対応状況**: 新規
- **内容**:
  - `youshiki1_5_filled.docx` が「inject 後」か「forms のみ」かを区別しない。
  - M14-04 で inject 経路の自動 forms 再実行は導入されたが、`build.sh check`
    自体は marker（`asvg:svgBlob` / `wp:anchor`）の存在を検査しない。

- **影響**:
  - 部分実行ミスで inject 未実行のまま check が「全部緑」を返す可能性。

- **推奨対応**:
  - check に「`unzip -p youshiki1_5_filled.docx word/document.xml | grep -c asvg:svgBlob`
    が期待値（narrative の図数 = 2）と一致するか」を追加。

---

### [N15-09] (Minor) `collab_watcher.sh` が `.env` 必須化で exit 1

- **箇所**: `scripts/collab_watcher.sh:33-43`
- **前回対応状況**: 新規
- **内容**:
  - `.env` が無いと `exit 1` で停止。`.env.example` をコピーして空欄のままでも
    起動はするが、`GCHAT_WEBHOOK_URL=""` が `log_warn` で skip される設計。
  - 提出当日に共同執筆者が予備機で collab_watcher を起動しようとして `.env` 構成
    ミスで起動失敗するリスク。

- **影響**:
  - 共同執筆経路の冗長性低下。

- **推奨対応**:
  - `.env` 不在時は `.env.example` を fallback として読み込み、warn で続行する
    オプションを追加。

---

### [N15-10] (Minor) 様式5 deletion 条件が `lead_institution.type` の typo / 未設定でスキップ

- **箇所**: `main/step02_docx/fill_forms.py:759`
- **前回対応状況**: 新規
- **内容**:
  - `if inst_type in ("大学等", "公的研究機関")` で削除を判定。
  - typo（"大学" / "公的機関" 等）または未設定で削除されず、「該当しない様式5」が
    PDF に含まれたまま提出される。
  - validate_yaml.py の REQUIRED_FIELDS に `lead_institution.type` の必須チェック
    がない（N15-02）。

- **影響**:
  - 提出書類に余分な様式5（法人概要）が混入。
  - 公募要領上「該当時のみ」のセクションが残ると審査員に不要な情報を見せる。

- **推奨対応**:
  - validate_yaml.py に `lead_institution.type` の必須化と enum 検査
    （`["大学等", "公的研究機関", "民間企業", ...]`）を追加。
  - typo 時は build 時点で fail-fast。

---

### [I15-01] (Info) [report14 I14-01 継続] lxml 移行は提出後の中期課題

提出 33 日では新規 dependency 導入のリスクが高すぎる。提出後の継続課題として
継続。

---

### [I15-02] (Info) [report14 I14-02 継続] 細目（wp:docPr 英語名 等）

提出に影響なし。継続。

---

### [I15-03] (Info) `data/original/` の用途未文書化

- **箇所**: `data/original/r08youshiki1_5.pdf` (320 KB)
- **内容**:
  - `data/source/`（テンプレート）と命名類似で混乱を招く。中身は様式 PDF 1 個のみ。
    参照用の元 PDF と推察されるが README / CLAUDE.md に説明なし。
- **推奨対応**:
  - CLAUDE.md に `data/original/` の用途を 1 行追記、または `data/source/` に統合。

---

### [I15-04] (Info) `docs/__archives/` 自体が git 管理外（N15-05 の補足）

レビュー履歴の長期保存方針を確立する必要。

---

### [I15-05] (Info) `docs/start15.md` が untracked

start*.md / report*.md の lifecycle ポリシーが暗黙運用。新規セッション開始時の
start ファイル管理ポリシー（`__archives/` への移動タイミング、git 管理 / 非管理）
が文書化されていない。

---

### [I15-06] (Info) `build.sh validate` が Docker 経由必須

YAML 単体検査で Docker 起動コストが大きい。提出直前に `validate_yaml.py` を高頻度
で走らせたい場面で支障。

- **推奨対応**:
  - validate のみ `python3 scripts/validate_yaml.py` を fallback として許可
    （pyyaml が host に必要だが、提出オペレータは uv で 1 cmd 解決可）。

---

## リスクマトリクス

| リスク | 影響度 | 発生確率 | 総合評価 | 対策 |
|--------|--------|---------|---------|------|
| 別添 (betten) が応募時パッケージに混入し提出書類取り違え | 高 | 高（現状の運用フローに組み込まれている） | Critical | C15-01: create_package.sh のモード分離 |
| PDF 結合運用未確立で提出形式違反 | 高 | 中（最終 1 PDF か個別添付かの判断混乱） | Critical | C15-02: CLAUDE.md 更新 + scripts/merge_pdf.sh 追加 |
| ステイル `betten_03_○○.{docx,pdf}` が提出物に混入 | 高 | 高（現に並存） | Major→Critical 寸前 | M15-01 + M15-04: data/output クリーン + 本番 researcher 確定 |
| 承諾書 placeholder が空欄のまま提出 | 高 | 中 | Major | M15-02: fill_consent_forms 拡充 + pdftotext での残存検査 |
| `delete_sections` が承諾書本文を巻き込んで誤削除 | 高 | 低-中 | Major | M15-05: 段落タイトル全文一致 + 削除範囲の上限設定 |
| `fill_forms.py:894` 変更で 4-2 duplicate が将来 fail | 中 | 低 | Major | M15-03: 変更意図の確認 + revert または `tables["4-2"]._parent` |
| Docker 環境喪失時に uv 経路が再現不能 | 中 | 低 | Major | M15-06: pyproject.toml / uv.lock を commit |
| `.claude/settings.local.json` 誤コミットによる機微情報流出 | 中 | 低 | Minor | N15-03: `.gitignore` に `.claude/` 追加 |
| validate_yaml が type / authorized_signer 未設定を検知できない | 中 | 中 | Minor | N15-02: REQUIRED_FIELDS 拡張 |
| collab_watcher が `.env` 無しで停止し共同執筆経路喪失 | 中 | 低 | Minor | N15-09: `.env.example` fallback 追加 |
| 提出当日に Google Drive / rclone / Windows いずれかの障害 | 高 | 低 | Major（運用） | バックアップ経路の事前確認（手動 docx→PDF 経路の準備） |
| 京大 URA / 会計課の事前承認に時間がかかる | 高 | 中 | Major（運用） | 4/末までに最終 docx を確定し承認プロセスを開始 |
| Critical / Major 全件対応に必要な工数 | — | — | — | C15-01/02 + M15-01〜07 で実装 5-7 日、検証 2-3 日 = 1.5 週間相当 |

---

## 提出日からの逆算スケジュール（提案）

残 33 日（2026-04-17 → 2026-05-20）に対するクリティカルパス:

| 期日 | マイルストーン | 関連指摘 |
|------|---------------|---------|
| 2026-04-20（残 30 日） | C15-01 / C15-02 / N15-03 / M15-06 / N15-04 を解消し、未コミット変更を整理 | C15-01, C15-02, M15-06, N15-03, N15-04 |
| 2026-04-25（残 25 日） | M15-01 / M15-04 を解消、本番 researcher 全員を確定、ステイル削除フローを整備 | M15-01, M15-04 |
| 2026-05-01（残 19 日） | M15-02 / M15-05 を解消、承諾書 fill と delete_sections を実装、pdftotext での placeholder 検出を CI 化 | M15-02, M15-05, N15-01, N15-02 |
| 2026-05-05（残 15 日） | M15-03 を解消、4-2 duplicate を revert または正規化、回帰テスト | M15-03 |
| 2026-05-10（残 10 日） | dry-run 提出（社内提出シミュレーション）、PDF 結合運用の最終確認 | C15-02 |
| 2026-05-13（残 7 日） | 京大 URA / 会計課の事前承認用 PDF 提出 | （運用） |
| 2026-05-17（残 3 日） | 最終 build + roundtrip、placeholder 検査、サイズ・ページ数検査 | （運用） |
| 2026-05-19（残 1 日） | e-Rad 入力、添付、提出 dry-run | （運用） |
| 2026-05-20 12:00 | 提出完了 | — |

提出当日のリカバリ経路（ダウンタイム発生時）:
- Windows 機ダウン: LibreOffice での PDF 化に切り替え（N14-01 修正で narrative も
  LO で開ける）。レイアウトは Windows と差異あるが「とりあえず提出」可能。
- Google Drive ダウン: rclone を介さず手動コピー（USB / メール添付）で Windows 機
  へ docx を渡す。
- Docker ダウン: `RUNNER=uv` で再現。**ただし M15-06 を解消していないと不可**。
- e-Rad 障害: 5/20 12:00 直前に集中するため、5/19 までに添付・送信寸前まで進める。

---

## 総評

### 局所健全性 vs 全体健全性

report14 までは Prompt 10-5 の局所要件（textbox / SVG / Word PDF 化）の健全性に
レビュー軸が集中し、**「順調に見える」状態**で本セッションに引き継がれた。

本レビュー（第15回）では視点を「2026-05-20 提出までに e-Rad に何を上げるか」の
**運用全体**に転じた結果、Critical 2 件 / Major 7 件 / Minor 10 件 / Info 6 件、
計 25 件の新規発見が集中した。これは局所修正が完了した直後にこそ、運用視点で
レビューする価値が大きいことを示している。

### 最も重要な 5 件

1. **C15-01** — 別添を応募時パッケージから分離する。1 commit で解消可能だが
   現状放置。
2. **C15-02** — 様式1-1〜5 + 参考様式の最終 PDF が「youshiki1_5_filled.pdf 1 個で
   完結する」設計なら、CLAUDE.md と create_package.sh のチェックリストを更新して
   明文化する。
3. **M15-01** — `data/output/` を毎回クリーンする。これが解消されないと M15-04
   の本番 placeholder と組み合わさり、提出物に古い研究者の別添が混入する経路が
   開いている。
4. **M15-02** — 承諾書 placeholder の自動 fill を実装する。手動運用は属人化と
   提出当日のミス源。
5. **M15-05** — `delete_sections` の `_find` 誤一致リスクは最も crash potential
   が高い。委託参考様式が誤削除された状態の PDF が提出される最悪シナリオを
   防ぐ必要。

### 提出までの判断

残 33 日で Critical 2 件と Major 7 件（うち M15-06 は 1 commit で解消）を計画的に
解消できれば、5/20 提出は技術的に可能。本セッション以降のレビューサイクルでは、
個別の指摘解消ごとに「diff レベルでの commit」と「dry-run でのフルパス確認」を
セットで実施することを推奨する。

提出後の継続課題（I14-01 lxml 移行、I14-02 細目、I15-03/04/05/06 の運用文書化）は
次年度応募・継続応募の改善 PDCA に組み込めばよい。

---

## 2026-04-18 修正セッション

ユーザ指示「重要度の高いものから順番にステップ・バイ・ステップで修正」に基づき、
Critical / Major / Minor の解消可能な指摘を一括対応した。手作業を伴うもの
（実データ確定、承諾書の機関別 signer 等）は本セッションでは対象外。

### 対応一覧

| ID | 修正箇所 | 変更サマリ |
|----|---------|-----------|
| C15-01 | `scripts/create_package.sh` | `PACKAGE_MODE=submission|interview` 環境変数で分離。submission は様式1-5 + 様式6/7/8 + `submission_merged.pdf` のみ、interview は別紙5 + 別添人数分 + `interview_merged.pdf`。チェックリストとマニュアル確認項目もモード別に再構成 |
| C15-02 | `main/step04_package/merge_pdfs.py` (前セッション完了) + 本セッションで `create_package.sh` のチェックリストに統合 | pypdf 駆動の結合パイプラインが既に整備済み。本セッションで提出形式の運用を package mode に紐付けて確定 |
| M15-01 | `scripts/roundtrip.sh:phase_collect` | 集約前に `data/output/*.{docx,xlsx}` を削除しステイル混入を防ぐ |
| M15-02 | `main/step02_docx/fill_forms.py:fill_consent_forms` | `R8〜R　` 1 種類のみだった置換を 5 系統に拡充: signer 行（代表機関版のみ）/ PI 所属氏名 / 分担者所属氏名（複数結合）/ 課題名 / 代表研究機関名 / 元号年（公募年・実施期間）。consent_type tracker（lead/partner/hojokin）で挙動分岐 |
| M15-03 | `main/step02_docx/fill_forms.py:894` | `DocxTable(new_tbl, doc.element.body)` → `DocxTable(new_tbl, tables["4-2"]._parent)`。`_parent.part` アクセスが正しく解決される |
| M15-04 | `scripts/validate_yaml.py` | placeholder マーカー（○○ / △△ / □□ / XX / ＸＸ）を name_ja / name_en / affiliation / department / position / researcher_id / furigana 各フィールドで検出。dummy E2E 用に `--allow-placeholder` フラグも追加 |
| M15-05 | `main/step02_docx/fill_forms.py:delete_sections` | 補助金参考様式の検出を「`（参考様式` かつ `補助金` を両方含む段落」の厳密一致に変更。削除範囲は次の `（参考様式` / `承諾書` / `（様式` 見出し or `w:sectPr` or チェックリスト位置のうち最も早いものまでに限定。様式5 deletion も同手法で安全化 |
| M15-06 | `pyproject.toml` / `uv.lock` | git 管理対象として最終 commit に含める（pypdf 6.10.2 含む 11 packages） |
| M15-07 | `data/dummy/researchers.yaml` | `□□ □□` co_investigator に「2-co_investigator E2E テスト」「同姓ハンドリング検証」の意図コメントを追加 |
| N15-01 | `scripts/build.sh:do_check` | betten 件数を `researchers.yaml` の PI + co_investigators 合計と照合、`asvg:svgBlob`/`wp:anchor` marker 検査、`submission_merged.pdf` 存在確認を追加 |
| N15-02 | `scripts/validate_yaml.py:REQUIRED_FIELDS` | `lead_institution.type` / `lead_institution.authorized_signer.{name,title}` / `project.period_end` / `pi.{name_en,department,position}` を追加。`INST_TYPE_ENUM` で大学等/公的研究機関/民間企業/その他 の検査も追加（N15-10 同時解消） |
| N15-03 | `.gitignore` | 末尾に `.claude/` を追加（settings.local.json 誤コミット防止） |
| N15-05 | `.gitignore` | `docs/__archives/*` 除外を削除し、レビュー履歴を git 管理に復活 |
| N15-07 | `main/step02_docx/fill_security.py:main` | 同姓衝突を families リストで事前検出、衝突時のみ `_pi` / `_co1` / `_co2` suffix を付与（衝突なしは従来命名維持） |
| N15-08 | `scripts/build.sh:do_check` | `unzip -p` で `youshiki1_5_filled.docx` の inject marker を検査（N15-01 と同時実装） |
| N15-09 | `scripts/collab_watcher.sh` | `.env` 不在時に `.env.example` を fallback として読み込み warn で続行（両方無いときのみ exit 1） |
| N15-10 | （N15-02 と同時解消） | `lead_institution.type` の必須化と enum 検査で typo 即 fail-fast |
| N15-04 | （最終 commit） | 本セッションの全変更を整理し履歴化。M15-06 の `pyproject.toml`/`uv.lock` も同 commit に含める |
| N15-06 | （M15-01 と連動） | `data/output/` クリーンで expected_pdfs ズレが解消 |

### 動作確認

- **bash / python syntax**: build.sh / roundtrip.sh / create_package.sh / collab_watcher.sh /
  fill_forms.py / fill_security.py / validate_yaml.py すべて syntax OK
- **dummy E2E (Docker)**: validate / forms / narrative / inject / security / excel 全 6
  ステップ ✓ OK。betten 3 件（PI + co 2 名）を正常生成
- **main validate (uv)**: placeholder 検出が想定通り発火（pi.researcher_id 等 7 件
  ERROR） — M15-04 の検出機構が機能している証拠
- **dummy validate (uv)**: `--allow-placeholder` 自動付与により ✓ OK
- **build.sh check**: 11 ファイル ✓、betten 件数照合 ✓、inject marker (count=5) ✓、
  submission_merged.pdf ✓
- **merge submission (uv)**: 29 ページ / 1.13 MB / metadata 4 項目埋め込み確認
- **create_package submission**: 5 ファイル（様式1-5 + 様式6/7/8 + 結合PDF）、
  betten/別紙5 を **正しく除外**
- **create_package interview**: 4 ファイル（別紙5 + betten 3 件）、様式1-5/6/7/8 を
  **正しく除外**

### 残課題（提出までに要手作業）

| ID | 内容 | 期限目安 |
|----|------|---------|
| M15-04 (実データ部分) | `main/00_setup/researchers.yaml` の co_investigators[1] = `○○ ○○` placeholder を実研究者で置換。`pi.researcher_id` 等の `○○○○○○○○` 値も実 ID に置換 | 2026-04-25 |
| M15-02 (機関別 signer) | 分担研究機関版承諾書の signer 行は機関ごとに異なるため手動入力 | 提出前最終 PDF 確認時 |
| 提出運用 | 京大 URA / 会計課の事前承認、e-Rad アカウント・添付準備 | 2026-05-13 |
| Windows 結合 PDF 取得 | `roundtrip.sh` Phase 5 の push back 経路を実地検証（gdrive `merged/` フォルダ → Windows 同期） | 提出前 dry-run 時 |

### Info 系の継続扱い

I15-01〜06 は提出後の改善 PDCA に組み込む。本セッション完了時点で残課題の総工数は
実データ確定（数時間）＋ 提出運用（社内承認の調整）のみで、コード起因の追加実装は
発生しない見込み。
