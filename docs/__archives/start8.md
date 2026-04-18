# セッション開始プロンプト: 敵対的レビュー（第08回）— Step 9 実装直前の最終確認

以下の指示に従い、Step 9（inject_narrative.py）実装に着手してよいかの最終判定を行ってください。report7 指摘事項への対応が正しく反映されたかの検証を含みます。レビュー結果は `docs/report8.md` に出力してください。

## レビュー方針

- **実装を開始しないでください。** レビューと指摘のみを行います。
- **研究計画書の論旨・内容のレビューは対象外です。** youshiki1_2.md / youshiki1_3.md の記述内容の妥当性は評価しないでください。
- **焦点は「report7 対応の検証」と「Step 9 実装開始の可否判定」です。**
- **敵対的に検証してください。** 「うまくいきそう」ではなく「どこで壊れるか」「何が足りないか」を探してください。
- **docs/report7.md を読まずに**独立してレビューを行い、レポート作成時に report7.md と突き合わせて所見を統合してください。
- レビュー結果は docs/report8.md に、重大度（Critical / Major / Minor / Info）付きで出力してください。
- 前回レビューとの差分（新規発見 / 既知だが未対応 / 前回から改善済み）を明示してください。

## 前回（report7.md）からの主な変化

report7.md の指摘に基づき以下を実施済み:

### コード修正
- **C7-08**: fill_forms.py の `DocxTable(new_tbl, doc)` → `DocxTable(new_tbl, doc.element.body)` に修正

### 設計文書修正
- **C7-01**: prompts.md Prompt 9-2 チェックリストに styles.xml マージを6番目の項目として追加
- **C7-09**: step4plan.md B-1 に footnotes.xml / endnotes.xml セクション（第6項）を追加
- **N7-04**: step4plan.md B-3「推奨アプローチ」→「必須」に変更
- **C7-10**: prompts.md Prompt 9-1 に Docker 実行環境指示を追加
- **C7-05**: prompts.md Prompt 9-4 に Linux 代替検証手段（python-docx 再読込 + LibreOffice）を追加

### プロジェクト文書修正
- **C7-02**: SPEC.md §3.1 出力テーブルを OOXML injection 方式に修正（narrative docx を中間ファイルと明記）
- **C7-04**: SPEC.md パイプライン図に inject_narrative.py ステップ追加、Step 02/04 記述更新
- **C7-07**: README.md 研究テーマを「サイバー攻撃×地域医療シミュレーション」に更新

### テストデータ拡充
- **C7-03**: data/dummy/ の researchers.yaml / security.yaml / other_funding.yaml に2人目の co-I（□□ □□）を追加
- E2E テスト（全5ステップ: validate/forms/narrative/security/excel）通過確認済み

### 環境整備
- **C7-06**: pyproject.toml を新規作成（RUNNER=uv での動作確認済み）

## レビュー対象

### 1. report7 指摘対応の検証（11件）

report7 で指摘された各項目の修正が**正しく・十分に**反映されているか検証してください:

#### C7-01 修正検証: styles.xml マージの追加
- `docs/prompts.md` Prompt 9-2 のチェックリスト（lines 524〜）に styles.xml の項目が追加されているか
- 追加された記述が step4plan.md B-3 と整合しているか
- fix_reference_styles.py への参照が含まれているか

#### C7-02 修正検証: SPEC.md §3.1 テーブル修正
- `SPEC.md` §3.1 の出力テーブルが OOXML injection 方式を反映しているか
- narrative docx が「中間ファイル」として記述されているか
- 脚注（lines 161-165）と矛盾がないか

#### C7-03 修正検証: ダミーデータ co-I 追加
- `data/dummy/researchers.yaml` に2人目の co-I が追加されているか
- `data/dummy/security.yaml` に対応するセキュリティ情報が追加されているか
- `data/dummy/other_funding.yaml` に対応するエントリがあるか
- 3つのYAMLファイル間で研究者名が一致しているか
- E2E テストで co-I=2 の状態で行追加・テーブル複製が実際に動作するか検証

#### C7-04 修正検証: SPEC.md パイプライン図
- パイプライン図に inject_narrative.py ステップが含まれているか
- Step 02 記述に inject_narrative.py が記載されているか
- Step 04 記述で narrative docx の除外が明記されているか

