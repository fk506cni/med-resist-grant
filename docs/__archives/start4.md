# セッション開始プロンプト: 敵対的レビュー（第4回）

以下の指示に従い、本プロジェクトの実装準備状況と資料整備状況について敵対的レビューを行ってください。レビュー結果は `docs/report4.md` に出力してください。

## レビュー方針

- **実装を開始しないでください。** レビューと指摘、およびその対応のみを行います。
- **研究内容のレビューは不要です。** refs/ 以下の研究資料には触れないでください。
- **敵対的に検証してください。** 「うまくいきそう」ではなく「どこで壊れるか」を探してください。
- **docs/report3.md を読まずに**独立してレビューを行い、レポート作成時に report3.md と突き合わせて所見を統合してください。
- レビュー結果は docs/report4.md に、重大度（Critical / Major / Minor / Note）付きで出力してください。
- 前回レビューとの差分（新規発見 / 既知だが未対応 / 前回から改善済み）を明示してください。

## 前回からの主な変化

- Step 1（メタデータYAML定義）が全4ファイル完了:
  - config.yaml（プロジェクト設定・予算）
  - researchers.yaml（研究者情報・CV）
  - other_funding.yaml（他制度応募・受入状況 — 様式3-1/3-2用）
  - security.yaml（セキュリティ情報 — 別紙5/別添用）
- docs/prompts.md の Prompt 1-1〜1-3 完了チェックが全て完了済み
- Docker環境は前回レビュー時点で構築済み（Prompt 0-1完了）

## レビュー対象

### 1. 4つのYAMLファイル間の整合性検証

main/00_setup/ の4ファイルが**相互に矛盾なく、下流スクリプト（fill_forms.py, fill_security.py, fill_excel.py）から利用可能な設計になっているか**を検証してください:

- **研究者名の一致**: researchers.yaml の `pi.name_ja` / `co_investigators[].name_ja` が、other_funding.yaml / security.yaml で参照されている研究者名と完全一致するか
- **機関名の一致**: config.yaml の `lead_institution.name` / `sub_institutions[].name` が、researchers.yaml の `pi.affiliation` / `co_investigators[].institution` / security.yaml の `due_diligence` の機関名と整合するか
- **エフォートの整合**: researchers.yaml の `effort_percent` と other_funding.yaml のエフォート合算が100%を超えないか（本課題分 + 他制度分）
- **研究者リストの網羅性**: security.yaml の `researchers` キーが、PI + 全co_investigatorsを網羅しているか

### 2. YAMLスキーマと様式テーブルの完全突合

各YAMLのフィールドが**実際の様式テーブルの全記入セルに1対1で対応しているか**、python-docxで様式ファイルをダンプして突合してください:

#### other_funding.yaml ↔ 様式3-1/3-2（Tables 10-11）
- 8列の各セルに対応するYAMLフィールドがあるか
- Row 1（本研究課題）の自動記入に必要なデータが config.yaml / researchers.yaml から取得可能か
- confidential: true の場合に「配分機関等名と予算額を空欄にできる」ロジックが設計上考慮されているか

#### security.yaml ↔ 別紙5（24テーブル）
- **Table 0（提案情報）**: PI氏名/所属/課題名は config.yaml / researchers.yaml から自動取得可能か
- **Tables 1-2（DD状況チェックボックス）**: due_diligence セクションの構造で全選択肢を表現できるか
- **Tables 3-15（13項目）**: 各テーブルの列構成（2列/3列/5列）が researchers セクションのフィールド構造と一致するか
  - 特に5列テーブル（③研究費、④報酬、⑤論文、⑥特許）のフィールド名と列ヘッダの対応
- **Table 16（DD結果）**: result フィールドの選択肢が実際のチェックボックスと一致するか
- **Tables 17-23（§2-§4）**: risk_assessment / consent セクションで全チェックボックスをカバーできるか

#### security.yaml ↔ 別添（13テーブル）
- 別紙5の13項目テーブルと別添の13項目テーブルが**同一データソース**で記入可能な設計か
- 別添は**研究者ごとに1ファイル生成**される — researchers セクションのデータだけで個別ファイル生成が可能か

### 3. prompts.md の Step 2〜3 プロンプト品質検証

次の実装フェーズ（Step 2: Markdown本文、Step 3: Word/セキュリティ文書生成）のプロンプトが**そのままAIに渡して実装できるレベルか**を検証してください:

#### Step 2（本文Markdown）
- Prompt 2-1（様式1-2テンプレート）のセクション構成が data/source/r08youshiki1_5.docx の実際の様式1-2の指示テキストと一致するか
- Pandoc変換に必要な reference-doc の作成指示（Prompt 2-2）が十分か
- 様式1-3 のテンプレート作成プロンプトが存在するか

#### Step 3（Word文書生成）
- Prompt 3-1（fill_forms.py）のテーブルマッピングが実際の docx テーブルインデックスと一致するか
- fill_security.py の作成プロンプトが存在するか — 別紙5（24テーブル）と別添（13テーブル×人数分）のテーブルマッピングが指示されているか
- 各プロンプトが「入力YAML → テーブルセルへの書き込みルール」を具体的に定義しているか

### 4. ドキュメント間の整合性（再検証）

Step 1 完了を経た現在の4ファイルを突き合わせてください:
- `CLAUDE.md`
- `SPEC.md`
- `README.md`
- `docs/prompts.md`

特に:
- CLAUDE.md の Project Structure に other_funding.yaml / security.yaml が記載されているか
- SPEC.md §1.2 の「メタデータ」表と実際のファイル構成が一致するか
- prompts.md の Step 1 完了チェックが全て [x] になっているか
- 出力ファイル名のサフィックス規約（_filled, _narrative 等）が全ドキュメントで統一されているか

### 5. report3.md の残存指摘事項の確認（レポート作成時のみ）

レポート作成の最終段階で docs/report3.md を読み、以下を確認してください:
- 前回「未対応」とされた項目の現在の状況:
  - C3-05: ruamel.yaml C拡張
  - C3-06: templates/ ディレクトリと reference.docx
  - C3-08: 全実装ファイル未作成
  - C3-09: openpyxl Data Validation 拡張非対応
  - C3-10: openpyxl 条件付き書式破損リスク
  - C3-11: pyproject.toml 未作成
  - C3-12: data/dummy/ が空
  - C3-13: Dockerfile ruamel.yaml.clib
  - C3-14: E2E テスト用 Prompt 未存在
  - C3-16: orphan container 警告
- 今回のレビューで新規発見した問題と、前回の既知問題との重複・関連
- Step 1 YAML作成によって解消された問題があるか

### 6. リスクマトリクス（更新版）

Step 1 完了を踏まえ、残存リスクを再評価してください:

- **技術リスク**: python-docx/openpyxl/Pandocの技術的制約に起因するリスク
- **データ整合性リスク**: 4つのYAML間、およびYAMLと様式テーブル間の不整合リスク
- **要件リスク**: 募集要項の解釈誤りに起因するリスク
- **スケジュールリスク**: 提出期限(5/20)までの残り46日に対する残作業量のリスク
- **環境リスク**: Docker/Windows/Google Drive連携に起因するリスク

## 出力フォーマット

`docs/report4.md` に以下の形式で出力してください:

```markdown
# 敵対的レビュー報告書（第4回）

レビュー実施日: YYYY-MM-DD
レビュー対象: （対象ファイル一覧）
前回レビュー: docs/report3.md (2026-04-04)

## サマリ

- Critical: N件 (新規N / 既知未対応N)
- Major: N件 (新規N / 既知未対応N)
- Minor: N件 (新規N / 既知未対応N)
- Note: N件

### 対応状況一覧

| ID | 重大度 | 状態 | 概要 |
|----|------|------|------|
| C4-01 | Critical | ... | ... |

## report3.md との差分サマリ

- report3.md の未対応項目で今回解消されたもの: N件
- report3.md の未対応項目で依然として未対応のもの: N件
- report3.md に記載がなく今回新規発見したもの: N件

## 指摘事項

### [C4-01] (Critical) タイトル
- **箇所**: フ���イル名:行番号 or セクション名
- **前回対応状況**: 新規 / report3.md [C3-NN] 対応済み / report3.md [C3-NN] 未対応
- **内容**: 具体的な問題の説明
- **影響**: この問題が放置された場合に起きること
- **推奨対応**: 修正方針

## リスクマトリクス

| リスク | 影響度 | 発生確率 | 総合評価 | 対策 |
|-------|------|--------|--------|-----|
| ... | 高/中/低 | 高/中/低 | Critical/Major/Minor | ... |
```

重大度の基準:
- **Critical**: 実装がブロックされる、または提出物に致命的欠陥が生じる
- **Major**: 実装に手戻りが発生する、または提出物の品質に重大な影響がある
- **Minor**: 修正すべきだが実装を進めながら対応可能
- **Note**: 改善推奨だが現状でも問題なく進められる
