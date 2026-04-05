# セッション開始プロンプト: 敵対的レビュー（第7回）— Step 9 実装前の最終準備レビュー

以下の指示に従い、Step 9（inject_narrative.py）の実装に着手する前の準備状況を包括的にレビューしてください。レビュー結果は `docs/report7.md` に出力してください。

## レビュー方針

- **実装を開始しないでください。** レビューと指摘のみを行います。
- **研究計画書の論旨・内容のレビューは対象外です。** youshiki1_2.md / youshiki1_3.md の記述内容の妥当性は評価しないでください。
- **焦点は「Step 9 実装の準備が整っているか」です。** 設計文書・プロンプト・コード・ビルドパイプラインを敵対的に検証し、実装着手前に解消すべき問題を洗い出してください。
- **敵対的に検証してください。** 「うまくいきそう」ではなく「どこで壊れるか」「何が足りないか」を探してください。
- **docs/report6.md を読まずに**独立してレビューを行い、レポート作成時に report6.md と突き合わせて所見を統合してください。
- レビュ���結果は docs/report7.md に、重大度（Critical / Major / Minor / Note）付きで出力してください。
- 前回レビューとの差分（新規発見 / 既知だが未対応 / 前回から改善済み）を明示してください。

## 前回（report6.md）からの主な変化

- report6.md の指摘に基づき以下を実施済み:
  - fill_forms.py: 共同研究者行の動的追加（C6-02）、様式4-2の複数co-I対応（C6-03）、様式2-2��ッダ削除修正（C6-10）
  - step4plan.md: ZIPレベルマージ仕様（Step B-1〜B-4）、セクションブレーク処理、スタイルマッピング、ルートタグ保存テクニック、フォールバック計画を追加
  - prompts.md Step 9: Prompt 9-1にPandoc出力解析追加、Prompt 9-2にエッジケース・atomic write・jami参照具体化追加、Prompt 9-3にダミーnarrative必須化追加、Prompt 9-4に検証項目5件追加
  - SPEC.md: OOXML要素挿入方式に更新（旧「python-docx文書結合は不採用」を改訂）
  - CLAUDE.md / SPEC.md / prompts.md: 研究テーマを新テーマに更新
- E2Eテスト（ダミーデータ）: validate/forms/narrative/security/excel 全OK

## レビュー対象

### 1. fill_forms.py の修正検証

report6 で実施した3つのコード修正が正しく動作するか検証してください:

#### C6-02 修正: 共同研究者行の動的追加
- `fill_forms.py` の該当コードを読み、ロジックの正確性を検証
- `copy.deepcopy(tbl.rows[-1]._element)` で行を複製する際、セル結合（vertically/horizontally merged cells）は正しくコピーされるか
- 行追加後の `tbl.cell(row, col)` アクセスでインデックスが正しいか
- テンプレートの様式1-1テーブルの最終行（row 19）の構造を確認 — 結合セルがある場合、それが複製されると不正���構造になる可能性
- 本番データ（3名co-I）で行が3行追加される動作をシミュレーション

#### C6-03 修正: 様式4-2の複数co-I対応
- `copy.deepcopy(tables["4-2"]._element)` + `addnext` のロジック検証
- `DocxTable(new_tbl, doc)` のラッパー生成が正しく動作するか — python-docx の Table コンストラクタの parent 引数の妥当性
- ページブレーク要素（`w:br w:type="page"`）の位置が正しいか
- delete_sections の様式4-2削除ロジック（`has_co` == False のケースのみ）と競合しないか
- 複製されたテーブルが delete_sections の走査範囲に入った場合の影響

#### C6-10 修正: 様式2-2ヘッダ削除の上方走査
- 上方走査（最大5要素遡行）のロジックが正しいか
- テンプレートの実際の構造で、ヘッダと表の間に何要素あるか確認
- `txt.strip()` による走査停止条件が適切か — 空でない非ヘッダ段落で止まるか

### 2. step4plan.md の改訂内容レビュー

report6 で大幅に拡充された step4plan.md ��技��仕様が**実装可能か**を検証してください:

#### Step B-1: ZIPレベルマージ仕様
- 5パーツ（document.xml, document.xml.rels, word/media/, word/numbering.xml, [Content_Types].xml）の処理仕様は網羅的か
- 漏れているパーツはないか（例: word/styles.xml のマージ、word/footnotes.xml、word/theme/）
- rIdリナンバリングのアルゴリズムが具体的に記述されているか
- numbering IDリナンバリングの手順が実装者にとって明確か

