#!/usr/bin/env python3
"""Post-process Pandoc docx output to wrap TextBoxMarker regions in OOXML text boxes.

Reads the docx file, finds TextBoxMarker-styled paragraphs emitted by
filters/textbox-minimal.lua, collects the content between START/END markers,
and wraps them in DrawingML text box anchors (wp:anchor > wps:wsp >
w:txbxContent). Optionally embeds SVG images natively via asvg:svgBlob.

Minimal port of next-gen-comp-paper/scripts/wrap-textbox.py for med-resist-grant.
Removed: booktabs borders, table resizing inside textboxes, page-based
relocation. Added: --docpr-id-base for narrative-scoped docPr@id allocation.

Preserves the original document.xml root element (with all namespace
declarations) to avoid corruption caused by ElementTree re-serialization.

================================================================================
⚠ ElementTree register_namespace のグローバル副作用に注意（M14-01 / N14-03）
================================================================================

`xml.etree.ElementTree._namespace_map` はモジュール global の dict で、
`register_namespace(prefix, uri)` はエントリを破壊的に上書きします。特に
`prefix=""`（default xmlns）は 1 つしか保持できないため、同一プロセス内で
複数の URI を default として使う場合、最後の呼び出しが勝つだけで既存の
default 指定は失効します。

M14-01 ではこれにより rels と Content_Types を両方 default にしようとして
rels 側の Relationship が空 namespace で serialize され、Word 2016+ が
「ファイルが破損している可能性があります」と判定する致命的バグが発生しました。

⇒ **新規要素は必ず fully-qualified Clark notation で作成する**:
   NG: `ET.SubElement(parent, "Tag")`
   OK: `ET.SubElement(parent, f"{{{URI}}}Tag")`
   これにより register_namespace の状態に依存せず、要素は常に正しい
   namespace URI を保持します。

この規約は `inject_narrative.py` にも共有（M14-02）。lxml 移行で根絶可能
（I14-01）。
"""

import argparse
import os
import re
import shutil
import sys
import tempfile
import zipfile
import xml.etree.ElementTree as ET
from io import BytesIO

# ============================================================================
# Namespaces — must include asvg + a14 (M09-04 parity with inject_narrative.py)
# ============================================================================

NSMAP = {
    "w": "http://schemas.openxmlformats.org/wordprocessingml/2006/main",
    "r": "http://schemas.openxmlformats.org/officeDocument/2006/relationships",
    "wp": "http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing",
    "wp14": "http://schemas.microsoft.com/office/word/2010/wordprocessingDrawing",
    "wps": "http://schemas.microsoft.com/office/word/2010/wordprocessingShape",
    "a": "http://schemas.openxmlformats.org/drawingml/2006/main",
    "mc": "http://schemas.openxmlformats.org/markup-compatibility/2006",
    "m": "http://schemas.openxmlformats.org/officeDocument/2006/math",
    "o": "urn:schemas-microsoft-com:office:office",
    "v": "urn:schemas-microsoft-com:vml",
    "w10": "urn:schemas-microsoft-com:office:word",
    "w14": "http://schemas.microsoft.com/office/word/2010/wordml",
    "w15": "http://schemas.microsoft.com/office/word/2012/wordml",
    "pic": "http://schemas.openxmlformats.org/drawingml/2006/picture",
    "wpc": "http://schemas.microsoft.com/office/word/2010/wordprocessingCanvas",
    "asvg": "http://schemas.microsoft.com/office/drawing/2016/SVG/main",
    "a14": "http://schemas.microsoft.com/office/drawing/2010/main",
}

for _prefix, _uri in NSMAP.items():
    ET.register_namespace(_prefix, _uri)

W = "{http://schemas.openxmlformats.org/wordprocessingml/2006/main}"
WP = "{http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing}"
WPS = "{http://schemas.microsoft.com/office/word/2010/wordprocessingShape}"
A = "{http://schemas.openxmlformats.org/drawingml/2006/main}"
ASVG = "{http://schemas.microsoft.com/office/drawing/2016/SVG/main}"
R = "{http://schemas.openxmlformats.org/officeDocument/2006/relationships}"
PIC = "{http://schemas.openxmlformats.org/drawingml/2006/picture}"


