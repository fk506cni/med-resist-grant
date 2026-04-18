# step4plan.md — 様式1-2/1-3 の統合実装計画

## 現状の問題

### パイプラインの現状

```
r08youshiki1_5.docx（テンプレート）
  ├── 様式1-1（テーブル） → fill_forms.py が記入
  ├── 様式1-2（空のセクション見出しのみ） → 未処理（空のまま残る）
  ├── 様式1-3（空のセクション見出しのみ） → 未処理（空のまま残る）
  ├── 様式2-1〜4-2（テーブル） → fill_forms.py が記入
  ├── 様式5（テーブル） → fill_forms.py が記入
  └── 参考様式 → fill_forms.py が記入

youshiki1_2.md → Pandoc → youshiki1_2_narrative.docx（独立ファイル）
youshiki1_3.md → Pandoc → youshiki1_3_narrative.docx（独立ファイル）
```

### 問題点

1. **youshiki1_5_filled.docx** の中に空の様式1-2/1-3テンプレートセクションが残っている
2. **youshiki1_2_narrative.docx / youshiki1_3_narrative.docx** は別ファイルとして生成される
3. 提出時にはこれらを **1つのPDF** に結合する必要がある（募集要項）
4. 現在これを自動で結合する仕組みがない

### 現在の出力（youshiki1_5_filled.pdf のページ構成）

| ページ | 内容 | 状態 |
|--------|------|------|
| 1 | 様式1-1（記入済み） | OK |
| 2 | 様式1-1 続き（研究者リスト） | OK |
| 3 | 様式1-2 ヘッダ（空） | **NG: 本文が未挿入** |
| 4+ | 様式1-3 ヘッダ（空）〜 様式2-1 以降 | 1-3 は空、2-1 以降は OK |

## 設計方針

**テンプレートへの挿入方式を採用する。**

- r08youshiki1_5.docx のテンプレート構造（様式ヘッダ「（様式１−２）」等）を維持する
- 空の様式1-2/1-3 セクションにPandoc生成コンテンツを **挿入** する
- 最終的に youshiki1_5_filled.docx 1ファイルに全様式が含まれる状態にする

```
[提出用PDF]
  ├── 様式1-1（テーブル記入済み）
  ├── 様式1-2（テンプレートヘッダ + Pandoc本文が挿入済み）  ← NEW
  ├── 様式1-3（テンプレートヘッダ + Pandoc本文が挿入済み）  ← NEW
  ├── 様式2-1〜4-2（テーブル記入済み）
  ├── 様式5
  └── 参考様式
```

## 実装計画

### Step A: テンプレート構造の解析

**目的**: r08youshiki1_5.docx 内の様式1-2/1-3 セクションの開始・終了位置を特定する。

**作業内容**:
1. python-docx で r08youshiki1_5.docx の全段落・テーブルを列挙し、各様式セクションの境界を特定
2. 様式1-2の開始マーカー（「（様式１−２）」ヘッダ段落）と終了位置（様式1-3 or 様式2-1 の直前）を特定
3. 様式1-3の開始マーカーと終了位置を特定
4. 各セクション内に「ここに記載」等のプレースホルダ段落があるか確認

**成果物**: セクション境界の情報（段落インデックス or テキストパターン）

### Step B: ナラティブ挿入スクリプトの作成

**目的**: Pandoc 生成の narrative docx の本文を、youshiki1_5_filled.docx の該当セクションに挿入する。

**ファイル**: `main/step02_docx/inject_narrative.py`（新規作成）

**処理フロー**:
```
入力:
  - youshiki1_5_filled.docx（fill_forms.py の出力）
  - youshiki1_2_narrative.docx（Pandoc の出力）
  - youshiki1_3_narrative.docx（Pandoc の出力）

処理:
  1. youshiki1_5_filled.docx を読み込み
  2. 様式1-2 セクション内のプレースホルダ段落を削除
  3. 様式1-2 ヘッダ直後に youshiki1_2_narrative.docx の本文要素を挿入
  4. 様式1-3 セクションについても同様
  5. 保存（上書き or 別名）

出力:
  - youshiki1_5_filled.docx（様式1-2/1-3 の本文が挿入済み）
```

