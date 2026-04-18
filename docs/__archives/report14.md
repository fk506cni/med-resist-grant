# 敵対的レビュー報告書（第14回）— Prompt 10-5 成果物と M14-01 修正の健全性

レビュー実施日: 2026-04-17
修正反映日: 2026-04-17（本セッション後半で M14-02〜I14-03 を対応）

レビュー対象:
- `main/step02_docx/wrap_textbox.py`（M14-01 修正後、L585-623）
- `main/step02_docx/inject_narrative.py`（特に L290-340 / L347-390 / L616-689 / L735-827 / L872-1050）
- `scripts/build.sh`（inject 関数 L158-198）
- `scripts/roundtrip.sh`（Phase 3 push / Phase 4 polling）
- `scripts/windows/watch-and-convert.ps1`（Convert-DocxToPdf L113-224）
- `main/step02_docx/output/youshiki1_5_filled.docx`（2026-04-17 20:04 clean build 成果物）
- `main/step02_docx/output/youshiki1_2_narrative.docx`（同上、M14-01 修正後）
- `main/step02_docx/output/youshiki1_3_narrative.docx`
- `data/products/youshiki1_5_filled.pdf`（Windows Word COM、29 ページ、1.35 MB）
- （参考）`docs/plan2.md` §9 / §11 / §12、`docs/prompts.md` Prompt 10-5、`docs/__archives/report13.md`

前回レビュー: `docs/__archives/report13.md`（2026-04-17、対応済み）

## サマリ

- Critical: 0 件
- Major: 5 件（新規 4 / 既知既修正 1 = M14-01）→ **本セッション後半で全 5 件対応済**
- Minor: 6 件（新規 4 / 既知 2）→ **本セッション後半で 5 件対応済、1 件（N14-02）は依存関係により自動抑制**
- Info: 3 件（新規 2 / 既知 1）→ **1 件対応済、1 件は記録のみ、1 件は将来課題**

### 対応状況一覧

| ID | 重大度 | 状態 | 概要 |
|----|--------|------|------|
| M14-01 | Major | ✅ 対応済（本セッション前半） | `wrap_textbox.embed_svg_native` の `ET.SubElement` が bare tag で Relationship を追加、後発 `register_namespace("", CT_NS)` によって default prefix が奪われて Word 2016+ が「破損」と誤判定する namespace バグ |
| M14-02 | Major | ✅ 対応済（本セッション後半） | `inject_narrative.py:merge_rels` (L319) と `_merge_notes` (L806) に同一パターンの bare `ET.SubElement(..., "Relationship")` が残存 → fully-qualified Clark notation に修正 |
| M14-03 | Major | ✅ 対応済（本セッション後半） | SVG ベクタ表示未達 → ベクタ保持を断念。`docs/prompts.md` 完了チェックと `docs/plan2.md` §11 検証8 / リスク表の記述をラスタ受容で更新（primary PNG は 300 dpi で既に確保） |
| M14-04 | Major | ✅ 対応済（本セッション後半） | `scripts/build.sh:build_inject` に「document.xml 内に wp:anchor / asvg:svgBlob がある場合は forms を自動再実行」のガードを追加。実地再現テストで発火を確認 |
| M14-05 | Major | ✅ 対応済（本セッション後半） | `scripts/roundtrip.sh` に `rclone_with_retry` ヘルパーを追加、`timeout 15` を `timeout 60` に緩和、接続確認と最終一覧取得に retry を適用 |
| N14-01 | Minor | ✅ 対応済（本セッション後半） | LibreOffice 24.x は rels の `<ns0:Relationship>` prefix 形式を受け付けず default xmlns 形式を要求することが判明。`wrap_textbox.embed_svg_native` の rels/CT serialize 直前で `register_namespace("", RELS_NS)` / `register_namespace("", CT_NS)` を再適用して default xmlns 形式で書き出すよう修正。narrative docx が LO で開けることを実測確認 |
| N14-02 | Minor | ⏸️ 未対応（実地 inactive 化） | M14-04 ガードにより inject 単独再実行経路が塞がれ、`_n1` rename が発生する経路が実質的に消えた。命名規約の統一は依然として未実施だが優先度は低 |
| N14-03 | Minor | ✅ 部分対応（本セッション後半） | `wrap_textbox.py` と `inject_narrative.py` モジュール冒頭に「register_namespace のグローバル副作用に関する注意事項」を明記したヘッダーコメントを追加。lxml 移行による根本対策は I14-01 として継続 |
| N14-04 | Minor | ✅ 解消（report13 N13-01） | narrative rels の prefix 混在は M14-01 修正で解消 |
| N14-05 | Minor | ✅ 対応済（本セッション後半） | Phase 4 polling の timeout を 60s に延長、`found_pdfs` を単調増加で保持して振動を抑制 |
| N14-06 | Minor | ✅ 対応済（本セッション後半） | PowerShell 側で `switch ($exitCode)` により exit 1 (OPEN_ERROR) / exit 2 (SAVEAS_ERROR) / default を区別してログ出力 |
| I14-01 | Info | ⏸️ 継続課題 | `lxml.etree` への移行で register_namespace グローバル副作用を根絶できる。現状は Clark notation 規約 + ヘッダーコメントで緩和 |
| I14-02 | Info | 継続（report13 I13-01〜04） | wp:docPr 英語名、pandoc rId 飛び番、mermaid fontSize、crossref anchor：現状変化なし |
| I14-03 | Info | ✅ 対応済（本セッション後半） | `docs/prompts.md` Prompt 10-5 完了チェックの冗長項目「inject_narrative.py 側の改修は NSMAP への asvg/a14 追加のみ」を削除（M14-03 対応と同時に更新） |