#### Step B-2: セクションブレーク処理
- 「テンプレート内のsectPrは絶対に削除・移動しない」というポリシーは十分か
- 挿入ポイントとsectPrの位置関係について、具体的なケース分析がされているか
- ヘッダ/フッタのリレーションシップが壊れないことの保証があるか

#### Step B-3: スタイルマッピング
- マッピングテーブルの内容が正確か — テンプレートの実際のスタイル名と合致しているか
- 「テンプレートのstyles.xmlにPandocスタイル定義を追加する」アプローチの具体的手順が記述されているか
- reference.docx のスタイル定義とテンプレートのスタイル定義の関係が明確か

#### Step B-4: ルートタグ保存
- jami-abstract-pandoc の該当コード（wrap-textbox.py:398-470）を実際に読み、記述された手法が正確か検証
- ElementTree 以外のXMLパーサ（lxml等）を使用した場合にも同じ問題が発生するか

#### フォールバック計画
- ピボット基準（「1週間以内に安定しなければWindows COM方式」）は具体的か
- Windows COM結合方式の実装方針が十分に記述されているか — ピボット時にスムーズに移行できるか

### 3. prompts.md Step 9 の改訂内容レビュー

修正後の Prompt 9-1〜9-4 が**そのままAIに渡して実装できるレベルか**を検証してください:

#### Prompt 9-1（テンプレート構造解析 + Pandoc出力解���）
- 追加された「B. Pandoc出力の構造解析」の調査項目が十分か
- 出力先が docs/template_analysis.md に変更された — ファイルフォーマットの指示はあるか
- 解析にはPythonコードの実行が必要 — Docker環境での実行指示が明確か

#### Prompt 9-2（inject_narrative.py の作成）
- stdlib `zipfile` + `xml.etree.ElementTree` への方針変更が一貫しているか — python-docx への言及が残っていないか
- エッジケースセクションの6項目は実装者にとって明確か
- jami-abstract-pandoc 参照テーブル（5項目）のファイル:行番号は正確か
- atomic write の指示が明確か — 具体的な実装パターン（tempfile → rename）の記載はあるか
- Step B-1〜B-4 との整合性 — Prompt 9-2 の指示と step4plan.md の仕様が矛盾していないか

#### Prompt 9-3（ビルドパイプライン統合）
- ダミーnarrative docx の「必須」化 — generate_stubs.py への具体的な変更指示は十分か
- build.sh の inject サブコマンドの引数・実行方式が明確か

#### Prompt 9-4（統合テスト）
- 追加された5検証項目（修復ダイアログ、画像、ハイパーリンク、空白ページ、ファイルサイズ）の検証方法が記述されているか
- 「Word修復ダイアログなし」の確認はWindows環境が必要 — Linux上での代替検証方法はあるか

### 4. SPEC.md / CLAUDE.md の整合性検証

- SPEC.md §3.1 の改訂内容が step4plan.md と整合しているか
- CLAUDE.md の研究テーマ・プロジェクト構成が最新状態か
- SPEC.md の他のセクションに、旧方針（PDF結合方式）の残存記述がないか
- README.md に旧テーマの記述が残っていないか

### 5. ビルドパイプライン全体の健全性

Step 9 以外のパイプライン問題を検証してください:

#### E2Eテストの網��性
- ダミーデータ（data/dummy/）でのE2Eテストがカバーしているステップと、カバーしていないステップ
- inject フェーズが未実装のため E2E テストに含まれていない — 現状のテスト範囲は十分か
- ダミーYAMLの構造が本番YAMLと一致しているか（report6で確認済みとされるが独立検証）

