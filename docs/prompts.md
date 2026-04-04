# 実装プロンプト集

令和8年度 安全保障技術研究推進制度（委託事業）申請書類作成システムの実装手順。
各セクションを順にClaudeに依頼して実装する。

## 前提文脈（全ステップ共通）

すべてのプロンプトを実行する際、エージェントは以下を把握しておく必要がある:

### プロジェクト概要

- **応募先**: 防衛装備庁 令和8年度 安全保障技術研究推進制度（委託事業）
- **研究テーマ**: (23) 医療・医工学に関する基礎研究（抗菌薬耐性関連）
- **応募タイプ**: Type A（総額最大5200万円/年 ＝ 直接経費4,000万円 + 間接経費1,200万円、最大3年）
- **提出期限**: 2026年5月20日(水) 正午 e-Rad経由
- **提出物**: Word→PDF（様式1-5結合PDF + 別紙5 PDF + 別添PDF×人数分）、Excel（様式6,7,8）

### 読むべきドキュメント

| ファイル | 読むタイミング | 内容 |
|---------|--------------|------|
| `CLAUDE.md` | 毎回 | プロジェクト構成、提出書類一覧、Tech Stack、制約 |
| `SPEC.md` | 毎回 | 入出力仕様、パイプライン、制約条件 |
| `data/source/募集要項.pdf` | テーマ・審査基準を参照する時 | 公募要領全文（44p + 別紙） |

### 絶対的な制約

1. **data/source/ のファイルは絶対に変更しない** — 常にコピーしてから操作
2. **ホストPythonを汚さない** — Docker or uv 経由でのみ実行
3. **提出ファイルサイズ**: 各10MB以下、目標3MB
4. **様式1-2は最大15ページ**

### data/dummy/ の位置づけ

- `data/dummy/` はパイプラインのエンドツーエンドテスト用ダミーデータの配置場所
- Step 1 で作成するYAMLプレースホルダをテスト用にコピーして配置する
- テスト用の最小限のdocx/xlsxスタブも将来配置予定

### Step番号とディレクトリの対応

| prompts.md Step | 内容 | 対応ディレクトリ |
|----------------|------|---------------|
| Step 0 | Docker/uv環境構築 | docker/, pyproject.toml |
| Step 1 | メタデータYAML定義 | main/00_setup/ |
| Step 2 | Markdown本文執筆環境 | main/step01_narrative/ |
| Step 3 | Word文書生成 | main/step02_docx/ |
| Step 4 | Excel文書生成 | main/step03_excel/ |
| Step 5 | ビルド統合・パッケージング | main/step04_package/ + scripts/build.sh |
| Step 6 | Google Drive同期設定 | scripts/ |
| Step 7 | Windows側Word修復環境 | scripts/windows/ |

### 参考プロジェクト

類似のMarkdown→Word変換システムが `/home/dryad/anal/jami-abstract-pandoc/` にある。
特に以下を参考にする:

| ファイル | 参考ポイント |
|---------|------------|
| `Makefile` | Docker経由実行パターンの参考 |
| `docker/pandoc/Dockerfile` | Pandoc + 日本語フォント + Pythonのインストール方法 |
| `docker-compose.yml` | ボリュームマウント、UID/GIDの扱い |
| `scripts/wrap-textbox.py` | python-docx/OOXMLのXML操作パターン |
| `scripts/fix-reference-cols.py` | docxをZIPとして開きXMLを操作する手法 |
| `scripts/word-to-pdf.bat` | Windows側Word COM APIでのPDF変換 |
| `filters/jami-style.lua` | Pandoc Luaフィルタの設計 |
| `SPEC.md` | 全体アーキテクチャ設計の参考 |

---

## Step 0: 環境構築（Docker / uv）

### 文脈

- このプロジェクトではPython (python-docx, openpyxl) とPandocの2つのツールを使う
- ユーザーはホストPythonを汚したくない → Docker or uv が必須
- jami-abstract-pandocではDocker内にPandoc + Python + 日本語フォントを同居させている
- 本プロジェクトでも同様の構成が望ましい

### Prompt 0-1: Dockerコンテナ構築

```
docker/以下にPython用のDockerfileとdocker-compose.ymlを作成してください。

## 文脈
このプロジェクトは研究費申請書類の自動生成システムです。
PythonスクリプトでWord/Excelテンプレートにデータを記入し、
PandocでMarkdownからWord文書を生成します。

## 参照資料
- /home/dryad/anal/jami-abstract-pandoc/docker/pandoc/Dockerfile を読んで構成を参考にしてください
- /home/dryad/anal/jami-abstract-pandoc/docker-compose.yml を読んでマウント構成を参考にしてください
- docs/prompts.md（冒頭に全体的な文脈有り）
- SPEC.md
- README.md
- CLAUDE.md

## 要件
- ベースイメージ: python:3.12-slim
- Pandoc 3.6.x のインストール（GitHub releasesからdebパッケージをダウンロード→dpkg -i）
- pipパッケージ: python-docx, openpyxl, pyyaml, ruamel.yaml, Jinja2
- 作業ディレクトリ: /workspace（プロジェクトルートをマウント）
- UID/GIDをホストと合わせるためのENTRYPOINT設計
  （jami-abstract-pandocでは `docker compose run --rm -u $(id -u):$(id -g)` で対応）
- 日本語フォント: fonts-noto-cjk（docx内の日本語テキスト処理に必要）

## docker-compose.yml の構成
- サービス名: python
- volumes: プロジェクトルート → /workspace
- working_dir: /workspace
- environment: HOME=/tmp（non-root user対応）
```

#### 完了チェック

- [x] `docker compose -f docker/docker-compose.yml build` がエラーなく完了する
- [x] `docker compose -f docker/docker-compose.yml run --rm python python -c "import docx; import openpyxl; import yaml; print('OK')"` が成功
- [x] `docker compose -f docker/docker-compose.yml run --rm python pandoc --version` でPandocバージョンが表示される
- [x] コンテナ内から `/workspace/data/source/` のファイルが見える
- [x] 生成されたファイルのUID/GIDがホストユーザーと一致する

---

### Prompt 0-2: uv代替環境（Docker不使用時）

```
uvを使ったローカルPython環境を構築してください。

## 文脈
Docker環境が使えない場合の代替手段です。
ホストPythonは汚さず、uv管理の仮想環境内で完結させます。
Pandocはシステムにインストール済みの前提（なければ別途案内）。

## 要件
- pyproject.tomlを作成
  - [project] セクション: name, version, requires-python = ">=3.11"
  - dependencies: python-docx, openpyxl, pyyaml, ruamel.yaml, Jinja2
- uv.lockによる再現可能な環境
- scripts/run.sh: uv run経由でスクリプトを実行するラッパー
  （例: ./scripts/run.sh python main/step02_docx/fill_forms.py）
```

#### 完了チェック

- [ ] `uv sync` がエラーなく完了する
- [ ] `uv run python -c "import docx; import openpyxl; print('OK')"` が成功
- [ ] `scripts/run.sh` に実行権限がある
- [ ] `.venv/` が `.gitignore` に含まれている

---

## Step 1: メタデータ定義（YAML）

### 文脈

- 様式1-1, 2-1, 2-2, 3-1, 3-2, 4-1, 4-2, 様式6, 7, 8 のすべてが
  このYAMLデータを参照して自動記入される → **全フォームの単一データソース**
- YAMLのスキーマ設計はStep 3, 4のスクリプトの使いやすさに直結する
- フィールド名は日本語の様式に対応しつつ、Pythonからアクセスしやすいスネークケース英語を使う

### 参照すべき資料

各YAMLのフィールドが **どの様式のどのセルに対応するか** を理解するため、
以下のドキュメント構造を確認する必要がある:

| YAML | 対応様式 | 確認方法 |
|------|---------|---------|
| config.yaml | 様式1-1, 様式6 | data/source/r08youshiki1_5.docx の最初のテーブル（20行×8列）、r08youshiki6.xlsx の「様式6」シート D〜AC列 |
| researchers.yaml | 様式1-1(11), 様式4-1/4-2, 様式7 | r08youshiki1_5.docx の研究者リストテーブル、CV テーブル（10行×5列）、r08youshiki7.xlsx |
| other_funding.yaml | 様式3-1, 3-2 | r08youshiki1_5.docx 内の他制度テーブル（6行×8列） |
| security.yaml | 別紙5, 別添 | r08youshiki_besshi5.docx（24テーブル）、r08youshiki_betten.docx（13テーブル） |

### Prompt 1-1: プロジェクトメタデータ