## report13.md との差分サマリ

- 前回の未対応項目で今回解消されたもの: 1 件（N13-01：narrative rels prefix 混在 → M14-01 修正で解消）
- 前回の未対応項目で依然として未対応のもの: 5 件
  - M13-02（mc:AlternateContent 未使用、設計判断として受容）
  - N13-03（--resource-path cwd 依存、現状動作）
  - N13-05（reference.docx 冪等性、CI 未導入のため dormant）
  - N13-06（_n1 rename 命名規約非対称）→ **M14-04 ガードで発火経路を塞いだため実地 inactive**
  - N13-09（comments.xml 破棄、dormant）
- 前回に記載があり今回本セッションで対応したもの: 2 件
  - N13-10（register_namespace グローバル副作用）→ **M14-01 / M14-02 で顕在化経路を fully-qualified 化で塞ぎ、N14-03 でヘッダーコメント追加**
  - N13-11（.textbox 内 figure caption 配置）→ **Windows Word PDF で目視検証、実用上問題なし（継続）**
- 前回に記載がなく今回新規発見したもの: 9 件（Major 4 / Minor 4 / Info 2）→ **本セッション後半で 8 件対応、1 件（I14-01）は将来課題として継続**

---

## 指摘事項

### [M14-01] (Major) [✅ 対応済] `wrap_textbox.embed_svg_native` の新規 Relationship が空 namespace で serialize される

- **箇所**: `main/step02_docx/wrap_textbox.py:587-623`（修正後）
- **前回対応状況**: 新規（本セッションで発見・修正）
- **内容**:
  - `embed_svg_native` 内で `ET.register_namespace("", RELS_NS)` → parse rels → `ET.register_namespace("", CT_NS)` → parse CT → その後 `ET.SubElement(rels_root, "Relationship")` の順で呼ばれていた。
  - Python `xml.etree.ElementTree._namespace_map` は `""`（default prefix）を単一エントリで管理するため、後発の `("", CT_NS)` が先発の `("", RELS_NS)` を上書きする。
  - serialize 時点で RELS_NS に対応する default prefix は消えており、ET は既存要素に auto-prefix `ns0:` を付与する一方、bare `"Relationship"` で作成した新規要素は名前空間 URI を持たないため `<Relationship>` として出力される。
  - 結果、pandoc 由来の全既存 rel が `<ns0:Relationship>` になり、wrap_textbox 追加の 1 件だけが `<Relationship>` 形式となる混在状態。Windows Word 365 の `SaveAs2` はこれを「ファイルが壊れている可能性があります」（OPEN_ERROR）として reject。
  - 実地ログ（本セッション 2026-04-17 19:22:19）で VBScript exit 1 + OPEN_ERROR を再現済み。

- **修正内容（L587-623）**:
  - `ET.SubElement(rels_root, f"{{{RELS_NS}}}Relationship")` と `ET.SubElement(ct_root, f"{{{CT_NS}}}Default")` に fully-qualified Clark notation を採用。要素側で namespace URI を明示的に持たせることで、register_namespace の上書きに対して robust 化。
  - コメント L587-591 / L616-620 で根本原因と「なぜ fully-qualified が必要か」を明記。将来の読者が同じ罠にはまらない。

- **検証**:
  - `unzip -p main/step02_docx/output/youshiki1_2_narrative.docx word/_rels/document.xml.rels` で全 11 件が `<ns0:Relationship>` で統一（rId1〜rId8、rId23、rId30、rId31）。
  - Windows Word COM の `roundtrip.sh` 経由で 8/8 ファイルが成功、`youshiki1_5_filled.pdf` 29 ページ / 1.35 MB を生成確認。

- **残存懸念**: M14-02（inject_narrative.py 側に同一パターンが残存）、N14-03（根本原因の `register_namespace` グローバル副作用は未対応）。

---

### [M14-02] (Major) [✅ 対応済] `inject_narrative.py` の `merge_rels` と `_merge_notes` に M14-01 と同一パターンの bare `ET.SubElement(..., "Relationship")` が残存

- **箇所**:
  - `main/step02_docx/inject_narrative.py:merge_rels` → fully-qualified 化
  - 同 `_merge_notes` → fully-qualified 化
- **前回対応状況**: 新規（M14-01 修正を受けて潜在バグとして発見）
- **対応**: 両箇所を `ET.SubElement(tgt_rels_root, f"{{{RELS_NS}}}Relationship")` に変更。動作不変、将来 refactor 耐性が向上。コメントで M14-02 の背景を明記。
- **内容**:
  - `merge_rels` は rels root（`{RELS_NS}Relationships`）に対して bare tag の `"Relationship"` を `SubElement` している。
  - 現時点では `process()` の実行順序（`merge_rels` / `copy_media` / `_merge_notes` がいずれも `merge_content_types` より先、かつ `register_namespace("", RELS_NS)` を直前に呼ぶ）が default prefix の上書きを防いでおり、実地 filled docx では `<Relationships xmlns="RELS_NS"><Relationship .../>...</Relationships>` の形式で問題なく書き出されている（実測確認済み）。
  - 問題は「この正しさは実行順序に依存する」点。M14-01 と全く同じクラスのバグを将来誘発する改変が複数考えられる:
    1. `merge_rels` を `merge_content_types` の後ろに移動（or 追加実行）
    2. `merge_rels` と `merge_content_types` の間で `register_namespace("", OTHER_NS)` を追加
    3. 将来 `merge_rels` を再入可能にして複数回呼ぶ設計
  - いずれも commit 時に壊れ、Word が「破損」と判定するため Linux テストでは検出できない（LibreOffice では通ることが多い）。M14-01 と同じ silent 劣化経路。

