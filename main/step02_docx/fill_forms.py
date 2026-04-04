#!/usr/bin/env python3
"""fill_forms.py — r08youshiki1_5.docx テーブルフォーム記入スクリプト

data/source/r08youshiki1_5.docx をコピーし、YAML データに基づいて
各テーブル様式にデータを書き込む。不要な様式は削除する。

Usage:
    python fill_forms.py \\
        --config main/00_setup/config.yaml \\
        --researchers main/00_setup/researchers.yaml \\
        --other-funding main/00_setup/other_funding.yaml \\
        --source data/source/r08youshiki1_5.docx \\
        --output main/step02_docx/output/
"""

import argparse
import copy
import math
import shutil
import sys
import warnings
from pathlib import Path

import yaml
from docx import Document
from docx.oxml.ns import qn
from docx.oxml import OxmlElement


# ============================================================================
# YAML helpers
# ============================================================================

def load_yaml(path):
    """Load YAML file."""
    with open(path, "r", encoding="utf-8") as f:
        return yaml.safe_load(f)


# ============================================================================
# Cell-level helpers
# ============================================================================

def _first_rpr(cell):
    """Return deepcopy of first run's rPr, or None."""
    for p in cell.paragraphs:
        for r in p.runs:
            rpr = r._element.find(qn("w:rPr"))
            if rpr is not None:
                return copy.deepcopy(rpr)
    return None


def _first_ppr(cell):
    """Return deepcopy of first paragraph's pPr, or None."""
    if cell.paragraphs:
        ppr = cell.paragraphs[0]._element.find(qn("w:pPr"))
        if ppr is not None:
            return copy.deepcopy(ppr)
    return None


def set_cell(cell, text):
    r"""Replace all cell content.  ``\n`` → new paragraph.  Preserves first-run format."""
    text = str(text) if text is not None else ""
    rpr = _first_rpr(cell)
    ppr = _first_ppr(cell)
    tc = cell._element
    for old_p in list(tc.findall(qn("w:p"))):
        tc.remove(old_p)
    for line in (text.split("\n") if text else [""]):
        p = OxmlElement("w:p")
        if ppr is not None:
            p.append(copy.deepcopy(ppr))
        r = OxmlElement("w:r")
        if rpr is not None:
            r.append(copy.deepcopy(rpr))
        t = OxmlElement("w:t")
        t.text = line
        t.set(qn("xml:space"), "preserve")
        r.append(t)
        p.append(r)
        tc.append(p)


def circle_choice(cell, target):
    """Mark *target* with ○ in cell to indicate selection."""
    for p in cell.paragraphs:
        for run in p.runs:
            if target in run.text:
                run.text = run.text.replace(target, f"○{target}")
                return True
    # fallback: work with assembled text
    full = cell.text
    if target in full:
        set_cell(cell, full.replace(target, f"○{target}"))
        return True
    warnings.warn(f"circle_choice: '{target}' not found in '{full[:60]}'")
    return False


# ============================================================================
# Format helpers
# ============================================================================

def _fw(s):
    """ASCII → full-width."""
    return "".join(
        chr(ord(c) + 0xFEE0) if 0x21 <= ord(c) <= 0x7E
        else ("\u3000" if c == " " else c)
        for c in str(s)
    )


def _amt(n):
    """Comma-formatted integer string."""
    return f"{int(n):,}" if isinstance(n, (int, float)) else str(n)


def _budget_year(yr, rate):
    """Calculate derived budget fields for one fiscal year."""
    e = yr.get("equipment", 0)
    c = yr.get("consumables", 0)
    t = yr.get("travel", 0)
    p = yr.get("personnel", 0)
    o = yr.get("other", 0)
    d = e + c + t + p + o
    i = math.ceil(d * rate)
    return dict(goods=e + c, travel=t, personnel=p, other=o,
                direct=d, indirect=i, total=d + i)


# ============================================================================
# Table identification
# ============================================================================