**技術的考慮事項**:
- python-docx での文書間要素コピーは書式崩壊リスクがある（SPEC.md で言及済み）
- **対策1**: OOXMLレベルでの直接操作 — python-docxの高レベルAPIではなく、stdlib `zipfile` + `xml.etree.ElementTree` でZIPアーカイブを直接操作する（jami-abstract-pandocと同じ方式）
- **対策2**: Pandoc 側で reference.docx のスタイル定義をテンプレートと統一し、スタイル競合を最小化
- **対策3**: 参考プロジェクト `/home/dryad/anal/jami-abstract-pandoc/` のOOXML後処理パターンから再利用可能なパターンを参照（後述の参考パターン一覧参照）
- **フォールバック**: OOXML挿入が1週間以内に安定しない場合、Windows COM結合方式にピボットする

### Step B-1: ZIPレベルマージ仕様

inject_narrative.py は以下の **ZIPパーツ** を��理する必要がある（※ styles.xml の処理は Step B-3 で別途規定）:

#### 1. word/document.xml — body 要素の移植
- ソースdocx（narrative）の `<w:body>` 子要素（`<w:p>`, `<w:tbl>` 等）をターゲットdocxの挿入ポイントにコピー
- **ソースの末尾 `<w:sectPr>` は除外する**（Pandocが必ず生成する。コピーするとターゲットにセクションブレークが挿入される）
- 挿入先のプレースホルダ段落を削除してから挿入

#### 2. word/_rels/document.xml.rels — リレーションシップ統合
- ソースdocxのrels内のリレーションシップ（画像=`rId*`, ハイパーリンク等）をターゲットに追加
- **rId衝突回避**: ターゲットの既存rIdの最大値を取得し、ソース側のrIdをリナンバリング
- コピーされたbody要素内のrId参照（`<a:blip r:embed="rIdX">` 等）を新IDに書き換え
- 画像がない場合はこのステップをスキップ

#### 3. word/media/ — メディアファイルコピー
- ソースdocxのZIP内 `word/media/` 配下のファイルをターゲットZIPにコピー
- ファイル名衝突時はリネーム（例: image1.png → image_n1.png）

#### 4. word/numbering.xml — リスト定義統合
- Pandocが番号付き/箇条書きリストを生成した場合、`word/numbering.xml` にリスト定義が含まれる
- ソースの `<w:abstractNum>` / `<w:num>` 定義をターゲットに追加
- `w:abstractNumId` / `w:numId` の衝突を回避するためリナンバリング
- コピーされたbody要素内の `<w:numPr>` 参照を新IDに書き換え
- ソースにnumbering.xmlがない場合はスキップ

#### 5. [Content_Types].xml — コンテンツタイプ登録
- ソースに新しいメディアタイプ（SVG, EMF等）がある場合、ターゲットの `[Content_Types].xml` に追加
- 重複するExtension/PartNameは追加しない

#### 6. word/footnotes.xml / word/endnotes.xml — 脚注・尾注統合（存在する場合のみ）
- Pandocが脚注構文（`[^1]`）を処理した場合、`word/footnotes.xml` に脚注定義が含まれる
- ソースの脚注定義をターゲットに追加（IDの衝突を回避するためリナンバリング）
- コピーされたbody要素内の脚注参照（`w:footnoteReference`）を新IDに書き換え
- ソースに footnotes.xml がない場合はスキップ

### Step B-2: セクションブレーク（w:sectPr）処理

