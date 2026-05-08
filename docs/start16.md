# セッション開始プロンプト: 第16回 — 共同研究者レビュー指摘 8 件 + 履歴書/エフォート反映

以下の指示に従い、**共同研究者からの指摘事項 8 件への対応、および新規受領した
履歴書 / エフォート資料の反映**を実装してください。

## 全体方針

- **本セッションは実装タスクです**（前回まではレビュー中心）。指摘ごとに
  ファイルを編集し、最後に `./scripts/roundtrip.sh` で PDF まで生成して目視確認。
- **レビュー結果ではなく実装変更を出力します。** 各指摘について、変更ファイル・
  変更理由・確認方法を簡潔にまとめながら進めてください。
- **本文の論旨・科学的妥当性は基本的に維持**してください（指摘 #6 の物流追加のみ
  論旨に手を入れます）。
- **データソース（`data/source/*.docx`）は読み取り専用**を維持し、編集は必ず
  `fill_*.py` または `inject_*.py` 経由で行ってください。
- **ホスト Python を汚さない**: Docker または uv 経由で実行（メモリ参照）。
- **京大の性質上「有事」表現は避ける**（メモリ参照）。

## プロジェクト前提（要約）

**プロジェクト**: med-resist-grant（薬剤耐性研究 科研費申請書類作成システム）
**応募先**: 防衛装備庁 安全保障技術研究推進制度（ATLA）、Type A 想定（年間最大5,200万円、最大3年）
**研究テーマ**: (23) 医療・医工学に関する基礎研究（サイバー攻撃×地域医療シミュレーション）
**提出期限**: 2026年5月20日(水) 正午（e-Rad 経由）
**作業ベースブランチ**: `main`

ビルドは `./scripts/build.sh` の 6 ステップ（validate / forms / narrative / inject /
security / excel / merge）。PDF 化は Windows 側 `watch-and-convert.ps1`（Word COM）に
docx を Google Drive 経由で渡す → `./scripts/roundtrip.sh` で一括ラウンドトリップ。

詳細は `CLAUDE.md` を参照。

## 前セッション（第15回終了後 〜 本セッション開始時点）での主な変化

**直前セッションで実施した変更**:
1. `main/step01_narrative/youshiki1_2.md`
   - 旧 `bg_hospital.jpg` を `figs/画像1.svg`（基盤インフラへのサイバー攻撃概念図）に置換
   - §2 本研究の目的の末尾に `figs/画像2.svg`（連鎖影響＋地域スケールの2軸）を新規挿入
   - 旧 `fig1_overview.svg` を `figs/画像3.svg`（開発システム概念図）に置換
   - textbox 高さを画像アスペクト比に合わせ調整: 画像1 80→115mm、画像2 100→95mm、画像3 70→115mm
   - キャプションを実質的な図説明文に差し替え（fig:hospital / fig:purpose / fig:overview）
2. `templates/reference.docx`
   - `Caption` スタイルの `<w:i/>` を `<w:i w:val="0"/>` 化 → 全キャプション非斜体
   - バックアップ `templates/reference.docx.bak` 保存済
3. roundtrip まで通し、`data/products/submission_merged.pdf` (38p, 1.6MB) で図表表示確認済

**未コミット**: 上記変更 + `figs/画像1〜3.svg`（新規追加）+ その他 untracked ファイル群。
セッション冒頭で `git status` を必ず確認すること。

## 対応すべき指摘事項

### 指摘 #1: 様式5 および参考様式（委託費・代表研究機関）が出力に含まれない

- **症状**: `data/products/submission_merged.pdf` または `youshiki1_5_filled.pdf` に
  様式5（法人概要）・参考様式（承諾書・委託費・代表研究機関版）のページが見当たらない。
- **想定原因**:
  - `data/source/r08youshiki1_5.docx` には全様式が含まれているはずだが、`fill_forms.py`
    で「未記入様式の自動削除」ロジックが過剰削除している可能性
  - Type A の場合は補助金版承諾書のみ削除すべきところ、委託・代表機関版まで削除している可能性