def identify_tables(doc):
    """Pattern-match each form table.  Returns ``{key: Table}``."""
    found = {}
    detail = []   # 様式2-2
    cv = []        # 様式4
    form3 = []     # 様式3

    for table in doc.tables:
        nr, nc = len(table.rows), len(table.columns)
        c00 = table.cell(0, 0).text

        # 様式1-1: 20r×8c  ①研究テーマ in top-left
        if "①研究テーマ" in c00 and nr >= 20:
            found["1-1"] = table
            continue

        # 様式2-1 費目内訳: 9r×7c  contains ア．物品費
        if nr == 9 and nc == 7:
            if any("ア．物品費" in table.cell(r, 0).text for r in range(nr)):
                found["2-1"] = table
                continue

        # 様式2-1 機関別: 6r×7c  header matches + appears after 2-1
        if nr == 6 and nc == 7 and "研究費の内訳" in c00 and "2-1" in found:
            found["2-1_inst"] = table
            continue

        # 様式2-2: 12r×5c  Ⅰ in row-1 col-0
        if nr == 12 and nc == 5:
            r1 = table.cell(1, 0).text
            if "Ⅰ" in r1 or "物品費" in r1:
                detail.append(table)
                continue

        # 様式3: 6r×8c  【本研究課題】 in row-1 col-2
        if nr >= 5 and nc == 8:
            try:
                if any("【本研究課題】" in table.cell(r, 2).text
                       for r in range(min(nr, 3))):
                    form3.append(table)
                    continue
            except Exception:
                pass

        # 様式4: 10r×5c  研究課題名 in top-left
        if nr == 10 and nc == 5 and "研究課題名" in c00:
            cv.append(table)
            continue

        # 様式5: 26r×7c  企業名
        if nr >= 25 and nc == 7 and "企" in c00:
            found["5"] = table
            continue

        # チェックリスト: Nx2  チェック in header
        if nc == 2 and any("チェック" in c.text for c in table.rows[0].cells):
            found["checklist"] = table
            continue

    for i, t in enumerate(detail):
        found[f"2-2_y{i + 1}"] = t
    if form3:
        found["3-1"] = form3[0]
    if len(form3) > 1:
        found["3-2"] = form3[1]
    for i, t in enumerate(cv):
        found[f"4-{i + 1}"] = t
    return found


# ============================================================================
# Fill: 様式1-1  (Table 0: 20r×8c)
# ============================================================================

