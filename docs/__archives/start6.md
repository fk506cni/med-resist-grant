# セッション開始プロンプト: 敵対的レビュー（第6回）— 書式統合の技術レビュー

以下の指示に従い、様式1-2/1-3 のテンプレート統合（Step 9）の実装計画・プロンプト設計、および関連するビルドパイプラインの問題点について敵対的レビューを行ってください。レビュー結果は `docs/report6.md` に出力してください。

## レビュー方針

- **実装を開始しないでください。** レビューと指摘のみを行います。
- **研究計画書の論旨・内容のレビューは対象外です。** youshiki1_2.md / youshiki1_3.md の記述内容の妥当性（背景の論理展開、先行研究の引用充実度、審査基準との整合等）は評価しないでください。
- **焦点は「書式統合の技術的実現可能性」です。** Pandoc生成の本文をテンプレートに挿入して1つのdocx/PDFにする処理が正しく動作するかを検証してください。
- **敵対的に検証してください。** 「うまくいきそう」ではなく「どこで壊れるか」を探してください。
- **docs/report5.md を読まずに**独立してレビューを行い、レポート作成時に report5.md と突き合わせて所見を統合してください。
- レビュー結果は docs/report6.md に、重大度（Critical / Major / Minor / Note）付きで出力してください。
- 前回レビューとの差分（新規発見 / 既知だが未対応 / 前回から改善済み）を明示してください。

## 前回（report5.md）からの主な変化

- 研究テーマ変更に伴い YAML 4ファイル・本文2ファイルを全面更新
- ビルド成功: validate/forms/narrative/security/excel 全OK、roundtrip.sh 完走
- **新たに判明した問題**: youshiki1_5_filled.pdf に空の様式1-2/1-3 セクションが残存し、Pandoc生成の本文が統合されていない
- step4plan.md 作成: テンプレート挿入方式による統合計画を策定
- docs/prompts.md に Step 9（Prompt 9-1〜9-4）を追加

## レビュー対象

### 1. 現在のビルド出力の問題分析

現在のパイプラインの出力を実際に検証し、問題の全容を把握してください:

#### youshiki1_5_filled.docx / PDF の構造
- python-docx で youshiki1_5_filled.docx の body 要素を列挙し、各様式セクションの配置を確認
- 空の様式1-2/1-3 セクションがどのような要素（段落、テーブル、セクションブレーク）で構成されているか
- 様式1-2 セクションの開始・終了境界を特定する際に使えるマーカー（テキストパターン、スタイル名等）
- fill_forms.py の「Deleted 41 elements from unnecessary sections」が何を削除しているか — 様式1-2/1-3 はなぜ削除対象から外れているのか

#### youshiki1_2_narrative.docx / youshiki1_3_narrative.docx の構造
- Pandoc が生成した docx の body 要素構成（段落、テーブル、画像等）
- 使用されているスタイル名（Heading 1, Body Text 等）
- テンプレート（r08youshiki1_5.docx）のスタイルとの互換性

#### co-investigator 行数不足
- `fill_forms.py:293: UserWarning: 様式1-1: not enough rows for all co-investigators` の原因
- co-I 3名に対してテンプレートの行数が不足 → 楠田の情報が欠落するか
- fill_forms.py のコードを読み、行追加ロジックの有無を確認

### 2. step4plan.md の技術的実現可能性

`docs/step4plan.md` の設計が**実装可能か**を、以下の観点から検証してください:

#### OOXML 操作の実現可能性
- python-docx + lxml で body 要素を別の docx からコピー・挿入する操作は技術的に可能か
- 具体的にどの lxml API（addnext, addprevious, append 等）を使うべきか
- 要素コピー時に名前空間（w:p, w:tbl, w:r 等）の問題が発生しないか