- **調査開始ポイント**:
  - `main/step02_docx/fill_forms.py` の様式削除条件
  - `main/00_setup/researchers.yaml` で代表機関の判定（京都大学が代表機関）
  - `data/source/r08youshiki1_5.docx` を unzip → `document.xml` で「様式5」「承諾書」セクションを grep
- **完了条件**: 結合 PDF に様式5（該当時のみ／空でも残す方針なら空欄ページ）と参考様式（委託・代表機関版）が含まれること。Type A では補助金版承諾書のみ削除。

### 指摘 #2: 様式1-2 のフォントが明朝体（規約上問題ないか）

- **症状**: `templates/reference.docx` の Normal/BodyText が `MS Mincho`（ＭＳ 明朝）。
- **対応**:
  1. `data/source/募集要項.pdf` の書式指定（フォント・サイズ・余白）該当ページを確認
  2. ATLA 規約が「ゴシック体 10.5pt 以上」等を要求している場合、`templates/reference.docx`
     の Normal / BodyText / Heading 系 rPr を `MS Gothic` 系に修正
  3. 既存の Heading は `MS Gothic` になっているので、本文のみ要変更
- **完了条件**: 募集要項の書式指定に準拠 + 共同研究者の指摘解消。
- **注意**: reference.docx を編集すると narrative 全体に影響。バックアップ取得 + 全体 visual 確認必須。

### 指摘 #3: 様式2-2 のフォント（ゴシック望ましい）+ セル内記載幅が極めて小さい

- **症状**:
  - 様式2-2（研究費計画書）のセル内テキストが明朝体になっている
  - セル内の表示幅が狭く、テキストが極端に折り返されている
- **調査開始ポイント**:
  - `main/step02_docx/fill_forms.py` の様式2-2 処理ロジック
  - セル幅は OOXML の `<w:tcW>` または `<w:tcMar>` 系設定の問題
  - フォントは run の `<w:rPr>` で個別指定が必要（reference.docx の影響を受けない可能性）
- **完了条件**: 様式2-2 のセル内が MS ゴシック表示 + テキストが読みやすい幅で折り返される。

### 指摘 #4: 物品費にメーカー記載（DELL 想定）

- **症状**: 物品費の品目記載がメーカー無しで漠然としている。
- **対応**:
  - `main/00_setup/config.yaml` または別の budget 用 YAML（`other_funding.yaml` か budget セクション）に DELL 等のメーカー名を入れる
  - 現状の物品費入力経路を確認（`fill_forms.py` から該当セクションを辿る）
- **完了条件**: 様式2-1 / 2-2 の物品費欄に「DELL ワークステーション」等のメーカー付き記載が反映。

### 指摘 #5: 様式への日付記載がない（20260510 で統一）

- **症状**: 各様式の日付欄（「令和　年　月　日」のような空白）が埋まっていない。
- **対応**:
  - `main/00_setup/config.yaml` に `submission_date: 2026-05-10` を追加（既にあれば値確認）
  - `fill_forms.py` で全様式の日付プレースホルダにこの日付を展開
  - 和暦表現（令和8年5月10日）と西暦の使い分けを規約で確認
- **完了条件**: 様式1-1, 2-1, 2-2, 3-1, 3-2, 4-1, 4-2, 5, 参考様式すべての日付欄に 2026-05-10（または令和8年5月10日）が入る。

### 指摘 #6: 障害を受けるインフラに「物流」を追加して論旨を修正

- **症状**: 現状は「電力・通信・交通・水道」をインフラ列挙の典型例としている。共同研究者から「物流」も含めるべきと指摘。
- **対応**:
  - `main/step01_narrative/youshiki1_2.md` のインフラ列挙箇所を全て「電力・通信・交通・水道・**物流**等」に統一
  - 該当箇所（grep で "電力・通信" や "電力、通信" を全件検出）:
    - §1 背景 (line 49 周辺): 「電力、ガス、通信、交通、水道等」→「電力、ガス、通信、交通、水道、物流等」
    - §2 目的 (line 79 周辺): 「電力、通信、交通、水道等」→「電力、通信、交通、水道、物流等」
    - §3 要素課題2 (line 117 周辺): 「電力・通信・交通・水道等」
    - §4 実施項目2 (line 144 周辺): 「電力、通信、交通、水道等」
    - §6 実施項目2 R8 (line 260 周辺): 「電力・通信・交通・水道等」
    - 概要図キャプション (line 360 周辺) も該当
  - 「物流」追加に伴う論旨補強: 物流障害が医療に与える影響（医薬品・医療機器・血液製剤の供給途絶等）を §1 背景 または §3 要素課題2 に短く加筆
  - `main/step01_narrative/figs/画像1.svg` / `画像2.svg` のラベルにも「物流」相当のアイコン追加が必要かは要検討（時間がなければ本文修正のみで対応）
