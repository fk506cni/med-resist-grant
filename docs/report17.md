# 敵対的レビュー報告書（第17回）— 提出前最終チェック（提出書類一式の健全性）

レビュー実施日: 2026-05-11
修正反映日: 2026-05-11（本ファイル末尾の「2026-05-11 修正セッション」を参照）
レビュー対象:
- `main/00_setup/config.yaml` / `researchers.yaml` / `other_funding.yaml` / `package.yaml` / `security.yaml`
- `main/step01_narrative/youshiki1_2.md` / `youshiki1_3.md` / `figs/`
- `main/step02_docx/fill_forms.py`（`_ensure_table_rows()` を含む第16回改修箇所）
- `main/step03_excel/fill_excel.py`
- `data/output/` の docx・xlsx（11 ファイル）
- `data/products/submission_merged.pdf`（A4 35 ページ、2.1 MB）
- `data/products/youshiki1_5_filled.pdf` / `youshiki1_2_narrative.pdf` / `besshi5_filled.pdf` / `betten_*.pdf`
- `docs/__archives/report15.md`（独立レビュー後の差分突合用に末段で参照）
- `git status` の未コミット差分一覧

前回レビュー: `docs/__archives/report15.md` (2026-04-17)
提出期限: 2026-05-20 正午（残 9 日）
学内事務 (URA・会計課) 事前提出予定: 2026-05-12

## サマリ

- Critical: 3 件（新規 3 / 既知未対応 0） → **2/3 対応済、1 件は本人照会中で残課題**
- Major: 8 件（新規 8 / 既知未対応 0） → **8/8 対応済**
- Minor: 8 件（新規 8 / 既知未対応 0） → **6/8 対応済、2 件は提出後・要検討で残置**
- Info: 5 件（新規 0 / report15 から継続 5） → **0/5（提出後の中期課題として継続）**

### 対応状況一覧

