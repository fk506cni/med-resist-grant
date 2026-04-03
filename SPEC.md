# 技術仕様書 (SPEC.md)

## 0. プロジェクト概要

### 0.1 背景

防衛装備庁 令和8年度 安全保障技術研究推進制度（委託事業）への応募書類を作成する。
研究テーマ (23) 医療・医工学に関する基礎研究（抗菌薬耐性関連）、Type A応募を想定。

### 0.2 目的

申請書類の本文をMarkdownで管理し、構造化データ（YAML）と組み合わせて、
提出用のWord/Excel/PDFファイルを自動生成するシステムを構築する。

### 0.3 設計方針

- **コンテンツとフォーマットの分離**: 本文はMarkdown、メタデータはYAML
- **原本非破壊**: data/source/ の様式ファイルを直接変更しない
- **再現可能ビルド**: `make build` で全成果物を再生成可能
- **ホスト環境非汚染**: Docker or uv 経由で実行

---

## 1. 入力データ

### 1.1 オリジナル様式 (data/source/)

| ファイル | 内容 | 操作 |
|---------|------|------|
| r08youshiki1_5.docx | 様式1-1〜5 + 参考様式 + チェックリスト (16テーブル, 376段落) | python-docx でテーブル記入 |
| r08youshiki_besshi5.docx | 別紙5: 研究セキュリティ質問票 (24テーブル) | python-docx でテーブル記入 |
| r08youshiki_betten.docx | 別添: セキュリティ自己申告書 (13テーブル) | python-docx でテーブル記入 |
| r08youshiki6.xlsx | 様式6: 申請概要 (4シート, 29列) | openpyxl でセル記入 |
| r08youshiki7.xlsx | 様式7: 研究者一覧 (1シート) | openpyxl でセル記入 |
| r08youshiki8.xlsx | 様式8: 連絡先 (1シート, 最大10アドレス) | openpyxl でセル記入 |

### 1.2 メタデータ (main/00_setup/)

| ファイル | 内容 |
|---------|------|
| config.yaml | プロジェクト設定（テーマ、タイトル、予算、機関情報） |
| researchers.yaml | 研究者情報（PI、分担者、CV） |
| other_funding.yaml | 他制度応募・受入状況 |
| security.yaml | セキュリティ関連情報（別紙5・別添用） |

### 1.3 本文ソース (main/step01_narrative/)

| ファイル | 内容 | 制約 |
|---------|------|------|
| youshiki1_2.md | 様式1-2: 研究課題申請書（詳細） | 最大15ページ |
| youshiki1_3.md | 様式1-3: 追加説明事項 | ページ制限なし |

---

## 2. 処理パイプライン

### 2.1 全体フロー

```
[main/00_setup/*.yaml]  ──────┐
                               ├──→ [step02_docx/fill_forms.py] ──→ 様式1-1,2-1~4-2.docx
[data/source/*.docx]   ───────┤
                               ├──→ [step02_docx/fill_security.py] → 別紙5,別添.docx
                               │
[main/step01_narrative/*.md] ──┤
                               ├──→ [step02_docx/build_narrative.sh] → 様式1-2,1-3.docx
                               │         (pandoc)
[main/00_setup/*.yaml]  ──────┤
                               ├──→ [step03_excel/fill_excel.py] ──→ 様式6,7,8.xlsx
[data/source/*.xlsx]   ───────┘
                                              │
                               [step04_package/package.sh]
                                              │
                               [main/step04_package/output/]
                                              │
                                   [Google Drive同期]
                                              │
                                   [Windows: Word修復+PDF化]
                                              │
                                        [e-Rad提出]
```

### 2.2 各ステップ仕様

#### Step 00: メタデータ定義 (00_setup/)

- **入力**: 手動入力
- **処理**: YAMLファイルの作成・編集
- **出力**: config.yaml, researchers.yaml, other_funding.yaml, security.yaml

#### Step 01: 本文執筆 (step01_narrative/)

- **入力**: 手動入力
- **処理**: Markdownで研究計画の本文を執筆
- **出力**: youshiki1_2.md, youshiki1_3.md

#### Step 02: Word文書生成 (step02_docx/)