def fill_1_1(tbl, cfg, res, ofund):
    """Fill 様式1-1 申請書概要."""
    proj = cfg["project"]
    pi = res["pi"]
    admin = res["admin_contact"]
    inst = cfg["lead_institution"]
    budget = cfg["budget"]
    rate = budget.get("indirect_rate", 0.3)

    # ① 研究テーマ
    set_cell(tbl.cell(0, 3), str(proj["theme_number"]))

    # ② 研究課題名
    set_cell(tbl.cell(1, 3), proj["title_ja"])
    set_cell(tbl.cell(2, 3), proj["title_en"])

    # ③ 研究分野 — ○ で選択
    circle_choice(tbl.cell(3, 3), proj["field"])

    # ④ キーワード
    kw = proj.get("keywords", [])
    set_cell(tbl.cell(4, 3), "、".join(str(k) for k in kw) if kw else "")

    # ⑤ 研究の概要
    set_cell(tbl.cell(5, 3), proj.get("summary", ""))

    # ⑥ 研究期間
    s = str(proj.get("period_start", "R8")).replace("R", "")
    e = str(proj.get("period_end", "R10")).replace("R", "")
    y = str(proj.get("period_years", 3))
    set_cell(tbl.cell(6, 3),
             f"令和{_fw(s)}年度 ～ 令和{_fw(e)}年度（{_fw(y)}か年度）")

    # ⑦ 申請額
    total = sum(_budget_year(yr, rate)["total"] for yr in budget["yearly"])
    set_cell(tbl.cell(7, 3), f"{_amt(total)}千円")

    # ⑧ タイプ — ○ で選択
    tp = str(proj.get("type", "A"))
    circle_choice(tbl.cell(8, 3), f"タイプ{_fw(tp)}")

    # ⑧ 重複応募
    if proj.get("duplicate_application"):
        circle_choice(tbl.cell(8, 7), "有")
    else:
        circle_choice(tbl.cell(8, 7), "無")

    # ⑨ 研究代表者 (rows 9–11)
    set_cell(tbl.cell(9, 3), pi["name_ja"])
    set_cell(tbl.cell(9, 7), pi.get("nationality", ""))

    set_cell(tbl.cell(10, 3),
             f"{pi.get('affiliation', '')}・"
             f"{pi.get('department', '')}・"
             f"{pi.get('position', '')}")

    ct = pi.get("contact", {})
    postal = ct.get("postal", "").replace("〒", "").strip()
    set_cell(tbl.cell(11, 3),
             f"〒{postal}\nTEL: {ct.get('tel', '')}\nE-mail: {ct.get('email', '')}")

    # ⑩ 経理事務担当者 (rows 12–14)
    set_cell(tbl.cell(12, 3), admin.get("name", ""))

    set_cell(tbl.cell(13, 3),
             f"{admin.get('affiliation', '')}・"
             f"{admin.get('department', '')}・"
             f"{admin.get('position', '')}")

    set_cell(tbl.cell(14, 3),
             f"〒\nTEL: {admin.get('tel', '')}\nE-mail: {admin.get('email', '')}")

    # ⑪ 研究者リスト (rows 17–19)
    set_cell(tbl.cell(17, 0), inst.get("name", ""))
    set_cell(tbl.cell(17, 3), f"研究代表者\n{pi['name_ja']}")
    set_cell(tbl.cell(17, 4),
             f"{pi.get('department', '')}・{pi.get('position', '')}\n"
             f"TEL: {ct.get('tel', '')}\nE-mail: {ct.get('email', '')}")

    for idx, co in enumerate(res.get("co_investigators", [])):
        row = 18 + idx
        if row >= len(tbl.rows):
            warnings.warn("様式1-1: not enough rows for all co-investigators")
            break
        co_ct = co.get("contact", {})
        set_cell(tbl.cell(row, 0),
                 co.get("institution", co.get("affiliation", "")))
        set_cell(tbl.cell(row, 3), f"研究分担者\n{co['name_ja']}")
        set_cell(tbl.cell(row, 4),
                 f"{co.get('department', '')}・{co.get('position', '')}\n"
                 f"TEL: {co_ct.get('tel', '')}\n"
                 f"E-mail: {co_ct.get('email', '')}")

    print("  ✓ 様式1-1")


# ============================================================================
# Fill: 様式2-1 費目内訳  (Table 3: 9r×7c)
# ============================================================================

def fill_2_1(tbl, cfg):
    """Fill 様式2-1 年度別費目内訳."""
    budget = cfg["budget"]
    rate = budget.get("indirect_rate", 0.3)
    for yr in budget["yearly"]:
        col = yr["year"]
        if col > 5:
            continue
        b = _budget_year(yr, rate)
        set_cell(tbl.cell(2, col), _amt(b["direct"]))     # 直接経費
        set_cell(tbl.cell(3, col), _amt(b["goods"]))       # ア．物品費
        set_cell(tbl.cell(4, col), _amt(b["personnel"]))   # イ．人件費・謝金
        set_cell(tbl.cell(5, col), _amt(b["travel"]))      # ウ．旅費
        set_cell(tbl.cell(6, col), _amt(b["other"]))       # エ．その他
        set_cell(tbl.cell(7, col), _amt(b["indirect"]))    # 間接経費
        set_cell(tbl.cell(8, col), _amt(b["total"]))       # 合計
    print("  ✓ 様式2-1 費目内訳")


# ============================================================================
# Fill: 様式2-1 機関別  (Table 4: 6r×7c)
# ============================================================================