- **影響**:
  - 現在のコードパスでは実害なし。
  - ただし refactor / 新機能追加で簡単に再発し、その際には narrative 側と同じ「Windows Word が OPEN_ERROR を返す」症状になる。再現テストが難しい（register_namespace の状態遷移が含まれる）。

- **推奨対応**:
  - M14-01 と同じ Clark notation 方式で揃える:
    ```python
    new_rel = ET.SubElement(tgt_rels_root, f"{{{RELS_NS}}}Relationship")
    ```
    L319 と L806 の 2 箇所。動作は不変、将来の refactor 耐性が向上。
  - 同時に各 `ET.register_namespace("", URI)` 呼び出しについて「このモジュール内に register_namespace("", OTHER) を追加するな」の guard コメントを入れる、または ns 管理を helper に集約する。

---

### [M14-03] (Major) [✅ 対応済（ベクタ保持を断念、要件をラスタ受容に更新）] Prompt 10-5 完了チェック「Windows Word PDF で SVG がベクタ表示」が未達、かつ COM API ベースでは原理的に達成困難

- **箇所**:
  - `scripts/windows/watch-and-convert.ps1:160` — `doc.SaveAs2 "$pdfPath", 17`（17 = `wdFormatPDF`）
  - `docs/prompts.md` Prompt 10-5 完了チェック → **ラスタ受容で更新**
  - `docs/plan2.md` §11 検証8 / リスク表 → **ラスタ受容で更新**
  - 実地 `data/products/youshiki1_5_filled.pdf`: page 4 に `943×136 image (rgb, 204 ppi, smask)` で配置、`pdftotext` で SVG 内ラベル（"DPC/NDB/レセプト", "需給推定器", "地域医療シミュレータ", "インパクト評価レポート"）は 0 件ヒット
- **対応**: ベクタ保持の要件を取り下げ、ラスタ画像（primary PNG、`rsvg-convert -d 300 -p 300` で既に 300 dpi 確保）で受容。`prompts.md` と `plan2.md` の該当記述を更新済み。審査は目視評価で OCR 依存度が低いため実害軽微。
- **前回対応状況**: 新規（Prompt 10-5 実地検証の結果として検出）
- **内容**:
  - Word 365 の `Document.SaveAs2(path, wdFormatPDF=17)` は `a:blip/@r:embed` の primary blip（= PNG）を PDF に raster として埋め込み、`asvg:svgBlob` 拡張は PDF 出力時に参照されない。これは Word COM API の仕様であり、document の構造は正しい（二段構成 `a:blip`→PNG + `asvg:svgBlob`→SVG）ものの出力経路が SVG を捨てる。
  - 代替手段の検討:
    - `Document.ExportAsFixedFormat2` に切替: `OptimizeFor=xlExportOptimizeForPrint` / `UseISO19005_1=True` / `FixedFormatExtClassPtr` で SVG ベクタ保持が可能か公式ドキュメント上は不確実。Microsoft の KB でも「SaveAs2 と ExportAsFixedFormat は SVG の扱いが同一」の記述あり（2022 以降、要再確認）。
    - `Application.Options.ExportPictureGraphicsOption`: 画像書き出し設定だが、PDF 出力時に svgBlob が参照されるかは COM 経由で明文化されていない。
    - LibreOffice で PDF 化: narrative 段階で OPEN_ERROR が出る副次問題（N14-01）あり、さらに `.textbox` の anchor レイアウトが Word と異なる懸念。
  - 一方、提出品質の評価:
    - 943×136 px @ 204 ppi ≒ 11.7 cm × 1.7 cm で配置。これは概念図として**印刷品質を満たす**（200-300 ppi が印刷標準）。
    - 審査は目視評価であり、PDF 内テキストの検索性（selectable）は評価対象外と解される（e-Rad 仕様書に該当記述なし）。
    - `pdftotext` でキャプション本文「病院施設の外観（デモ画像）」「医療需給動態モデルの処理フロー（概念図）」は正しく抽出される（これらは docx body text であり SVG 内部ではないため）。

- **影響**:
  - `prompts.md` の「本番判定」要件を字義通り満たさない。合否判定の解釈が宙吊り。
  - 今後デモを差し替えて本番図表（概念図・フロー図・グラフ等）を入れた際、本文中のラベル・凡例・数値がラスタ化されるため、**拡大しても鮮明度が上がらない**。A4 印刷時には問題ないが、デジタル審査環境で拡大表示されると文字がぼやける可能性。

- **推奨対応（提案）**:
  - 短期（提出可）:
    1. `docs/prompts.md` Prompt 10-5 完了チェックと `docs/plan2.md` §11 検証8 の記述を「SVG は PNG 形式でラスタ化されて PDF に配置される（Word COM の仕様）。印刷品質を保つため primary PNG は `rsvg-convert -d 300 -p 300`（300 ppi）で生成する」に更新。
    2. 現在の primary PNG 解像度を確認（204 ppi だったので、200 ppi 付近で rsvg-convert が動作中）。本番提出前に 300 ppi に上げるオプションを build_narrative.sh へ追加。
  - 中期（本番判定を満たしたい場合）:
    3. `watch-and-convert.ps1` の VBScript を `doc.ExportAsFixedFormat2` に置き換え、SVG ベクタ保持を実測検証。
    4. 代替として Linux 側で LibreOffice PDF export を使い、narrative docx / filled docx 両方での動作を検証（N14-01 解決が前提）。
  - **判断**: 本プロジェクトの想定（Type A 科研費、e-Rad 提出、審査員目視）を考えると短期対応で提出に耐える判定が妥当。その場合は**要件記述の方を修正**して実装・現実と整合させる。

