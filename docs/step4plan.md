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
- **対策1**: OOXMLレベルでの直接操作（lxml で body 要素を移植）
- **対策2**: Pandoc 側で reference.docx のスタイル定義をテンプレートと統一し、スタイル競合を最小化
- **対策3**: 参考プロジェクト `/home/dryad/anal/jami-abstract-pandoc/` の OOXML 後処理パターンを参照
- Pandoc が生成する段落スタイル（Heading 1, Body Text 等）とテンプレートのスタイルのマッピングが必要

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
| python-docx での要素挿入時に書式崩壊 | レイアウト崩れ | OOXML 直接操作（lxml）で対応。jami-abstract-pandoc の実績あり |
| Pandoc スタイルとテンプレートスタイルの競合 | フォント・余白の不整合 | reference.docx をテンプレートから抽出して統一 |
| 様式1-2 のページ数が15p超過 | 提出不可 | inject 時にページ数チェックを追加 |
| テンプレート様式の更新（将来の公募時） | セクション境界の変更 | マーカー検出をテキストパターンベースにし、ハードコードしない |

## 代替案（不採用）

1. **PDF結合方式**: 個別 PDF を後から結合 → ページ番号が不連続になる、テンプレートヘッダが二重になる
2. **空セクション削除 + PDF結合**: テンプレートの様式準拠性が失われる
3. **手動結合**: 再現性がない、ヒューマンエラーのリスク

## 作業順序

1. Step A（構造解析）: 1h — テンプレートの段落構造を把握
2. Step B（inject_narrative.py 作成）: 3-4h — コアロジックの実装
3. Step C（build.sh 統合）: 30min
4. Step D（package/roundtrip 更新）: 30min
5. Step E（テスト）: 1h

## 依存関係

- Docker 環境に追加パッケージは不要（python-docx + lxml は既存）
- jami-abstract-pandoc の OOXML 後処理コードを参考にする
