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
- **再現可能ビルド**: `./scripts/build.sh` で全成果物を再生成可能
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
                               [scripts/create_package.sh]
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
| youshiki1_5_filled.docx | 様式1-1〜5 + 参考様式（テーブル記入済） | Windows で PDF化 |
| youshiki1_2_narrative.docx | 様式1-2 本文（Pandoc生成） | Windows側で個別PDF化 → PDF結合 |
| youshiki1_3_narrative.docx | 様式1-3 本文（Pandoc生成） | 同上 |

※ 様式1-2, 1-3の統合方法: 各docxをWindows側で個別にPDF化した後、
pypdf または Acrobat で様式1-5のPDFと結合して1つの提出用PDFを作成する。
python-docxでの文書結合は書式崩壊リスクが高いため採用しない。
※ 未記入の様式（様式5等）は様式ごと削除し、提出PDFに含めないこと（別紙2 §4）。
| besshi5_filled.docx | 別紙5（テーブル記入済） | Windows で PDF化 |
| betten_[氏名].docx | 別添（研究者ごと） | Windows で PDF化 |

### 3.2 Excelファイル (step03_excel/output/)

| 出力ファイル | 内容 | 備考 |
|-------------|------|------|
| youshiki6.xlsx | 様式6: 申請概要 | そのまま提出 |
| youshiki7.xlsx | 様式7: 研究者一覧 | そのまま提出 |
| youshiki8.xlsx | 様式8: 連絡先 | そのまま提出 |

### 3.3 提出ファイル (step04_package/output/)

| ファイル | 提出先 | サイズ制約 | 提出タイミング |
|---------|--------|-----------|--------------|
| 様式1-5_参考様式.pdf | e-Rad | 10MB以下（目標3MB） | 応募時(5/20) |
| 様式6.xlsx | e-Rad | 10MB以下 | 応募時(5/20) |
| 様式7.xlsx | e-Rad | 10MB以下 | 応募時(5/20) |
| 様式8.xlsx | e-Rad | 10MB以下 | 応募時(5/20) |
| 別紙5.pdf | e-Rad | 10MB以下 | 面接選出後(7月中旬) |
| 別添_[氏名].pdf × N人 | e-Rad | 10MB以下 | 面接選出後(7月中旬) |

---

## 4. 環境・依存関係

### 4.1 Docker

```yaml
# docker/docker-compose.yml
services:
  python:
    build:
      context: ./python
      dockerfile: Dockerfile
    volumes:
      - ..:/workspace
    working_dir: /workspace
    environment:
      - HOME=/tmp
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
- Type A予算上限: 総額5,200万円/年（直接経費4,000万円 + 間接経費1,200万円(30%)）
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

※ 募集要項 表2より。**革新性及び成果の波及効果については特に重視して審査される**。

| # | 審査項目 | 審査の観点（Type S, A） |
|---|--------|---------------------|
| 1 | 研究の発展性・将来性 | 研究テーマとの整合性、成果の新規性/独創性/革新性、成果の波及効果 |
| 2 | 研究の有効性 | 目標の具体性/明確性/適切性、研究計画及び方法（マイルストーン含む）、研究方法の新規性/独創性/革新性、必要経費 |
| 3 | 研究の効率性 | 研究の準備状況、研究代表者等の能力（エフォート含む）、研究実施体制（人材育成含む） |
| 4 | その他 | 不合理な重複・過度の集中がないか |

### 応募資格要件チェックリスト

#### 研究代表者（募集要項 §2.2.3）
- [ ] 日本国籍を有すること
- [ ] 日本語による面接審査・評価に対応できること
- [ ] 研究期間中、代表研究機関に継続的に在籍できること

#### 研究者全般（§2.2.2）
- [ ] 国内の研究実施能力のある機関に所属していること
- [ ] 機関及び研究実施場所が日本国内に所在すること

#### 研究機関（§2.2.4）
- [ ] 国内に所在し、日本の法律に基づく法人格を有すること
- [ ] 全省庁統一資格を有すること（「役務」のA/B/C/D等級、関東・甲信越地域）
- [ ] 指名停止期間中でないこと
- [ ] 公的研究費の管理・監査体制を整備していること
