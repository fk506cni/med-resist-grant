# テンプレート構造解析レポート（Prompt 9-1）

**生成日**: 2026-04-05
**解析対象**:
- テンプレート: `main/step02_docx/output/youshiki1_5_filled.docx`（`data/source/r08youshiki1_5.docx` から fill_forms.py 経由で生成）
- 様式1-2 narrative: `main/step02_docx/output/youshiki1_2_narrative.docx`
- 様式1-3 narrative: `main/step02_docx/output/youshiki1_3_narrative.docx`

> **注意**: ダミーテンプレート（`data/dummy/r08youshiki1_5.docx`）は `generate_stubs.py` でテーブルのみ生成されたスタブであり、様式1-2/1-3のセクションが存在しない。本解析および inject_narrative.py は `data/source/` の実テンプレートから生成された出力を対象とする。

---

## A. テンプレート構造（youshiki1_5_filled.docx）

### A-1. 全体構成

| 項目 | 値 |
|------|---|
| body 子要素数 | 352 |
| sectPr 数 | 2（inline 1 + body-level 1）|
| ページサイズ | A4 (w=11906, h=16838 twips) |
| マージン | 上下左右 1418 twips (≒25mm) |
| ページ番号 | numberInDash |

### A-2. セクション境界一覧

| セクション | 開始インデックス | 終了インデックス | マーカーテキスト |
|-----------|----------------|----------------|----------------|
| 様式1-1 | 0 | 4 | （様式１－１） |
| *(inline sectPr)* | 4 | — | `w:type=continuous` |
| **様式1-2** | **5** | **129** | **（様式１－２）** |
| **様式1-3** | **130** | **176** | **（様式１－３）** |
| 様式2-1 | 177 | 201 | （様式２－１） |
| 様式2-2 | 202 | 232 | （様式２－２） |
| 様式3-1 | 233 | 259 | （様式３－１） |
| 様式3-2 | 260 | 286 | （様式３－２） |
| 様式4-1 | 287 | 291 | （様式４－１） |
| 様式4-2 | 292 | 299 | （様式４－２） |
| 参考様式 | 300 | 350 | 研究課題の応募・実施承諾書 |
| *(body sectPr)* | 351 | — | — |

### A-3. 様式1-2 セクション詳細（indices 5–129）

```
[  5] w:p     （様式１－２）                      ← KEEP: ヘッダ
[  6] w:p     (empty)                              ← KEEP
[  7] w:p     安全保障技術研究推進制度　研究課題申請書（詳細） ← KEEP
[  8] w:p     (empty)                              ← KEEP
[  9] w:p     研究課題名：　　　　　　　　　　　　　 ← KEEP（要記入）
[ 10] w:p     (empty)                              ← KEEP
[ 11] w:p     １．本研究の背景           ← DELETE: プレースホルダ開始
[ 12–15]      (empty × 4)
[ 16] w:p     ２．本研究の目的
[ 17–20]      (empty × 4)
[ 21] w:p     ３．本研究の最終目標および要素課題
[ 22–29]      (empty × 8)
[ 30] w:p     ４．最終目標に対する実施項目
[ 31–36]      (empty × 6)
[ 37] w:p     ５．最終目標の達成に係る検討状況と最終目標を達成する見込み
[ 38–51]      (empty × 14)
[ 52] w:p     ６．研究実施計画
[ 53] w:tbl   実施項目テーブル (5 rows)    ← 空テーブル
[ 54–60]      (empty/milestone × 7)
[ 61] w:p     ７．研究実施体制
[ 62] w:p     ７．１　研究者と実施内容
[ 63] w:tbl   研究者テーブル (4 rows)       ← 空テーブル
[ 64–81]      サブセクション + empty
[ 82] w:p     ７．２　分担研究機関が必要な理由...
[ 83–87]      (empty × 5)
[ 88] w:p     ７．３　研究者間の情報共有、連携体制
[ 89–96]      (empty × 8)
[ 97] w:p     ８．研究課題の最終目標...概要図
[ 98–129]     (empty × 32)                 ← DELETE: プレースホルダ終了
```