- **完了条件**: 全インフラ列挙箇所に「物流」が含まれ、論旨に整合した加筆がある。

### 指摘 #7: 本文に `[@fig:schedule]` がそのまま出力されている

- **症状**: §6 研究実施計画 (line 244): 「全体像を [@fig:schedule] に Gantt 図で示す。」
  → PDF 出力時に `[@fig:schedule]` が文字列のまま表示。本来は `図3` 等に展開されるべき。
- **想定原因**:
  - Pandoc の cross-reference は `pandoc-crossref` フィルタを通さないと展開されない
  - `main/step02_docx/build_narrative.sh` で `--filter pandoc-crossref` が指定されていない可能性
  - Docker python image (`docker/python/Dockerfile`) に pandoc-crossref がインストールされていない可能性
- **調査開始ポイント**:
  - `main/step02_docx/build_narrative.sh` の pandoc コマンドライン
  - `docker/python/Dockerfile` のインストール内容
  - 同様の参照は `[@fig:hospital]`, `[@fig:purpose]`, `[@fig:overview]`, `[@fig:structure]` も該当する可能性
- **対応案**:
  1. pandoc-crossref を Docker image に追加 + `--filter pandoc-crossref` を pandoc 呼び出しに追加
  2. または、本文の `[@fig:schedule]` を「下図」「Gantt 図」等の自然言語表現に置き換え（後退対応）
- **完了条件**: 結合 PDF 上で `[@fig:...]` 形式の生テキストが残っていないこと。

### 指摘 #8: fig3_schedule.svg / fig2_structure.svg がピンボケ気味

- **症状**: §6 の Gantt 図、§8 の概要図がぼやけて見える。`画像1〜3.svg` と比較してコントラスト・解像度が劣る。
- **想定原因**:
  - mermaid → svg → png（ラスタライズ）→ docx embed の経路で png 解像度が低い
  - または primary に PNG が、secondary に SVG が embed され、Word が PNG を表示している
  - `画像1〜3.svg` はベクタのまま native embed されているため鮮明
- **調査開始ポイント**:
  - `main/step01_narrative/figs/build_fig1_overview.py` と mermaid ビルド経路
  - `wrap_textbox.py` の SVG native embed ロジック（`embed_svg_native` 関数）が `画像1〜3` には適用されているが `fig2/3` には適用されていない可能性
  - 画像1〜3 と fig2/3 の embed 方式の差分を比較（unzip → media/ 内のファイル形式・docPr 構造）
- **対応案**:
  1. `fig2_structure.svg` / `fig3_schedule.svg` も `画像1〜3` と同じ native SVG embed 経路に統一
  2. もし PNG ラスタが必要な場合は 300dpi 以上で生成し直す
- **完了条件**: 結合 PDF の §6 Gantt 図・§8 概要図が `画像1〜3` 並みの鮮明さで表示される。

## 追加資料の取り込み

### 履歴書（refs/3.履歴書様式（教員、特定研究員）_fk.doc）

- **目的**: 様式4-1（代表者調書）の福山欄を実データ化
- **対応**:
  1. `.doc` を Word で開ける環境または LibreOffice / `antiword` で内容抽出
  2. 学歴・職歴・主要業績・受賞歴・所属学会等を `main/00_setup/researchers.yaml` の福山セクションに反映
  3. `fill_forms.py` の様式4-1 処理が拾える形式に整える（既存スキーマ要確認）
- **注意**: `.doc`（バイナリ Word 97-2003 形式）なので、Read tool では直接読めない。
  Docker 内で `libreoffice --headless --convert-to docx` で `.docx` 化してから Python で処理。

### エフォート資料（refs/effort_fk.pdf）

