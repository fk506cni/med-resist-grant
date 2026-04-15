# セッション開始プロンプト: 敵対的レビュー（第09回）— Step 10 設計レビュー

以下の指示に従い、Step 10（図表挿入：Mermaid→SVG + テキストボックス）の設計について敵対的レビューを行ってください。レビュー結果は `docs/report09.md` に出力してください。

## レビュー方針

- **実装を開始しないでください。** レビューと指摘のみを行います。
- **研究計画書本文（youshiki1_2.md / youshiki1_3.md の研究内容そのもの）はレビュー対象外です。**
- **焦点は「Step 10 図表挿入機能の設計妥当性と既存パイプライン非破壊性」です。**
- **敵対的に検証してください。** 「うまくいきそう」ではなく「どこで壊れるか」を探してください。
- **`docs/__archives/report8.md` を読まずに**独立してレビューを行い、レポート作成段階で report8.md と突き合わせて所見を統合してください。
- レビュー結果は `docs/report09.md` に、重大度（Critical / Major / Minor / Info）付きで出力してください。
- 前回レビュー（report8.md）との差分（新規発見 / 既知だが未対応 / 前回から改善済み）を明示してください。

## 前回（report8.md）からの主な変化

1. **Step 9 実装完了** — `main/step02_docx/inject_narrative.py` が完成し、Prompt 9-3 完了チェック全項目クリア（コミット `d491ae0`「Prompt 9-3 完了チェック全項目クリア（PDF確認済み）」）
2. **Step 10 設計策定** — `docs/plan2.md` 新規作成、`docs/prompts.md` に Prompt 10-1〜10-5 を追加。`docs/prompts_trash.md` に旧 Step 8-9 を退避
3. **参考プロジェクト追加** — 従来の `jami-abstract-pandoc` に加え、`/home/dryad/anal/next-gen-comp-paper/`（テキストボックス挿入）と `/home/dryad/anal/auto-eth-paper/`（Mermaid→SVG コンテナ）を移植元として導入する方針
4. **デモ素材配置** — `main/step01_narrative/figs/bg_hospital.jpg` を新規配置

## レビュー対象

### A. 設計ドキュメント

- `docs/plan2.md`（全文）
- `docs/prompts.md` の Step 10 セクション（Prompts 10-1〜10-5、完了チェック含む）

観点:

- 設計の前提条件と達成基準が明確か
- §13 のステップ・バイ・ステップ実装順序の依存関係が破綻していないか
- 文書間の整合性（plan2.md の章番号と prompts.md の参照、ファイルパスの正確性）

### B. 既存パイプライン非破壊性

特に `main/step02_docx/inject_narrative.py` を **無改修** で運用する想定の妥当性:

- `merge_rels` の `_COPY_REL_TYPES = {image, hyperlink}` がテキストボックス内 SVG（`asvg:svgBlob` の `r:embed`）を漏れなく拾えるか
- `copy_media` のリネーム規則（`*_nN.ext`）が衝突時に rels Target を正しく更新するか
- `merge_content_types` で svg の Default extension が確実に運搬されるか
- `merge_styles` / `merge_numbering` / `merge_footnotes` でテキストボックス入りドキュメントが破綻する条件はないか
- `wp:docPr/@id` 衝突によるオフセットずれリスク（テンプレート側の既存 docPr id 帯と wrap_textbox.py が採番する 1000/2000 番台の関係）
- `extract_root_tag` / `restore_root_tag` が wp / wps / asvg 名前空間を正しく保存できるか

### C. 移植元コードの簡略化方針

- `next-gen-comp-paper/filters/jami-style.lua` から JSEK本文 ラップ・OrderedList 番号化・`.grid` マーカー・`.svg→.svg.png` リネームを削除する判断の影響範囲
- `next-gen-comp-paper/scripts/wrap-textbox.py` から `apply_booktabs_borders` / `relocate_textbox_by_page` を削除する判断の影響範囲
- `relocate_textbox_by_page` を削除した場合のテキストボックス配置安定性（`anchor-h=column` / `anchor-v=paragraph` 既定での副作用）
- 移植によりオリジナルにあった既知バグや回避策を一緒に落としていないか

### D. Mermaid コンテナの統合

- `auto-eth-paper/docker/mermaid-svg/` をそのまま流用する妥当性
- `mmdc` の出力を `.pdf → .svg` に切り替えた際の SVG 内日本語フォント埋込（`fonts-noto-cjk` + `fonts-ipafont`）
- `docker/docker-compose.yml` に `mermaid` サービスを追加する際の既存 `python` サービスへの副作用（ボリュームマウント、ユーザ ID、environment）
- `.mmd → .svg` のキャッシュ（mtime 比較）が正しく機能する条件と失敗パターン
- 初回ビルド時間（chromium ダウンロード）の許容性と CI / 共同執筆者環境への影響
- mmdc puppeteer のサンドボックス無効化が seccomp / AppArmor 環境で問題を起こさないか

### E. ビルドパイプラインと E2E 非破壊性

