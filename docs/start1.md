# セッション開始プロンプト: 敵対的レビュー

以下の指示に従い、本プロジェクトの実装準備状況と資料整備状況について敵対的レビューを行ってください。レビュー結果は `docs/report1.md` に出力してください。

## レビュー方針

- **実装を開始しないでください。** レビューと指摘のみを行います。
- **研究内容のレビューは不要です。** refs/ 以下の研究資料には触れないでください。
- **敵対的に検証してください。** 「うまくいきそう」ではなく「どこで壊れるか」を探してください。
- レビュー結果は docs/report1.md に、重大度（Critical / Major / Minor / Note）付きで出力してください。

## レビュー対象

### 1. ドキュメント間の整合性

以下の4ファイルを突き合わせ、矛盾・不整合・記載漏れを洗い出してください:

- `CLAUDE.md`
- `SPEC.md`
- `README.md`
- `docs/prompts.md`

確認観点:
- ファイルパス・ディレクトリ名は全ドキュメントで一致しているか
- Tech Stack、提出書類一覧、パイプライン構成に矛盾がないか
- ステップ番号・名称がドキュメント間で一致しているか
- 同期先の記述（Google Drive / rclone gdrive）が統一されているか

### 2. 提出要件の網羅性

`data/source/募集要項.pdf` を読み、以下を検証してください:

- 提出書類一覧（CLAUDE.md/SPEC.md記載）に漏れがないか
- 各書類の提出形式（PDF/Excel）が正しいか
- ファイルサイズ制約、ページ制約が正確か
- e-Radの提出方法に関する記述が正確か
- 審査基準（表2）の記述が正確か
- Type Aの予算上限・期間制約が正確か
- 応募資格要件の記述に漏れがないか

### 3. 様式ファイルの実構造との整合

`data/source/` の各ファイルを実際にPythonで開き、ドキュメント記載のテーブル数・行列数・シート構成が正確か検証してください:

```python
# 検証コード例
from docx import Document
import openpyxl

# docxファイルの実テーブル構造
for fname in ['r08youshiki1_5.docx', 'r08youshiki_besshi5.docx', 'r08youshiki_betten.docx']:
    doc = Document(f'data/source/{fname}')
    print(f"{fname}: {len(doc.tables)} tables, {len(doc.paragraphs)} paragraphs")
    for i, t in enumerate(doc.tables):
        print(f"  Table {i}: {len(t.rows)}rows x {len(t.columns)}cols")

# xlsxファイルの実構造
for fname in ['r08youshiki6.xlsx', 'r08youshiki7.xlsx', 'r08youshiki8.xlsx']:
    wb = openpyxl.load_workbook(f'data/source/{fname}')
    print(f"{fname}: sheets={wb.sheetnames}")
    for name in wb.sheetnames:
        ws = wb[name]
        print(f"  {name}: {ws.max_row}rows x {ws.max_column}cols")
```

SPEC.md や prompts.md に記載されている数値（「16テーブル」「24テーブル」「29列」等）が実際と一致するか確認してください。不一致があれば具体的な差分を報告してください。

### 4. prompts.md の実行可能性

各プロンプトについて以下を検証してください:

- **前提条件の欠落**: そのプロンプトを実行するために必要だが明示されていない前提はないか
- **参照ファイルの実在**: `## 参照` セクションで指定されたファイルパスが実在するか
- **調査コードの妥当性**: 埋め込まれたPythonコードが実際に動作するか（構文レベルで確認）
- **完了チェックの十分性**: 重要な検証項目が欠けていないか
- **ステップ間依存の明示**: あるステップの成果物が次のステップで必要だが、明示されていない依存はないか
- **曖昧な指示**: エージェントが判断に迷う可能性のある曖昧な記述はないか

### 5. アーキテクチャ上のリスク

以下の観点でリスクを評価してください:

- **python-docx の限界**: 複雑なテーブル（セル結合、ネスト）を python-docx で操作できるか。data/source/ の docx を実際に開いてセル結合の有無を確認すること
- **Pandoc reference-doc の制約**: 元の様式docxをreference-docとして使う場合、スタイル定義以外の内容（テーブル、ヘッダ等）がどう扱われるか
- **openpyxl の制約**: ドロップダウンバリデーション、条件付き書式、VBAマクロの維持可否。data/source/ の xlsx に実際にこれらが含まれているか確認すること
- **様式1-2の統合問題**: Pandocで生成した本文docxを、python-docxで記入済みの様式1-5 docxにどう統合するか。prompts.md にこの統合手順の記載があるか
- **文字コード・フォント**: docx/xlsx内の日本語テキストが正しく読み書きできるか
- **ファイルサイズ**: 画像を含む場合、3MB目標を達成できるか

### 6. ディレクトリ構造の現状

実際のディレクトリ構造（`find main/ -type f`）と、CLAUDE.md/SPEC.md記載の構造が一致しているか。
現在のstep01/, step02/, step03/ のディレクトリ名が設計（step01_narrative等）と一致しているか。
必要なディレクトリやファイルで未作成のものをリストアップしてください。

### 7. Git管理状況

- `.gitignore` の設定は十分か（output/, data/source/, .venv/ 等）
- 現在のgitステータス（未追跡ファイル、未コミット変更）
- コミットすべきだが未コミットのファイルがないか

## 出力フォーマット

`docs/report1.md` に以下の形式で出力してください:

```markdown
# 敵対的レビュー報告書

## サマリ

- Critical: N件
- Major: N件
- Minor: N件
- Note: N件

## 指摘事項

### [C-01] (Critical) タイトル
- **箇所**: ファイル名:行番号 or セクション名
- **内容**: 具体的な問題の説明
- **影響**: この問題が放置された場合に起きること
- **推奨対応**: 修正方針

### [M-01] (Major) タイトル
...

### [m-01] (Minor) タイトル
...

### [N-01] (Note) タイトル
...
```

重大度の基準:
- **Critical**: 実装がブロックされる、または提出物に致命的欠陥が生じる
- **Major**: 実装に手戻りが発生する、または提出物の品質に重大な影響がある
- **Minor**: 修正すべきだが実装を進めながら対応可能
- **Note**: 改善推奨だが現状でも問題なく進められる