**挿入ポイント**: index [10]（`研究課題名：` の直後の空段落）の**後**に Pandoc コンテンツを挿入。
**削除範囲**: indices [11]–[129]（119要素）— 見出しプレースホルダ + 空段落 + 空テーブル。

### A-4. 様式1-3 セクション詳細（indices 130–176）

```
[130] w:p     （様式１－３）                      ← KEEP: ヘッダ
[131] w:p     追加説明事項                          ← KEEP
[132] w:p     (empty)                              ← KEEP
[133] w:p     研究課題名：　　　　　　　　　　　　　 ← KEEP（要記入）
[134] w:p     (empty)                              ← KEEP
[135] w:p     （１）研究テーマとの整合性  ← DELETE: プレースホルダ開始
[136–140]     (empty × 5)
[141] w:p     （２）新規性、独創性又は革新性
[142–146]     (empty × 5)
[147] w:p     （３）波及効果
[148–152]     (empty × 5)
[153] w:p     （４）所要経費及び研究期間の妥当性
[154–160]     (empty × 7)
[161] w:p     （５）研究代表者の能力
[162–176]     (empty × 15)                 ← DELETE: プレースホルダ終了
```

**挿入ポイント**: index [134]の**後**に Pandoc コンテンツを挿入。
**削除範囲**: indices [135]–[176]（42要素）。

### A-5. セクション検出のためのテキストパターン

inject_narrative.py はハードコードされたインデックスではなく、以下のテキストパターンで検出すること:

| 対象 | 検出パターン | 用途 |
|------|-------------|------|
| 様式1-2 ヘッダ | `（様式１－２）` を含む段落 | セクション開始 |
| 様式1-2 プレースホルダ開始 | ヘッダ後、`１．` で始まる最初の段落 | 削除範囲の開始 |
| 様式1-3 ヘッダ | `（様式１－３）` を含む段落 | 様式1-2 の終端 & 様式1-3 の開始 |
| 様式1-3 プレースホルダ開始 | ヘッダ後、`（１）` で始まる最初の段落 | 削除範囲の開始 |
| 様式2-1 ヘッダ | `（様式２－１）` を含む段落 | 様式1-3 の終端 |

**ロジック**:
```
様式1-2 の保持範囲: [様式1-2 ヘッダ] ～ [ヘッダ後 "１．" の直前]
様式1-2 の削除範囲: ["１．" 段落] ～ [様式1-3 ヘッダの直前]
様式1-3 の保持範囲: [様式1-3 ヘッダ] ～ [ヘッダ後 "（１）" の直前]
様式1-3 の削除範囲: ["（１）" 段落] ～ [様式2-1 ヘッダの直前]
```

### A-6. w:sectPr 詳細

#### Inline sectPr（paragraph [4]）

```xml
<w:sectPr>
  <w:footerReference w:type="default" r:id="rId8" />
  <w:type w:val="continuous" />
  <w:pgSz w:w="11906" w:h="16838" w:code="9" />
  <w:pgMar w:top="1418" w:right="1418" w:bottom="1418"
           w:left="1418" w:header="851" w:footer="567" w:gutter="0" />
  <w:pgNumType w:fmt="numberInDash" />
  <w:cols w:space="425" />
  <w:docGrid w:type="linesAndChars" w:linePitch="291" w:charSpace="-3486" />
</w:sectPr>
```

- `w:type=continuous`: 連続セクション区切り（改ページなし）
- `w:footerReference rId8 → footer1.xml`: フッタあり
- ヘッダ参照なし（様式1-1 セクションにはヘッダ不要）

#### Body-level sectPr（element [351]）