```
main/00_setup/config.yaml を作成してください。

## 文脈
このYAMLは全提出書類の共通データソースです。
様式1-1（申請概要テーブル）、様式2-1/2-2（予算テーブル）、様式6（Excel概要）で使われます。
Step 3, 4のPythonスクリプトがこのYAMLを読み取って各フォームに自動記入します。

## 参照
以下のファイルを読み、テーブル構造とフィールド名を確認してから設計してください:
- data/source/r08youshiki1_5.docx — python-docxで開いてテーブル内容を確認
  （様式1-1: 最初のテーブル、20行×8列。様式2-1: 2つの予算テーブル）
- data/source/r08youshiki6.xlsx — openpyxlで開いて「様式6」シートの列構成を確認
  （D列〜AC列、記載行は18〜25行目付近）
- data/source/募集要項.pdf — Type Aの予算上限・期間制約を確認
- docs/prompts.md（全体的な文脈記載有り）
- SPEC.md
- README.md
- CLAUDE.md

## 構造
- project:
  - theme_number: 研究テーマ番号（23: 医療・医工学に関する基礎研究）
  - title_ja: 研究課題名（日本語、30文字以内）
  - title_en: 研究課題名（英語）
  - field: 研究分野（「医療」を選択）
    ※ 選択肢: 知能 / 情報 / 通信 / 電気 / 電子 / 光 / 材料 / 機械 / 医療 / その他
  - keywords: キーワード（最大5つ）
    ※ 募集要項 別紙1のキーワード例: 外傷評価, AI診断支援, 遠隔医療, 抗菌薬耐性 等
  - summary: 研究概要（180文字以内、一般向け平易な表現）
  - type: "A"（年間最大5200万円、最大3年）
  - period_start: R8（令和8年度 = 2026年度、研究開始は12月以降）
  - period_end: R10（最大R10、3年間）
  - duplicate_application: false（重複応募の有無）

- lead_institution:
  - name: 機関名
  - type: 種別（大学等/公的研究機関/公益法人等/企業等 から1つ）
  - is_sme: false
  - is_startup: false
  - address: 所在地
  - procurement_grade: 全省庁統一資格等級（A/B/C/D）
  - authorized_signer:（参考様式の署名者 — 委託契約の最終権限者）
    - name: 氏名（例: 学部長、契約担当部署の長）
    - title: 肩書き

- contacts:
  - emails: 通知用メールアドレスリスト（最大10件、様式8用）

- budget:
  - indirect_rate: 0.3
    ※ 原則30%。ただし公益法人・一般法人・民間企業（技術研究組合、NPO含む）は
      必要に応じて30%以下に設定可能（別紙2 §4 様式2-1）。
      大学・国立研究機関の場合は0.3固定。
  - yearly:（年度ごとのリスト、Type Aは最大3年分）
    - year: 1
      equipment: 設備備品費（千円）— 耐用年数1年以上 かつ 取得価格10万円以上
      consumables: 消耗品費（千円）— 上記以外の物品
      travel: 旅費（千円）
      personnel: 人件費・謝金（千円）
      other: その他（千円）
      ※ 物品費 = equipment + consumables（自動計算、様式2-1 Table 3の小計行用）
      ※ 直接経費 = 全費目合計（自動計算）
      ※ 間接経費 = 直接経費 × indirect_rate（自動計算）
      ※ 各年度の経費額合計は様式1-1 ⑦申請額と一致すること
  - by_institution:（機関ごとの年度別予算内訳 — 様式2-1 Table 4用）
    - institution: 機関名
      yearly:
        - year: 1
          amount: 直接経費合計（千円）
  - details:（様式2-2用: 品目レベルの積算明細）
    - year: 1
      line_items:
        - category: equipment / consumables / travel / personnel / other
          name: "品名（メーカー名、型番、仕様等）"
          quantity: "1台"    # 数量＋単位（文字列。様式2-2 Col 1「数量(単位)」に対応）
          amount: 0          # 千円（様式2-2 Col 2「金額（単位：千円）」に対応）
          institution: "○○大学"  # 設置機関／担当研究機関（様式2-2 Col 3 に対応）
          justification: "使用目的及び必要性の説明"  # 様式2-2 Col 4 に対応

## 注意
- プレースホルダ値で作成し、各フィールドにYAMLコメントで説明と対応様式を付記
- 金額の単位は千円（様式準拠）、消費税込みで記載
- 様式2-1の記載注意事項（別紙2 §4）:
  - 建物や構築物、およびそれらと一体となった設備の購入は認められない
  - 汎用性の高い備品（パソコン等）は事業の遂行に必要と認められるもののみ購入可能
  - 研究に必要な機器設備の調達にあたっては、購入とリース・レンタルで調達経費を比較し、安価な方法を採用すること
  - 外国旅費は最低限必要なもののみ計上
  - 各所要経費は支払の発生する年度に計上すること
```

#### 完了チェック

- [x] YAMLとして正しくパースできる（`python -c "import yaml; yaml.safe_load(open('main/00_setup/config.yaml'))"` がエラーなし）
- [x] 様式1-1の全フィールド (1)〜(11) に対応するキーが存在する
- [x] 予算構造が年度別 × 費目別（設備備品費/消耗品費/旅費/人件費・謝金/その他）になっている
- [x] 品目レベル積算明細（budget.details）が存在する
- [x] 各フィールドにコメントで対応様式番号が記載されている
- [x] 金額単位が千円で統一されている

---

### Prompt 1-2: 研究者情報

```
main/00_setup/researchers.yaml を作成してください。

## 文脈
このYAMLは研究者の個人情報を一元管理します。
以下の様式で参照されます:
- 様式1-1 (9)(10)(11): PI連絡先、経理担当者、研究者リスト
- 様式4-1: PI調書（CV）
- 様式4-2: 分担者調書（CV）
- 様式7 (Excel): 研究者一覧
- 別紙5・別添: セキュリティ質問票の研究者識別

## 参照
以下のファイルを読み、必要なフィールドを確認してください:
- data/source/r08youshiki1_5.docx — 様式4-1/4-2のCVテーブル構造
  （10行×5列: 研究課題名, 氏名/ふりがな, 生年月日/年齢, 研究者番号,
   所属/部局/職, 最終学歴/学位, 専門分野, 主な経歴, 競争的研究資金獲得実績,
   受賞歴, 関連論文/著書, 関連知財）
- data/source/r08youshiki7.xlsx — 研究者一覧の列構成
  （B: 課題名, C: 機関名, D: 氏名, E: 部局・職）
- docs/prompts.md（全体的な文脈記載有り）
- SPEC.md
- README.md
- CLAUDE.md

## 構造
- pi:（研究代表者 — 1名のみ）
  - name_ja / name_en / furigana
  - nationality: "日本"（PIは日本国籍必須 — 募集要項の応募資格要件）
  - birth_date / age
  - researcher_id:（e-Rad研究者番号）
  - affiliation / department / position
  - education:（最終学歴・学位）
  - specialty:（専門分野）
  - career_history:（主な経歴リスト — 年月, 内容）
    ※ 現在の**全ての**所属機関・役職を含むこと（兼業、外国の人材登用プログラムへの参加、
      雇用契約のない名誉教授等を含む）。別紙2 §4【様式4-1】で「必ず記入」と明記。
  - funding_history:（競争的研究資金獲得実績リスト — 制度名, 課題名, 役割, 期間, 金額）
  - awards:（受賞歴・表彰歴リスト — 年月, 名称。該当なしの場合は「無し」）
  - publications:（関連研究論文・著書リスト — 著者, タイトル, 雑誌, 年）
    ※ **主要なもの5本程度**を選んで記載（別紙2 §4【様式4-1】）
    ※ researchmapの登録情報も活用すること
  - patents:（関連知的財産権リスト — 発明名称, 出願番号, 年）
    ※ 同様に主要なもの5件程度
  - researchmap_id:（researchmap研究者ID — 任意、記載に活用）
  - contact:
    - postal: 郵送先住所
    - tel: 電話番号
    - email: メールアドレス
  - effort_percent:（本研究へのエフォート率 %）
  - tasks:（担当業務の説明 — 様式1-2 §7.1の表で使用）

- co_investigators:（研究分担者リスト — 0名以上）
  - 各要素はpiと同様の構造
  - institution:（所属研究機関名 — PIと異なる場合は分担研究機関）

- admin_contact:（経理事務担当者 — 様式1-1(10)用）
  - name / affiliation / tel / email

## 注意
- プレースホルダ値で作成
- リスト型フィールド（career_history等）は最低1件のサンプルエントリを含める
- PIと分担者で構造を共通化し、差異はキーの有無で表現
```