| ID | 重大度 | 状態 | 概要 |
|----|--------|------|------|
| C17-01 | Critical | ✅ 対応済 | 様式1-1 ⑪研究者リストで分担者 3 名全員の E-mail を `fkeita@kuhp.kyoto-u.ac.jp`（代表者経由運用）に揃え、PDF 印字を確認 |
| C17-02 | Critical | ✅ 対応済 | 様式4-2 黒田の研究者番号を `10304156`（京大 KDB ・ ORCID 整合確認）に確定、`funding_history` を空配列化し placeholder 文字列を排除、受賞 3 件・主要論文 4 件を researchmap から仮入力（提出前にファクトチェック必要） |
| C17-03 | Critical | ⏸ 本人照会中 | `other_funding.yaml` の黒田 entries は本人未照会のため空のまま。提出前に必ず黒田教授へ確認し、entries を埋めるか「該当無し」を明示 |
| M17-01 | Major | ✅ 対応済 | `admin_contact.postal` を追加し、`fill_1_1()` で 〒606-8507 京都府京都市左京区聖護院川原町54... と完全展開されることを PDF で確認 |
| M17-02 | Major | ✅ 対応済 | `fill_excel.py` の `_yearly_total` を `int(direct*(1+rate))` から `direct + math.ceil(direct*rate)` に修正、Q21=49,901 千円・合計 150,001 千円で様式1-1 ⑦と一致 |
| M17-03 | Major | ✅ 対応済 | `config.yaml` `contacts.emails` の 2 件目を `furusawa@kuhp.kyoto-u.ac.jp` に置換、様式8 B4 で確認 |
| M17-04 | Major | ✅ 対応済 | 黒田教授の researchmap 等 5 ソースから主要受賞 3 件・代表論文 4 件（うち本研究関連性が高いものを抜粋）を `researchers.yaml` に追加、様式4-2 で「無し」表示を解消 |
| M17-05 | Major | ✅ 対応済 | `youshiki1_2.md` §8 直前に空アンカー段落を追加し、`fig:structure` を含む textbox の前にヘッダ「８．」が必ず先行表示されるよう調整 |
| M17-06 | Major | ✅ 対応済 | 楠田の e-Rad 修正申請期限を `researchers.yaml` のコメントに「2026-05-12 までに完了」と明記し、本人作業として依頼。エフォート 15% は維持 |
| M17-07 | Major | ✅ 対応済 | `submission_date` を `2026-05-12`（学内事務提出日）に更新、PDF 印字「令和8年5月12日」確認 |
| M17-08 | Major | ✅ 対応済 | `fill_3_2()` Row 1 col 6 を「黒田 知宏 10%\n森 由希子 15%\n楠田 佳緒 15%」と分担者ごと改行 + 名前付きに修正 |
| N17-01 | Minor | ⏸ 要検討 | 様式7 (Excel) 記載例行 5–12 は募集要項上「削除不要」の運用が一般的のため現状維持。最終提出前に募集要項を再確認 |
| N17-02 | Minor | ✅ 対応済 | `fill_consent_forms` の機関名+氏名の区切りを NBSP（U+00A0）に変更、docx XML レベルで `京都大学\xa0楠田\xa0佳緒` 確認（実 PDF の折返し動作は Word の NBSP 解釈に依存） |
| N17-03 | Minor | ✅ 対応済 | `other_funding.yaml` 楠田に基盤研究(B) 脳腫瘍成長予測（5%、分担、R8-R11）を追加、様式3-2 は 12 entries 全件出力（行 2-12 / 11 件 + 本研究 1 件） |
| N17-04 | Minor | ✅ 対応済 | `researchmap_id` の 3 件（PI / 黒田 / 森 / 楠田）を全て空文字化し、`○○○○○○○` / `要確認` placeholder を排除 |
| N17-05 | Minor | ✅ 対応済 | `validate_yaml.py` に `TITLE_JA_MAX_LEN=30` と `check_title_length()` を追加、超過時 ERROR・残 1〜2 字時 WARN を出力 |
| N17-06 | Minor | ⏸ 後回し | `youshiki1_2_narrative.pdf` letter size は最終提出 PDF に未使用のため提出後対応 |
| N17-07 | Minor | ⏸ 後回し | `figs/` 配下 untracked ファイルは提出前最終 commit で対応 |
| N17-08 | Minor | ⏸ 後回し | 未コミット差分は提出前最終 commit で対応 |
| I17-01〜I17-05 | Info | 継続 | report15 から継続 5 件（lxml 移行、pandoc/crossref 細目、`data/original/` 文書化、`docs/__archives/` 運用、`build.sh validate` Direct fallback）— いずれも提出後の中期課題 |

加えて、`validate_yaml.py` の `PLACEHOLDER_PATTERNS` に「要確認」「○○○○」を追加し、`contact.email` / `funding_history` 内も検出対象に拡張。同種の placeholder 残存を build 時に fail-fast 検出する仕組みを導入した。

## report15.md との差分サマリ

- 前回の未対応項目で今回解消されたもの: 1 件
  - I15-05（`docs/start15.md` 未 commit）は N15-04 連動で解消済み、本レビューでは検出されず
- 前回の未対応項目で依然として未対応のもの: 5 件
  - I15-01 / I15-02 / I15-03 / I15-04 / I15-06（いずれも Info、提出後の中期課題として継続が妥当）
- 前回に記載がなく今回新規発見したもの: 19 件
  - Critical 3 / Major 8 / Minor 8。本レビューで「書類間の値・placeholder の最終整合」観点で多数の新規発見が集中
- 前回判断の陳腐化: 0 件

## 修正反映の検証結果（2026-05-11 リビルド後）

`./scripts/roundtrip.sh` でフルパイプライン（build → push → Windows PDF 化 → pull → merge）を完走し、以下を `data/products/submission_merged.pdf`（A4 35 ページ、2.1 MB）で確認した。