def fill_2_1_inst(tbl, cfg):
    """Fill 様式2-1 機関別研究費."""
    budget = cfg["budget"]
    rate = budget.get("indirect_rate", 0.3)
    by_inst = budget.get("by_institution", [])

    for ii, inst_data in enumerate(by_inst):
        row = 2 + ii
        if row >= len(tbl.rows) - 1:
            warnings.warn("様式2-1機関別: not enough rows")
            break
        set_cell(tbl.cell(row, 0), inst_data["institution"])
        for yr in inst_data.get("yearly", []):
            col = yr["year"]
            if col > 5:
                continue
            amt = yr.get("amount", 0)
            ind = math.ceil(amt * rate)
            tot = amt + ind
            set_cell(tbl.cell(row, col), f"{_amt(tot)}\n({_amt(ind)})")

    # totals row (last row)
    last = len(tbl.rows) - 1
    for yr in budget["yearly"]:
        col = yr["year"]
        if col > 5:
            continue
        b = _budget_year(yr, rate)
        set_cell(tbl.cell(last, col), f"{_amt(b['total'])}\n({_amt(b['indirect'])})")
    print("  ✓ 様式2-1 機関別")


# ============================================================================
# Fill: 様式2-2  (Tables 5–9: 12r×5c each)
# ============================================================================

def _fill_budget_block(tbl, row, sections):
    """Write aligned multi-line content into a budget-detail row.

    *sections*: list of ``(header_str | None, items_list | None)``
    """
    cols = [[] for _ in range(5)]
    for hdr, items in sections:
        if hdr:
            cols[0].append(hdr)
            for c in range(1, 5):
                cols[c].append("")
        if items:
            for it in items:
                cols[0].append(it.get("name", ""))
                cols[1].append(it.get("quantity", ""))
                cols[2].append(_amt(it.get("amount", 0)))
                cols[3].append(it.get("institution", ""))
                cols[4].append(it.get("justification", ""))
    for c in range(5):
        set_cell(tbl.cell(row, c), "\n".join(cols[c]))


def fill_2_2(tables, cfg):
    """Fill 様式2-2 年度別研究費計画書."""
    budget = cfg["budget"]
    rate = budget.get("indirect_rate", 0.3)

    for yd in budget.get("details", []):
        yr = yd["year"]
        key = f"2-2_y{yr}"
        if key not in tables:
            warnings.warn(f"様式2-2 year {yr} table not found")
            continue
        tbl = tables[key]
        items = yd.get("line_items", [])
        equip = [i for i in items if i["category"] == "equipment"]
        consu = [i for i in items if i["category"] == "consumables"]
        pers  = [i for i in items if i["category"] == "personnel"]
        trav  = [i for i in items if i["category"] == "travel"]
        othr  = [i for i in items if i["category"] == "other"]

        # Row 1: Ⅰ．物品費  (equipment + consumables)
        _fill_budget_block(tbl, 1, [
            ("Ⅰ．物品費", None),
            ("1.設備備品費", equip),
            ("2.消耗品費", consu),
        ])
        g_tot = sum(i.get("amount", 0) for i in equip + consu)
        set_cell(tbl.cell(2, 2), _amt(g_tot))   # 小計

        # Row 3: Ⅱ．人件費・謝金
        _fill_budget_block(tbl, 3, [
            ("Ⅱ．人件費・謝金", None),
            ("1.人件費", pers),
        ])
        p_tot = sum(i.get("amount", 0) for i in pers)
        set_cell(tbl.cell(4, 2), _amt(p_tot))

        # Row 5: Ⅲ．旅費
        _fill_budget_block(tbl, 5, [
            ("Ⅲ．旅費", None),
            ("1.旅費", trav),
        ])
        t_tot = sum(i.get("amount", 0) for i in trav)
        set_cell(tbl.cell(6, 2), _amt(t_tot))

        # Row 7: Ⅳ．その他
        _fill_budget_block(tbl, 7, [
            ("Ⅳ．その他", None),
            (None, othr),
        ])
        o_tot = sum(i.get("amount", 0) for i in othr)
        set_cell(tbl.cell(8, 2), _amt(o_tot))

        # Totals
        direct = g_tot + p_tot + t_tot + o_tot
        indirect = math.ceil(direct * rate)
        set_cell(tbl.cell(9, 2), _amt(direct))
        set_cell(tbl.cell(10, 2), _amt(indirect))
        set_cell(tbl.cell(11, 2), _amt(direct + indirect))

    print("  ✓ 様式2-2")