#### 完了チェック

- [x] YAMLとして正しくパースできる
- [x] PI情報が様式4-1のテーブル全行（10項目）をカバーしている
- [x] co_investigators がリスト構造で、0名でも動作する設計になっている
- [x] 様式7に必要なフィールド（機関名, 氏名, 部局・職）が含まれている
- [x] effort_percent フィールドが存在する（様式3-1/3-2で必要）

---

### Prompt 1-3: 他制度応募状況・セキュリティ情報

```
main/00_setup/other_funding.yaml と main/00_setup/security.yaml を作成してください。

## 文脈
other_funding.yaml は様式3-1（PI）と様式3-2（各分担者）で使われます。
security.yaml は別紙5（機関のセキュリティ質問票）と別添（各研究者の自己申告書）で使われます。

## 参照
以下のファイルを読んでテーブル構造を確認してください:
- data/source/r08youshiki1_5.docx — 様式3-1/3-2テーブル
  （6行×8列: 番号, 状態, 制度名/期間/配分機関, 課題名, 役割, 予算額, エフォート%, 相違点）
- data/source/r08youshiki_besshi5.docx — 別紙5の全24テーブル
  （§1: デューデリジェンス、§2: 共同研究機関、§3: リスク確認13項目×テーブル、§4: リスク軽減措置）
- data/source/r08youshiki_betten.docx — 別添の全13テーブル
  （各研究者の自己申告: 学歴, 職歴, 資金歴, 論文, 特許, 外国人材プログラム,
   処分歴, リスト掲載, 居住者区分, 国籍 — 計13項目に対応するテーブル）
- docs/prompts.md（全体的な文脈記載有り）
- SPEC.md
- README.md
- CLAUDE.md

## other_funding.yaml 構造
- pi_funding:（様式3-1: PIの他制度応募/受入状況）
  - entries:（リスト）
    - status: "応募中" or "受入中"
    - program_name: 制度名
    - period: 研究期間
    - agency: 配分機関名
    - project_title: 研究課題名
    - role: 役割（代表/分担）
    - budget: 本人の受入れ予算額（千円）
    - total_budget: 研究課題全体の予算額（千円）— Col 6 括弧内に記入
    - effort_percent: エフォート率
    - difference: 本課題との相違点・重複しない理由
    - confidential: false
      ※ 秘密保持契約等のやむを得ない事情がある場合はtrueに設定。
        trueの場合、配分機関等名と予算額を記入しないことができる（別紙2 §4【様式3-1】）。

- co_investigator_funding:（様式3-2: 各分担者の他制度応募/受入状況）
  - researcher_name ごとに pi_funding と同構造

## security.yaml 構造
- due_diligence:
  - lead_institution:
    - status: "提出済" / "要提出・未提出" / "不要"
  - partner_institutions:（リスト — 機関ごと）
    - name: 機関名
    - status: 同上

- researchers:（研究者ごとのセキュリティ情報 — 別紙5 §3 + 別添の両方で使用）
  - [研究者名]:
    - education_history:（高校以降の学歴、外国の教育機関を含む）
    - career_history:（研究経歴・職歴、特に海外勤務）
    - funding_history:（R5年度以降の研究費取得歴）
    - non_research_support:（研究費以外の支援: 給与, 奨学金等）
    - publications:（共著者を含む発表論文）
    - patents:（共同出願者を含む特許出願）
    - foreign_talent_programs:（外国の人材採用プログラム参加歴、「1286リスト」含む）
    - disciplinary_history:（競争的研究費指針に基づく処分歴）
    - list_status:（経産省外国ユーザーリスト / 米国統合スクリーニングリスト掲載有無）
    - listed_entity_affiliation:（リスト掲載機関への所属歴）
    - listed_entity_relationships:（リスト掲載機関の研究者との関係）
    - residency_status:（非居住者/特定類型への該当性）
    - nationality: 国籍

- risk_assessment:
  - mitigation_needed: true/false
  - measures:（リスク軽減措置リスト）
    - 施設アクセス管理 / 研究場所管理 / 会議参加者管理 / 雇用契約 / 研修 / データアクセス制御 / サイバーセキュリティ / その他

- consent:
  - all_members_consented: true/false
  - institutional_confirmation: true/false

## 注意
- スキーマのみ作成（値はプレースホルダ）
- 別紙5の13項目と別添の13項目は同じ情報を異なる視点で使うので、データソースは共通化する
- 空リストの場合も動作する設計にする（該当なし = 空リスト）
```

#### 完了チェック

- [x] 両ファイルともYAMLとして正しくパースできる
- [x] other_funding.yaml の各エントリが様式3-1テーブルの8列に対応している
- [x] security.yaml の researchers セクションが別紙5の13項目をすべてカバーしている
- [x] security.yaml の researchers セクションが別添の13テーブルにも対応できる設計になっている
- [x] 空リスト（該当なし）のケースでエラーにならない構造になっている

---

## Step 2: 本文Markdown執筆環境

### 文脈

- 様式1-2（研究計画詳細、最大15ページ）と様式1-3（追加説明事項）がMarkdownで執筆する主要対象
- これらはPandocでdocxに変換し、Windows側で体裁を整えてPDF化する
- Pandocの `--reference-doc` でスタイル（フォント、段落書式）を元の様式から継承できる
- `east_asian_line_breaks` 拡張で日本語テキストの改行処理を適切にする
- 審査は「表2」の観点で行われる → セクション構成と内容はこの審査基準に沿わせる

### 参照すべき資料

| 資料 | 確認ポイント |
|------|------------|
| data/source/r08youshiki1_5.docx | 様式1-2のセクション見出し・記載要領（原本の指示テキスト） |
| data/source/募集要項.pdf p.10-12 | 審査基準「表2」（発展性, 有効性, 効率性, その他） |
| data/source/募集要項.pdf 別紙1 | テーマ(23)のキーワードと研究対象範囲 |
| data/source/募集要項.pdf p.5-6 | Type A の予算・期間制約 |
| /home/dryad/anal/jami-abstract-pandoc/src/paper.md | Pandoc Markdownの記述例 |

- docs/prompts.md（全体的な文脈記載有り）
- SPEC.md
- README.md
- CLAUDE.md


### Prompt 2-1: 様式1-2 テンプレート

```
main/step01_narrative/youshiki1_2.md を作成してください。

## 文脈
様式1-2「研究課題申請書（詳細）」のMarkdownテンプレートです。
最終的にPandocでdocxに変換されます。最大15ページ。
Type A（年間最大5200万円、最大3年間）での応募を想定。

## 参照
まず以下を読んでセクション構成と記載要領を正確に確認してください:
- data/source/r08youshiki1_5.docx をpython-docxで開き、「様式1-2」部分の
  見出しテキスト・記載指示を抽出してください
  （「次の事項について記入してください」の後にセクション指示がある）
- data/source/募集要項.pdf の審査基準（表2）を確認し、
  各セクションがどの審査観点に対応するかをHTMLコメントで注記してください

## セクション構成
以下は想定構成です。原本docxの指示と異なる場合は原本を優先してください:

# 1. 本研究の背景
<!-- 審査観点: 研究の発展性・将来性 -->
<!-- 研究分野の現状と課題。抗菌薬耐性の国際的動向、WHOの優先病原体リスト、
     AMR対策アクションプラン等の背景を含めること。 -->
<!-- ※ 本公募は基礎研究を対象。応用研究や臨床研究は対象外。
     人体に対する侵襲的手技（外科的処置、内視鏡処置、組織生検等）及び
     投薬を伴う臨床介入（治験等）は対象外（別紙1 テーマ(23)）。 -->
<!-- ※ 補足資料（「その他」様式自由）は審査対象外。必要情報は全て様式1-2内に完結させること。 -->

# 2. 本研究の目的
<!-- 審査観点: 研究の有効性（目標の具体性・明確性） -->
<!-- 最終的に何を達成するかを簡潔に。定量的な目標を含む。 -->

# 3. 本研究の最終目標および要素課題
<!-- 審査観点: 研究の有効性 -->
<!-- 最終目標を箇条書きで明確化し、それを分解した要素課題を列挙 -->

# 4. 最終目標に対する実施項目
<!-- 審査観点: 研究の有効性（研究計画の質） -->
<!-- 実施項目の説明 + 年次スケジュール表（Markdown table） -->
<!-- 表の例:
| 実施項目 | 1年目 | 2年目 | 3年目 |
|---------|------|------|------|
| 項目1   | ○    | ○    |      |
-->

# 5. 最終目標の達成に係る検討状況と最終目標を達成する見込み
<!-- 審査観点: 研究の効率性（準備状況） -->
<!-- 予備実験結果、技術的実現可能性の根拠を記述 -->
<!-- タイプCとして応募する場合には、提案するアイディアが実現できると見込まれる理由も記載 -->

# 6. 研究実施計画
<!-- 審査観点: 研究の有効性（研究計画の質、手法の新規性） -->
<!-- 年次ごとの具体的な計画。各年度の目標とマイルストーン。 -->

# 7. 研究実施体制
<!-- 審査観点: 研究の効率性（実施体制、研究者の能力） -->

## 7.1 研究者と実施内容
<!-- 各研究者が担当する実施内容と、各研究者の本研究に対するエフォートを記載 -->
<!-- Markdown表:
| 研究機関 | 氏名 | 実施内容 | エフォート(%) |
|---------|------|---------|-------------|
-->

## 7.2 分担研究機関が必要な理由／別の研究機関に所属する研究分担者が必要な理由
<!-- 分担研究機関/別機関の研究分担者がいない場合は「分担研究機関なし。」
     又は「別の研究機関に所属する研究分担者なし。」と記載 -->

## 7.3 研究者間の情報共有、連携体制
<!-- 研究機関間又は研究者間の情報共有や連携体制について具体的に記載 -->

# 8. 研究課題の最終目標、実施項目、研究者間の連携体制を示す概要図
<!-- §3〜7の関係が明らかになるよう、フローチャートを記載。§3〜7と整合が取れていること。 -->
<!-- ![概要図](figs/overview.png) -->

## 注意
- 各セクションにHTMLコメントで (a) 対応する審査観点、(b) 記載ガイド を付記
- Type Aの場合、中間評価のマイルストーンは不要（Type Sのみ）
- Pandoc変換を想定: 画像参照は相対パス、表はpipe table記法
- 15ページを超えないよう、セクションごとに推奨ページ配分もコメントで示す
  （例: §1-2で2p, §3で1p, §4で1p, §5で2p, §6で4p, §7で3p, §8で1p = 計14p）
```