# ============================================================================
# Marker detection
# ============================================================================

def get_marker_text(para):
    """Extract hidden text from a TextBoxMarker paragraph."""
    for r in para.findall(f"{W}r"):
        for t in r.findall(f"{W}t"):
            if t.text:
                return t.text
    return ""


def is_textbox_marker(para):
    """Return True if paragraph uses the TextBoxMarker style."""
    ppr = para.find(f"{W}pPr")
    if ppr is None:
        return False
    pstyle = ppr.find(f"{W}pStyle")
    if pstyle is None:
        return False
    return pstyle.get(f"{W}val") == "TextBoxMarker"


def parse_attrs(text):
    """Parse 'TEXTBOX_START:key=val;key=val;...' into a dict."""
    prefix = "TEXTBOX_START:"
    if not text.startswith(prefix):
        return {}
    params_str = text[len(prefix):]
    attrs = {}
    for pair in params_str.split(";"):
        if "=" in pair:
            k, v = pair.split("=", 1)
            attrs[k.strip()] = v.strip()
    return attrs


# ============================================================================
# Content resizing
# ============================================================================

def resize_images_in_content(content_elements, max_width_emu):
    """Resize inline images in content to fit within max_width_emu.

    Updates both the outer wp:inline/wp:extent (which Word uses for
    layout) and the inner a:xfrm/a:ext (which DrawingML uses for the
    picture frame). Only the dimensional a:ext inside the xfrm is
    touched — the URI-tagged a:ext inside a:extLst (used by the
    asvg:svgBlob extension) is never rewritten because we address the
    xfrm/ext explicitly rather than iter()ing over every a:ext
    descendant (N11-03).
    """
    xfrm_ext_path = (
        f"{A}graphic/{A}graphicData/{PIC}pic/{PIC}spPr/{A}xfrm/{A}ext"
    )
    for elem in content_elements:
        for inline in elem.iter(f"{WP}inline"):
            ext = inline.find(f"{WP}extent")
            if ext is None:
                continue
            cx = int(ext.get("cx", "0"))
            cy = int(ext.get("cy", "0"))
            if cx <= 0 or cx <= max_width_emu:
                continue
            ratio = max_width_emu / cx
            new_cx = max_width_emu
            new_cy = int(cy * ratio)
            ext.set("cx", str(new_cx))
            ext.set("cy", str(new_cy))
            xfrm_ext = inline.find(xfrm_ext_path)
            if xfrm_ext is not None:
                a_cx = int(xfrm_ext.get("cx", "0"))
                a_cy = int(xfrm_ext.get("cy", "0"))
                if a_cx > 0:
                    a_ratio = max_width_emu / a_cx
                    xfrm_ext.set("cx", str(max_width_emu))
                    xfrm_ext.set("cy", str(int(a_cy * a_ratio)))


# ============================================================================
# Textbox paragraph builder
# ============================================================================