# ============================================================================
# Fill: 様式3-1  (Table 10: 6r×8c)
# ============================================================================

def fill_3_1(tbl, cfg, res, ofund):
    """Fill 様式3-1 他制度応募状況（研究代表者）."""
    proj = cfg["project"]
    pi = res["pi"]
    budget = cfg["budget"]
    rate = budget.get("indirect_rate", 0.3)

    start = str(proj.get("period_start", "R8"))
    end = str(proj.get("period_end", "R10"))

    # Row 1: 本研究課題
    set_cell(tbl.cell(1, 2), f"【本研究課題】\n{start}～{end}\n防衛装備庁")
    set_cell(tbl.cell(1, 3), proj["title_ja"])
    set_cell(tbl.cell(1, 4), "代表")

    totals = [_budget_year(yr, rate)["total"] for yr in budget["yearly"]]
    yr1 = totals[0] if totals else 0
    grand = sum(totals)
    set_cell(tbl.cell(1, 5), f"{_amt(yr1)}\n({_amt(grand)})")
    set_cell(tbl.cell(1, 6), str(pi.get("effort_percent", "")))

    # Other funding entries
    entries = ofund.get("pi_funding", {}).get("entries", [])
    if not entries:
        set_cell(tbl.cell(2, 2), "無し")
    else:
        for idx, ent in enumerate(entries):
            row = 2 + idx
            if row >= len(tbl.rows):
                warnings.warn("様式3-1: not enough rows for all entries")
                break
            set_cell(tbl.cell(row, 0), str(idx + 2))
            set_cell(tbl.cell(row, 1), ent.get("status", ""))
            agency = ent.get("agency", "") if not ent.get("confidential") else ""
            set_cell(tbl.cell(row, 2),
                     f"{ent.get('program_name', '')}\n"
                     f"{ent.get('period', '')}\n{agency}")
            set_cell(tbl.cell(row, 3), ent.get("project_title", ""))
            set_cell(tbl.cell(row, 4), ent.get("role", ""))
            if ent.get("confidential"):
                set_cell(tbl.cell(row, 5), "")
            else:
                set_cell(tbl.cell(row, 5),
                         f"{_amt(ent.get('budget', 0))}\n"
                         f"({_amt(ent.get('total_budget', 0))})")
            set_cell(tbl.cell(row, 6), str(ent.get("effort_percent", "")))
            set_cell(tbl.cell(row, 7), ent.get("difference", ""))

    print("  ✓ 様式3-1")


# ============================================================================
# Fill: 様式3-2  (Table 11: 6r×8c)
# ============================================================================