#### 完了チェック

- [x] セクション見出しが原本docxの指示と一致している
- [x] 全8セクション（7は3サブセクション含む）が含まれている
- [x] 各セクションにHTMLコメントで審査観点と記載ガイドがある
- [x] ページ配分の目安がコメントで示されている
- [x] Markdown構文がPandoc互換（pipe table, 画像参照等）

---

### Prompt 2-2: 様式1-3 テンプレート

```
main/step01_narrative/youshiki1_3.md を作成してください。

## 文脈
様式1-3「追加説明事項」のMarkdownテンプレートです。
様式1-2を補完する位置づけで、審査の重要項目を個別に深掘りします。

## 参照
- data/source/r08youshiki1_5.docx をpython-docxで開き、「様式1-3」部分の
  見出しテキスト・記載指示を抽出してください
- data/source/募集要項.pdf 審査基準「表2」— 各セクションが直接対応する観点を確認
- data/source/募集要項.pdf 別紙1 テーマ(23) — 研究対象範囲との整合性記述に必要

## セクション構成

# 1. 研究テーマとの整合性
<!-- 審査観点: 研究の発展性・将来性（テーマとの整合性） -->
<!-- テーマ(23)「医療・医工学に関する基礎研究」のキーワード:
     外傷評価, AI診断支援, 遠隔医療, モバイル手術環境, 可搬型生命維持装置,
     止血, 輸血, 人工臓器, 義肢, 生体適合性表面処理, バイオファブリケーション,
     組織工学, 免疫寛容誘導, 抗菌薬耐性
     本研究がこれらのどれに対応し、どう貢献するかを明確に -->
<!-- ※ 本公募は基礎研究を対象。応用研究や臨床研究は対象外。
     人体に対する侵襲的手技・投薬を伴う臨床介入（治験等）は対象外（別紙1）。 -->

# 2. 新規性、独創性又は革新性
<!-- 審査観点: 研究の発展性・将来性（新規性/独創性/革新性） -->
<!-- 既存研究との差別化。先行研究を引用しつつ本研究の独自性を主張 -->

# 3. 波及効果
<!-- 審査観点: 研究の発展性・将来性（波及効果） -->
<!-- 学術的波及 + 社会的波及 + 産業的波及 -->
<!-- ※ 防衛分野への波及効果は審査の観点に含まれないため記載不要（別紙2 §4(3)）。
     学術分野や民生分野への波及効果を記述すること。 -->

# 4. 所要経費及び研究期間の妥当性
<!-- 審査観点: 研究の有効性（所要経費・研究期間の妥当性） -->
<!-- config.yaml の budget セクションと整合させること -->

# 5. 研究代表者の能力
<!-- 審査観点: 研究の効率性（研究者の能力） -->
<!-- researchers.yaml の pi セクション（業績、獲得資金等）と整合させること -->

## Type A応募時の注意
- Type A応募では (4) 所要経費及び研究期間の妥当性 と (5) 研究代表者の能力 は
  **項目ごと削除する**こと（別紙2 様式1-3記載要領に基づく）。
  タイプS、またはタイプDで総額1.56億円超/期間3年超の場合のみ記載する。
- テンプレートには全5セクションを含めるが、build_narrative.sh での
  Pandoc変換時にType判定に基づき該当セクションを除外する。

## 注意
- 各セクションにHTMLコメントで対応する審査観点を明記
- 「防衛」という語は意識的に使用。ただし募集要項が強調する「基礎研究」「学術的自由」
  の文脈を踏まえ、軍事応用への直接言及は避ける
```

#### 完了チェック

- [x] セクション見出しが原本docxの指示と一致している
- [x] 全5セクション（ただしType Aでは(4)(5)を削除対象として明示）が含まれている
- [x] テーマ(23)のキーワードが§1のコメント内に列挙されている
- [x] 各セクションに審査観点がコメントで対応付けされている
- [x] §4, §5のコメントでconfig.yaml/researchers.yamlとの整合性に言及している

---

## Step 3: Word文書生成（テーブル系フォーム）

### 文脈

- Word文書は2種類のアプローチで生成する:
  - **テーブルフォーム** (様式1-1, 2-1, 2-2, 3, 4, 5, 参考様式, 別紙5, 別添) → python-docxでセル記入
  - **本文** (様式1-2, 1-3) → Pandocで Markdown→docx 変換
- python-docx はWord文書のテーブルセルの中身を変更できるが、完全なレイアウト保持は保証されない
  → 最終的にWindows側Word COM APIで「修復して開く」が必要
- r08youshiki1_5.docx には **複数の様式が1ファイルに含まれている**
  → テーブルの特定はインデックスまたはセル内テキストのパターンマッチで行う

### 参照すべき資料

| 資料 | 確認ポイント |
|------|------------|
| data/source/r08youshiki1_5.docx | python-docxで開いてテーブル数・各テーブルの行列数・セル内容を調査 |
| data/source/r08youshiki_besshi5.docx | 同上（24テーブル） |
| data/source/r08youshiki_betten.docx | 同上（13テーブル） |
| /home/dryad/anal/jami-abstract-pandoc/scripts/wrap-textbox.py | OOXML直接操作の手法 |
| /home/dryad/anal/jami-abstract-pandoc/scripts/fix-reference-cols.py | docxをZIPとして開きXML操作する手法 |
| /home/dryad/anal/jami-abstract-pandoc/Makefile | pandocコマンド構成 |

### Prompt 3-1: python-docxによるフォーム記入スクリプト

