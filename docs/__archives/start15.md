# セッション開始プロンプト: 敵対的レビュー（第15回）— 提出前の最終健全性チェック

以下の指示に従い、**2026-05-20 提出に向けた全体健全性の最終点検**について敵対的レビューを行ってください。
レビュー結果は `docs/report15.md` に出力してください。

## レビュー方針

- **実装を開始しないでください。** レビューと指摘のみを行います。
- **研究計画書の論旨・内容（`main/step01_narrative/youshiki1_2.md` および
  `youshiki1_3.md` の本文、研究テーマの科学的妥当性・新規性・実現可能性）はレビュー対象外です。**
  本文の技術的な Markdown 構文破綻・ビルド連動箇所（crossref、textbox、fig 参照等）の
  レビューは対象に含みます。
- **焦点は「提出までに残っている健全性上の穴を敵対的に炙り出す」です。** 順調に
  見える状態ほど見落としを疑ってください。
- **敵対的に検証してください。** 「うまくいきそう」ではなく「どこで壊れるか」を
  探してください。提出当日の事故シナリオ、部分失敗時のリカバリ、オペレーター誤操作、
  依存サービス障害（Google Drive / rclone / Windows / Docker Hub）まで射程に入れて
  ください。
- **`docs/__archives/report14.md` を読まずに**独立してレビューを行い、レポート作成時に
  report14.md と突き合わせて所見を統合してください。
- レビュー結果は `docs/report15.md` に、重大度（Critical / Major / Minor / Info）付きで
  出力してください。
- 前回レビューとの差分（新規発見 / 既知だが未対応 / 前回から改善済み / 前回の判断が
  陳腐化）を明示してください。

## 前回（`docs/__archives/report14.md`）からの主な変化

**report14 の対応状況（要約）**
- Major 5 件：すべて対応済
  - M14-01: `wrap_textbox.embed_svg_native` の namespace バグ → fully-qualified Clark
    notation で修正
  - M14-02: `inject_narrative.py` の `merge_rels` / `_merge_notes` 同パターン →
    fully-qualified 化
  - M14-03: SVG ベクタ保持要件 → ラスタ受容に要件変更（primary PNG 300 dpi）、
    `docs/prompts.md` / `docs/plan2.md` 改訂済
  - M14-04: `build.sh:build_inject` の再実行非冪等性 → `wp:anchor / asvg:svgBlob`
    マーカー検出で forms 自動再実行ガード追加
  - M14-05: `roundtrip.sh` の `timeout 15 rclone lsf` → `rclone_with_retry` 導入、
    timeout 60s + retry 3 に緩和
- Minor 6 件：5 件対応済、1 件（N14-02 `copy_media _n1` rename）は M14-04 により
  実地 inactive 化
- Info 3 件：1 件（I14-03）対応済、2 件（I14-01 lxml 移行 / I14-02 英語 docPr 名等）
  は継続課題

**本セッション（2026-04-17 後半）での追加変化**
- Prompt 10-5（inject 連携 + E2E 検証）の実地検証を完走:
  - フルビルド全 6 ステップ通過
  - 二段構成 `a:blip`(PNG) + `asvg:svgBlob`(SVG) の実地確認
  - docPr@id 一意性（4/4 ユニーク）
  - LibreOffice 検証（pdfimages で 2 画像検出）
  - Windows Word COM 経由の PDF 生成（29 ページ、1.35 MB、様式1-2 は 8 ページ）
  - 非破壊性テスト（textbox 削除時に anchor/svgBlob 不発生、dummy E2E 通過）
- `docs/prompts.md` Prompt 10-5 完了チェック 8 項目を `[x]` に更新
- **コード改修は本セッションでは発生していない**（report14 段階で全て解消済）

**未コミット変更（本セッション開始時点）**
- `CLAUDE.md`
- `data/dummy/{other_funding,researchers,security}.yaml`
- `docs/prompts.md`（Prompt 10-5 の完了チェック更新）
- `docs/step4plan.md`
- `main/step02_docx/fill_forms.py`
- `templates/reference.docx`