def fill_3_2(tbl, cfg, res, ofund):
    """Fill 様式3-2 他制度応募状況（研究分担者）."""
    proj = cfg["project"]
    budget = cfg["budget"]
    rate = budget.get("indirect_rate", 0.3)

    start = str(proj.get("period_start", "R8"))
    end = str(proj.get("period_end", "R10"))

    # Row 1: 本研究課題
    set_cell(tbl.cell(1, 2), f"【本研究課題】\n{start}～{end}\n防衛装備庁")
    set_cell(tbl.cell(1, 3), proj["title_ja"])
    set_cell(tbl.cell(1, 4), "分担")

    totals = [_budget_year(yr, rate)["total"] for yr in budget["yearly"]]
    yr1 = totals[0] if totals else 0
    grand = sum(totals)
    set_cell(tbl.cell(1, 5), f"{_amt(yr1)}\n({_amt(grand)})")

    co_invs = res.get("co_investigators", [])
    efforts = [str(co.get("effort_percent", "")) for co in co_invs]
    set_cell(tbl.cell(1, 6), ", ".join(efforts) if efforts else "")

    # Collect all entries across all co-investigators
    all_entries = []
    for co_fund in ofund.get("co_investigator_funding", []):
        rname = co_fund.get("researcher_name", "")
        for ent in co_fund.get("entries", []):
            all_entries.append((rname, ent))

    if not all_entries:
        set_cell(tbl.cell(2, 2), "無し")
    else:
        for idx, (rname, ent) in enumerate(all_entries):
            row = 2 + idx
            if row >= len(tbl.rows):
                warnings.warn("様式3-2: not enough rows for all entries")
                break
            set_cell(tbl.cell(row, 0), str(idx + 2))
            set_cell(tbl.cell(row, 1), ent.get("status", ""))
            agency = ent.get("agency", "") if not ent.get("confidential") else ""
            set_cell(tbl.cell(row, 2),
                     f"{ent.get('program_name', '')}\n"
                     f"{ent.get('period', '')}\n{agency}")
            set_cell(tbl.cell(row, 3),
                     f"{ent.get('project_title', '')}\n（{rname}）")
            set_cell(tbl.cell(row, 4), ent.get("role", ""))
            if ent.get("confidential"):
                set_cell(tbl.cell(row, 5), "")
            else:
                set_cell(tbl.cell(row, 5),
                         f"{_amt(ent.get('budget', 0))}\n"
                         f"({_amt(ent.get('total_budget', 0))})")
            set_cell(tbl.cell(row, 6), str(ent.get("effort_percent", "")))
            set_cell(tbl.cell(row, 7), ent.get("difference", ""))

    print("  ✓ 様式3-2")


# ============================================================================
# Fill: 様式4  (Tables 12–13: 10r×5c)
# ============================================================================

def fill_4(tbl, cfg, person, label="様式4-1"):
    """Fill 様式4-1 or 4-2 研究者調書."""
    proj = cfg["project"]

    # Row 0: 研究課題名
    set_cell(tbl.cell(0, 2), proj["title_ja"])

    # Row 1: ふりがな/氏名, 生年月日/年齢
    set_cell(tbl.cell(1, 2),
             f"{person.get('furigana', '')}\n{person['name_ja']}")
    age = person.get("age", "")
    set_cell(tbl.cell(1, 4),
             f"{person.get('birth_date', '')}\n（{age}歳）")

    # Row 2: 研究者番号
    set_cell(tbl.cell(2, 2), person.get("researcher_id", ""))

    # Row 2–3, col 4: 最終学歴・学位 (vertically merged)
    edu = person.get("education", {})
    set_cell(tbl.cell(2, 4),
             f"{edu.get('school', '')}\n"
             f"{edu.get('graduation_year', '')}\n"
             f"{edu.get('degree', '')}")

    # Row 3: 所属機関・部局・職/職階
    set_cell(tbl.cell(3, 2),
             f"{person.get('affiliation', '')}・"
             f"{person.get('department', '')}・"
             f"{person.get('position', '')}")

    # Row 4: 専門分野
    set_cell(tbl.cell(4, 2), person.get("specialty", ""))

    # Row 5: 主な経歴
    career = person.get("career_history", [])
    set_cell(tbl.cell(5, 2),
             "\n".join(f"{c.get('year_month', '')}\t{c.get('description', '')}"
                       for c in career) if career else "")

    # Row 6: 競争的研究資金獲得実績
    funding = person.get("funding_history", [])
    lines = []
    for f in funding:
        lines.append(
            f"{f.get('program', '')} 「{f.get('title', '')}」 "
            f"{f.get('role', '')} {f.get('period', '')} {f.get('amount', '')}")
    set_cell(tbl.cell(6, 2), "\n".join(lines) if lines else "")

    # Row 7: 受賞歴・表彰歴
    awards = person.get("awards", [])
    if awards:
        set_cell(tbl.cell(7, 2),
                 "\n".join(f"{a.get('year_month', '')}\t{a.get('name', '')}"
                           for a in awards))
    else:
        set_cell(tbl.cell(7, 2), "無し")

    # Row 8: 研究論文・著書
    pubs = person.get("publications", [])
    set_cell(tbl.cell(8, 2),
             "\n".join(
                 f"{p.get('authors', '')} ({p.get('year', '')}). "
                 f"{p.get('title', '')}. {p.get('journal', '')}."
                 for p in pubs) if pubs else "")

    # Row 9: 知的財産権
    patents = person.get("patents", [])
    if patents:
        set_cell(tbl.cell(9, 2),
                 "\n".join(
                     f"{p.get('title', '')} "
                     f"({p.get('application_number', '')}, {p.get('year', '')})"
                     for p in patents))
    else:
        set_cell(tbl.cell(9, 2), "")

    print(f"  ✓ {label}")