- **Prompt 9-1 で各 sectPr の位置とプロパティを調査する** こと（ページ設定、ヘッダ/フッタ、ページ番号設定を含む）
- テンプレート内のsectPrは**絶対に削除・移動しない**（fill_forms.py の delete_sections と同じポリシー）
- 挿入対象のbody要素を取り出す際、ソースdocxの末尾sectPrを必ず除外
- 挿入ポイントがsectPr直前の場合、sectPrの前に要素を挿入（sectPr自体は移動しない）
- ヘッダ/フッタ: 各セクションの `w:headerReference` / `w:footerReference` が壊れないよう、sectPrの内容は変更しない

### Step B-3: スタイルマッピング

Pandoc docxとテンプレートdocxのスタイル体系が異なる:

| Pandoc docx | テンプレート docx | 対応方針 |
|---|---|---|
| Heading 1 | 公募要領：タイトル２　節項 | reference.docxでフォント・サイズを合わせる |
| Heading 2 | 公募要領：タイトル３　目 | 同上 |
| Body Text / First Paragraph | 公募要領：本文１ | 同上 |
| Compact | （対応なし） | Body Textと同じ定義にする |
| TableGrid | （テンプレート固有テーブルスタイル） | 要調査 |

**必須**: テンプレートの `word/styles.xml` にPandocスタイルの定義を追加する。
定義はテンプレートの既存スタイル（公募要領：本文１ 等）と同じフォント・サイズ・行間にする。
これにより、Pandoc側のスタイル名（Heading 1等）を変更せずにテンプレートの書式で表示される。

### Step B-4: ルートタグ保存（必須テクニック）

jami-abstract-pandocの `wrap-textbox.py:398-470` で実装されている重要なテクニック:
- ElementTreeはシリアライズ時に未使用の名前空間宣言を除去する
- Wordは特定の名前空間宣言が欠落したdocxを不正なファイルとして拒否する
- **対策**: シリアライズ前に `<w:document ...>` ルートタグを正規表現で保存し、シリアライズ後に復元する

### jami-abstract-pandocから再利用可能なパターン

| パターン | ファイル:行 | 用途 |
|---------|-----------|------|
| ZIPアーカイブI/O | wrap-textbox.py:754-759, 851-853 | docxの読み書き |
| 名前空間登録 | wrap-textbox.py:20-38 | OOXML全名前空間の `ET.register_namespace` |
| ルートタグ保存 | wrap-textbox.py:398-470 | `extract_root_tag()` / `restore_root_tag()` |
| body要素列挙・削除・挿入 | wrap-textbox.py:780-831 | `list(body)` → iterate → remove/insert |
| リレーションシップ操作 | wrap-textbox.py:660-751 | rId追加、Content_Types更新 |
| スタイル追加 | fix-reference-cols.py:90-172 | styles.xmlへのスタイル定義追加 |

**注意**: 上記はいずれも**単一文書内の操作**。文書間要素コピー（rIdリナンバリング、numbering統合）は新規実装が必要。

### Step C: ビルドパイプラインへの統合

**目的**: build.sh に inject_narrative.py を組み込む。

**変更対象**: `scripts/build.sh`

**処理順序の変更**:
```
現在:
  validate → forms → narrative → security → excel

変更後:
  validate → forms → narrative → inject → security → excel
                                   ↑ NEW
```

`inject` サブコマンド:
```bash
# build.sh に追加
phase_inject() {
    docker compose ... run --rm python \
        python main/step02_docx/inject_narrative.py \
            --template main/step02_docx/output/youshiki1_5_filled.docx \
            --youshiki12 main/step02_docx/output/youshiki1_2_narrative.docx \
            --youshiki13 main/step02_docx/output/youshiki1_3_narrative.docx \
            --output main/step02_docx/output/youshiki1_5_filled.docx
}
```

### Step D: create_package.sh / roundtrip.sh の更新