def build_textbox_paragraph(attrs, content_elements, z_order, id_base):
    """Build an OOXML paragraph containing a text box anchor with content.

    docPr@id is allocated as ``id_base + z_order`` so that narrative-level
    callers (1-2, 1-3) can pick disjoint ranges to avoid post-inject collisions.
    """
    # N12-07: z_order が 1000 を超えると隣接 narrative の id_base 空間
    # （1-2=3000, 1-3=4000）に侵食する。inject 時の衝突検査で発見は可能だが、
    # 事前に wrap_textbox 単体で fail-fast させる方が開発体験が良い。
    if z_order >= 1000:
        raise ValueError(
            f"textbox z_order={z_order} exceeds the 1000-id window reserved "
            f"for a single narrative (id_base={id_base}). Either split the "
            f"narrative or widen the base spacing in build_narrative.sh."
        )
    width = int(attrs.get("width", "0"))
    height = int(attrs.get("height", "0"))
    pos_x = int(attrs.get("pos-x", "0"))
    pos_y = int(attrs.get("pos-y", "0"))
    anchor_h = attrs.get("anchor-h", "page")
    anchor_v = attrs.get("anchor-v", "page")
    wrap = attrs.get("wrap", "tight")
    behind = attrs.get("behind", "true")
    behind_val = "1" if behind == "true" else "0"

    # Internal margin (EMU): minimal — align content to top/edges.
    l_ins = 45720   # ~1.27mm left
    t_ins = 0       # 0 top — content aligns to textbox top edge
    r_ins = 45720   # ~1.27mm right
    b_ins = 0       # 0 bottom

    # Resize images to fit textbox content width.
    content_width = width - l_ins - r_ins
    resize_images_in_content(content_elements, content_width)

    anchor = ET.Element(f"{WP}anchor")
    anchor.set("distT", "0")
    anchor.set("distB", "0")
    anchor.set("distL", "114300")
    anchor.set("distR", "114300")
    anchor.set("simplePos", "0")
    anchor.set("relativeHeight", str(251659776 + z_order * 2))
    anchor.set("behindDoc", behind_val)
    anchor.set("locked", "0")
    anchor.set("layoutInCell", "1")
    anchor.set("allowOverlap", "1")

    sp = ET.SubElement(anchor, f"{WP}simplePos")
    sp.set("x", "0")
    sp.set("y", "0")

    ph = ET.SubElement(anchor, f"{WP}positionH")
    ph.set("relativeFrom", anchor_h)
    po_h = ET.SubElement(ph, f"{WP}posOffset")
    po_h.text = str(pos_x)

    pv = ET.SubElement(anchor, f"{WP}positionV")
    pv.set("relativeFrom", anchor_v)
    po_v = ET.SubElement(pv, f"{WP}posOffset")
    po_v.text = str(pos_y)

    ext = ET.SubElement(anchor, f"{WP}extent")
    ext.set("cx", str(width))
    ext.set("cy", str(height))

    ee = ET.SubElement(anchor, f"{WP}effectExtent")
    ee.set("l", "0")
    ee.set("t", "0")
    ee.set("r", "0")
    ee.set("b", "0")

    if wrap == "tight":
        wt = ET.SubElement(anchor, f"{WP}wrapTight")
        wt.set("wrapText", "bothSides")
        wp_poly = ET.SubElement(wt, f"{WP}wrapPolygon")
        wp_poly.set("edited", "0")
        for idx, coords in enumerate(
            [(0, 0), (0, 21600), (21600, 21600), (21600, 0), (0, 0)]
        ):
            tag = f"{WP}start" if idx == 0 else f"{WP}lineTo"
            pt = ET.SubElement(wp_poly, tag)
            pt.set("x", str(coords[0]))
            pt.set("y", str(coords[1]))
    elif wrap == "square":
        ws = ET.SubElement(anchor, f"{WP}wrapSquare")
        ws.set("wrapText", "bothSides")
    else:
        ET.SubElement(anchor, f"{WP}wrapNone")

    dp = ET.SubElement(anchor, f"{WP}docPr")
    dp.set("id", str(id_base + z_order))
    dp.set("name", f"TextBox {z_order + 1}")

    cnv = ET.SubElement(anchor, f"{WP}cNvGraphicFramePr")
    ET.SubElement(cnv, f"{A}graphicFrameLocks")

    graphic = ET.SubElement(anchor, f"{A}graphic")
    gd = ET.SubElement(graphic, f"{A}graphicData")
    gd.set("uri", "http://schemas.microsoft.com/office/word/2010/wordprocessingShape")

    wsp = ET.SubElement(gd, f"{WPS}wsp")

    cnvsp = ET.SubElement(wsp, f"{WPS}cNvSpPr")
    cnvsp.set("txBox", "1")
    ET.SubElement(cnvsp, f"{A}spLocks")

    sppr = ET.SubElement(wsp, f"{WPS}spPr")
    xfrm = ET.SubElement(sppr, f"{A}xfrm")
    off = ET.SubElement(xfrm, f"{A}off")
    off.set("x", "0")
    off.set("y", "0")
    aext = ET.SubElement(xfrm, f"{A}ext")
    aext.set("cx", str(width))
    aext.set("cy", str(height))
    pgeom = ET.SubElement(sppr, f"{A}prstGeom")
    pgeom.set("prst", "rect")
    ET.SubElement(pgeom, f"{A}avLst")
    sfill = ET.SubElement(sppr, f"{A}solidFill")
    sysclr = ET.SubElement(sfill, f"{A}sysClr")
    sysclr.set("val", "window")
    sysclr.set("lastClr", "FFFFFF")
    ln = ET.SubElement(sppr, f"{A}ln")
    ln.set("w", "6350")
    ET.SubElement(ln, f"{A}noFill")

    txbx = ET.SubElement(wsp, f"{WPS}txbx")
    txbxc = ET.SubElement(txbx, f"{W}txbxContent")
    for elem in content_elements:
        txbxc.append(elem)

    valign = attrs.get("valign", "top")
    anchor_val = "b" if valign == "bottom" else "t"
    bpr = ET.SubElement(wsp, f"{WPS}bodyPr")
    bpr.set("wrap", "square")
    bpr.set("anchor", anchor_val)
    bpr.set("lIns", str(l_ins))
    bpr.set("tIns", str(t_ins))
    bpr.set("rIns", str(r_ins))
    bpr.set("bIns", str(b_ins))

    # Anchor paragraph collapsed to zero height so it doesn't consume
    # vertical space in the document flow.
    p = ET.Element(f"{W}p")
    pPr = ET.SubElement(p, f"{W}pPr")
    spacing = ET.SubElement(pPr, f"{W}spacing")
    spacing.set(f"{W}line", "1")
    spacing.set(f"{W}lineRule", "exact")
    spacing.set(f"{W}before", "0")
    spacing.set(f"{W}after", "0")
    r_el = ET.SubElement(p, f"{W}r")
    rPr = ET.SubElement(r_el, f"{W}rPr")
    sz = ET.SubElement(rPr, f"{W}sz")
    sz.set(f"{W}val", "2")
    drawing = ET.SubElement(r_el, f"{W}drawing")
    drawing.append(anchor)

    return p