#### スタイル・リレーションシップの移植
- Pandoc docx のスタイル定義とテンプレートのスタイル定義が競合した場合の挙動
- 画像を含む場合の rId（リレーションシップID）の再割り当て手法
- ヘッダ/フッタ、ページ番号（セクションプロパティ）への影響
- セクションブレーク（w:sectPr）が挿入位置で発生する場合の処理

#### 書式崩壊リスクの評価
- SPEC.md に「python-docxでの文書結合は書式崩壊リスクが高いため採用しない」との記載がある
- step4plan.md はこの方針と矛盾するか、あるいは「文書結合」と「要素挿入」は異なるアプローチか
- 書式崩壊が発生する具体的なシナリオ（フォント変更、余白変更、表の崩れ等）を列挙
- リスク軽減策は十分か

### 3. prompts.md Step 9 プロンプト品質検証

Prompt 9-1〜9-4 が**そのままAIに渡して実装できるレベルか**を検証してください:

#### Prompt 9-1（テンプレート構造解析）
- 調査の指示が具体的か — 何を調べ、何を出力すべきか明確か
- 出力形式が後続の Prompt 9-2 で利用可能か

#### Prompt 9-2（inject_narrative.py 作成）
- 機能要件が十分に具体的か — 曖昧な部分はないか
- 技術的注意事項が実装者にとって有用か
- エッジケース（画像なし、テーブルのみ、空のナラティブ等）への言及があるか
- テスト方法の指示があるか
- jami-abstract-pandoc への参照が「参考にすること」だけで具体性に欠けないか

#### Prompt 9-3（ビルドパイプライン統合）
- build.sh への inject サブコマンド追加の指示が具体的か
- create_package.sh の変更指示が正確か
- E2Eテスト（data/dummy）で inject が動作するための前提条件が記述されているか

#### Prompt 9-4（統合テスト）
- 検証項目が網羅的か
- 「ページ番号が通しで振られている」の検証方法（Word側のセクション設定に依存）
- 失敗時のフォールバック手順があるか

#### Prompt 間の依存関係
- 各 Prompt の前提条件が明示されているか
- Prompt 9-1 の出力が Prompt 9-2 の入力として参照される旨が記載されているか

### 4. 代替アプローチの評価

step4plan.md で「不採用」とされた代替案を再評価してください:

#### 代替案A: PDF結合方式
- youshiki1_5_filled.pdf のページ1-2（様式1-1）+ youshiki1_2_narrative.pdf + youshiki1_3_narrative.pdf + youshiki1_5_filled.pdf のページ3+（様式2-1以降）をPDF結合ツール（pypdf等）で結合
- 利点: docx操作が不要、書式崩壊リスクがない
- 欠点: ページ番号の不連続、テンプレートヘッダの二重化
- これらの欠点は本当に致命的か？ ページ番号はPDFレベルで再設定可能か？

#### 代替案B: Windows側でのWord COM結合
- Windows の Word COM API で複数 docx を1つの PDF に統合出力
- watch-and-convert.ps1 / VBScript を拡張
- 利点: Word のレイアウトエンジンが整合性を保証
- 欠点: Windows依存、VBScript の複雑化

#### 代替案C: fill_forms.py でのdocx分割出力
- fill_forms.py を修正して youshiki1_1.docx（様式1-1のみ）と youshiki2_5.docx（様式2-1以降）を分離出力
- PDF結合: 1-1.pdf + 1-2.pdf + 1-3.pdf + 2-5.pdf
- テンプレートヘッダの二重化問題は解消されるか

### 5. jami-abstract-pandoc プロジェクトの実態調査

`/home/dryad/anal/jami-abstract-pandoc/` を実際に調査し、以下を確認してください:

- OOXML後処理のコード（Python/Lua/シェル）が存在するか
- どのような操作（段落挿入、スタイル変更、セクション操作等）を行っているか
- inject_narrative.py の参考になる具体的なコードパターンはあるか
- 同プロジェクトで「文書間の要素コピー」を行った実績はあるか