# ============================================================================
# Fill: 参考様式 (consent forms — paragraph-based)
# ============================================================================

def fill_consent_forms(doc, cfg, res):
    """Search consent-form paragraphs for placeholder patterns and fill them.

    The exact placeholder text depends on the template.  This function
    performs best-effort replacement of common patterns.
    """
    inst = cfg["lead_institution"]
    proj = cfg["project"]
    pi = res["pi"]

    signer_name = inst.get("authorized_signer", {}).get("name", "")
    signer_title = inst.get("authorized_signer", {}).get("title", "")
    inst_name = inst.get("name", "")

    in_consent = False
    for para in doc.paragraphs:
        text = para.text
        # Detect consent-form section
        if "承諾書" in text:
            in_consent = True
        elif text.strip().startswith("（様式") or "チェックリスト" in text:
            in_consent = False
            continue
        if not in_consent:
            continue

        for run in para.runs:
            rt = run.text
            # Period placeholder: R8～R　 → R8～R10 etc.
            if "R8～R\u3000" in rt:
                end = str(proj.get("period_end", "R10"))
                run.text = rt.replace("R8～R\u3000", f"R8～{end}")

    print("  ✓ 参考様式 (best-effort)")


# ============================================================================
# Section deletion
# ============================================================================

def delete_sections(doc, tables, cfg, res):
    """Remove unnecessary forms/sections from the document."""
    proj_type = str(cfg["project"].get("type", "A"))
    inst_type = cfg["lead_institution"].get("type", "")
    has_co = bool(res.get("co_investigators", []))

    body = doc.element.body
    children = list(body)

    def _text(el):
        """Extract text from a paragraph element."""
        if el.tag == qn("w:p"):
            return "".join(t.text or ""
                           for t in el.findall(f".//{qn('w:t')}"))
        return ""

    def _find(text, start=0):
        """Find index of first body-child whose text contains *text*."""
        for i in range(start, len(children)):
            if text in _text(children[i]):
                return i
        return -1

    def _tbl_idx(table):
        """Find body-child index for a python-docx Table."""
        el = table._element
        for i, ch in enumerate(children):
            if ch is el:
                return i
        return -1

    remove = set()

    # --- 1. チェックリスト: always delete ---
    ci = _find("応募書類チェックリスト")
    if ci < 0:
        ci = _find("チェックリスト")
    if ci >= 0:
        for i in range(ci, len(children)):
            if children[i].tag != qn("w:sectPr"):
                remove.add(i)

    # --- 2. 補助金参考様式: delete for 委託事業 (S/A/C) ---
    if proj_type in ("S", "A", "C"):
        hi = _find("補助事業")
        if hi < 0:
            hi = _find("補助金")
        if hi >= 0:
            end = ci if (ci >= 0 and ci > hi) else len(children)
            for i in range(hi, end):
                if children[i].tag != qn("w:sectPr"):
                    remove.add(i)

    # --- 3. 様式5: delete if university/public institution ---
    if inst_type in ("大学等", "公的研究機関"):
        si = _find("（様式５）")
        if si >= 0:
            end = _find("承諾書", si + 1)
            if end < 0:
                end = _find("参考様式", si + 1)
            if end < 0:
                end = si + 1
            for i in range(si, end):
                if children[i].tag != qn("w:sectPr"):
                    remove.add(i)

    # --- 4. 様式4-2: delete if no co-investigators ---
    if not has_co:
        fi = _find("（様式４－２）")
        if fi >= 0:
            end = _find("（様式５）", fi + 1)
            if end < 0:
                end = _find("承諾書", fi + 1)
            if end < 0:
                end = fi + 1
            for i in range(fi, end):
                if children[i].tag != qn("w:sectPr"):
                    remove.add(i)

    # --- 5. 様式2-2 years 4 & 5: delete for Type A (3-year) ---
    if proj_type == "A":
        for key in ("2-2_y4", "2-2_y5"):
            if key in tables:
                ti = _tbl_idx(tables[key])
                if ti >= 0:
                    remove.add(ti)
                    # Remove year-header paragraph above the table
                    if ti > 0 and "年目" in _text(children[ti - 1]):
                        remove.add(ti - 1)

    # Delete in reverse order to keep indices stable
    for i in sorted(remove, reverse=True):
        if i < len(children) and children[i].tag != qn("w:sectPr"):
            body.remove(children[i])

    if remove:
        print(f"  ✓ Deleted {len(remove)} elements from unnecessary sections")