```xml
<w:sectPr>
  <w:headerReference w:type="default" r:id="rId9" />
  <w:pgSz w:w="11906" w:h="16838" w:code="9" />
  <w:pgMar w:top="1418" w:right="1418" w:bottom="1418"
           w:left="1418" w:header="851" w:footer="567" w:gutter="0" />
  <w:pgNumType w:fmt="numberInDash" />
  <w:cols w:space="425" />
  <w:docGrid w:type="linesAndChars" w:linePitch="291" w:charSpace="-3486" />
</w:sectPr>
```

- `w:headerReference rId9 → header1.xml`: ヘッダあり
- ページ設定は inline sectPr と同一

### A-7. テンプレートのリレーションシップ

| rId | Type | Target |
|-----|------|--------|
| rId1 | customXml | ../customXml/item1.xml |
| rId2 | numbering | numbering.xml |
| rId3 | styles | styles.xml |
| rId4 | settings | settings.xml |
| rId5 | webSettings | webSettings.xml |
| rId6 | footnotes | footnotes.xml |
| rId7 | endnotes | endnotes.xml |
| rId8 | footer | footer1.xml |
| rId9 | header | header1.xml |
| rId10 | fontTable | fontTable.xml |
| rId11 | theme | theme/theme1.xml |

**既存の最大 rId**: rId11。Pandoc からのリレーションシップは rId12 以降を使用すること。

### A-8. テンプレートのスタイル一覧（様式1-2/1-3 で使用されるもの）

| styleId | Name | 用途 |
|---------|------|------|
| aff0 | 公募要領：タイトル２　節項 | セクション見出し（１．本研究の背景 等） |
| aff6 | 公募要領：本文１ | 本文段落 |
| aff9 | 公募要領：タイトル３　目 | サブセクション見出し（７．１ 等） |
| aff3 | 公募要領：注意書き　表 | テーブル注記 |
| Default | Default | 様式ヘッダ |
| af7 | Table Grid | テーブル |

---

## B. Narrative 構造（Pandoc 出力）

### B-1. youshiki1_2_narrative.docx

| 項目 | 値 |
|------|---|
| body 子要素数 | 211 |
| うち w:p | ~200 |
| うち w:tbl | 1（5 rows — 実施計画テーブル） |
| うち w:bookmarkStart/End | 多数 |
| 末尾 w:sectPr | 1（**挿入時に除外すること**） |

#### 使用スタイル名

| Pandoc スタイル | テンプレート対応 |
|---------|----------------|
| Heading1 | → aff0（公募要領：タイトル２　節項） |
| Heading2 | → aff9（公募要領：タイトル３　目） |
| Heading3 | → aff9 or 独自追加 |
| FirstParagraph | → aff6（公募要領：本文１） |
| BodyText | → aff6（公募要領：本文１） |
| Compact | → aff6（公募要領：本文１）+ numPr |
| SourceCode | → 独自追加が必要 |
| Table | → af7（Table Grid） |

#### リレーションシップ

| rId | Type | Target |
|-----|------|--------|
| rId1 | numbering | numbering.xml |
| rId2 | styles | styles.xml |
| rId3 | settings | settings.xml |
| rId4 | webSettings | webSettings.xml |
| rId5 | fontTable | fontTable.xml |
| rId6 | theme | theme/theme1.xml |
| rId7 | footnotes | footnotes.xml |
| rId8 | comments | comments.xml |

**画像**: なし。**ハイパーリンク**: なし。

#### numbering.xml

| 種別 | abstractNumId | numId 数 | 用途 |
|------|--------------|---------|------|
| Bullet (空白) | 990 | 1 (numId=1000) | Pandoc内部用 |
| Decimal | 99411 | 4 (numId=1001–1004) | 番号付きリスト |
| Bullet (●/○) | 991 | 14 (numId=1005–1018) | 箇条書きリスト |

**numId range**: 1000–1018。テンプレートの numbering.xml との衝突を確認すること。