### 6. ビルドパイプライン周辺の問題

Step 9 以外のビルドパイプラインの問題点を検証してください:

- **旧テンプレートの残骸**: data/output/ に betten_01_yamada.docx, betten_02_suzuki.docx が残存 — build.sh clean で除去されるか
- **data/dummy/ の整合性**: YAML全面更新後、data/dummy/ のダミーYAMLとの乖離がE2Eテストに影響しないか
- **CLAUDE.md / SPEC.md の更新漏れ**: 研究テーマ変更に伴い、ドキュメントの記述が旧テーマ（薬剤耐性菌）のまま残っていないか

## 参照すべき資料

| ファイル | 確認ポイント |
|---------|------------|
| `docs/step4plan.md` | PDF統合実装計画 |
| `docs/prompts.md` Step 9 | Prompt 9-1〜9-4（ナラティブ挿入の実装プロンプト） |
| `main/step02_docx/fill_forms.py` | 既存のテーブル記入ロジック・クリーンアップ処理 |
| `main/step02_docx/build_narrative.sh` | Pandoc変換設定 |
| `main/step02_docx/output/youshiki1_5_filled.docx` | ビルド出力docx（空セクション残存） |
| `main/step02_docx/output/youshiki1_2_narrative.docx` | Pandoc出力docx |
| `data/source/r08youshiki1_5.docx` | オリジナルテンプレート |
| `data/products/youshiki1_5_filled.pdf` | ビルド出力PDF（空セクション残存を目視確認可能） |
| `/home/dryad/anal/jami-abstract-pandoc/` | OOXML後処理の参考プロジェクト |
| `scripts/build.sh` | ビルドスクリプト（inject フェーズ追加予定） |
| `scripts/create_package.sh` | パッケージングスクリプト |
| `scripts/windows/watch-and-convert.ps1` | Windows側PDF変換 |
| `SPEC.md` §3.1 | 出力仕様（「python-docxでの文書結合は書式崩壊リスクが高い」の記載） |
| `CLAUDE.md` | プロジェクト構成 |
| `templates/reference.docx` | Pandocスタイル定義 |

## 出力フォーマット

`docs/report6.md` に以下の形式で出力してください:

```markdown
# 敵対的レビュー報告書（第6回）— 書式統合の技術レビュー

レビュー実施日: YYYY-MM-DD
レビュー対象: （対象ファイル一覧）
前回レビュー: docs/report5.md (2026-04-05)

## サマリ

- Critical: N件 (新規N / 既知未対応N)
- Major: N件 (新規N / 既知未対応N)
- Minor: N件 (新規N / 既知未対応N)
- Note: N件

### 対応状況一覧

| ID | 重大度 | 状態 | 概要 |
|----|------|------|------|
| C6-01 | Critical | ... | ... |

## report5.md との差分サマリ

- report5.md の未対応項目で今回解消されたもの: N件
- report5.md の未対応項目で依然として未対応のもの: N件
- report5.md に記載がなく今回新規発見したもの: N件

## 指摘事項

### [C6-01] (Critical) タイトル
- **箇所**: ファイル名:行番号 or セクション名
- **前回対応状況**: 新規 / report5.md [C5-NN] 対応済み / report5.md [C5-NN] 未対応
- **内容**: 具体的な問題の説明
- **影響**: この問題が放置された場合に起きること
- **推奨対応**: 修正方針

## 代替アプローチ比較表

| 方式 | 書式崩壊リスク | 実装難度 | ページ番号 | テンプレート準拠 | 推奨度 |
|------|-------------|---------|----------|--------------|-------|
| OOXML挿入（step4plan.md） | ? | ? | ? | ? | ? |
| PDF結合 | ? | ? | ? | ? | ? |
| Windows COM結合 | ? | ? | ? | ? | ? |
| docx分割+PDF結合 | ? | ? | ? | ? | ? |

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