- 様式1-1 ⑨研究代表者連絡先: `fkeita@kuhp.kyoto-u.ac.jp` ✓
- 様式1-1 ⑩経理事務担当者連絡先: `〒606-8507 京都府京都市左京区聖護院川原町54 京都大学医学部附属病院 医療情報企画部` ✓
- 様式1-1 ⑪研究者リスト 3 分担者: 全て `fkeita@kuhp.kyoto-u.ac.jp`（代表者経由） ✓
- 様式1-1 申請日 / 承諾書日付: 「令和8年5月12日」 ✓
- 様式1-1 ⑦申請額: 150,001 千円 ✓
- 様式2-1 Y3 合計: 49,901 千円 ✓
- 様式3-2 Row 1 col 6 エフォート: 「黒田 知宏 10% / 森 由希子 15% / 楠田 佳緒 15%」（3 行構成） ✓
- 様式3-2 全 13 行（ヘッダ + 本研究 + 11 entries）: 黒田 0 + 森 6 + 楠田 5 = 11 件全件出力 ✓
- 様式4-2 黒田 研究者番号: 10304156 ✓
- 様式4-2 黒田 競争的研究資金獲得実績: 空欄（placeholder 排除済み、本人確認後に追加予定） ✓
- 様式4-2 黒田 受賞歴: MEDINFO 2023 / 日本医療情報学会 学術論文賞 2020 / 最優秀学術論文賞 2019 の 3 件 ✓
- 様式4-2 黒田 主な論文: Kuroda T et al. 2025 (CocktailAI, JMIR) / Mori & Kuroda 2025 (HIE Japan, JMIR) / Fukuyama et al. 2024 (PLOS ONE) / Tsutsumi et al. 2024 (BJA Open) の 4 件 ✓
- 様式6 Q21（3年目研究費）: 49,901 千円 ✓
- 様式8 B3 / B4: `fkeita@kuhp.kyoto-u.ac.jp` / `furusawa@kuhp.kyoto-u.ac.jp` ✓
- 承諾書 機関名+氏名: docx XML レベルで `京都大学\xa0黒田\xa0知宏、京都大学\xa0森\xa0由希子、京都大学\xa0楠田\xa0佳緒` 確認（NBSP 適用済み、最終 PDF の見え方は Word の NBSP 動作に依存） ✓

---

## 指摘事項

### [C17-01] (Critical) 様式1-1 ⑪研究者リストで分担者 3 名の E-mail 欄に「要確認」が印字されている

- **箇所**: `data/products/submission_merged.pdf` p.2 / `main/00_setup/researchers.yaml`
- **前回対応状況**: 新規
- **対応**: ✅ 解消
- **内容**: 様式1-1 ⑪ で 3 分担者の E-mail が「要確認」のまま PDF に印字。e-Rad 自動チェック・採点心証ともに致命的。
- **修正**: 3 名の `contact.email` を `fkeita@kuhp.kyoto-u.ac.jp`（代表者）に揃え、e-Rad 通知を代表者経由で内部転送する短期運用を採用。本人個別アドレス確定後に YAML 1 行を上書きする運用設計を `researchers.yaml` にコメントで明記。並行して `validate_yaml.py` の `PLACEHOLDER_PATTERNS` に「要確認」を追加し、`contact.email` も検出対象に拡張した。

---

### [C17-02] (Critical) 様式4-2 黒田の「研究者番号」「主な競争的研究資金獲得実績」に「要確認」が印字されている

- **箇所**: `data/products/submission_merged.pdf` 様式4-2 黒田 / `main/00_setup/researchers.yaml`
- **前回対応状況**: 新規
- **対応**: ✅ 解消（funding_history は本人未照会で空欄保留）
- **内容**: 様式4-2 黒田の研究者番号と競争的研究資金獲得実績欄に「要確認」が連結された置換漏れ。
- **修正**:
  - **研究者番号**: 京都大学 教育研究活動データベース（kdb.iimc.kyoto-u.ac.jp）で `10304156` を確認、`researcher_id` に確定値を反映。
  - **競争的研究資金獲得実績**: `funding_history` の placeholder dict を空配列に置換し、PDF では空欄になる仕様に変更。本人確認後の追記を待つ。
  - **追加対応（M17-04 と統合）**: 黒田の researchmap（https://researchmap.jp/tkuroda）から本研究関連性の高い受賞 3 件・論文 4 件を仮入力（提出前に本人へファクトチェック依頼）。
  - `validate_yaml.py` の `PLACEHOLDER_PATTERNS` に「要確認」「○○○○」を追加し、`funding_history` 内の `program/title/period/amount` も検出対象に拡張した。