```
main/step02_docx/fill_forms.py を作成してください。

## 文脈
data/source/r08youshiki1_5.docx は1つのdocxファイルに以下の様式がすべて含まれています:
- 様式1-1: 申請概要テーブル (20行×8列)
- 様式1-2: 詳細申請書（セクション見出しのみ — 本文はPandocで別途生成）
- 様式1-3: 追加説明事項（同上）
- 様式2-1: 予算見込額テーブル × 2
- 様式2-2: 年度別予算計画テーブル × 5（各年度1つ、Type Aは3テーブルのみ使用）
- 様式3-1: PI他制度テーブル
- 様式3-2: 分担者他制度テーブル
- 様式4-1: PI CVテーブル
- 様式4-2: 分担者CVテーブル
- 様式5: 法人概要テーブル
- 参考様式: 承諾書（3種類: 委託事業・代表研究機関 / 委託事業・分担研究機関 / 補助事業）
- チェックリスト（提出不要）

このスクリプトは上記のうちテーブル記入型の様式にデータを書き込み、
不要な様式を削除します。

## 参照
まず以下の調査コードを実行してテーブル構造を把握してください
（内側のコードブロックは4スペースインデント）:

    from docx import Document
    doc = Document('data/source/r08youshiki1_5.docx')
    for i, table in enumerate(doc.tables):
        print(f"--- Table {i} ({len(table.rows)}rows x {len(table.columns)}cols) ---")
        for j, row in enumerate(table.rows):
            cells = [cell.text[:30] for cell in row.cells]
            print(f"  Row {j}: {cells}")

さらに以下を参考にしてください:
- /home/dryad/anal/jami-abstract-pandoc/scripts/wrap-textbox.py — python-docx + lxml でOOXMLを直接操作するパターン
- /home/dryad/anal/jami-abstract-pandoc/scripts/fix-reference-cols.py — docxをzipfileで開いてword/document.xmlを書き換えるパターン

## 様式1-1 セルマッピング（Table 0, 20r×8c、105箇所超のセル結合あり）

  行      ラベル(列0-2)              値(列3-7)                対応データ
  [0]     ①研究テーマ                [0,3]                    config.yaml.project.theme_number
  [1]     ②研究課題名 日             [1,3]                    config.yaml.project.title_ja
  [2]     ②研究課題名 英             [2,3]                    config.yaml.project.title_en
  [3]     ③研究分野                  [3,3] ○選択(10択)        config.yaml.project.field
  [4]     ④キーワード                [4,3]                    config.yaml.project.keywords
  [5]     ⑤研究の概要(180字)         [5,3]                    config.yaml.project.summary
  [6]     ⑥研究期間                  [6,3]                    config.yaml.project.period_*
  [7]     ⑦申請額                    [7,3]                    config.yaml.budget（合計）
  [8]     ⑧タイプ                   [8,3] ○選択 / [8,7] 重複  config.yaml.project.type
  [9-11]  ⑨研究代表者                氏名,国籍,所属,連絡先      researchers.yaml.pi
  [12-14] ⑩経理事務担当者            同上                      researchers.yaml.admin_contact
  [17-19] ⑪研究者リスト              機関名,氏名,部局,連絡先    researchers.yaml（全員）

  ※ ③研究分野と⑧タイプは「丸を付ける」形式。元テキスト内の該当選択肢に○を挿入する操作が必要。
  ※ 3+5列パターンの結合: ラベルが列0-2、値が列3-7にspan。row.cells で重複セルが返るため注意。

## 機能
1. data/source/r08youshiki1_5.docx をコピー → 作業用docxを作成
2. main/00_setup/config.yaml, researchers.yaml, other_funding.yaml を読み込み
3. 各テーブルを特定し、対応するセルにデータを書き込み:
   - 様式1-1: config.yaml → テーブルセル（上記マッピング参照）
   - 様式2-1: config.yaml.budget.yearly → 予算テーブル（Table 3: 年度別費目内訳、Table 4: 機関別）
     ※ Table 3 の行構成（9r×7c）:
       Row 0-1: ヘッダ、Row 2: 直接経費、Row 3: ア．物品費（= equipment + consumables の合算）、
       Row 4: イ．人件費・謝金、Row 5: ウ．旅費、Row 6: エ．その他、
       Row 7: 間接経費（原則30%）、Row 8: 合計
     ※ Table 3 には「設備備品費」「消耗品費」の個別行は存在しない。
       config.yaml の equipment + consumables を合算して「ア．物品費」行に記入すること。
   - 様式2-2: config.yaml.budget.details → 年度別積算明細テーブル（Type Aは3年分のみ、Tables 5-7を使用。Tables 8-9は空欄のまま）
     ※ Tables 5-9 の列構成（12r×5c）:
       Col 0: 項目(メーカー名・規格等を併記)、Col 1: 数量(単位)、
       Col 2: 金額（単位：千円）、Col 3: 設置機関／担当研究機関、Col 4: 使用目的及び必要性
     ※ 「単価」列は存在しない。金額のみ記入する。
     ※ 行構造はカテゴリブロック方式:
       Row 1 に「Ⅰ．物品費 / 1.設備備品費 / 2.消耗品費」がセル内段落として存在し、
       品目はカテゴリ内の改行区切りで記入する。Row 3「Ⅱ．人件費・謝金」等も同様。
       各カテゴリの後に小計行（Row 2, 4, 6, 8）がある。
   - 様式3-1: other_funding.yaml.pi_funding → テーブル行を追加
     ※ 1行目は本研究課題を記入。該当がない場合は2行目の「制度名」欄に「無し」と記入。
     ※ confidential: true のエントリは配分機関名と予算額を空欄にする。
   - 様式3-2: other_funding.yaml.co_investigator_funding → テーブル行を追加
   - 様式4-1: researchers.yaml.pi → CVテーブル
   - 様式4-2: researchers.yaml.co_investigators → CVテーブル（人数分）
   - 参考様式: config.yaml.lead_institution + researchers.yaml → 署名者情報を記入
4. 不要な様式・セクションを削除（別紙2 §4: 「未記入の様式は様式ごと削除し、提出するPDFに含めないでください」）:
   - 様式4-2 (Table 13 + 段落P[283]-P[287]): 分担者がいない場合
   - 様式5 (Table 14 + 段落P[288]-P[293]): 大学・国立研究機関の場合（config.yaml.lead_institution.type で判定）
   - 様式2-2 Tables 8-9: Type A（3年）の場合、4-5年目テーブルを削除
   - 参考様式・補助金版 (段落P[347]-P[370]): Type A（委託事業）の場合は常に削除
   - チェックリスト (Table 15 + 段落P[372]-P[375]): 常に削除（提出不要）
5. main/step02_docx/output/youshiki1_5_filled.docx に保存

## 参考様式の扱い

r08youshiki1_5.docx には以下の3種類の参考様式（承諾書）が含まれる:
- P[294]-P[319]: 委託事業・代表研究機関用（Type A では必要）
- P[320]-P[346]: 委託事業・分担研究機関用（分担研究機関がある場合のみ。機関数分複製）
- P[347]-P[370]: 補助事業用（Type A では不要 → 削除）

Type S, A, C の場合: 「委託契約を締結する最終権限を有する所属機関の長」
の名義で作成（別紙2 §4【参考様式】）。config.yaml に署名者情報フィールドを
追加し（lead_institution.authorized_signer）、記入に使用する。

## 設計方針
- テーブルの特定: テーブルインデックスは環境依存で脆いため、
  セル内テキスト（「研究テーマ」「研究課題名」等）でパターンマッチして特定する
- セル書き込み: cell.text への直接代入ではなく、
  cell.paragraphs[0].runs を操作してフォント情報を維持する
- 行の動的追加: 様式3-1/3-2で他制度エントリが複数ある場合、テーブル行を追加する
- セクション削除: 不要な段落・テーブルは paragraph._element.getparent().remove(paragraph._element) で削除
  （段落インデックス範囲は上記参照。テーブルも同様に table._element で削除可能）
- エラーハンドリング: テーブルが見つからない場合は警告を出して続行（部分的な記入を許容）

## 注意
- data/source/のオリジナルファイルは変更しない（shutil.copy2でコピーしてから操作）
- 間接経費は config.yaml.budget.indirect_rate に基づき自動計算
- 引数でYAMLファイルパスと出力パスを指定できるようにする
  （例: python fill_forms.py --config main/00_setup/config.yaml --output main/step02_docx/output/）
```

#### 完了チェック

- [x] data/source/ のオリジナルファイルが変更されていないこと: `md5sum data/source/r08youshiki1_5.docx` で実行前後を比較
- [x] 出力docxがWordまたはLibreOfficeで開ける
- [x] 様式1-1のテーブルにプレースホルダ値が記入されている
- [x] 予算テーブルの間接経費が直接経費×0.3になっている
- [x] YAMLのプレースホルダ値をすべて「TODO」等に変えても動作する（空入力耐性）
- [x] `python -m py_compile main/step02_docx/fill_forms.py` がエラーなし

---

### Prompt 3-2: Pandocによる本文Word変換