# ============================================================================
# Root tag preservation
# ============================================================================

def extract_root_tag(xml_bytes):
    """Extract the original <w:document ...> opening tag verbatim."""
    xml_str = xml_bytes.decode("utf-8")
    m = re.search(r"<([a-zA-Z][a-zA-Z0-9]*:)?document\s[^>]*>", xml_str)
    if m:
        return m.group(0)
    return None


def restore_root_tag(new_xml_bytes, original_root_tag):
    """Replace re-serialized root tag with the original (plus mc:Ignorable)."""
    xml_str = new_xml_bytes.decode("utf-8")

    new_m = re.search(r"<([a-zA-Z][a-zA-Z0-9]*:)?document\s([^>]*)>", xml_str)
    if not new_m:
        return new_xml_bytes

    new_attrs = new_m.group(2)
    new_ns_decls = dict(re.findall(r'xmlns:(\w+)="([^"]*)"', new_attrs))
    orig_ns_decls = dict(re.findall(r'xmlns:(\w+)="([^"]*)"', original_root_tag))

    merged_tag = original_root_tag
    for prefix, uri in new_ns_decls.items():
        if prefix not in orig_ns_decls:
            merged_tag = merged_tag[:-1] + f' xmlns:{prefix}="{uri}">'
            orig_ns_decls[prefix] = uri

    MC_URI = "http://schemas.openxmlformats.org/markup-compatibility/2006"
    WP14_URI = "http://schemas.microsoft.com/office/word/2010/wordprocessingDrawing"
    if "mc" not in orig_ns_decls:
        merged_tag = merged_tag[:-1] + f' xmlns:mc="{MC_URI}">'
    if "wp14" not in orig_ns_decls:
        merged_tag = merged_tag[:-1] + f' xmlns:wp14="{WP14_URI}">'

    # N11-05: use word-boundary match so an unrelated attribute containing
    #         the substring "mc:Ignorable" cannot cause a false positive.
    # N11-06: only wps is actually an Ignorable extension; wp14 is consumed
    #         by Word 2010+ directly.
    ig_attr_re = re.compile(r'\bmc:Ignorable\s*=\s*"([^"]*)"')
    ig_m = ig_attr_re.search(merged_tag)
    if ig_m is None:
        merged_tag = merged_tag[:-1] + ' mc:Ignorable="wps">'
    else:
        ignorable = ig_m.group(1).split()
        if "wps" not in ignorable:
            ignorable.append("wps")
        merged_tag = merged_tag.replace(
            ig_m.group(0), f'mc:Ignorable="{" ".join(ignorable)}"'
        )

    xml_str = re.sub(
        r"<([a-zA-Z][a-zA-Z0-9]*:)?document\s[^>]*>",
        merged_tag,
        xml_str,
        count=1,
    )
    return xml_str.encode("utf-8")