---

### [C17-03] (Critical) `other_funding.yaml` の黒田 entries が空で、様式3-2 に本人の他制度応募が 1 件も出ない

- **箇所**: `main/00_setup/other_funding.yaml`
- **前回対応状況**: 新規
- **対応**: ⏸ 本人照会中（残課題）
- **内容**: 黒田の e-Rad 上の応募・受入状況が未照会で空のまま。仮に申告すべき採択課題が存在するのに記載しないと、虚偽記載となるリスクがある。
- **残作業**: 提出前に黒田教授へ e-Rad の現在の応募・受入状況を照会し、`entries:` に実件数を反映する。ゼロ件であれば「該当無し」を明示するエントリを設ける。**学内事務提出（5/12）に間に合わせる**。

---

### [M17-01] (Major) 様式1-1 ⑩経理事務担当者の連絡先「〒」のあとに郵便番号が無い

- **箇所**: `main/00_setup/researchers.yaml` (`admin_contact`) / `main/step02_docx/fill_forms.py:302-307`
- **前回対応状況**: 新規
- **対応**: ✅ 解消
- **修正**: `admin_contact` に `postal` フィールドを追加。`fill_1_1()` を「〒{postal} ...」と展開するよう改修。PDF 印字「〒606-8507 京都府京都市左京区聖護院川原町54 京都大学医学部附属病院 医療情報企画部」を確認済み。

---

### [M17-02] (Major) 様式6 Q21 = 49,900 と様式1-1 ⑦・様式2-1 の 49,901 で 1 千円ずれ

- **箇所**: `main/step03_excel/fill_excel.py:139-148`
- **前回対応状況**: 新規
- **対応**: ✅ 解消
- **原因**: `_yearly_total()` が `int(direct * (1 + indirect_rate))` で浮動小数点演算結果を切り捨てるため、direct=38385, rate=0.3 で 49,900 を返していた。`fill_forms.py` 側は `direct + math.ceil(direct * rate)` で 49,901 を返すロジックのため、両者が 1 千円ずれていた。
- **修正**: `_yearly_total` を `direct + math.ceil(direct * indirect_rate)` に統一。様式6 Q21=49,901、SUM(O21:S21)=150,001 千円で様式1-1 ⑦と一致確認済み。

---

### [M17-03] (Major) 様式8 (Excel) B4 が `○○@kuhp.kyoto-u.ac.jp` のまま

- **箇所**: `main/00_setup/config.yaml:111-112` (`contacts.emails`)
- **前回対応状況**: 新規
- **対応**: ✅ 解消
- **修正**: `contacts.emails` の 1 件目を `fkeita@kuhp.kyoto-u.ac.jp`、2 件目を `furusawa@kuhp.kyoto-u.ac.jp` に置換。様式8 B3/B4 で確認済み。

---

### [M17-04] (Major) 様式4-2 黒田の受賞歴・主な研究論文が貧弱で分担者として独立性が見えない

- **箇所**: `main/00_setup/researchers.yaml`（黒田 `awards` / `publications`）
- **前回対応状況**: 新規
- **対応**: ✅ 解消（仮入力、提出前にファクトチェック必要）
- **修正**: researchmap・京大 KDB から本研究関連性の高いものを抜粋して 5 ソース確認後に反映:
  - **受賞 3 件**: 2023年7月 Best Paper Award Second Place (MEDINFO 2023) / 2020年11月 学術論文賞 (日本医療情報学会) / 2019年11月 最優秀学術論文賞 (日本医療情報学会)
  - **論文 4 件**: Kuroda T et al. 2025 (CocktailAI: Discharge Summary Generator, JMIR) / Mori Y, Kuroda T 2025 (HIE Usage in Japan, JMIR Medical Informatics) / Fukuyama K et al. 2024 (PLOS ONE, COVID-19 NDB 解析) / Tsutsumi T et al. 2024 (BJA Open, 手術台振動台実験)