**未追跡ファイル**
- `pyproject.toml` / `uv.lock`（uv 導入の痕跡）
- `data/original/`（data/source と類似の命名、用途要確認）
- `.claude/`（ローカル設定、gitignore 想定）

**提出日までの残日数**
- 本レビュー実施想定日 2026-04-17 前後 → 2026-05-20 まで 33 日

## レビュー対象

### 1. 提出書類の完全性（17 書類）

- 応募時（2026-05-20 必着）提出書類: 様式1-1 / 1-2 / 1-3 / 2-1 / 2-2 / 3-1 / 3-2 /
  4-1 / 4-2 / 5（該当時のみ）/ 参考様式（承諾書 3 種中 Type A では 2 種）/ 様式6 /
  7 / 8（Excel）
- 面接選出後（7 月中旬想定）提出書類: 別紙5（セキュリティ質問票）/ 別添（自己申告書
  人数分）
- **チェック観点**:
  - ビルドパイプラインが生成するファイルと CLAUDE.md「提出書類一覧」の対応漏れ
  - 未記入様式の削除運用（Type A では補助金版承諾書を削除等）が自動化されているか
    手動運用か
  - PDF 結合（様式1-1〜5 + 参考様式を 1 PDF に）を実装する script が存在するか、
    運用手順が明文化されているか
  - 別紙5 / 別添が応募時に混入しないようパッケージ境界が設計されているか

### 2. ファイルサイズ・ページ数制約

- 制約（CLAUDE.md より）: 各 10MB 以下 / 目標 3MB / 様式1-2 最大 15p
- 現状実測:
  - `main/step02_docx/output/youshiki1_5_filled.docx` = 158 KB
  - Windows Word COM 経由の `data/products/youshiki1_5_filled.pdf` = 1.3 MB、
    29 ページ、様式1-2 部分は 8 ページ
  - LO 経由は 47 ページ（描画差異、参考値）
- **チェック観点**:
  - 本文が完成した場合のページ数推計（現在の本文ボリュームから 15p 収束の現実性）
  - 画像差替え時のサイズ膨張率（primary PNG 300 dpi が守られる保証の仕組み）
  - サイズ・ページ数の自動検知（`./scripts/build.sh check` 等）の網羅性
  - 画像を含む様式1-3 / 様式4-X 追加時のサイズリスク

### 3. ビルドパイプライン健全性

- `./scripts/build.sh` の全 6 ステップ: validate / forms / narrative / inject /
  security / excel
- RUNNER モード: docker（デフォルト）/ uv / direct
- **チェック観点**:
  - RUNNER=docker 以外のモードで動作する保証（direct モードで pandoc 不在時に
    narrative が fail する既知事象の扱い）
  - clean build / 差分 build / 部分再実行の冪等性（M14-04 ガードの edge case）
  - `build.sh check` の網羅性（どのファイルを何基準で検査しているか）
  - `validate_yaml.py` が必須フィールドを網羅検査しているか、欠落時のエラー親切度
  - 並列実行時の衝突（`output/` 同時書き込み等）
  - Docker イメージの再現性（pandoc 3.6.x 固定、python-docx / openpyxl のバージョン
    pin 状況）

### 4. データフローと整合性

- 実データ: `main/00_setup/*.yaml` / `main/step01_narrative/*.md`
- ダミーデータ: `data/dummy/*.yaml`（E2E テスト用）
- **チェック観点**:
  - `main/00_setup/*.yaml` と `data/dummy/*.yaml` のスキーマ差異（本番にあって dummy
    にない／dummy にあって本番にないフィールド）
  - 研究者情報・他制度応募状況・セキュリティ情報の実データ化進捗
  - 承諾書の placeholder 自動埋め（memory: `project_consent_form_autofill.md`）が
    未実装のまま提出ギリギリで必要になるリスク
  - 本セッションで変更されている `data/dummy/*.yaml` の変更意図