#### C7-05 修正検証: Linux 代替検証手段
- Prompt 9-4 に Linux 環境での代替検証手段が記述されているか
- 記述された手段（python-docx再読込、LibreOffice変換）は実用的か

#### C7-06 修正検証: pyproject.toml
- `pyproject.toml` が存在し、必要な依存関係が記述されているか
- Dockerfile の pip install と依存が一致しているか
- `RUNNER=uv` で実際にビルドが通るか

#### C7-07 修正検証: README.md テーマ更新
- README.md に新テーマ「サイバー攻撃×地域医療シミュレーション」が記載されているか

#### C7-08 修正検証: DocxTable コンストラクタ
- `fill_forms.py` の `DocxTable(new_tbl, doc.element.body)` が正しいか
- python-docx の Table コンストラクタで `doc.element.body` を parent として渡すことは妥当か

#### C7-09 修正検証: footnotes.xml 追加
- step4plan.md B-1 に footnotes.xml / endnotes.xml のセクションが追加されているか
- 記述内容（IDリナンバリング、参照書き換え、スキップ条件）は十分か

#### C7-10 修正検証: Docker 実行指示
- Prompt 9-1 に Docker 実行環境指示が含まれているか

#### N7-04 修正検証: B-3 必須化
- step4plan.md B-3 が「推奨」ではなく「必須」になっているか

### 2. step4plan.md の最終状態レビュー

修正後の step4plan.md が**そのまま実装の設計書として使えるレベルか**を検証してください:

- B-1（ZIPマージ）: 全パーツが網羅されているか。rIdリナンバリング・numbering ID リナンバリングのアルゴリズムは実装者にとって明確か
- B-2（セクションブレーク）: sectPr保護ポリシーは十分か。挿入ポイントとsectPrの位置関係の分析は具体的か
- B-3（スタイルマッピング）: マッピングテーブルの正確性。実装手順が明確か
- B-4（ルートタグ保存）: jami-abstract-pandoc の参照が正確か
- フォールバック計画: ピボット基準と代替方式の記述は十分か
- 作業順序・工数見積り: 現実的か

### 3. prompts.md Step 9 の最終状態レビュー

修正後の Prompt 9-1〜9-4 が**そのままAIに渡して実装できるレベルか**を検証してください:

- Prompt 9-1: 解析タスクの網羅性、出力フォーマット、Docker実行指示
- Prompt 9-2: 実装チェックリストの完全性（styles.xml含む6+項目）、エッジケース、jami参照テーブルの正確性、step4plan.md との整合性
- Prompt 9-3: build.sh / create_package.sh / generate_stubs.py への変更指示の具体性
- Prompt 9-4: 検証項目の網羅性、Linux代替手段

### 4. SPEC.md / CLAUDE.md / README.md の整合性

- SPEC.md の全セクションが step4plan.md の最新方針と整合しているか
- CLAUDE.md のプロジェクト構成・Tech Stack が最新か
- README.md が最新の研究テーマ・アーキテクチャを反映しているか
- 3ファイル間で矛盾する記述がないか

### 5. ビルドパイプラインの健全性

- E2E テスト（co-I=2のダミーデータ）で全ステップが通過しているか確認
- ダミー YAML と本番 YAML の構造整合性（キー名・階層構造の一致）
- validate_yaml.py が co-I=2 のデータを正しくバリデーションできるか
- generate_stubs.py のスタブが co-I=2 に対応しているか（テーブル行数等）
- pyproject.toml と Dockerfile の依存整合性

### 6. 提出期限までのスケジュールリスク

提出期限 2026-05-20 まで **45日** を切っている状況で:

- Step 9 実装に着手可能と判断できるか（設計・プロンプトの準備度）
- YAML メタデータの未完成度（N7-01）が提出にどの程度影響するか
- フォールバック（Windows COM / PDF結合）に移行した場合のスケジュール影響
- report7 以前からの継続課題（C5-04 rclone sync、C5-06 trigger.txt race 等）の影響度

## 参照すべき資料