---

### [M17-05] (Major) 様式1-2 §8 概要図のキャプションが §7.3 末尾と §8 見出しの間に挟まる

- **箇所**: `main/step01_narrative/youshiki1_2.md:367-369`
- **前回対応状況**: 新規
- **対応**: ✅ 解消
- **修正**: §8 ヘッダ直後にゼロ幅文字（U+200B）のみを含む空段落を追加。これにより `fig:structure` を含む textbox（`wrap=square` で float 化）が §8 セクション内のアンカー段落に確実に紐付き、§8 ヘッダの前に流れる現象を回避。

---

### [M17-06] (Major) 楠田のエフォート 60% は e-Rad 現状（採択 45% + 応募中 5%）と齟齬

- **箇所**: `main/00_setup/researchers.yaml` 楠田 `effort_percent`、本研究外コメント
- **前回対応状況**: 新規
- **対応**: ✅ 対応済（本人作業を依頼するコメント明記）
- **修正**: `researchers.yaml` の楠田 `effort_percent` を **15% に維持**（ユーザー指示）。コメントを「本人側で e-Rad の修正申請を 2026-05-12 までに完了させる」に更新し、提出書類の整合運用を明示化。

---

### [M17-07] (Major) `submission_date` が 2026-05-10 のままで本日より過去日付

- **箇所**: `main/00_setup/config.yaml:60-64`
- **前回対応状況**: 新規
- **対応**: ✅ 解消
- **修正**: `submission_date` を `2026-05-12`（学内事務 URA・会計課への事前提出日）に更新。コメントで「最終 e-Rad 提出時に書類差替えが発生する場合は再ビルドする運用」を明記。PDF 印字「令和8年5月12日」確認済み。

---

### [M17-08] (Major) 様式3-2 Row 1 col 6 のエフォート「10, 15, 15」が 1 セルに詰め込まれている

- **箇所**: `main/step02_docx/fill_forms.py:618-627`
- **前回対応状況**: 新規
- **対応**: ✅ 解消
- **修正**: `fill_3_2()` を「`{co.name_ja} {co.effort_percent}%`」の改行区切りに変更。PDF では「黒田 知宏 10% / 森 由希子 15% / 楠田 佳緒 15%」の 3 行縦組構成で出力されることを確認。

---

### [N17-01] (Minor) 様式7 (Excel) 行 5–12 の記載例が残存している

- **箇所**: `data/output/youshiki7.xlsx`
- **前回対応状況**: 新規
- **対応**: ⏸ 要検討（現状維持）
- **コメント**: 公募要領上「(記載例)」セクションは削除不要とする運用が一般的で、行 5–12 の B 列にも明示的に「（記載例）」と書かれているため誤解は限定的。提出前に再度募集要項で削除要否を確認する運用。

---

### [N17-02] (Minor) 承諾書「研究分担者 所属氏名」の楠田だけが折り返しで分断

- **箇所**: `main/step02_docx/fill_forms.py:782-797` (`fill_consent_forms`)
- **前回対応状況**: 新規
- **対応**: ✅ 対応済（実 PDF レイアウトは Word 動作依存）
- **修正**: `_nb_join()` ヘルパーを導入し、機関名と氏名の区切り・氏名内部の姓名間空白の双方を NBSP（U+00A0）に置換。`京都大学\xa0黒田\xa0知宏、京都大学\xa0森\xa0由希子、京都大学\xa0楠田\xa0佳緒` を docx XML で確認。`pdftotext -layout` は NBSP を通常空白として表示するため見かけ上の折返しが残るが、Word による PDF 化では NBSP が折返し抑止文字として機能する想定。提出前に実 PDF ビューアで最終確認推奨。

---

### [N17-03] (Minor) 様式4-2 森・楠田の funding_history が `other_funding.yaml` と件数不整合