# ============================================================================
# SVG native embedding (asvg:svgBlob)
# ============================================================================

_FENCE_OPEN_RE = re.compile(r'^(\s*)([`~])\2{2,}')


def _strip_yaml_and_code(md_text):
    """Remove YAML front matter, fenced code, inline code, and HTML
    comments from markdown text.

    C11-01: the original `r'```[^`]*```'` silently failed for 4-backtick
    fences, ~~~ fences, inline code, and HTML comments. We now:

    1. Normalize CRLF → LF (N11-04).
    2. Strip YAML front matter once at the top.
    3. Strip HTML comments greedily-but-non-nested.
    4. Strip fenced code blocks **line-by-line**, tracking the opening
       fence char and count so the closer must match or exceed it.
    5. Strip inline code spans last (they cannot span multiple lines).

    The result is not a perfect Markdown parse — it is only meant to
    suppress false-positive image references that ``embed_svg_native``
    would otherwise pick up.
    """
    md_text = md_text.replace('\r\n', '\n').replace('\r', '\n')

    md_text = re.sub(r'^---\n.*?\n---\n', '', md_text, count=1, flags=re.DOTALL)
    md_text = re.sub(r'<!--.*?-->', '', md_text, flags=re.DOTALL)

    out_lines = []
    fence = None  # (char, min_count) while inside a fence
    for line in md_text.split('\n'):
        m = _FENCE_OPEN_RE.match(line)
        if fence is None:
            if m:
                fence = (m.group(2), len(m.group(0)) - len(m.group(1)))
                continue  # drop the opener
            out_lines.append(line)
        else:
            if m and m.group(2) == fence[0] \
                    and (len(m.group(0)) - len(m.group(1))) >= fence[1]:
                fence = None
            # inside a fence (and on the closer) — drop the line
    md_text = '\n'.join(out_lines)

    md_text = re.sub(r'`[^`\n]*`', '', md_text)

    return md_text


_IMAGE_RE = re.compile(
    # ![alt](url)  — non-greedy alt with escape handling, DOTALL for
    # multi-line alt text; supports bare URLs and <angle-bracket> URLs.
    # Reference-style images (![alt][ref]) are intentionally NOT matched
    # — the K-th alignment check in embed_svg_native will fail loudly
    # if one slips through.
    r'!\[(?:[^\]\\]|\\.)*?\]'
    r'\('
    r'(?:'
    r'<(?P<angle>[^>\n]+)>'
    r'|'
    r'(?P<bare>[^)\s]+)'
    r')',
    flags=re.DOTALL,
)


def _extract_image_paths(md_text):
    """Return the ordered list of image paths referenced in md_text."""
    paths = []
    for m in _IMAGE_RE.finditer(md_text):
        paths.append(m.group("angle") or m.group("bare"))
    return paths