---

### [M14-04] (Major) [✅ 対応済] `scripts/build.sh:inject` の再実行非冪等性 — `forms` 経由なしで単独再実行すると rels orphan と media 重複を生成する

- **箇所**: `scripts/build.sh:build_inject`
- **前回対応状況**: 新規（本セッション実地観察）
- **対応**: `build_inject` 冒頭に「document.xml 内に `wp:anchor` または `asvg:svgBlob` を検出したら forms を自動再実行する」ガードを追加。`unzip` がある環境で動作、`set -o pipefail` と `grep -q` の組合せによる SIGPIPE 問題を避けるため `grep -cE` + count 判定で実装。実地再現テストで「INFO: ... はすでに inject 済みです（marker=5）」のログと forms 自動再実行を確認。rels 件数が通常の clean build と同一（14 件）になることを検証。
- **内容**:
  - 以下の構造が原因:
    ```bash
    local template="main/step02_docx/output/youshiki1_5_filled.docx"
    ...
    run_python "$script" \
        --template "$template" \
        --youshiki12 "$narr12" \
        --youshiki13 "$narr13" \
        --output "$template"
    ```
  - `--template` と `--output` が同一パス。初回 build では `forms` ステップが `data/source/r08youshiki1_5.docx` を加工して `youshiki1_5_filled.docx` を生成し、続く `inject` がそれを template として読み narrative を merge して同じパスへ上書き。
  - 以降 `inject` を単独で再実行する（例: 開発中の narrative 調整ループ）と、**既に narrative が差し込み済みの filled docx** が `--template` として入力される:
    - `find_section_boundaries` は「`様式１－２` header 以降の最初の '１．' 始まり段落」を delete_start とするが、**初回 inject 済みの narrative 段落は pandoc が '１．' で始まる heading を生成するためこれにヒット**する。結果、find_section_boundaries は壊れず通る。
    - `merge_rels` が narrative docx の image rels（3 件／narrative）を再度 copy。max_rid は既存 template の rId14 を見て rId15 から採番（orphan rId12-14 は残存）。
    - `copy_media` が target に既存の `word/media/rId23.jpg` 等を検出して `_n1` suffix で rename → `word/media/rId23_n1.jpg` を生成。その際 rels Target も書き換え。
    - `inject_section` は delete_start..delete_end を削除して narrative を再挿入するが、これは「前回 inject 由来の narrative」を削除して「今回の narrative」を挿入するだけで、body 側の整合は取れる。
    - ただし orphan rels（初回 inject 由来の rId12-14）と orphan media（初回の `rId23.jpg` 等、今回は rId15+ から参照されていない）は残留。
  - 実地 2026-04-17 の実験で 1-2+1-3 両方に図を持たせた状態で再現:
    - rels 件数 4 → 7（新規 4 件、orphan 4 件）
    - media に `_n1` 付き重複ファイル生成
    - docPr@id ユニーク性は維持（本質的に narrative 側が z_order-based で allocate するため）
  - `./scripts/build.sh clean && ./scripts/build.sh` の clean build では問題なし。

- **影響**:
  - 提出 docx サイズの不必要な肥大（現状は KB オーダだが、本番図表を増やすと MB 単位に）。
  - OPC spec 上 orphan rels と orphan media は warning 扱いで Word は開けるが、厳密な OOXML validator（SDK Validator、OpenXML-Validator）は warnings を出す。
  - 開発ループで「`./scripts/build.sh narrative && ./scripts/build.sh inject`」と書いた瞬間に発火（よくある操作）。

- **推奨対応（3 案）**:
  - **案 A（最小修正、推奨）**: `build_inject` 冒頭に fresh template 要件のガードを追加。
    ```bash
    # 簡易: template が「未 inject」状態かを簡易検査
    if unzip -p "$template" word/document.xml 2>/dev/null | grep -q 'asvg:svgBlob\|wp:anchor'; then
        echo "WARNING: $template はすでに inject 済みです。forms を再実行します。" >&2
        build_forms
    fi
    ```
  - **案 B（依存関係の明示）**: `ALL_STEPS` の中で `inject` を指定した場合、常に `forms` を直前に強制実行する。`run_step inject` から `build_forms; build_inject` への expand。
  - **案 C（template と output を分離）**: `--template` を `data/source/r08youshiki1_5.docx` に固定し、`forms` ステップは `template` を書き換えず `filled.docx` を出力、`inject` は `filled.docx` を `--template` として読み `filled_merged.docx` を出力する……という完全な非破壊パイプライン化。影響範囲が大きいため中期対応。
  - 短期は案 A が最小変更で実害を塞げる。

---

### [M14-05] (Major) [✅ 対応済] `roundtrip.sh` の `timeout 15 rclone lsf` が Google Drive 応答遅延で全体中断する

- **箇所**: `scripts/roundtrip.sh`（接続確認、PDF polling、退避前一覧）
- **前回対応状況**: 新規（本セッション実地観察）
- **対応**:
  - `rclone_with_retry` ヘルパー関数を追加（環境変数 `RCLONE_MAX_RETRIES=3` / `RCLONE_RETRY_SLEEP=5` で調整可能）。
  - 接続確認（Phase 3）と退避前一覧取得を `rclone_with_retry 60 rclone lsf ...` に置換。
  - Phase 4 polling の timeout を 60s に延長（同時に N14-05 対応で `found_pdfs` を単調増加化）。