# ============================================================================
# Main
# ============================================================================

def main():
    ap = argparse.ArgumentParser(
        description="Fill table forms in r08youshiki1_5.docx")
    ap.add_argument("--config", default="main/00_setup/config.yaml",
                    help="config.yaml path")
    ap.add_argument("--researchers", default="main/00_setup/researchers.yaml",
                    help="researchers.yaml path")
    ap.add_argument("--other-funding", default="main/00_setup/other_funding.yaml",
                    help="other_funding.yaml path")
    ap.add_argument("--source", default="data/source/r08youshiki1_5.docx",
                    help="Source docx template")
    ap.add_argument("--output", default="main/step02_docx/output/",
                    help="Output directory")
    args = ap.parse_args()

    # ---- Load data ----
    print("Loading YAML data...")
    cfg = load_yaml(args.config)
    res = load_yaml(args.researchers)
    ofund = load_yaml(args.other_funding)

    # ---- Copy source ----
    out_dir = Path(args.output)
    out_dir.mkdir(parents=True, exist_ok=True)
    out_path = out_dir / "youshiki1_5_filled.docx"
    shutil.copy2(args.source, out_path)
    print(f"Copied template -> {out_path}")

    # ---- Open ----
    doc = Document(str(out_path))

    # ---- Identify tables ----
    tables = identify_tables(doc)
    print(f"Identified tables: {sorted(tables.keys())}")

    has_co = bool(res.get("co_investigators", []))

    # ---- Fill forms ----
    print("\nFilling forms...")

    if "1-1" in tables:
        fill_1_1(tables["1-1"], cfg, res, ofund)
    else:
        warnings.warn("様式1-1 not found")

    if "2-1" in tables:
        fill_2_1(tables["2-1"], cfg)

    if "2-1_inst" in tables:
        fill_2_1_inst(tables["2-1_inst"], cfg)

    fill_2_2(tables, cfg)

    if "3-1" in tables:
        fill_3_1(tables["3-1"], cfg, res, ofund)

    if "3-2" in tables:
        fill_3_2(tables["3-2"], cfg, res, ofund)

    if "4-1" in tables:
        fill_4(tables["4-1"], cfg, res["pi"], "様式4-1")

    if "4-2" in tables and has_co:
        fill_4(tables["4-2"], cfg, res["co_investigators"][0], "様式4-2")

    fill_consent_forms(doc, cfg, res)

    # ---- Delete unnecessary sections ----
    print("\nCleaning up...")
    delete_sections(doc, tables, cfg, res)

    # ---- Save ----
    doc.save(str(out_path))
    print(f"\nDone: {out_path}")


if __name__ == "__main__":
    main()