def embed_svg_native(root, parts, source_md_path, skip_missing=False):
    """Embed SVG files natively using Office 2016+ asvg:svgBlob extension.

    K-th image in source markdown → K-th a:blip element in document.xml.
    SVG paths are resolved **relative to the source markdown's directory**
    (NOT CWD — the CWD-based version in next-gen-comp-paper silently
    failed when build_narrative.sh chdir'd to project root).

    Missing SVG files raise FileNotFoundError by default so CI catches
    the breakage. Pass ``skip_missing=True`` (CLI: ``--skip-missing-svg``)
    to emit a warning and skip instead — intended for in-progress local
    builds where not all figures have been drawn yet (M11-03).

    M11-05: every SVG is scanned for ``<foreignObject>`` before embedding.
    Mermaid-cli with ``htmlLabels:false`` should never emit one; if it
    does (e.g. for a classDiagram / stateDiagram we have not configured)
    we fail loudly rather than let Word silently render blank rectangles.
    """

    with open(source_md_path, "r", encoding="utf-8") as f:
        md_text = f.read()

    md_text = _strip_yaml_and_code(md_text)
    image_paths = _extract_image_paths(md_text)

    if not image_paths:
        return

    svg_images = []
    for idx, path in enumerate(image_paths):
        if path.lower().endswith(".svg"):
            svg_images.append((idx, path))

    if not svg_images:
        return

    print(f"Found {len(svg_images)} SVG image(s) to embed natively")

    blips = list(root.iter(f"{A}blip"))

    # M11-02 / M13-05 / N13-07: md 側と docx 側の画像数が一致しない場合、
    # K-th alignment がズレて asvg 拡張を誤った画像に貼ってしまう。
    # pandoc の画像解決 WARNING (`[WARNING] Could not fetch resource ...`) は
    # exit 0 で通過するため、ここが silent 欠落の最後の検出点となる。
    # 従来は WARNING のみで継続していたが、実地 Prompt 10-4 で silent 欠落が
    # 顕在化したため hard fail に格上げする（report13 M13-05/N13-07）。
    if len(image_paths) != len(blips):
        raise ValueError(
            f"markdown image count ({len(image_paths)}) does not match "
            f"document.xml a:blip count ({len(blips)}) in {source_md_path}. "
            f"Pandoc が画像解決に失敗（図ファイル欠落・タイポ・resource-path 設定漏れ）"
            f"したか、md に reference-style image や raw HTML image が含まれています。"
            f"pandoc の stderr を確認し、`[WARNING] Could not fetch resource` が無いか"
            f"チェックしてください。"
        )

    RELS_NS = "http://schemas.openxmlformats.org/package/2006/relationships"
    ET.register_namespace("", RELS_NS)
    rels_path = "word/_rels/document.xml.rels"
    rels_root = ET.fromstring(parts[rels_path])

    max_rid = 0
    for rel in rels_root:
        rid = rel.get("Id", "")
        if rid.startswith("rId"):
            try:
                num = int(rid[3:])
                max_rid = max(max_rid, num)
            except ValueError:
                pass

    CT_NS = "http://schemas.openxmlformats.org/package/2006/content-types"
    ET.register_namespace("", CT_NS)
    ct_root = ET.fromstring(parts["[Content_Types].xml"])

    svg_ct_added = False
    svg_counter = 0

    # Resolve SVG paths relative to the source markdown directory.
    src_dir = os.path.dirname(os.path.abspath(source_md_path))

    for img_idx, svg_path in svg_images:
        if img_idx >= len(blips):
            print(f"  Warning: no matching blip for image index {img_idx} ({svg_path})")
            continue

        blip = blips[img_idx]

        svg_full_path = os.path.normpath(os.path.join(src_dir, svg_path))
        if not os.path.isfile(svg_full_path):
            if skip_missing:
                print(
                    f"  SKIP: {svg_path} (missing; asvg layer skipped)",
                    file=sys.stderr,
                )
                continue
            raise FileNotFoundError(
                f"SVG referenced in {source_md_path} not found: {svg_full_path}"
            )

        with open(svg_full_path, "rb") as f:
            svg_data = f.read()

        # M13-03: .svg と .svg.png の mtime が整合しているか検査する。
        # Phase A は 2 段階 mtime 比較で独立に up-to-date 判定するため、
        # 外部要因（rclone --preserve-modtime / 手動 git checkout 等）で
        # .svg.png だけ過去に巻き戻された場合、docx 内の primary blip (PNG) が
        # 旧版・asvg:svgBlob (SVG) が新版の silent 劣化が発生する。ここで
        # .svg の mtime が .svg.png より新しければ hard fail して再ビルドを強制。
        png_path = svg_full_path + ".png"
        if os.path.isfile(png_path):
            svg_mtime = os.path.getmtime(svg_full_path)
            png_mtime = os.path.getmtime(png_path)
            if svg_mtime > png_mtime:
                raise ValueError(
                    f"{svg_full_path} is newer than {png_path}. primary blip (PNG) "
                    f"and asvg:svgBlob (SVG) would encode different versions of the "
                    f"same figure. Re-run Phase A (`bash main/step02_docx/build_narrative.sh`) "
                    f"after deleting {png_path}, or touch the source `.mmd` to trigger "
                    f"regeneration."
                )

        # M11-05: refuse to embed a mermaid SVG that still contains
        # <foreignObject> — Word silently renders those as blank
        # rectangles. htmlLabels:false should prevent this for
        # flowchart / sequenceDiagram; new diagram types may need
        # additional config (see plan2.md §5.2).
        if b"<foreignObject" in svg_data:
            raise ValueError(
                f"{svg_full_path}: SVG contains <foreignObject>. Word "
                f"will render the labels as blank rectangles. Re-run "
                f"mermaid with htmlLabels:false (or the equivalent "
                f"per-diagram setting) so labels are emitted as plain "
                f"<text>/<tspan>."
            )

        svg_counter += 1
        svg_media_path = f"word/media/svg{svg_counter}.svg"
        parts[svg_media_path] = svg_data

        max_rid += 1
        new_rid = f"rId{max_rid}"
        # M14-01: use fully-qualified tag so the new Relationship stays in
        # RELS_NS even after a later register_namespace("", CT_NS) wipes
        # the default-prefix binding. Without this, pandoc rels get
        # reserialized with ns0: prefix while the bare <Relationship>
        # lands in no namespace, which Word 2016+ opens as "corrupt".
        rel_el = ET.SubElement(rels_root, f"{{{RELS_NS}}}Relationship")
        rel_el.set("Id", new_rid)
        rel_el.set("Type", "http://schemas.openxmlformats.org/officeDocument/2006/relationships/image")
        rel_el.set("Target", f"media/svg{svg_counter}.svg")

        ext_lst = blip.find(f"{A}extLst")
        if ext_lst is None:
            ext_lst = ET.SubElement(blip, f"{A}extLst")

        ext_el = ET.SubElement(ext_lst, f"{A}ext")
        ext_el.set("uri", "{96DAC541-7B7A-43D3-8B79-37D633B846F1}")

        svg_blob = ET.SubElement(ext_el, f"{ASVG}svgBlob")
        svg_blob.set(f"{R}embed", new_rid)

        print(f"  Embedded: {svg_path} → {svg_media_path} ({new_rid})")

        if not svg_ct_added:
            has_svg_ct = False
            for default in ct_root.findall(f"{{{CT_NS}}}Default"):
                if default.get("Extension") == "svg":
                    has_svg_ct = True
                    break
            if not has_svg_ct:
                # M14-01: mirror the fully-qualified tag fix from the rels
                # branch. CT currently uses a default xmlns so a bare
                # <Default> happens to inherit CT_NS, but another module
                # calling register_namespace("", <other>) later would
                # break that. Stay robust regardless of prefix state.
                ct_default = ET.SubElement(ct_root, f"{{{CT_NS}}}Default")
                ct_default.set("Extension", "svg")
                ct_default.set("ContentType", "image/svg+xml")
            svg_ct_added = True

    # N14-01: rels を serialize する直前で default xmlns を RELS_NS に戻す。
    # L517 の register_namespace("", CT_NS) で default binding が奪われたまま
    # rels を書くと、rels 全体が `<ns0:Relationships>...<ns0:Relationship/>...`
    # という auto-prefix 形式で serialize される。ECMA-376 的には valid だが
    # LibreOffice 24.x は rels を parse する際に default xmlns 形式を要求し、
    # ns0: prefix 形式では "source file could not be loaded" で拒否する。
    # 一度 RELS_NS を "" に再 bind してから write することで pandoc と同じ
    # `<Relationships xmlns="...">...<Relationship .../>...` 形式に揃える。
    ET.register_namespace("", RELS_NS)
    rels_buf = BytesIO()
    ET.ElementTree(rels_root).write(rels_buf, xml_declaration=True, encoding="UTF-8")
    parts[rels_path] = rels_buf.getvalue()

    # CT 側も同様に default xmlns を CT_NS に戻してから serialize する。
    ET.register_namespace("", CT_NS)
    ct_buf = BytesIO()
    ET.ElementTree(ct_root).write(ct_buf, xml_declaration=True, encoding="UTF-8")
    parts["[Content_Types].xml"] = ct_buf.getvalue()