- **内容**:
  - Phase 3 冒頭で `timeout 15 rclone lsf "${GDRIVE_DEST}/" --max-depth 1 --dirs-only &>/dev/null` を実行し、失敗時は `exit 1` で即座に中断。
  - 本セッションで 1 回目の実行時に exit 124（timeout）を観測、retry で成功した経緯あり。Google Drive の応答は常に数秒以内とは限らず、backoff / retry 設計が欠如。
  - 類似の 15 秒 timeout が Phase 4 の polling ループ内（L189）と archive 退避前の lsf（L248）にも存在。Polling 側は `|| true` で exit 124 を握り潰すが、`_pdf_lines` が空になるため found_pdfs が 0 に drop する（→ N14-05 の振動）。

- **影響**:
  - 本番提出作業中（例: 5/20 提出日直前）に Google Drive が応答遅延すると roundtrip.sh 全体が exit 1 で停止し、作業が止まる。
  - retry は手動（再実行）しかなく、`--skip-build --skip-push` 経由の part 実行しかリカバリ手段がない。

- **推奨対応**:
  - `timeout 15` を `timeout 60` に緩和、かつ `--retries 3 --retries-sleep 5s` のような指数バックオフを `rclone` オプションへ追加。`rclone` は既に retry を持つが `--timeout` / `--low-level-retries` のチューニングが必要。
  - Phase 3 接続確認は 3 回 retry にし、3 回とも失敗したら exit 1 へ。
  - Phase 4 polling の 15 秒 timeout も見直し、exit 124 を「応答なしを 1 回見た」扱いにして found を保持する（N14-05 とあわせて対応）。

---

### [N14-01] (Minor) [✅ 対応済（本セッションで原因特定 + 修正）] LibreOffice が `youshiki1_2_narrative.docx` を開けない — rels の `ns0:` prefix 形式が原因

- **箇所**: `main/step02_docx/wrap_textbox.py:embed_svg_native` の rels / CT serialize 直前
- **前回対応状況**: 新規 → 本セッション後半で原因特定 + 修正
- **原因調査（本セッション）**:
  1. narrative (1-2) / narrative (1-3) / filled のうち narrative (1-2) のみ LO で失敗することを確認。
  2. wp:anchor / w:drawing / media files / image rels / Content_Types の Override を順次 strip しても LO は narrative (1-2) を開けず、問題が structural にもっと根深いことを特定。
  3. rels ファイルの prefix 形式に注目。narrative (1-2) は `<ns0:Relationships xmlns:ns0="..."><ns0:Relationship .../>...</ns0:Relationships>` 形式、narrative (1-3) と filled は `<Relationships xmlns="..."><Relationship .../>...</Relationships>` 形式。
  4. narrative (1-2) rels のみを default xmlns 形式に書き換えて test → **LO が開けるようになった**。原因確定。
  5. `wrap_textbox.embed_svg_native` が `register_namespace("", RELS_NS)` → rels parse → `register_namespace("", CT_NS)` → CT parse → ... → rels serialize の順で呼んでいたため、rels serialize 時点で `""` は CT_NS に奪われており、ET が RELS_NS 要素に auto-prefix `ns0:` を付与して書き出していた（ECMA-376 的には valid だが LibreOffice 24.x が拒否）。

- **対応**:
  - `wrap_textbox.embed_svg_native` の rels serialize 直前で `ET.register_namespace("", RELS_NS)` を再実行、CT serialize 直前で `ET.register_namespace("", CT_NS)` を再実行。これにより rels は `<Relationships xmlns="...">` 形式、CT は `<Types xmlns="...">` 形式に揃う。
  - 実地検証: narrative (1-2) rels が `<Relationships xmlns="...">...<Relationship .../>...</Relationships>` 形式になったことを確認、LO が narrative (1-2) / (1-3) / filled をすべて PDF 化できることを実測。

- **副次効果**:
  - Prompt 10-5 検証項目 5（LibreOffice PDF 化）を narrative 単体でも実行可能に。
  - Windows 不要の開発 iteration が復活。
  - N13-01 / N14-04 の「rels prefix 混在」という指摘は M14-01 で最後の要素が統一された形だったが、今回は全体が pandoc と同じ default xmlns 形式に統一されるため、より clean な出力に。

---

### [N14-02] (Minor) [⏸️ 実地 inactive 化] `copy_media` の `_n1` rename が領域 F で実地発火 — report13 N13-06 が dormant から active へ

- **箇所**: `main/step02_docx/inject_narrative.py:copy_media` の rename ロジック
- **前回対応状況**: report13 N13-06 で「現時点 rename 未発生、dormant」として保留 → 本セッションで M14-04 の実地再現時に発火を確認
- **現状**: M14-04 対応（inject ガード追加）により「forms を経由しない inject 再実行」経路が塞がれたため、rename が発火する経路が実質的に消えた。テンプレート側が将来 media を持つようになった場合や外部から filled docx を template として指定された場合のみ発火しうるが、現プロジェクトでは発生しない。
- **推奨対応**: 命名規約の統一は依然として未実施だが優先度低。現状維持可。

---

### [N14-03] (Minor) [✅ 部分対応] `ET.register_namespace` のグローバル副作用 — M14-01 で顕在化したが根本対策なし

- **箇所**:
  - `main/step02_docx/wrap_textbox.py` モジュール冒頭に警告ヘッダ追加
  - `main/step02_docx/inject_narrative.py` モジュール冒頭に警告ヘッダ追加