- **入力**: Step 00の YAML + Step 01の MD + data/source/*.docx
- **処理**:
  - `fill_forms.py`: python-docx で様式1-1, 2-1〜4-2 のテーブルセルにデータを書き込み
  - `fill_security.py`: python-docx で別紙5, 別添のテーブルにデータを書き込み
  - `build_narrative.sh`: pandoc で Markdown → docx 変換（様式1-2, 1-3）
- **出力**: `step02_docx/output/*.docx`

#### Step 03: Excel文書生成 (step03_excel/)

- **入力**: Step 00の YAML + data/source/*.xlsx
- **処理**: `fill_excel.py` で openpyxl により各シートのセルにデータを書き込み
- **出力**: `step03_excel/output/*.xlsx`

#### Step 04: パッケージング (step04_package/)

- **入力**: Step 02-03 の出力
- **処理**: ファイル収集、バリデーション、サイズチェック
- **出力**: `step04_package/output/` に提出用ファイル一式

---

## 3. 出力仕様

### 3.1 Word文書 (step02_docx/output/)

| 出力ファイル | 内容 | 後処理 |
|-------------|------|--------|
| youshiki1_5.docx | 様式1-1〜5 + 参考様式（テーブル記入済） | Windows で PDF化 |
| youshiki1_2_narrative.docx | 様式1-2 本文（Pandoc生成） | 様式1-5.docxに組み込み or 単独PDF |
| youshiki1_3_narrative.docx | 様式1-3 本文（Pandoc生成） | 同上 |
| besshi5.docx | 別紙5（テーブル記入済） | Windows で PDF化 |
| betten_[氏名].docx | 別添（研究者ごと） | Windows で PDF化 |

### 3.2 Excelファイル (step03_excel/output/)

| 出力ファイル | 内容 | 備考 |
|-------------|------|------|
| youshiki6.xlsx | 様式6: 申請概要 | そのまま提出 |
| youshiki7.xlsx | 様式7: 研究者一覧 | そのまま提出 |
| youshiki8.xlsx | 様式8: 連絡先 | そのまま提出 |

### 3.3 提出ファイル (step04_package/output/)

| ファイル | 提出先 | サイズ制約 |
|---------|--------|-----------|
| 様式1-5_参考様式.pdf | e-Rad | 10MB以下（目標3MB） |
| 別紙5.pdf | e-Rad | 10MB以下 |
| 別添_[氏名].pdf × N人 | e-Rad | 10MB以下 |
| 様式6.xlsx | e-Rad | 10MB以下 |
| 様式7.xlsx | e-Rad | 10MB以下 |
| 様式8.xlsx | e-Rad | 10MB以下 |

---

## 4. 環境・依存関係

### 4.1 Docker

```yaml
# docker/docker-compose.yml
services:
  python:
    build: ./python
    volumes:
      - ../../:/workspace
    working_dir: /workspace
```

### 4.2 パッケージ

| パッケージ | バージョン | 用途 |
|-----------|-----------|------|
| python-docx | >=1.1 | Word文書操作 |
| openpyxl | >=3.1 | Excel操作 |
| pyyaml | >=6.0 | YAML読み込み |
| ruamel.yaml | >=0.18 | YAML読み込み（コメント保持） |
| Jinja2 | >=3.1 | テンプレートエンジン（必要に応じ） |
| pandoc | 3.6.x | Markdown→docx変換（Docker内） |

### 4.3 外部環境

| 環境 | 用途 | 備考 |
|------|------|------|
| Windows + Word | docx修復・PDF変換 | COM API使用 |
| Google Drive | ファイル同期 | rclone gdrive bisync |
| e-Rad | 申請提出 | Web UI |

---

## 5. 制約・前提条件

### 提出制約

- 様式1-2は最大15ページ
- 各ファイル10MB以下（目標3MB）
- 様式6,7,8はExcel形式で提出（PDF不可）
- 様式1-1〜5 + 参考様式は1つのPDFに結合
- PIは日本国籍必須
- 全研究者が国内機関所属

### 技術制約

- data/source/ のオリジナルファイルは変更しない
- ホストPython環境を汚さない（Docker or uv）
- python-docxはWord書式の完全な保持を保証しない → Windows側での修復が必要
- pandoc生成のdocxはレイアウトが崩れる場合がある → reference-doc + 後処理で対応

### 審査観点（様式1-2, 1-3の執筆指針）

1. **研究の発展性・将来性**: テーマ整合性、新規性/革新性、波及効果
2. **研究の有効性**: 目標の具体性/明確性、計画の質、手法の新規性、経費の妥当性
3. **研究の効率性**: 準備状況、実施体制、研究者の能力
4. **その他**: 不合理な重複・集中がないこと