- **目的**: 福山のエフォート 40% の根拠確認 + 様式3-1（他制度応募状況・代表者）の整合性確認
- **対応**:
  1. PDF 内容を確認（Read tool で直接読み込み可能）
  2. `main/00_setup/researchers.yaml` の福山 effort と整合
  3. 他制度との重複（合計 100% 超過していないか）を `other_funding.yaml` と照合

## 推奨される実装順序

ビルドパイプラインに関わる修正を先に解決すると、以降の content 修正が 1 回の roundtrip で
全て反映できて効率的。

1. **#7 (pandoc-crossref) と #8 (svg 鮮明化)** — ビルド系。最初に解決
2. **#5 (日付統一)** — config.yaml + fill_forms.py、影響範囲広い
3. **#1 (様式5・参考様式の出力漏れ)** — fill_forms.py の削除ロジック
4. **#3 (様式2-2 ゴシック・セル幅)** — fill_forms.py
5. **#4 (物品費メーカー)** — config.yaml
6. **#2 (様式1-2 フォント)** — reference.docx（規約確認後）
7. **#6 (物流追加)** — youshiki1_2.md 本文修正
8. **履歴書 + エフォート反映** — researchers.yaml への転記
9. **最終 roundtrip** — `./scripts/roundtrip.sh` で PDF 化、目視確認、submission_merged.pdf 検証

各ステップで `./scripts/build.sh check` または該当サブコマンドのみで早期検証することを推奨。

## 着手前に確認すべきファイル

| ファイル | 確認ポイント |
|---|---|
| `CLAUDE.md` | プロジェクト全体方針、提出書類一覧、ビルド手順 |
| `data/source/募集要項.pdf` | 書式指定（#2 #3 のフォント規約）、様式5 / 参考様式の取り扱い |
| `main/step01_narrative/youshiki1_2.md` | 図参照(#7)、インフラ列挙(#6)、前セッション変更箇所 |
| `main/step02_docx/fill_forms.py` | #1 / #3 / #4 / #5 のすべて関係 |
| `main/step02_docx/build_narrative.sh` | #7 pandoc-crossref フィルタ |
| `main/step02_docx/wrap_textbox.py` | #8 SVG native embed の経路差分 |
| `main/step01_narrative/figs/build_fig1_overview.py` | #8 mermaid ビルド経路 |
| `templates/reference.docx` | #2 フォント変更（前セッションで Caption 斜体除去済み） |
| `main/00_setup/config.yaml` | #4 #5 設定追加 |
| `main/00_setup/researchers.yaml` | 履歴書・エフォート反映先 |
| `docker/python/Dockerfile` | #7 pandoc-crossref 追加候補 |
| `refs/3.履歴書様式（教員、特定研究員）_fk.doc` | 履歴書（要 LibreOffice 変換） |
| `refs/effort_fk.pdf` | エフォート資料 |
| `data/products/submission_merged.pdf` | 前セッション最終出力（38p, 1.6MB）。比較ベースライン |

## 完了基準

- 8 件の指摘すべてに対し、変更内容と確認方法をまとめて報告
- `./scripts/roundtrip.sh` 完走（Phase 1 ビルド〜Phase 5 結合 PDF まで）
- `data/products/submission_merged.pdf` で全指摘箇所の改善を目視確認
- 履歴書・エフォート資料の反映箇所を `researchers.yaml` の diff で確認
- 未コミットの変更について、論理的に分割可能なコミット単位を提案（コミットは
  ユーザの明示的指示があるまで作成しないこと）

## 注意事項

- **commit / push は明示指示まで実行しない**（前セッション継続のスタイル）
- **Windows 機の watch-and-convert.ps1 が稼働していること**を Phase 4 突入前に確認
- **roundtrip 中の Google Drive 共有領域** (`gdrive:tmp/med-resist-grant/`) は他者と
  競合する可能性があるため、長時間放置しない
- **submission_date: 2026-05-10** はあくまで様式記載日。e-Rad 提出期限 2026-05-20 とは別
- **「有事」表現は使用しない**（京大の性質上、メモリ参照）。「サイバー攻撃時」「インフラ障害時」等の中立表現を使用