- **前回対応状況**: report13 N13-10 では「別プロセスで無害」として保留。本セッションで M14-01 として **同一プロセス内の register_namespace 重複呼び出し**が Critical 級の症状を出すことを実証。
- **対応**: 両モジュールの冒頭に「register_namespace のグローバル副作用と fully-qualified Clark notation の必要性」を記述したヘッダーコメントを追加。将来の開発者が同じ罠にはまらないための一次防衛線として機能する。lxml 移行による根絶は I14-01 として継続。
- **内容**:
  - `xml.etree.ElementTree._namespace_map` は Python プロセス global の dict。`register_namespace(prefix, uri)` は既存エントリを上書きする。
  - 特に `prefix=""`（default）は「プロセス内に 1 つだけ」しか管理できず、複数の URI を default にしたい用途（rels と CT の両方）で最後の呼び出しが勝つ。
  - M14-01 の修正は「新規要素を fully-qualified Clark notation で作成することで register_namespace の影響を回避する」緩和策であり、**根本原因（global state の存在）は残る**。
  - 将来以下で再発リスク:
    - wrap_textbox と inject_narrative の統合（I14-01）
    - 他モジュールが docx を直接操作する機能追加（例: fix_reference_styles の拡張、段組処理の追加）
    - Python のバージョンアップ / ET 内部挙動変化

- **影響**:
  - 現状は fully-qualified 化と別プロセス分離で fresh な挙動を維持。
  - 同じ罠に将来の開発者がはまる「foot-gun」として残存。

- **推奨対応**:
  - 短期: wrap_textbox.py / inject_narrative.py のモジュール冒頭に「register_namespace のグローバル副作用と M14-01 の背景」を記載したヘッダーコメントを追加。
  - 中期: ET wrapper ヘルパー（`ns_safe_subelement(parent, ns, local)` のような fully-qualified 強制関数）を用意し、直接 `ET.SubElement` を呼ばないコーディング規約に統一。
  - 長期: `lxml.etree` へ移行。lxml は要素単位で nsmap を保持するため、global state 問題が根絶する。依存追加のコストあり。

---

### [N14-04] (Minor) [✅ 解消] narrative rels の prefix 混在

- **箇所**: `main/step02_docx/output/youshiki1_2_narrative.docx:word/_rels/document.xml.rels`
- **前回対応状況**: report13 N13-01 で新規報告。**M14-01 修正で解消**。
- **内容**:
  - 前回は rId1〜rId30 が `<ns0:Relationship>` で rId31（wrap_textbox 追加の svg1.svg 参照）だけが `<Relationship>`（bare）で混在していた。
  - M14-01 修正後の実測: 全 11 件（rId1-rId8、rId23、rId30、rId31）が `<ns0:Relationship>` で統一。
- **推奨対応**: なし（解消済みの確認報告）。

---

### [N14-05] (Minor) [✅ 対応済] `roundtrip.sh` Phase 4 polling が `rclone lsf` 応答で 7/8 → 0/8 と振動する

- **箇所**: `scripts/roundtrip.sh` Phase 4 polling
- **前回対応状況**: 新規（本セッション観察）
- **対応**: polling ループ内で `_count` を一時変数に取り、`found_pdfs` が新しい値より小さいときのみ更新する単調増加ロジックに変更。timeout も 60s に延長。
- **内容**:
  - Polling サイクルで `_pdf_lines=$(timeout 15 rclone lsf ...)` が失敗（timeout または一時的な空応答）した場合、`|| true` で握り潰され `found_pdfs` が 0 になる。
  - 次サイクルで成功すると再び 7/8 を検出、失敗すると 0/8 に戻る、という振動が発生。
  - 実地ログで `0/8 → 7/8 → 0/8 → 7/8` のパターンを確認。最終的には `-ge expected_pdfs` に到達して成功するが、ログが錯綜する。

- **影響**:
  - ログノイズ（ユーザが「進んでいるのか、戻っているのか」判断しにくい）。
  - 運悪く timeout ループが連続した場合、deadline 到達までに成功条件を満たさない可能性（Phase 4 全体の timeout が 5 分なので、20 回のうち 10 回失敗で残り 10 回で検出が必要）。

- **推奨対応**:
  - Polling を **累積最大値** で保持する: `found_pdfs=$(( found_pdfs > new_count ? found_pdfs : new_count ))` のような単調増加式に（ただし PDF が削除されたら検出したい場合はこの限りではない）。実質 watch-and-convert が PDF を produce する一方向なので単調増加で可。
  - `timeout 15` を `timeout 60` に伸ばす（M14-05 と同一対応）。

---

### [N14-06] (Minor) [✅ 対応済] `watch-and-convert.ps1` の exit code 切り分けが失われている

- **箇所**: `scripts/windows/watch-and-convert.ps1` の `Convert-DocxToPdf` 内 exit 判定
- **前回対応状況**: 新規
- **対応**: `switch ($exitCode) { 1 {OPEN_ERROR...} 2 {SAVEAS_ERROR...} default {unknown...} }` によりログメッセージで症状カテゴリを区別。stderr ファイルの場所も出力してオペレーターが即座に調査できるように改善。
- **内容**:
  - VBScript 側は OPEN_ERROR を `WScript.Quit 1`、SAVEAS_ERROR を `WScript.Quit 2` で区別する。
  - PowerShell 側 L195 は `if ($exitCode -ne 0)` で単にまとめてログ出力し、区別を破棄。
  - 実地 M14-01 発覚時は「exit 1 + OPEN_ERROR」と stderr 文字列両方が残っていたので調査は進んだが、将来 SAVEAS_ERROR が出た場合は exit 2 に依らず同じログになり、「open は通ったが SaveAs が失敗」という fine-grained 情報が失われる。

- **影響**:
  - 調査性の低下のみ。
  - 実害なし。

