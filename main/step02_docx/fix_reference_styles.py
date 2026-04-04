#!/usr/bin/env python3
"""fix_reference_styles.py — reference.docx のスタイルを様式に合わせて設定する

Pandocデフォルトの reference.docx に対して、元の様式 (r08youshiki1_5.docx) に
合わせたフォント・サイズを設定する。

Usage:
    python fix_reference_styles.py templates/reference.docx
"""

import sys
from pathlib import Path

from docx import Document
from docx.shared import Pt
from docx.oxml.ns import qn
from docx.oxml import OxmlElement


def set_style_font(style, ascii_font, east_asia_font, size_pt, bold=None):
    """スタイルのフォント名・サイズ・太字を設定する。"""
    font = style.font
    font.name = ascii_font
    font.size = Pt(size_pt)
    if bold is not None:
        font.bold = bold

    # East Asian font (python-docx doesn't expose this directly)
    rpr = style.element.get_or_add_rPr()
    rfonts = rpr.find(qn("w:rFonts"))
    if rfonts is None:
        rfonts = OxmlElement("w:rFonts")
        rpr.insert(0, rfonts)
    rfonts.set(qn("w:eastAsia"), east_asia_font)
    # Also set hAnsi to match ascii
    rfonts.set(qn("w:hAnsi"), ascii_font)


def set_doc_defaults(doc, ascii_font, east_asia_font, size_pt):
    """ドキュメントデフォルトのフォントとサイズを設定する。"""
    styles_elem = doc.styles.element
    defaults = styles_elem.find(qn("w:docDefaults"))
    if defaults is None:
        defaults = OxmlElement("w:docDefaults")
        styles_elem.insert(0, defaults)

    rpr_default = defaults.find(qn("w:rPrDefault"))
    if rpr_default is None:
        rpr_default = OxmlElement("w:rPrDefault")
        defaults.insert(0, rpr_default)

    rpr = rpr_default.find(qn("w:rPr"))
    if rpr is None:
        rpr = OxmlElement("w:rPr")
        rpr_default.insert(0, rpr)

    # Font
    rfonts = rpr.find(qn("w:rFonts"))
    if rfonts is None:
        rfonts = OxmlElement("w:rFonts")
        rpr.insert(0, rfonts)
    rfonts.set(qn("w:ascii"), ascii_font)
    rfonts.set(qn("w:eastAsia"), east_asia_font)
    rfonts.set(qn("w:hAnsi"), ascii_font)

    # Size
    sz = rpr.find(qn("w:sz"))
    if sz is None:
        sz = OxmlElement("w:sz")
        rpr.append(sz)
    sz.set(qn("w:val"), str(int(size_pt * 2)))

    sz_cs = rpr.find(qn("w:szCs"))
    if sz_cs is None:
        sz_cs = OxmlElement("w:szCs")
        rpr.append(sz_cs)
    sz_cs.set(qn("w:val"), str(int(size_pt * 2)))


def main():
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <reference.docx>", file=sys.stderr)
        sys.exit(1)

    ref_path = Path(sys.argv[1])
    if not ref_path.exists():
        print(f"ERROR: {ref_path} が見つかりません", file=sys.stderr)
        sys.exit(1)

    doc = Document(str(ref_path))

    # --- ドキュメントデフォルト: MS明朝 10.5pt ---
    set_doc_defaults(doc, "MS Mincho", "ＭＳ 明朝", 10.5)
    print("  docDefaults: ＭＳ 明朝 10.5pt")

    # --- Normal (本文): MS明朝 10.5pt ---
    style = doc.styles["Normal"]
    set_style_font(style, "MS Mincho", "ＭＳ 明朝", 10.5)
    print("  Normal: ＭＳ 明朝 10.5pt")

    # --- Heading 1: MSゴシック 12pt 太字 ---
    style = doc.styles["Heading 1"]
    set_style_font(style, "MS Gothic", "ＭＳ ゴシック", 12, bold=True)
    # Remove color override (Pandoc default sets blue)
    font = style.font
    font.color.rgb = None
    print("  Heading 1: ＭＳ ゴシック 12pt 太字")

    # --- Heading 2: MSゴシック 10.5pt 太字 ---
    style = doc.styles["Heading 2"]
    set_style_font(style, "MS Gothic", "ＭＳ ゴシック", 10.5, bold=True)
    font = style.font
    font.color.rgb = None
    print("  Heading 2: ＭＳ ゴシック 10.5pt 太字")

    # --- Heading 3: MSゴシック 10.5pt ---
    try:
        style = doc.styles["Heading 3"]
        set_style_font(style, "MS Gothic", "ＭＳ ゴシック", 10.5)
        font = style.font
        font.color.rgb = None
        print("  Heading 3: ＭＳ ゴシック 10.5pt")
    except KeyError:
        pass

    # --- Body Text: MS明朝 10.5pt ---
    try:
        style = doc.styles["Body Text"]
        set_style_font(style, "MS Mincho", "ＭＳ 明朝", 10.5)
        print("  Body Text: ＭＳ 明朝 10.5pt")
    except KeyError:
        pass

    # --- First Paragraph / Compact: MS明朝 10.5pt ---
    for name in ["First Paragraph", "Compact"]:
        try:
            style = doc.styles[name]
            set_style_font(style, "MS Mincho", "ＭＳ 明朝", 10.5)
            print(f"  {name}: ＭＳ 明朝 10.5pt")
        except KeyError:
            pass

    doc.save(str(ref_path))
    print(f"\n  Saved: {ref_path}")


if __name__ == "__main__":
    main()