### 5. roundtrip.sh / Windows Word COM

- 本番 PDF 化の唯一経路
- **チェック観点**:
  - M14-05 の `rclone_with_retry` が扱いきれない障害パターン（rclone config 破損、
    Google Drive 2FA 再認証要求、gdrive quota 枯渇、Windows 側 watcher 停止）
  - watch-and-convert.ps1 のエディタマクロ保存・リトライ上限・stderr 出力先の
    運用実態
  - N14-06 exit code 識別後のログ集約と、連続失敗時のオペレーター通知手段
  - 提出当日に roundtrip が失敗した場合のバックアップ経路（例: 手動 docx→PDF）
  - 複数の担当者が共同で roundtrip を走らせた場合の Google Drive 排他

### 6. パッケージング・配信スクリプト

- `scripts/create_package.sh` / `scripts/sync_gdrive.sh` / `scripts/collab_watcher.sh`
- **チェック観点**:
  - create_package.sh が CLAUDE.md 記載の提出書類一覧と対応しているか
  - パッケージング時のチェックリスト（サイズ・ページ数・必須書類）の実装状況
  - 共同執筆ワークフロー（`collab_watcher.sh` ＋ `scripts/collab/README_使い方.md`）が
    本番提出前に共同研究者と通じるか

### 7. 未追跡ファイルの位置づけ

- `pyproject.toml` / `uv.lock`
- `data/original/`
- `.claude/`
- **チェック観点**:
  - `pyproject.toml` / `uv.lock` の導入経緯、.gitignore への影響、RUNNER=uv との整合
  - `data/original/` の内容と `data/source/` との違い（命名混乱）、gitignore 扱い
  - `.claude/` が共有されるリスク（settings.local.json 等の機微情報）

### 8. 未コミット変更の棚卸し

- 本セッション開始時点で既に未コミットだった 6 ファイル（CLAUDE.md / dummy YAML 3 点 /
  step4plan.md / fill_forms.py / reference.docx）
- 本セッションで追加変更: docs/prompts.md
- **チェック観点**:
  - それぞれの変更意図の妥当性（diff レベルで精査）
  - コミット単位としての健全性（まとめて 1 コミットで良いか、分割すべきか）
  - `templates/reference.docx` のスタイル定義変更が全 narrative docx に与える影響
  - `fill_forms.py` の変更内容と既存テストへの影響

### 9. report14 残存項目の再評価

- I14-01（lxml 移行）: 提出前 33 日時点で着手すべきか、現行の fully-qualified +
  ヘッダーコメントで凍結するか
- I14-02（wp:docPr 英語名、pandoc rId 飛び番、mermaid fontSize、crossref anchor）:
  提出直前に顕在化するリスクの再評価
- N14-02（`copy_media _n1` rename）: M14-04 ガードで inactive 化した前提が崩れる
  シナリオ

### 10. 提出日からの逆算スケジュール

- 2026-05-20 までの残 33 日で必要なマイルストーン:
  - 本文完成（youshiki1_2.md / youshiki1_3.md）
  - 全 YAML の実データ化
  - 最終 roundtrip 実行 + 目視確認
  - e-Rad 提出フォームの入力 / 添付 / 提出完了
  - 組織内の申請承認プロセス（京大の場合の URA / 会計課等の事前確認）
- **チェック観点**:
  - スケジュールに対して残作業が収まるか、クリティカルパスの特定
  - 最終 PDF 確定から e-Rad 提出までの buffer 時間
  - Windows 機のダウンタイムが直前に発生した場合のリカバリ手段

## 参照すべき資料