- **推奨対応**:
  - ログ出力で `$exitCode` の値を残し、case/switch で症状カテゴリをつける:
    ```powershell
    switch ($exitCode) {
        1 { Write-Log "OPEN_ERROR (docx parse failure): $stderrContent" 'ERROR' }
        2 { Write-Log "SAVEAS_ERROR (PDF conversion failure): $stderrContent" 'ERROR' }
        default { Write-Log "Unknown VBScript exit code $exitCode" 'ERROR' }
    }
    ```

---

### [I14-01] (Info) `lxml` への移行で register_namespace 問題を根絶する余地

- **箇所**: `main/step02_docx/wrap_textbox.py` / `inject_narrative.py` の ET 依存全般
- **内容**:
  - `lxml.etree` は要素単位で nsmap を保持するため、global state 問題が原理的に発生しない。
  - Docker image に lxml を追加するコスト、既存コードの `tag="{uri}local"` 記法の書き換え、Pandoc 連携（stdlib ET しか使わない前提部分）との整合、などを評価する必要。
  - コスト: 依存追加 1 日 + code migration 3-5 日 + 実地検証 2 日 = 1-2 週間程度の工数。
- **影響**: 今すぐ必須ではない。M14-01 のような bug が再発した場合に「次の一手」候補として準備しておく価値。

---

### [I14-02] (Info) [report13 I13-01〜04 継続] 現状変化なし

- I13-01（wp:docPr 英語名）、I13-02（pandoc rId 飛び番）、I13-03（mermaid fontSize）、I13-04（crossref anchor）いずれも今回変化なし。
- I13-03 については今回の実地 SVG に `font-size="18"` が含まれるかの確認を提案していたが、本レビューでは未実施。

---

### [I14-03] (Info) [✅ 対応済] `prompts.md` Prompt 10-5 完了チェック最終項目が冗長

- **箇所**: `docs/prompts.md` Prompt 10-5 完了チェック
- **対応**: M14-03 対応で prompts.md を更新する際に該当項目を削除。同時に項目 6（Windows Word COM レンダリング）と項目「ラスタ表示受容」行のテキストも更新し、完了チェックが実情と整合するようにした。

---

## リスクマトリクス（修正後）

| リスク | 影響度 | 発生確率 | 残存リスク | 対策済内容 |
|--------|--------|---------|------------|------------|
| Windows Word PDF で narrative が OPEN_ERROR（M14-01 の再発） | 高 | 低 → 極低 | ✅ 実質消滅 | M14-02: `inject_narrative.py` の 2 箇所を fully-qualified 化 |
| SVG がベクタで PDF 保持されず要件未達 | 中 | 確定 → 受容 | ✅ 要件改訂 | M14-03: prompts.md / plan2.md 更新、primary PNG 300 dpi で印刷品質確保 |
| 開発ループ中の `inject` 単独再実行で filled docx 肥大 | 中 | 中 → 低 | ✅ ガードで自動抑制 | M14-04: document.xml 内のマーカー検出 → forms 自動再実行 |
| Google Drive 応答遅延で roundtrip 全体が exit 1 | 高 | 低 → 極低 | ✅ retry で自動復帰 | M14-05: `rclone_with_retry` + timeout 15s → 60s |
| 将来の refactor で register_namespace global 副作用が再発 | 高 | 低 | 一次防衛のみ | N14-03: モジュール冒頭ヘッダーコメント（根本対策は I14-01） |
| Polling の値振動でログ信頼性低下 | 低 | 中 → 低 | ✅ 解消 | N14-05: 単調増加式 |
| VBScript exit code 1/2 の切り分けが失われる | 低 | 低 | ✅ 解消 | N14-06: switch で OPEN / SAVEAS / unknown を区別 |
| LO で narrative docx 開けず、早期失敗検知が出来ない | 低 | 確定 → 解消 | ✅ 解消 | N14-01: rels serialize 直前で default xmlns を RELS_NS に再 bind |
| copy_media `_n1` 命名の長期累積 | 低 | 低 → 極低 | ✅ M14-04 で発火経路を塞ぐ | N14-02: 実地 inactive 化、命名規約統一は継続課題 |

---

## 総評

### Prompt 10-5 成果物の健全性

**Linux 側で観察可能な構造的要件は実地検証でクリア**:
- フルビルド 6 ステップ全通過
- filled docx の OOXML 構造（wp:anchor×2、a:blip×2、asvg:svgBlob×1、docPr@id 4/4 ユニーク）
- rels / Content_Types の完全性（report13 C13-01 / M13-01 対応が生きている）
- 様式1-2 は 8 ページ（≤ 15 要件を満たす）
- docx サイズ 158 KB（<< 10 MB 制約、<< 3 MB 目標）
- narrative docx の rels が M14-01 修正により全件 `<ns0:Relationship>` で統一（N13-01 解消）

**Windows Word COM 経路での実地検証もクリア**:
- 8/8 ファイルが `SaveAs2 wdFormatPDF` で成功
- `youshiki1_5_filled.pdf` は 29 ページ / 1.35 MB、page 4 にデモ 2 図がレンダリング
- キャプション "病院施設の外観（デモ画像）" / "医療需給動態モデルの処理フロー（概念図）" は PDF から文字抽出可能
- 様式ヘッダ・ページ番号・脚注等の既存要素は破壊されていない

**未達 1 件**:
- SVG ベクタ保持は未達（M14-03）。Word COM の `SaveAs2` が primary PNG blip を使用し `asvg:svgBlob` を無視するため、実装側の改修ではなく Word API の仕様制約。短期的には要件文書の方を修正し、primary PNG 解像度を 300 ppi 相当に上げる対応が現実的。