**変更内容**:
- `create_package.sh`: youshiki1_2_narrative.docx と youshiki1_3_narrative.docx を個別の必須ファイルから除外（youshiki1_5_filled.docx に統合済みのため）
- チェックリストの「手動確認項目」から PDF結合の手順を削除
- `roundtrip.sh`: 変更不要（youshiki1_5_filled.docx がそのまま push される）

### Step E: テスト・検証

1. **E2Eテスト**: `DATA_DIR=data/dummy SETUP_DIR=data/dummy ./scripts/build.sh` で全ステップ通過を確認
2. **本番ビルド**: `./scripts/roundtrip.sh` で PDF を生成
3. **PDF確認**: youshiki1_5_filled.pdf を開き、以下を検証
   - 様式1-1 の後に様式1-2 の本文が正しく挿入されている
   - 様式1-2 のテンプレートヘッダ（「（様式１−２）」）が維持されている
   - 様式1-3 も同様
   - 様式2-1 以降が正常
   - ページ番号が通しで振られている
   - フォント・スタイルが崩れていない

## リスクと代替案

| リスク | 影響 | 対策 |
|--------|------|------|
| OOXML要素挿入時にスタイル崩壊 | フォント・余白の不整合 | Step B-3のスタイルマッピング + テンプレートstyles.xmlにPandocスタイル定義追加 |
| rId/numId衝突でWord修復ダイアログ | ファイル破損 | Step B-1のリナンバリング処理を必須実装 |
| sectPr不整合で空白ページ/ヘッダ消失 | レイアウト崩壊 | Step B-2のsectPr保護を厳守 |
| ルートタグの名前空間欠落 | Wordがファイルを拒否 | Step B-4のルートタグ保存を必須適用 |
| 様式1-2 のページ数が15p超過 | 提出不可 | inject 時にページ数チェックを追加 |
| テンプレート様式の更新（将来の公募時） | セクション境界の変更 | マーカー検出をテキストパターンベースにし、ハードコードしない |
| inject失敗時の入力ファイル破損 | 再ビルド必要 | 一時ファイルに出力→成功時にリネーム（atomic write） |

## 代替案（フォールバック）

| 方式 | 書式崩壊リスク | 実装難度 | ページ番号 | テンプレート準拠 | 採否 |
|------|--------------|---------|----------|--------------|------|
| OOXML挿入（本計画） | 中〜高 | 高 | 制御可能 | 高 | **主方式** |
| Windows COM結合 | 極低 | 中 | Word制御 | 高 | **第1フォールバック** |
| PDF結合（pypdf） | 低 | 低 | 要対処 | 中 | **第2フォールバック** |
| 手動結合 | 低 | 低 | 手動 | 中 | 最終手段 |

- **Windows COM結合**: watch-and-convert.ps1 のVBScript基盤を拡張し、Word InsertFile で文書統合 → PDF化。Word自身がレイアウト保証。Windows依存だがパイプラインは既にWindows PDF変換に依存しているため追加コストは低い。
- **PDF結合**: SPEC.md §3.1 の当初方針。ページ番号の非連続が最大の懸念。pypdf のCJKフォント処理に注意。
- **ピボット基準**: OOXML挿入方式の実装開始から1週間以内にWord修復ダイアログなしで開けるdocxが生成できない場合、Windows COM方式にピボットする。

## 作業順序

1. Step A（構造解析）: 1-2h — テンプレート **および** Pandoc出力の両方の構造を把握
2. Step B（inject_narrative.py 作成）: 10-15h — コアロジック + ZIPレベルマージ + スタイルマッピング
3. Step C（build.sh 統合）: 30min
4. Step D（package/roundtrip 更新）: 30min
5. Step E（テスト）: 2h — docxの妥当性検証、Word修復ダイアログチェック含む

## 依存関係

- Docker 環境に追加パッケージは不要（xml.etree.ElementTree, zipfile は Python 標準ライブラリ）
- jami-abstract-pandoc のOOXML後処理パターンを参照（再利用可能パターン一覧は Step B-4 後の表を参照）