| ファイル | 確認ポイント |
|---------|------------|
| `docs/step4plan.md` | B-1〜B-4 修正後の最終状態、フォールバック計画 |
| `docs/prompts.md` Step 9 | Prompt 9-1〜9-4 修正後の最終状態 |
| `main/step02_docx/fill_forms.py` | C7-08 修正（DocxTable コンストラクタ）、C6-02/C6-03 の修正コード |
| `main/step02_docx/fix_reference_styles.py` | スタイル定義パターン（C7-01 参照先） |
| `data/dummy/researchers.yaml` | C7-03 修正（2人目 co-I 追加） |
| `data/dummy/security.yaml` | C7-03 修正（2人目 co-I セキュリティ情報） |
| `data/dummy/other_funding.yaml` | C7-03 修正（2人目 co-I 他制度情報） |
| `data/dummy/generate_stubs.py` | スタブ生成が co-I=2 に対応しているか |
| `SPEC.md` | C7-02/C7-04 修正後の §2.1, §2.2, §3.1 |
| `CLAUDE.md` | プロジェクト構成の最新性 |
| `README.md` | C7-07 修正（テーマ更新） |
| `pyproject.toml` | C7-06 新規作成 |
| `scripts/build.sh` | ビルドパイプライン |
| `scripts/validate_yaml.py` | YAML バリデーション |
| `main/00_setup/*.yaml` | 本番 YAML（ダミーとの構造比較） |
| `/home/dryad/anal/jami-abstract-pandoc/scripts/wrap-textbox.py` | jami参照テーブルの行番号検証 |
| `templates/reference.docx` | Pandocスタイル定義 |

## 出力フォーマット

`docs/report8.md` に以下の形式で出力してください:

```markdown
# 敵対的レビュー報告書（第08回）— Step 9 実装直前の最終確認

レビュー実施日: YYYY-MM-DD
レビュー対象: （対象ファイル一覧）
前回レビュー: docs/report7.md (2026-04-05)

## サマリ

- Critical: N件 (新規N / 既知未対応N)
- Major: N件 (新規N / 既知未対応N)
- Minor: N件 (新規N / 既知未対応N)
- Info: N件

### 対応状況一覧

| ID | 重大度 | 状態 | 概要 |
|----|--------|------|------|
| C08-01 | Critical | ... | ... |

## report7.md との差分サマリ

- report7.md の未対応項目で今回解消されたもの: N件
- report7.md の未対応項目で依然として未対応のもの: N件
- report7.md で「対応済み」とされた項目で実際には不十分なもの: N件
- report7.md に記載がなく今回新規発見したもの: N件

## report7 指摘対応の検証結果

### 検証サマリ

| report7 ID | 重大度 | 対応内容 | 検証結果 | 残存問題 |
|------------|--------|---------|---------|---------|
| C7-01 | Critical | styles.xml追加 | ✓ OK / ✗ 不十分 | ... |
| C7-02 | Major | SPEC.mdテーブル | ✓ OK / ✗ 不十分 | ... |
| ... | ... | ... | ... | ... |

## 指摘事項

### [C08-01] (Critical) タイトル
- **箇所**: ファイル名:行番号 or セクション名
- **前回対応状況**: 新規 / report7.md [C7-NN] 対応済み / report7.md [C7-NN] 未対応 / report7.md [C7-NN] 対応不十分
- **内容**: 具体的な問題の説明
- **影響**: この問題が放置された場合に起きること
- **推奨対応**: 修正方針

## Step 9 実装開始の可否判定

### 判定結果: GO / CONDITIONAL GO / NO-GO

### 判定理由
（設計文書・プロンプト・パイプラインの準備状況を総合的に評価）

### GO条件（CONDITIONAL GOの場合）
（実装開始前に解消すべき残存課題のリスト）

### 推奨実装順序
（Prompt 9-1 → 9-2 → 9-3 → 9-4 の順序で問題ないか、変更すべき点があるか）

## リスクマトリクス

| リスク | 影響度 | 発生確率 | 総合評価 | 対策 |
|--------|--------|---------|---------|------|
| ... | 高/中/低 | 高/中/低 | Critical/Major/Minor | ... |
```

重大度の基準:
- **Critical**: 実装がブロックされる、または提出物に致命的欠陥が生じる
- **Major**: 実装に手戻りが発生する、または提出物の品質に重大な影響がある
- **Minor**: 修正すべきだが実装を進めながら対応可能
- **Info**: 改善推奨だが現状でも問題なく進められる