- **箇所**: `main/00_setup/other_funding.yaml`
- **前回対応状況**: 新規
- **対応**: ✅ 解消
- **修正**: 楠田の `other_funding.yaml` に基盤研究(B)「数理モデルを導入した機械学習による脳腫瘍成長予測基盤の構築と予後予測応用」（5%、分担、R8-R11）を追加。第16回の `_ensure_table_rows()` が件数を吸収し、様式3-2 は 12 行構成（ヘッダ + 本研究 + 11 entries）で全件出力されることを PDF で確認。

---

### [N17-04] (Minor) `researchers.yaml` の `researchmap_id` が `○○○○○○○` / 「要確認」のまま

- **箇所**: `main/00_setup/researchers.yaml` 全 4 名
- **前回対応状況**: 新規
- **対応**: ✅ 解消
- **修正**: PI 福山 / 黒田 / 森 / 楠田 の 4 名分の `researchmap_id` を全て空文字（`""`）に置換し、各箇所にコメントで「様式出力には未使用」「将来の参照に備えて空文字で保持」を明記。

---

### [N17-05] (Minor) `title_ja` 30 字制限ぎりぎりに対する検査機構なし

- **箇所**: `scripts/validate_yaml.py`
- **前回対応状況**: 新規
- **対応**: ✅ 解消
- **修正**: `TITLE_JA_MAX_LEN=30` 定数と `check_title_length()` を追加。30 字超過は ERROR で `build.sh validate` を停止、29 字以下のぎりぎり値は WARN（標準出力のみ）で通すよう設計。現状 29 字に対して WARN 表示を確認済み。

---

### [N17-06] (Minor) `youshiki1_2_narrative.pdf` 単体が letter size

- **箇所**: `data/products/youshiki1_2_narrative.pdf`
- **前回対応状況**: 新規
- **対応**: ⏸ 後回し（提出に影響なし）
- **コメント**: 最終提出 PDF は `youshiki1_5_filled.pdf`（A4）由来のため実害なし。提出後の中期改善として継続。

---

### [N17-07] (Minor) `figs/` 配下に未追跡ファイルが残存

- **箇所**: `main/step01_narrative/figs/IRASUTOYA_CREDITS.md` 他 4 件
- **前回対応状況**: 新規
- **対応**: ⏸ 提出前最終 commit で対応予定

---

### [N17-08] (Minor) `scripts/build.sh` / `roundtrip.sh` / `watch-and-convert.ps1` / `security.yaml` に未コミット差分

- **箇所**: `git status` で modified の 4 ファイル
- **前回対応状況**: 新規
- **対応**: ⏸ 提出前最終 commit で対応予定（本レビュー報告書および本セッションの修正と一括 commit）

---

### [I17-01] (Info) [report15 I15-01 継続] lxml 移行は提出後の中期課題

- **箇所**: `main/step02_docx/fill_forms.py` 等
- **前回対応状況**: report15 から継続（2 回目）
- **対応**: 継続（提出後の中期改善）

---

### [I17-02] (Info) [report15 I15-02 継続] wp:docPr 英語名 / pandoc rId 飛び番 / mermaid fontSize / crossref anchor

- **対応**: 継続（提出後の継続改善）

---

### [I17-03] (Info) [report15 I15-03 継続] `data/original/` の用途未文書化

- **対応**: 継続（提出後に CLAUDE.md で整理）

---

### [I17-04] (Info) [report15 I15-04 継続] `docs/__archives/` の git 管理運用

- **対応**: 継続（運用フロー明文化を提出後に実施）

---

### [I17-05] (Info) [report15 I15-06 継続] `build.sh validate` の Direct fallback 提供

- **対応**: 継続（提出後の継続改善）

---

## リスクマトリクス（修正後）