#### footnotes.xml

separator + continuationSeparator のみ。**実質的な脚注なし** — 移植不要。

### B-2. youshiki1_3_narrative.docx

| 項目 | 値 |
|------|---|
| body 子要素数 | 64 |
| うち w:p | ~60 |
| うち w:tbl | 0 |
| 末尾 w:sectPr | 1（**挿入時に除外すること**） |

#### 使用スタイル名

Heading1, Heading2, FirstParagraph, BodyText, Compact（Heading3/SourceCode は未使用）

#### numbering.xml

| 種別 | abstractNumId | numId 数 |
|------|--------------|---------|
| Bullet (空白) | 990 | 1 (numId=1000) |
| Decimal | 99411 | 2 (numId=1001, 1004) |
| Bullet (●/○) | 991 | 3 (numId=1002, 1003, 1005) |

**numId range**: 1000–1005。

画像: なし。脚注: separator のみ。

### B-3. Pandoc styles.xml（両ファイル共通）

81 スタイル定義（reference.docx に基づく）。主要なもの:
- Normal, BodyText, FirstParagraph, Compact
- Heading1–9
- Table, SourceCode
- syntax highlight 用 character スタイル多数

---

## C. 挿入戦略まとめ

### C-1. 処理フロー

```
1. youshiki1_5_filled.docx を ZIP として開く
2. word/document.xml をパース

3. 様式1-2:
   a. テキスト検索で「（様式１－２）」段落を特定
   b. その後の「１．」で始まる段落を特定 → 削除開始点
   c. テキスト検索で「（様式１－３）」段落を特定 → 削除終了点の直前
   d. 削除開始点〜終了直前のbody要素をすべて削除
   e. youshiki1_2_narrative.docx の body 要素（末尾sectPr除外）を挿入

4. 様式1-3:
   a. テキスト検索で「（様式１－３）」段落を特定
   b. その後の「（１）」で始まる段落を特定 → 削除開始点
   c. テキスト検索で「（様式２－１）」段落を特定 → 削除終了点の直前
   d. 同様に削除＋挿入

5. リレーションシップ統合:
   - narrative の rId を rId12 以降にリナンバリング
   - 両narrative分のリレーションシップを追加

6. numbering.xml 統合:
   - テンプレートの既存 numId/abstractNumId の最大値を取得
   - narrative の numbering 定義をリナンバリングして追加
   - body 要素内の numPr 参照を新 ID に書き換え

7. styles.xml 統合:
   - Pandoc スタイル定義をテンプレートの styles.xml に追加
   - テンプレートに既存のスタイル ID と衝突しないことを確認

8. ルートタグ保存 (Step B-4):
   - <w:document> タグを正規表現で保存し、シリアライズ後に復元

9. ZIP 書き出し（atomic write）
```

### C-2. 注意事項

1. **sectPr の保護**: inline sectPr（[4]）と body-level sectPr（[351]）は絶対に変更・削除しない
2. **末尾 sectPr の除外**: Pandoc 出力の末尾 `w:sectPr` は挿入時に除外すること
3. **bookmarkStart/End**: Pandoc 出力には多数の bookmark 要素が含まれる。body 要素として扱い、そのまま挿入して問題ないが、ID衝突の可能性がある場合はリナンバリング
4. **研究課題名の記入**: [9] と [133] の「研究課題名：」は inject_narrative.py で YAML の `project.title` から記入することを検討
5. **ダミービルドでのテスト不可**: ダミーテンプレートには様式1-2/1-3 セクションがないため、inject のテストには `DATA_DIR=data/source` でのビルドが必須
6. **画像なし**: 現時点では両 narrative に画像がないため、word/media/ コピーと [Content_Types].xml 更新はスキップ可能（将来の画像追加時に実装）
7. **脚注の移植不要**: 両 narrative とも実質的な脚注がない（separator のみ）