- `build_narrative.sh` 改修により Phase A（mmd→svg）/ Lua filter / Phase C（wrap_textbox）が追加される際、テキストボックス未使用時の出力 docx の同一性（バイナリ diff or document.xml diff の予測）
- E2E テスト `RUNNER=docker DATA_DIR=data/dummy SETUP_DIR=data/dummy ./scripts/build.sh` が Step 10 導入後も通過する条件
- Word 2016+ 前提（`asvg:svgBlob` 利用）と LibreOffice レンダリング互換性の整合
- フォールバック PNG 生成（`rsvg-convert`）を将来 enhancement とする判断の妥当性
- `RUNNER=local` / `RUNNER=uv` 系の代替実行モードでの動作（mermaid コンテナ無しのフォールバック）

### F. リスク表の網羅性

- `docs/plan2.md §12` のリスクマトリクスに不足はないか
- chromium サンドボックス、フォント埋込、docPr id 衝突、`anchor-v=paragraph` の挙動、Word 2016 未満互換、Docker イメージビルド時間以外に見落としはないか
- Windows 側の word-to-pdf 変換で SVG / asvg:svgBlob が破壊されるリスク
- `roundtrip.sh` の rclone push / pull で SVG メディアが想定通り運搬されるか

### G. プロンプト設計の妥当性

- Prompts 10-1〜10-5 の依存関係宣言が正しく、後戻りの少ない順序か
- 各 Prompt の完了チェック項目が独立して検証可能（Pass/Fail を客観判定できる）か
- スモークテスト（Prompt 10-1 の `_smoke_test.mmd` / Prompt 10-2 の `/tmp/tb_smoke.docx`）が実効性のある検証になっているか
- Prompt 10-5 の検証項目で見落としているエッジケースはないか
- Prompt 内で参照されるファイルパス / コマンドが現状のリポジトリと一致しているか

## 参照すべき資料

| ファイル | 確認ポイント |
|---------|------------|
| `docs/plan2.md` | 全文（設計の根幹） |
| `docs/prompts.md`（Step 10 セクション） | Prompts 10-1〜10-5 と完了チェック |
| `docs/prompts_trash.md` | 退避された Step 8-9 を参照する場面で |
| `docs/__archives/report8.md` | レポート作成段階で突き合わせ（独立レビュー時は読まない） |
| `main/step02_docx/inject_narrative.py` | `merge_rels` / `copy_media` / `merge_content_types` の実装詳細 |
| `main/step02_docx/build_narrative.sh` | 改修対象スクリプトの現状 |
| `docker/docker-compose.yml` | mermaid サービス追加先 |
| `docker/python/Dockerfile` | 既存 python コンテナ構成 |
| `/home/dryad/anal/next-gen-comp-paper/filters/jami-style.lua` | Lua フィルタ移植元 |
| `/home/dryad/anal/next-gen-comp-paper/scripts/wrap-textbox.py` | wrap_textbox 移植元 |
| `/home/dryad/anal/auto-eth-paper/docker/mermaid-svg/` | mermaid コンテナ移植元 |
| `/home/dryad/anal/auto-eth-paper/Makefile` | mermaid + svg のビルド統合参考 |
| `CLAUDE.md` | プロジェクト制約 |
| `SPEC.md` | 入出力仕様 |
| `main/step01_narrative/youshiki1_2.md` | デモブロック挿入対象（本文論旨は対象外） |
| `main/step01_narrative/figs/bg_hospital.jpg` | デモ画像 |

## 出力フォーマット

`docs/report09.md` に以下の形式で出力してください:

````markdown
# 敵対的レビュー報告書（第09回）— Step 10 設計レビュー

レビュー実施日: YYYY-MM-DD
レビュー対象: docs/plan2.md, docs/prompts.md（Step 10）, main/step02_docx/inject_narrative.py,
              main/step02_docx/build_narrative.sh, docker/docker-compose.yml,
              /home/dryad/anal/next-gen-comp-paper/, /home/dryad/anal/auto-eth-paper/
前回レビュー: docs/__archives/report8.md (2026-04-06)

## サマリ

- Critical: N件 (新規N / 既知未対応N)
- Major: N件 (新規N / 既知未対応N)
- Minor: N件 (新規N / 既知未対応N)
- Info: N件

### 対応状況一覧

| ID | 重大度 | 状態 | 概要 |
|----|--------|------|------|
| C09-01 | Critical | ... | ... |

## report8.md との差分サマリ

- 前回の未対応項目で今回解消されたもの: N件
- 前回の未対応項目で依然として未対応のもの: N件
- 前回に記載がなく今回新規発見したもの: N件

## 指摘事項

### [C09-01] (Critical) タイトル
- **箇所**: ファイル名:行番号 or セクション名
- **前回対応状況**: 新規 / report8.md [C08-XX] 対応済み / 未対応
- **内容**: 具体的な問題の説明
- **影響**: この問題が放置された場合に起きること
- **推奨対応**: 修正方針

## リスクマトリクス

| リスク | 影響度 | 発生確率 | 総合評価 | 対策 |
|--------|--------|---------|---------|------|
| ... | 高/中/低 | 高/中/低 | Critical/Major/Minor | ... |
````

重大度の基準:

- **Critical**: 実装がブロックされる、または成果物に致命的欠陥が生じる
- **Major**: 実装に手戻りが発生する、または成果物の品質に重大な影響がある
- **Minor**: 修正すべきだが実装を進めながら対応可能
- **Info**: 改善推奨だが現状でも問題なく進められる