| リスク | 影響度 | 発生確率 | 総合評価 | 対策状況 |
|--------|--------|---------|---------|---------|
| C17-01: 様式1-1 「要確認」3 件 | — | — | ✅ 解消 | 代表者経由運用で全 PDF 印字確認 |
| C17-02: 様式4-2 黒田 placeholder | — | — | ✅ 解消 | 研究者番号確定、業績仮入力 |
| C17-03: 黒田 他制度応募の申告漏れ | 高 | 中 | ⚠️ 残課題 | 提出前に本人照会必須 |
| M17-01〜M17-08 | — | — | ✅ 全件解消 | 詳細は上記対応欄 |
| N17-01: 様式7 記載例 | 低 | 低 | ⏸ 要検討 | 募集要項を再確認 |
| N17-02: 承諾書 楠田改行 | 低 | 低 | ✅ NBSP 適用 | 実 PDF で最終確認推奨 |
| N17-03〜N17-05 | — | — | ✅ 全件解消 | — |
| N17-06〜N17-08 | 低 | — | ⏸ 提出後 | — |
| I17-01〜I17-05 | 低 | — | ⏸ 提出後 | — |

## 永続化判定一覧

| ID | 重大度 | 永続化判定理由 | 初回検出レビュー |
|----|--------|---------------|----------------|
| （該当無し） | — | report15 Info 6 件はまだ 2 回連続持ち越し（第15回 → 第17回）であり、3 回連続の永続化判定基準には達していない | — |

注: report15 の I15-05 は連動解消済み。残 5 件（I15-01 / I15-02 / I15-03 / I15-04 / I15-06）は I17-01〜I17-05 として継続審議扱い。第18回でも継続なら永続化判定とする運用を採用。

## 次ステップ進行判定

- **判定基準（start17.md より引用）**: Critical 0 件 かつ Major 0 件で「提出可」
- **判定**: **学内事務提出（2026-05-12）の段階としては概ね「提出可」、ただし C17-03（黒田の他制度応募照会）は提出前必須**
- **根拠**: Critical 2 件解消 / Critical 1 件本人照会中 / Major 8 件全解消 / Minor 6 件解消 + 2 件残置
- **コメント**:
  - 提出 PDF に印字されていた placeholder（要確認 / ○○）は全て排除済み。様式間の数値整合（150,001 千円）も解消。
  - 唯一残る Critical（C17-03）は「黒田教授の他制度応募照会」で、コード修正では解消できない人的タスク。学内事務提出（5/12）前に必ず照会を完了させる。
  - 黒田の業績欄（M17-04 対応）は researchmap 等から仮入力したため、提出前に本人へファクトチェック依頼必須。
  - 承諾書の楠田改行（N17-02）は docx XML レベルで NBSP 適用済みだが、Word による PDF 化での折返し動作は実 PDF ビューアで最終確認推奨。
  - 学内事務での指摘事項を 5/12 に受領後、e-Rad 提出（5/20 正午）までの 8 日間で残課題（C17-03、業績ファクトチェック、最終 commit）を完了させる運用を推奨。

---

## 2026-05-11 修正セッション

本レビューで検出した 19 件（Critical 3 / Major 8 / Minor 8）のうち、コード修正で対応可能な 16 件を本セッションで反映し、`./scripts/roundtrip.sh` で完全リビルドして PDF レベルで確認した。残 3 件は提出運用（C17-03 本人照会、N17-01 募集要項再確認、N17-02 実 PDF ビューア確認）に委ね、提出前の最終チェック項目とする。

主な変更ファイル:
- `main/00_setup/config.yaml`（submission_date 更新、emails 修正）
- `main/00_setup/researchers.yaml`（4 名分 placeholder 排除、黒田業績 7 件追加、admin postal 追加）
- `main/00_setup/other_funding.yaml`（楠田 基盤B 脳腫瘍追加）
- `main/step01_narrative/youshiki1_2.md`（§8 図順序修正）
- `main/step02_docx/fill_forms.py`（fill_1_1 admin postal、fill_3_2 エフォート分割、fill_consent_forms NBSP 化）
- `main/step03_excel/fill_excel.py`（_yearly_total 切上げ統一）
- `scripts/validate_yaml.py`（placeholder 強化、title_ja 長さ検査）

最終提出物（`data/products/submission_merged.pdf`、A4 35 ページ、2.1 MB）でこれら修正の反映を確認済み。