```
main/step02_docx/build_narrative.sh を作成してください。

## 文脈
Markdownで書かれた様式1-2, 1-3の本文をPandocでdocxに変換します。
最終的にはこのdocxの内容を様式1-5のdocxに統合するか、
またはWindows側で手動コピー＆ペーストします。

## 参照
- /home/dryad/anal/jami-abstract-pandoc/Makefile を読み、pandocコマンドの構成を確認してください
  （特に --from, --to, --reference-doc, --filter オプション）
- /home/dryad/anal/jami-abstract-pandoc/SPEC.md の「Pandoc Command Chain」セクション

## 機能
- main/step01_narrative/youshiki1_2.md → main/step02_docx/output/youshiki1_2_narrative.docx
- main/step01_narrative/youshiki1_3.md → main/step02_docx/output/youshiki1_3_narrative.docx
- Dockerコンテナ内でpandocを実行（またはuvで直接実行）

## Pandocオプション
pandoc INPUT.md \
  --from markdown+east_asian_line_breaks \
  --to docx \
  --reference-doc=templates/reference.docx \
  --output OUTPUT.docx

- east_asian_line_breaks: 日本語テキストの改行をスペースにしない
- reference-doc: スタイル（フォント、段落書式）を元の様式から継承
  ※ reference-docは「スタイル定義のみ」を参照する。内容は無視される。
  ※ data/source/r08youshiki1_5.docx は16テーブル・376段落の複合文書であり、
     そのまま reference-doc として使用すると不要なスタイルが混入するため非推奨。

## reference-doc の作成手順
1. Pandocデフォルトのreference.docxを生成:
   pandoc --print-default-data-file reference.docx -o templates/reference.docx
2. templates/reference.docx をWordで開き、以下のスタイルを元の様式に合わせて編集:
   - 本文（Body Text）: MS明朝 10.5pt
   - 見出し1（Heading 1）: MSゴシック 12pt 太字
   - 見出し2（Heading 2）: MSゴシック 10.5pt 太字
   - 表（Table）: MS明朝 9pt
   ※ 実際のフォント・サイズは data/source/r08youshiki1_5.docx の様式1-2部分を参照して合わせる
3. templates/reference.docx を git 管理する

## スクリプト構造
1. reference.docxの存在確認（なければ上記手順でデフォルト生成し、手動調整を促す警告を出す）
2. pandocコマンド実行（Docker経由 or 直接）
3. 出力確認

## 実行方法の分岐
- Docker環境:
  docker compose -f docker/docker-compose.yml run --rm \
    -u $(id -u):$(id -g) python \
    pandoc [OPTIONS]
- uv環境（Pandocがシステムインストール済み前提）:
  pandoc [OPTIONS]
- どちらかを引数やenvで切り替え可能にする
```

#### 完了チェック

- [x] `bash main/step02_docx/build_narrative.sh` がエラーなく完了する
- [x] main/step02_docx/output/youshiki1_2_narrative.docx が生成される
- [x] main/step02_docx/output/youshiki1_3_narrative.docx が生成される
- [ ] 生成されたdocxをWordで開いてセクション見出しと段落が正しく表示される
- [ ] 日本語テキストが文字化けしていない
- [ ] reference-docのスタイル（フォント等）が適用されている

---

### Prompt 3-3: 別紙5・別添の記入

```
main/step02_docx/fill_security.py を作成してください。

## 文脈
別紙5（研究セキュリティ質問票）と別添（自己申告書）はそれぞれ独立したdocxファイルです。
別添は**研究者の人数分のコピーを生成**する必要があります（PI + 各分担者）。

## 参照
まず以下の調査コードでテーブル構造を把握してください:

```python
from docx import Document
for fname in ['r08youshiki_besshi5.docx', 'r08youshiki_betten.docx']:
    doc = Document(f'data/source/{fname}')
    print(f"\n=== {fname} ({len(doc.tables)} tables) ===")
    for i, table in enumerate(doc.tables):
        print(f"  Table {i} ({len(table.rows)}r x {len(table.columns)}c): {table.rows[0].cells[0].text[:50]}")
```

- main/00_setup/security.yaml の構造（Step 1-3で定義済み）
- main/00_setup/researchers.yaml の研究者リスト

## 機能
1. data/source/r08youshiki_besshi5.docx をコピーして記入
   - Table 0: 提案情報（PI名、所属、研究課題名）→ config.yaml/researchers.yaml から自動取得
   - Tables 1-2: §1(1) デューデリジェンス状態チェックボックス
   - Tables 3-15: §1(2) 13項目の確認テーブル（①〜⑬、**全研究者のデータを同一テーブルに記入**）
   - Table 16: §1 デューデリジェンス結果チェックボックス
   - Tables 17-18: §2 リスク軽減措置要否・新規追加時確認
   - Tables 19-20: §3 共同研究機関リスク確認
   - Tables 21-22: §4 リスク軽減措置チェックボックス
   - Table 23: §4 同意確認
   - 出力: main/step02_docx/output/besshi5_filled.docx

2. data/source/r08youshiki_betten.docx をコピーして記入（研究者ごと）
   - ヘッダ: 研究者名、所属
   - テーブル0〜12: 13項目の自己申告（学歴, 職歴, 資金歴, ...）
   - 出力: main/step02_docx/output/betten_NN_romanized.docx × 人数分
     （例: betten_01_yamada.docx, betten_02_suzuki.docx）

## 設計方針
- fill_forms.py と同様のテーブル特定・セル記入パターンを使用
- 別添は researchers.yaml の全研究者（pi + co_investigators）分を生成
- 「該当なし」の項目は空テーブルのまま残す
- **行追加（row insertion）**: 別紙5 Tables 3-15 は全研究者のデータを同一テーブルに記入する。
  各テーブルのデータ行（ヘッダ除く）は4行前後しかなく、研究者2名以上でオーバーフローする
  場合がある（例: ②職歴は PI 3件 + Co-I 2件 = 5件で4行をオーバー）。
  データ行数が不足する場合は以下の手順で行を追加すること:
  1. テーブルの最終データ行の `_element` を `copy.deepcopy()` で複製
  2. `table._element.append(copied_row)` で末尾に挿入
  3. 複製した行のセルテキストをクリアしてからデータを記入
  4. 書式（フォント、罫線、セル幅）は複製元から継承されるため維持される

## 注意
- data/source/ のオリジナルは変更しない
- ファイル名に日本語氏名を使わない（OS互換性のため連番+ローマ字を使用）
```

#### 完了チェック

- [ ] data/source/ のオリジナルファイルが変更されていない
- [ ] besshi5_filled.docx が生成され、Wordで開ける
- [ ] betten_*.docx が研究者の人数分生成される
- [ ] 「該当なし」の項目でエラーにならない
- [ ] `python -m py_compile main/step02_docx/fill_security.py` がエラーなし

---

## Step 4: Excel文書生成

### 文脈

- Excel文書は**そのまま提出**するため、フォーマットの完全な維持が重要
- openpyxlはドロップダウンリスト（データバリデーション）を維持できるが、
  VBA, 条件付き書式の一部は壊れる場合がある → 元のファイルで使われている機能を確認する
- 様式6は「記載例」シートと「記入用」シートが別になっている点に注意

### 参照すべき資料

| 資料 | 確認ポイント |
|------|------------|
| data/source/r08youshiki6.xlsx | シート構成（4シート）、「様式6」シートの記入対象行（18〜25行目付近）、列の意味（D〜AC列） |
| data/source/r08youshiki7.xlsx | 「採択課題抜粋」シート、記入対象行（21行目以降）、列構成（B〜E列） |
| data/source/r08youshiki8.xlsx | 連絡先シート、行構成（3〜12行目、2列） |
| data/source/r08youshiki6.xlsx 「リスト」シート | ドロップダウンの選択肢一覧（テーマ23種、分野12種、タイプS/A/C/D等） |

### Prompt 4-1: 様式6, 7, 8のExcel記入

```
main/step03_excel/fill_excel.py を作成してください。

## 文脈
Excel文書はそのまま e-Rad で提出されるため、フォーマットの維持が最重要です。
openpyxlでセルに値を書き込むが、書式（フォント、罫線、列幅、行高、セル結合、
ドロップダウンバリデーション）はすべて維持する必要があります。

## 参照
まず以下の調査コードで各ファイルの構造を把握してください:

```python
import openpyxl

# 様式6
wb = openpyxl.load_workbook('data/source/r08youshiki6.xlsx')
for name in wb.sheetnames:
    ws = wb[name]
    print(f"\n=== Sheet: {name} ({ws.max_row}rows x {ws.max_column}cols) ===")
    for row in ws.iter_rows(min_row=1, max_row=min(30, ws.max_row), values_only=False):
        for cell in row:
            if cell.value is not None:
                print(f"  {cell.coordinate}: {str(cell.value)[:60]}")