| ファイル | 確認ポイント |
|---------|------------|
| `CLAUDE.md` | プロジェクト全体方針、提出書類一覧、本セッションで変更有 |
| `SPEC.md` / `README.md` | 仕様と運用手順の整合 |
| `scripts/build.sh` | 全 6 ステップの実装、M14-04 inject ガード、RUNNER 分岐 |
| `scripts/create_package.sh` | 提出パッケージング・バリデーション |
| `scripts/roundtrip.sh` | rclone retry、Phase 4 polling、M14-05 / N14-05 修正状態 |
| `scripts/sync_gdrive.sh` | Google Drive 同期仕様 |
| `scripts/collab_watcher.sh` / `scripts/collab/README_使い方.md` | 共同執筆フロー |
| `scripts/validate_yaml.py` | YAML バリデーション網羅性 |
| `scripts/windows/watch-and-convert.ps1` | N14-06 switch、exit code、マクロ保存動作 |
| `main/step02_docx/fill_forms.py` | 本セッションで未コミット変更あり |
| `main/step02_docx/inject_narrative.py` | M14-01 / M14-02 修正後の状態 |
| `main/step02_docx/wrap_textbox.py` | N14-01 / N14-03 ヘッダーコメント |
| `main/step02_docx/fill_security.py` | 別紙5 / 別添の応募時混入リスク |
| `main/step03_excel/fill_excel.py` | 様式6 / 7 / 8 生成 |
| `main/00_setup/*.yaml` | 実データ化進捗、dummy との差異 |
| `data/dummy/*.yaml` | 本セッションで未コミット変更あり、E2E 整合性 |
| `docs/prompts.md` | Prompt 10-5 完了チェック更新 |
| `docs/step4plan.md` | 本セッションで未コミット変更あり |
| `docs/plan2.md` | §9 / §11 / §12 のリスク表現 |
| `docs/__archives/report14.md` | 前回指摘、**レビュー後に突合** |
| `pyproject.toml` / `uv.lock` | 未追跡、導入経緯確認 |
| `.gitignore` | 未追跡ファイルとの整合 |

## 出力フォーマット

`docs/report15.md` に以下の形式で出力してください:

```markdown
# 敵対的レビュー報告書（第15回）— 提出前の最終健全性チェック

レビュー実施日: YYYY-MM-DD
レビュー対象: （対象ファイル一覧）
前回レビュー: docs/__archives/report14.md (2026-04-17)

## サマリ

- Critical: N件 (新規N / 既知未対応N)
- Major: N件 (新規N / 既知未対応N)
- Minor: N件 (新規N / 既知未対応N)
- Info: N件

### 対応状況一覧

| ID | 重大度 | 状態 | 概要 |
|----|--------|------|------|
| C15-01 | Critical | ... | ... |

## report14.md との差分サマリ

- 前回の未対応項目で今回解消されたもの: N件
- 前回の未対応項目で依然として未対応のもの: N件
- 前回に記載がなく今回新規発見したもの: N件
- 前回の判断が本セッションの状態変化により陳腐化したもの: N件

## 指摘事項

### [C15-01] (Critical) タイトル
- **箇所**: ファイル名:行番号 or セクション名
- **前回対応状況**: 新規 / report14.md [C14-XX] 対応済み / 未対応 / 陳腐化
- **内容**: 具体的な問題の説明
- **影響**: この問題が放置された場合に起きること
- **推奨対応**: 修正方針

## リスクマトリクス

| リスク | 影響度 | 発生確率 | 総合評価 | 対策 |
|--------|--------|---------|---------|------|
| ... | 高/中/低 | 高/中/低 | Critical/Major/Minor | ... |
```

重大度の基準:
- **Critical**: 提出不能または提出書類に致命的欠陥（Type A 要件違反、必須書類欠落、
  ファイルサイズ / ページ数超過等）
- **Major**: 提出品質に重大な影響、または提出直前に手戻りが発生
- **Minor**: 修正すべきだが提出作業を進めながら並行対応可能
- **Info**: 改善推奨だが現状でも提出可能

ID 体系: C15-01, M15-01, N15-01, I15-01（NN=15 固定、XX=01 起点のゼロパディング）