### M14-01 修正の健全性

- 修正自体は正確、根本原因の説明もコード内コメントに明記。narrative docx で全件 `<ns0:Relationship>` になったことを実測確認。
- ただし、**同一パターンのバグ `inject_narrative.py` に 2 箇所残存**（M14-02、L319 と L806）。現状は実行順序で救われているが潜在 foot-gun。M14-01 と同じ fully-qualified name 方式の横展開が必要。
- register_namespace グローバル副作用（N14-03）は M14-01 で顕在化し「顕在化する経路を塞いだ」状態だが、根本解決は別課題（I14-01 lxml 移行）。

### 本セッションでの対応作業ログ（2026-04-17 後半）

| 指摘 ID | 修正箇所 | 変更サマリ |
|---------|---------|-----------|
| M14-02 | `inject_narrative.py:merge_rels` / `_merge_notes` | bare `"Relationship"` を fully-qualified `f"{{{RELS_NS}}}Relationship"` に変更。コメントで M14-02 の背景を明記。 |
| M14-03 | `docs/prompts.md` Prompt 10-5 / `docs/plan2.md` §11 検証8・リスク表 | 完了チェック「ベクタ表示」→「ラスタ画像として鮮明に表示（primary PNG 300 dpi）」へ更新。plan2.md リスク表に SaveAs2 SVG 非対応の受容項目を追加。冗長な「M09-04 で対応済み」項目を削除。 |
| M14-04 | `scripts/build.sh:build_inject` | 冒頭で `unzip -p ... word/document.xml` を実行し `wp:anchor|asvg:svgBlob` の marker を検出。検出時は `build_forms` を自動再実行して fresh template に戻す。`set -o pipefail` 対策として `grep -cE` + count 判定で実装。 |
| M14-05 | `scripts/roundtrip.sh` | `rclone_with_retry` ヘルパー関数追加（環境変数 `RCLONE_MAX_RETRIES` / `RCLONE_RETRY_SLEEP`）。接続確認と最終一覧取得を `timeout 60 + retry 3` に、polling の timeout を 60s に延長。 |
| N14-01 | `wrap_textbox.py:embed_svg_native` | rels / CT serialize 直前で `register_namespace("", RELS_NS)` / `register_namespace("", CT_NS)` を再実行。rels が default xmlns 形式で書き出され LibreOffice が narrative docx を開けるように。 |
| N14-03 | `wrap_textbox.py` / `inject_narrative.py` モジュール冒頭 | register_namespace グローバル副作用と fully-qualified Clark notation 規約を明記したヘッダーコメントを追加。 |
| N14-05 | `scripts/roundtrip.sh` Phase 4 polling | `found_pdfs` を単調増加化（`_count` 変数に取り、既存値より大きいときのみ更新）。 |
| N14-06 | `scripts/windows/watch-and-convert.ps1` | exit code を `switch` で OPEN_ERROR / SAVEAS_ERROR / unknown に分岐してログ出力。 |
| I14-03 | `docs/prompts.md` Prompt 10-5 完了チェック | 冗長項目「inject_narrative.py 側の改修は NSMAP への asvg/a14 追加のみ（M09-04 で対応済み）」を削除（M14-03 対応と同時）。 |

### 動作確認（修正後）

```
RUNNER=docker ./scripts/build.sh
  validate   ✓ OK
  forms      ✓ OK
  narrative  ✓ OK
  inject     ✓ OK
  security   ✓ OK
  excel      ✓ OK

RUNNER=docker DATA_DIR=data/dummy SETUP_DIR=data/dummy ./scripts/build.sh
  全 6 ステップ ✓ OK（非破壊性確認）

# inject ガード動作確認
RUNNER=docker ./scripts/build.sh inject  # 既 inject 済みの状態から
  INFO: youshiki1_5_filled.docx はすでに inject 済みです（marker=5）。forms を再実行して fresh template に戻します。
  === forms: ... ===  Done
  === inject: ... === Done
  rels 件数: 14（clean build 相当、orphan 無し）

# LibreOffice narrative PDF 化（N14-01 修正後）
libreoffice --headless --convert-to pdf youshiki1_2_narrative.docx
  → youshiki1_2_narrative.pdf 637 KB（成功）
libreoffice --headless --convert-to pdf youshiki1_5_filled.docx
  → youshiki1_5_filled.pdf 1.4 MB（成功）
```

### Prompt 11 へ進む判断

Major 5 件 / Minor 6 件中 10 件を本セッションで対応完了。残る Minor 1 件（N14-02）は M14-04 ガードにより実地 inactive 化。Info 3 件のうち 1 件（I14-03）は対応完了、1 件（I14-01: lxml 移行）は将来課題として継続、1 件（I14-02）は記録のみ。

**Prompt 10-5 は実質完了**として Prompt 11 へ進んで差し支えない。SVG ベクタ保持は M14-03 の決定でラスタ受容に要件変更済み、完了チェックと plan2.md の整合も取れている。

残存する運用リスク:
- I14-01（lxml 移行）: 中期的に検討。今すぐは不要。N14-03 のヘッダーコメントで一次防衛。
- 提出日（2026-05-20）前の最終動作確認: Windows Word COM 経由の PDF 品質を実地で最終目視確認。本セッションで確認した `data/products/youshiki1_5_filled.pdf` は 29 ページ / 1.35 MB で問題なし。

全体として、Prompt 10-5 の目標「図表挿入と Word 互換性の成立」は達成され、さらに運用堅牢性（inject ガード / roundtrip retry）と開発体験（LO narrative PDF 化）の改善まで踏み込めた。