# 様式7, 8も同様に
```

## 機能

### 様式6 (r08youshiki6.xlsx)
- 「様式6」シートの記入対象行にデータを書き込む
  ※ 上段（1〜4行目付近）は記載例 → 触らない
  ※ 下段（18行目以降）が実際の記入行
- 列の対応:
  - D: 研究テーマ（config.yaml.project.theme_number → テーマ名に変換）
  - E: キーワード
  - F: 研究分野
  - G: タイプ（A）
  - H: 重複応募有無
  - I: 研究課題名（日本語）
  - J: 研究代表者役職
  - K: 研究代表者名
  - L: 代表研究機関
  - M: 分担研究機関（改行区切りで複数）
  - N: 研究期間(年)
  - O〜S: 1年目〜5年目の研究費
  - T: 総額（SUM式を維持するか、値を書くか確認）
  - U: メールアドレス
  - V: 郵送先
  - W〜AC: 機関種別、中小企業、スタートアップ関連
- データソース: config.yaml + researchers.yaml
- 「リスト」シートの選択肢に合致する値を書き込むこと

### 様式7 (r08youshiki7.xlsx)
- 記入対象行（21行目以降）に研究者リストを書き込む
- B: 研究課題名（セル結合あり — 全行で同一値）
- C: 研究機関名（同一機関の研究者はセル結合）
- D: 研究者氏名
- E: 部局・職/職階
- ※ シート名は「採択課題抜粋」（「様式7」ではない）。wb.sheetnames[0] でアクセスすること。
- F, G: 利害関係欄 → 記入しない（事務局使用）
- データソース: researchers.yaml（pi + co_investigators、機関ごとにグループ化）

### 様式8 (r08youshiki8.xlsx)
- ※ シート名は「Sheet1」。wb.sheetnames[0] でアクセスすること。
- 行3: PI メールアドレス（必須）
- 行4〜12: 追加連絡先（最大9件、任意）
- データソース: config.yaml.contacts.emails + researchers.yaml.pi.contact.email

## 設計方針
- load_workbook(data_only=False) で数式を維持
- セルに値を書く際、元の書式（font, alignment, border）を保持
  → 既存のcell.fontを読み取り、変更しない（値の代入のみ）
- セル結合されている場合は merged_cells の範囲を考慮
- ドロップダウンバリデーションは自動維持される（openpyxlのデフォルト挙動）

## 既知の openpyxl 制約と対策（重要）

### Data Validation 拡張非対応（様式6）
openpyxl で様式6を読み込むと `UserWarning: Data Validation extension is not supported
and will be removed` が発生する。保存時にドロ���プダウンリストが削除される可能性がある。

**実装初期に以下の検証テストを実施すること:**
1. `shutil.copy2` でコピー → `load_workbook` → 即 `save` → Excel で開く
2. ドロップダウンリスト（テーマ、分野、タイプ等）が機能するか確認
3. **失敗した場合のフォールバック**: xlsx を ZIP として開き、保存前後で
   `xl/worksheets/sheet1.xml` の `<extLst>` 要素を比較。削除されていれば
   保存後の xlsx に元の `<extLst>` 要素を再注入する（zipfile モジュール使用）

### 条件��き書式破損リスク（様式6）
様式6 には 19個の conditional_formatting ルールが存在する。openpyxl 保存時に
破損する可能性がある。上記の検証テストで条件付き書式の維持も同時に確認すること。

## 注意
- data/source/ のオリジナルは変更しない（shutil.copy2でコピー）
- openpyxl はxlsxのみ対応（xlsは非対応だが今回はすべてxlsx）
- 出力: main/step03_excel/output/youshiki6.xlsx, youshiki7.xlsx, youshiki8.xlsx
- 引数でYAMLパスと出力パスを指定可能にする
```

#### 完了チェック

- [ ] data/source/ のオリジナルファイルが変更されていない
- [ ] 3つのxlsxが出力される
- [ ] 出力xlsxをExcelで開いて書式が維持されている（フォント、罫線、列幅）
- [ ] 様式6のドロップダウンが機能する（テーマ選択等）
- [ ] 様式6の総額列に式が維持されている（or 正しい合計値が入っている）
- [ ] 様式7の研究者が機関ごとにグループ化されている
- [ ] 様式8のPIメールが行3に入っている
- [ ] `python -m py_compile main/step03_excel/fill_excel.py` がエラーなし

---

## Step 5: ビルドスクリプト・パッケージング

### 文脈

- 全ステップを `./scripts/build.sh` 一発で実行可能にする
- 各ステップのスクリプト（fill_forms.py, build_narrative.sh, fill_excel.py 等）を順次呼び出す
- Docker環境での実行を前提とし、uv環境もオプションでサポートする

### 参照すべき資料

| 資料 | 確認ポイント |
|------|------------|
| /home/dryad/anal/jami-abstract-pandoc/Makefile | Docker実行パターン（docker compose run の構成） |

### Prompt 5-1: ビルドスクリプト作成

```
scripts/build.sh を作成してください。

## 文脈
このスクリプトは全ビルドプロセスを統合します。
Docker環境とuv環境の両方に対応する必要があります。

## 参照
- /home/dryad/anal/jami-abstract-pandoc/Makefile を読み、
  Docker経由でのスクリプト実行パターンを参考にしてください

## サブコマンド
引数なしで全ステップを実行。引数で個別ステップを指定可能:

  ./scripts/build.sh          # 全ステップ実行（validate + forms + narrative + excel + security）
  ./scripts/build.sh validate  # YAMLバリデーションのみ（他のステップの前に自動実行される）
  ./scripts/build.sh forms     # テーブルフォーム記入のみ（step02_docx/fill_forms.py）
  ./scripts/build.sh narrative # Markdown→docx変換のみ（step02_docx/build_narrative.sh）
  ./scripts/build.sh security  # セキュリティ文書記入（step02_docx/fill_security.py）
  ./scripts/build.sh excel     # Excel記入のみ（step03_excel/fill_excel.py）
  ./scripts/build.sh package   # パッケージング（scripts/create_package.sh）
  ./scripts/build.sh clean     # 全output/をクリーン
  ./scripts/build.sh check     # 全出力ファイルの存在とサイズチェック

## YAMLバリデーション（validate サブコマンド）
全ステップ実行時、最初に main/00_setup/*.yaml の整合性チェックを行う:
- 4ファイルがYAMLとして正しくパースできるか
- 必須フィールド（project.title_ja, pi.name_ja 等）の存在チェック
- budget.by_institution の機関別合計と budget.details の institution 別合算が一致するか
- researchers.yaml の全研究者が security.yaml の researchers キーに存在するか
- effort_percent の合算が100%を超えていないか（other_funding.yaml との突合）
バリデーション失敗時はエラーメッセージを表示してビルドを中断する。
簡易Pythonスクリプト（例: scripts/validate_yaml.py）として実装し、build.sh から呼び出す。

## 実行方法の切替
環境変数 RUNNER でDocker/uv/直接実行を切替:
  RUNNER=docker ./scripts/build.sh   # デフォルト: docker compose run 経由
  RUNNER=uv ./scripts/build.sh       # uv run 経由
  RUNNER=direct ./scripts/build.sh   # 直接実行

Docker実行時のコマンド例:
  docker compose -f docker/docker-compose.yml run --rm -u $(id -u):$(id -g) python \
    python main/step02_docx/fill_forms.py
```

#### 完了チェック

- [ ] `./scripts/build.sh --help` がサブコマンド一覧を表示する
- [ ] `./scripts/build.sh` が全ステップを実行する（Step 0-4の成果物が揃っている前提）
- [ ] `./scripts/build.sh clean` が全output/を削除する
- [ ] RUNNER=uv に切り替えても動作する

---

### Prompt 5-2: パッケージスクリプト

```
scripts/create_package.sh を新規作成してください。
（既存の同名ファイルは別プロジェクトのものであり、__archives/ に退避済み。）

## 文脈
ビルド成果物を集約し、提出前のバリデーションを行います。
e-Radの制約:
- 各ファイル10MB以下（目標3MB）
- 様式1-1〜5 + 参考様式 → 1つのPDFに結合（Windows側で実施）
- 様式6, 7, 8 → Excel形式のまま提出

## 参照
- SPEC.md §3.3「提出ファイル」の一覧
- data/source/募集要項.pdf p.14-15 の提出方法の説明

## 機能
1. main/step02_docx/output/ と main/step03_excel/output/ の成果物を確認
2. 提出に必要なファイルが揃っているかバリデーション:
   - 必須: youshiki1_5_filled.docx, youshiki1_2_narrative.docx, youshiki1_3_narrative.docx,
           besshi5_filled.docx, betten_*.docx(×人数分),
           youshiki6.xlsx, youshiki7.xlsx, youshiki8.xlsx
3. main/step04_package/output/ にコピーして整理
4. ファイルサイズチェック（各10MB以下、3MB超は警告）
5. チェックリスト出力:
   ☑ 様式1-1〜5: ファイル名, サイズ
   ☑ 別紙5: ファイル名, サイズ
   ☑ 別添 × N人: ファイル名, サイズ
   ☑ 様式6: ファイル名, サイズ
   ☑ 様式7: ファイル名, サイズ
   ☑ 様式8: ファイル名, サイズ
   ☐ Windows側PDF変換（手動確認）
   ☐ e-Radアップロード（手動確認）
```