# ============================================================================
# Main pipeline
# ============================================================================

def process_docx(docx_path, source_md=None, docpr_id_base=3000,
                 skip_missing_svg=False):
    """Process the docx file, replacing TextBoxMarker regions with text boxes.

    Page-based relocation (``relocate_textbox_by_page`` in
    next-gen-comp-paper) is intentionally not ported; the grant
    narratives use natural flow positioning only.
    """
    with zipfile.ZipFile(docx_path, "r") as zin:
        parts = {}
        for item in zin.infolist():
            parts[item.filename] = zin.read(item.filename)

    doc_xml = parts["word/document.xml"]
    original_root_tag = extract_root_tag(doc_xml)

    root = ET.fromstring(doc_xml)
    body = root.find(f"{W}body")

    if body is None:
        print("ERROR: No body element found", file=sys.stderr)
        sys.exit(1)

    if source_md:
        embed_svg_native(root, parts, source_md, skip_missing=skip_missing_svg)

    children = list(body)

    regions = []
    i = 0
    while i < len(children):
        child = children[i]
        if child.tag == f"{W}p" and is_textbox_marker(child):
            text = get_marker_text(child)
            if text.startswith("TEXTBOX_START:"):
                attrs = parse_attrs(text)
                start_idx = i
                content = []
                i += 1
                while i < len(children):
                    if (children[i].tag == f"{W}p"
                            and is_textbox_marker(children[i])):
                        end_text = get_marker_text(children[i])
                        if end_text == "TEXTBOX_END":
                            regions.append((start_idx, i, attrs, content))
                            break
                    else:
                        content.append(children[i])
                    i += 1
        i += 1

    if not regions:
        print(f"No TextBoxMarker regions found in {docx_path}")
        return

    print(f"Found {len(regions)} textbox region(s)")

    for z_order, (start_idx, end_idx, attrs, content) in enumerate(
        reversed(regions)
    ):
        actual_z = len(regions) - 1 - z_order

        for j in range(end_idx, start_idx - 1, -1):
            body.remove(children[j])

        tb_para = build_textbox_paragraph(attrs, content, actual_z, docpr_id_base)
        body.insert(start_idx, tb_para)
        children = list(body)

    tree = ET.ElementTree(root)
    buf = BytesIO()
    tree.write(buf, xml_declaration=True, encoding="UTF-8")
    new_xml = buf.getvalue()

    if original_root_tag:
        new_xml = restore_root_tag(new_xml, original_root_tag)

    parts["word/document.xml"] = new_xml

    # M12-01: ZipFile(docx_path, "w") は原ファイルを即 truncate するため、
    #         書き込み途中で例外が発生すると原 docx が破壊される。
    #         inject_narrative.py と同じく tempfile → shutil.move で atomic に
    #         上書きする。
    out_dir = os.path.dirname(os.path.abspath(docx_path)) or "."
    fd, tmp_path = tempfile.mkstemp(suffix=".docx", dir=out_dir)
    os.close(fd)
    try:
        with zipfile.ZipFile(tmp_path, "w", zipfile.ZIP_DEFLATED) as zout:
            for filename, data in parts.items():
                zout.writestr(filename, data)
        shutil.move(tmp_path, docx_path)
    except Exception:
        if os.path.exists(tmp_path):
            os.unlink(tmp_path)
        raise

    print(f"Processed: {docx_path} ({len(regions)} text box(es))")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Post-process Pandoc docx: wrap TextBoxMarker regions in text boxes")
    parser.add_argument("docx", help="Path to docx file")
    parser.add_argument("--source", help="Source markdown for SVG embedding")
    parser.add_argument("--docpr-id-base", type=int, default=3000,
                        help="Base value for wp:docPr/@id (default: 3000). "
                             "Use distinct bases per narrative to avoid post-inject collisions.")
    parser.add_argument("--skip-missing-svg", action="store_true",
                        help="Warn and continue when an SVG referenced by "
                             "the source markdown is missing. Default is to "
                             "raise FileNotFoundError so CI catches the "
                             "breakage; use this flag only for in-progress "
                             "local builds.")
    args = parser.parse_args()
    process_docx(
        args.docx,
        source_md=args.source,
        docpr_id_base=args.docpr_id_base,
        skip_missing_svg=args.skip_missing_svg,
    )