#### 本番データでのビルド
- main/00_setup/*.yaml のプレースホルダ（○○等）がビルドに影響しないか
- data/source/ のテンプレートファイルが存在する前提 — 開発環境でのビルド可能性

#### create_package.sh の整合性
- inject 実装前の現在の状態で create_package.sh は正しく動作するか
- inject 実装後に必要な create_package.sh の変更が明確に記述されているか

#### Windows PDF変換パイプライン
- watch-and-convert.ps1 は inject 後の統合 docx（様式1-2/1-3本文入り）を正しく処理できるか
- ファイルサイズ増大（本文+画像挿入後）が変換に影響しないか

### 6. 提出期限までの残タスク分析

提出期限 2026-05-20 まで **45日** を切っている。以下を評価してください:

- Step 9（inject_narrative.py）の実装＋テストに必要な工数（step4plan.md の見積り 10-15h は妥当か）
- youshiki1_2.md（最大15ページの研究計画）の執筆状況 — 現在の分量と完成度
- youshiki1_3.md の執筆状況
- main/00_setup/*.yaml のプレースホルダ記入状況（実データへの置換がどの程度進んでいるか）
- 本番ビルド → Windows PDF変換 → e-Rad提出 までの統合テストのスケジュール余裕
- Step 9 がフォールバック（Windows COM or PDF結合）に移行した場合のスケジュールへの影響

## 参照すべき資料

| ファイル | 確認ポイント |
|---------|------------|
| `docs/step4plan.md` | 改訂後のPDF統合実装計画（Step B-1〜B-4、フォールバック計画） |
| `docs/prompts.md` Step 9 | 改訂後の Prompt 9-1〜9-4 |
| `main/step02_docx/fill_forms.py` | C6-02/C6-03/C6-10 の修正コード |
| `main/step02_docx/build_narrative.sh` | Pandoc変換設定 |
| `main/step02_docx/fix_reference_styles.py` | reference.docx スタイル設定 |
| `main/step02_docx/output/youshiki1_5_filled.docx` | ビルド出力docx |
| `main/step02_docx/output/youshiki1_2_narrative.docx` | Pandoc出力docx |
| `main/step01_narrative/youshiki1_2.md` | 様式1-2 本文（執筆状況確認） |
| `main/step01_narrative/youshiki1_3.md` | 様式1-3 本文（執筆状況確認） |
| `main/00_setup/*.yaml` | メタデータ（プレースホルダ残存状況確認） |
| `data/dummy/*.yaml` | ダミーデータ（本番との構造整合性） |
| `data/source/r08youshiki1_5.docx` | オリジナルテンプレート（セル構造、sectPr確認） |
| `/home/dryad/anal/jami-abstract-pandoc/scripts/wrap-textbox.py` | ルートタグ保存テクニック（398-470行） |
| `scripts/build.sh` | ビルドスクリプト |
| `scripts/create_package.sh` | パッケージングスクリプト |
| `scripts/windows/watch-and-convert.ps1` | Windows側PDF変換 |
| `SPEC.md` | 改訂後の出力仕様 |
| `CLAUDE.md` | プロジェクト構成 |
| `templates/reference.docx` | Pandocスタイル定義 |

## 出力フォーマット

`docs/report7.md` に以下の形式で出力してください:

```markdown
# 敵対的レビュー報告書（第7回）— Step 9 実装前の最終準備レビュー

レビュー実施日: YYYY-MM-DD
レビュー対象: （対象ファイル一覧）
前回レビュー: docs/report6.md (2026-04-05)

## サマリ

- Critical: N件 (新規N / 既知未対応N)
- Major: N件 (新規N / 既知未対応N)
- Minor: N件 (新規N / 既知未対応N)
- Note: N件

### 対応状況一覧

| ID | 重大度 | 状態 | 概要 |
|----|--------|------|------|
| C7-01 | Critical | ... | ... |

## report6.md との差分サマリ

- report6.md の未対応項���で今回解消されたもの: N件
- report6.md の未対応項目で依然として未対応のもの: N件
- report6.md で「対応済み」とされた項目で実際には不十分なもの: N件
- report6.md に記載がなく今回新規発見したもの: N件

## 指摘事項

### [C7-01] (Critical) タイトル
- **箇所**: ファイル名:行番号 or セクション名
- **前回対応状況**: 新規 / report6.md [C6-NN] 対応済み / report6.md [C6-NN] 未対応 / report6.md [C6-NN] 対応不十分
- **内容**: 具体的な問題の説明
- **影響**: この問題が放置された場合に起きること
- **推奨対応**: 修正方針

## Step 9 ��装準備状況の総合評価

### 設計文書の充足度
（step4plan.md の仕���が実装開始に十分かの評価）

### プロンプトの実装可能性
（Prompt 9-1〜9-4 がAIに渡して動くかの評価）

### ビルドパイプラインの安定性
（現状のパイプラインに未解決の問題がないかの評価）

### 提出期限までのスケジュールリスク
（45日で全タスク完了可能かの評価）

## リスクマトリクス

| リスク | 影響度 | 発生確率 | 総合評価 | 対策 |
|--------|--------|---------|---------|------|
| ... | 高/中/低 | 高/中/低 | Critical/Major/Minor | ... |
```

重大度の基準:
- **Critical**: 実装がブロックされる、または提出物に致命的欠陥が生じる
- **Major**: 実装に手戻りが発生する、または提出物の品質に重大な影響がある
- **Minor**: 修正すべきだが実装を進めながら対応可能
- **Note**: 改善推奨だが現状でも問題なく進められる