#### 完了チェック

- [ ] スクリプトが実行可能（chmod +x済み）
- [ ] 全ファイルが揃っている場合に正常終了する
- [ ] 一部ファイルが欠けている場合にエラーメッセージが表示される
- [ ] ファイルサイズが10MBを超える場合に警告が出る
- [ ] チェックリストが標準出力に表示される

---

### Prompt 5-3: E2Eテスト用ダミーデータ配置とテスト実行

```
data/dummy/ にE2Eテスト用のダミーデータを配置し、パイプライン全体の結合テストを実施してください。

## 文脈
各ステップの個別スクリプトが完成した後、全体を通して動作することを確認する必要があります。
data/dummy/ はパイプラインのエンドツーエンドテスト用ダミーデータの配置場所です。
data/source/ の実ファイルがなくても基本的な動作確認ができるようにします。

## 手順
1. main/00_setup/*.yaml の4ファイルを data/dummy/ にコピー
   （プレースホルダ値のままでOK）
2. data/source/*.docx, *.xlsx のテスト用スタブを作成
   - 最小限のテーブル構造を持つ空のdocx/xlsxファイル
   - python-docx / openpyxl で空テンプレートとして生成
3. E2Eテストを実行:
   ./scripts/build.sh を data/dummy/ のYAMLと data/dummy/ のスタブで実行
   （環境変数またはオプションでダミーデータパスを指定）
4. 結果を検証:
   - 全出力ファイルが生成されること
   - 出力docx/xlsxがWordまたはLibreOfficeで開けること
   - ファイルサイズが10MB以下であること
   - YAMLバリデーション（build.sh validate）が通ること
```

#### 完了チェック

- [ ] data/dummy/ に YAML 4ファイルが配置されている
- [ ] `./scripts/build.sh validate` がダミーYAMLで通る
- [ ] `./scripts/build.sh` がダミーデータで全ステップ完走する（data/source/ が必要なステップはスキップ可）
- [ ] 生成された全出力ファイルが開ける

---

## Step 6: Google Drive同期設定

### 文脈

- Linux開発環境とWindows環境の間でGoogle Drive経由でファイルを同期する
- rclone の gdrive リモート（Google Drive）を使用
- main/フォルダのMarkdownソース → Windows側でも閲覧・編集可能にする
- output/フォルダの生成物 → Windows側でWord修復＋PDF化する
- Windows側はGoogle Drive for Desktopでローカル同期済みの前提

### 参照すべき資料

| 資料 | 確認ポイント |
|------|------------|
| scripts/backup.sh | 既存のrclone gdrive使用パターン |
| .gitignore | 同期対象外にすべきパターン |

### Prompt 6-1: 同期スクリプト

```
scripts/sync_gdrive.sh を作成してください。

## 文脈
Linux開発環境（このマシン）とWindows環境の間でGoogle Drive経由のファイル同期を行います。
rclone の gdrive リモートを使用します（rclone config で設定済みの前提）。
Windows側はGoogle Drive for Desktop でローカルフォルダに自動同期されます。

## 参照
- scripts/backup.sh を読んで、既存のrclone gdrive使用パターンを確認してください
- .gitignore を読んで、同期から除外すべきパターンを確認してください

## 機能
- rclone bisync で双方向同期（Linux ↔ Google Drive）
- 同期対象:
  - main/ ↔ gdrive:med-resist-grant/main/
  - main/step02_docx/output/ ↔ gdrive:med-resist-grant/output/docx/
  - main/step03_excel/output/ ↔ gdrive:med-resist-grant/output/excel/
  - main/step04_package/output/ ↔ gdrive:med-resist-grant/output/package/
- 除外パターン（.gitignoreベース）:
  - __pycache__/, .ipynb_checkpoints/, *.pyc, *.tmp, .DS_Store
- オプション:
  - -n (--dry-run): ドライラン（実際の同期なし、プレビューのみ）
  - --resync: 初回同期（bisyncの初期化に必要）
  - --remote=NAME: rcloneリモート名の指定（デフォルト: gdrive）

## 使い方例
  # 初回
  ./scripts/sync_gdrive.sh --resync
  # ドライラン
  ./scripts/sync_gdrive.sh -n
  # 通常同期
  ./scripts/sync_gdrive.sh
  # リモート名を指定
  ./scripts/sync_gdrive.sh --remote=mygdrive
```

#### 完了チェック

- [ ] `./scripts/sync_gdrive.sh -n` がドライランとして動作する（rclone未設定でもエラーメッセージが適切）
- [ ] --help オプションで使い方が表示される
- [ ] 除外パターンが.gitignoreと整合している
- [ ] data/source/ は同期対象に含まれていない

---

## Step 7: Windows側Word修復環境

### 文脈

- python-docxやPandocで生成したdocxは、Wordで開くと「修復が必要」と表示される場合がある
- Word COM APIの「Open and Repair」で修復→保存→PDF出力を自動化する
- jami-abstract-pandocのword-to-pdf.batが参考になる

### 参照すべき資料

| 資料 | 確認ポイント |
|------|------------|
| /home/dryad/anal/jami-abstract-pandoc/scripts/word-to-pdf.bat | VBScript/COM APIでのWord操作パターン、ドラッグ＆ドロップUI |

### Prompt 7-1: Windows側バッチスクリプト

```
scripts/windows/ 以下にWord修復・PDF変換スクリプトを作成してください。

## 文脈
Google Drive経由で転送されたdocxファイルをWindows上のMicrosoft Wordで修復し、
PDF形式に変換するスクリプトです。
VBScript（.vbs）またはPowerShell（.ps1）で実装します。

## 参照
必ず以下を読んで実装パターンを把握してください:
- /home/dryad/anal/jami-abstract-pandoc/scripts/word-to-pdf.bat
  （Word COM API: Application.Documents.Open の ConfirmConversions, OpenAndRepair パラメータ、
   ExportAsFixedFormat でのPDF出力等）

## 機能

### repair_and_pdf.ps1（または .vbs）
1. 引数: 入力docxパス, 出力フォルダパス
2. Word COMオブジェクトを作成
3. OpenAndRepair=True で docx を開く
4. 修復済みdocxを保存（元ファイルと同名 or _repaired サフィックス）
5. ExportAsFixedFormat で PDF 出力
6. Wordを閉じる

### batch_convert.ps1
1. 引数: 入力フォルダパス, 出力フォルダパス
2. フォルダ内の全 *.docx を列挙
3. 各ファイルに対して repair_and_pdf を実行
4. 結合が必要なPDF（様式1-1〜5）については案内メッセージを表示
   （Word/Acrobatでの結合手順、またはPython pypdf での結合スクリプト）

## 注意
- Windows環境で実行されるスクリプト（このLinux環境では動作確認不可）
- エラーハンドリング: Wordが見つからない場合の案内メッセージ
- ファイルパスにスペースが含まれる場合の対応（引用符）
```

#### 完了チェック（Windows側で確認）

- [ ] PowerShell/VBSスクリプトの構文エラーがない
- [ ] テストdocxに対してPDFが生成される
- [ ] 修復済みdocxがWordで正常に開ける
- [ ] バッチ変換でフォルダ内全ファイルが処理される

---

## 実装順序の推奨

```
Step 0 → Step 1 → Step 2 → Step 4 → Step 3 → Step 5 → Step 6 → Step 7
環境構築  YAML定義  MD執筆環境  Excel生成  Word生成   ビルド統合  同期設定   Windows
                    ↓
              （ここから執筆開始可能）
```

**理由:**
1. **Step 0 (環境構築)**: 以降の全ステップの前提
2. **Step 1 (YAML)**: 全フォームの共通データソース → 先に設計
3. **Step 2 (MD)**: 作成後すぐに本文の執筆に着手可能（最も時間がかかる作業）
4. **Step 4 (Excel)**: テーブル構造が単純で動作確認しやすい → 先に実装しパイプラインの検証
5. **Step 3 (Word)**: Excel で得た知見を活かし、より複雑なWord操作を実装
6. **Step 5 (ビルド)**: 全コンポーネント完成後に統合
7. **Step 6, 7**: 環境連携は最後（他のステップと独立）

Step 2完了後は **執筆作業** と **Step 3-5の開発** を並行して進められます。
