#!/usr/bin/env python3
"""inject_narrative.py — Pandoc生成の様式1-2/1-3本文をテンプレートdocxに挿入する

Pandoc生成の youshiki1_2_narrative.docx / youshiki1_3_narrative.docx の本文要素を
youshiki1_5_filled.docx の該当セクションに挿入する。

python-docxの高レベルAPIではなく、stdlib zipfile + xml.etree.ElementTree で
ZIPアーカイブを直接操作し、リレーションシップ・スタイル・numbering を個別制御する。

Usage:
    python inject_narrative.py \\
        --template main/step02_docx/output/youshiki1_5_filled.docx \\
        --youshiki12 main/step02_docx/output/youshiki1_2_narrative.docx \\
        --youshiki13 main/step02_docx/output/youshiki1_3_narrative.docx \\
        --output main/step02_docx/output/youshiki1_5_filled.docx
"""

import argparse
import os
import re
import shutil
import sys
import tempfile
import xml.etree.ElementTree as ET
import zipfile
from io import BytesIO

# ============================================================================
# OOXML Namespaces
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
    "pic": "http://schemas.openxmlformats.org/drawingml/2006/picture",
    "wpc": "http://schemas.microsoft.com/office/word/2010/wordprocessingCanvas",
    "w14": "http://schemas.microsoft.com/office/word/2010/wordml",
    "w15": "http://schemas.microsoft.com/office/word/2012/wordml",
    "a14": "http://schemas.microsoft.com/office/drawing/2010/main",
    "asvg": "http://schemas.microsoft.com/office/drawing/2016/SVG/main",
}

for _prefix, _uri in NSMAP.items():
    ET.register_namespace(_prefix, _uri)

W = "{http://schemas.openxmlformats.org/wordprocessingml/2006/main}"
R = "{http://schemas.openxmlformats.org/officeDocument/2006/relationships}"
A = "{http://schemas.openxmlformats.org/drawingml/2006/main}"
WP = "{http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing}"
RELS_NS = "http://schemas.openxmlformats.org/package/2006/relationships"
CT_NS = "http://schemas.openxmlformats.org/package/2006/content-types"


# ============================================================================
# ZIP I/O
# ============================================================================

def read_docx(path):
    """Read a docx file and return {filename: bytes} dict."""
    with zipfile.ZipFile(path, "r") as zin:
        return {item.filename: zin.read(item.filename) for item in zin.infolist()}


def write_docx(path, parts):
    """Write parts dict to a docx ZIP file."""
    with zipfile.ZipFile(path, "w", zipfile.ZIP_DEFLATED) as zout:
        for filename, data in parts.items():
            zout.writestr(filename, data)


# ============================================================================
# Root tag preservation (jami-abstract-pandoc pattern)
#
# ElementTree drops unused namespace declarations on re-serialization.
# Word rejects docx files missing expected namespace declarations.
# We preserve the original root opening tag and restore it after serialization.
# ============================================================================

def extract_root_tag(xml_bytes, tag_local="document"):
    """Extract the original root element opening tag from XML bytes."""
    xml_str = xml_bytes.decode("utf-8")
    pattern = rf"<([a-zA-Z][a-zA-Z0-9]*:)?{re.escape(tag_local)}\s[^>]*>"
    m = re.search(pattern, xml_str)
    return m.group(0) if m else None


def restore_root_tag(new_xml_bytes, original_root_tag, tag_local="document",
                     extra_ignorable=()):
    """Replace the re-serialized root element tag with the original one,
    merging any new namespace declarations added during processing.

    M13-01: `mc:Ignorable` 属性もトークンの和集合で merge する。narrative 側で
    wrap_textbox が `mc:Ignorable="wps"` を設定していても、単純に template の
    `mc:Ignorable="w14 wp14"` で上書きしてしまうと `wps` が脱落し、strict parser が
    wps:wsp を未知要素として扱うリスクがあるため。

    ``extra_ignorable``: body 転送時に失われる narrative 側の mc:Ignorable トークンを
    明示的に補完するための呼出元指定。body に wps:wsp / asvg:svgBlob 等が含まれる
    場合、対応する prefix を渡すこと。
    """
    if not original_root_tag:
        return new_xml_bytes
    xml_str = new_xml_bytes.decode("utf-8")
    pattern = rf"<([a-zA-Z][a-zA-Z0-9]*:)?{re.escape(tag_local)}\s[^>]*>"
    new_m = re.search(pattern, xml_str)
    if not new_m:
        return new_xml_bytes

    new_root_tag = new_m.group(0)

    # Merge namespace declarations: keep original, add any new ones
    new_ns = dict(re.findall(r'xmlns:(\w+)="([^"]*)"', new_root_tag))
    orig_ns = dict(re.findall(r'xmlns:(\w+)="([^"]*)"', original_root_tag))

    merged_tag = original_root_tag
    for prefix, uri in new_ns.items():
        if prefix not in orig_ns:
            merged_tag = merged_tag[:-1] + f' xmlns:{prefix}="{uri}">'

    # M13-01: mc:Ignorable の値を和集合で merge
    ig_re = re.compile(r'\bmc:Ignorable\s*=\s*"([^"]*)"')
    orig_ig = ig_re.search(merged_tag)
    new_ig = ig_re.search(new_root_tag)
    orig_tokens = orig_ig.group(1).split() if orig_ig else []
    new_tokens = new_ig.group(1).split() if new_ig else []
    merged_tokens = list(orig_tokens)
    for t in list(new_tokens) + list(extra_ignorable):
        if t not in merged_tokens:
            merged_tokens.append(t)
    if merged_tokens:
        merged_value = " ".join(merged_tokens)
        if orig_ig:
            merged_tag = merged_tag.replace(
                orig_ig.group(0), f'mc:Ignorable="{merged_value}"'
            )
        else:
            merged_tag = merged_tag[:-1] + f' mc:Ignorable="{merged_value}">'

    xml_str = re.sub(pattern, lambda _: merged_tag, xml_str, count=1)
    return xml_str.encode("utf-8")


def _detect_required_ignorable(root):
    """Scan body for elements whose namespaces need mc:Ignorable entries.

    M13-01: narrative 側で wps:wsp / asvg:svgBlob を使っている場合、template の
    mc:Ignorable に `wps` が含まれていないと strict parser で未知要素扱いされる。
    body 内に該当要素があるかを検出し、必要な prefix を返す。
    """
    WPS_URI = "http://schemas.microsoft.com/office/word/2010/wordprocessingShape"
    needed = []
    for e in root.iter():
        if e.tag.startswith(f"{{{WPS_URI}}}"):
            if "wps" not in needed:
                needed.append("wps")
            break
    return needed


def serialize_xml(root):
    """Serialize an ElementTree root to bytes with XML declaration."""
    buf = BytesIO()
    ET.ElementTree(root).write(buf, xml_declaration=True, encoding="UTF-8")
    return buf.getvalue()


# ============================================================================
# Text extraction
# ============================================================================

def get_element_text(elem):
    """Extract all w:t text from an OOXML element."""
    return "".join(t.text for t in elem.iter(f"{W}t") if t.text)


# ============================================================================
# Section boundary detection
# ============================================================================

def find_section_boundaries(body):
    """Find section boundaries for 様式1-2 and 様式1-3 using text patterns.

    Returns dict with indices into body children:
        youshiki12_header_idx   — （様式１－２） paragraph
        youshiki12_delete_start — first placeholder (１．…)
        youshiki12_delete_end   — last element before 様式1-3 header
        youshiki13_header_idx   — （様式１－３） paragraph
        youshiki13_delete_start — first placeholder (（１）…)
        youshiki13_delete_end   — last element before 様式2-1 header
    """
    children = list(body)
    markers = {}

    for i, child in enumerate(children):
        text = get_element_text(child).strip()
        if "様式１－２" in text and "（" in text and "youshiki12_header_idx" not in markers:
            markers["youshiki12_header_idx"] = i
        elif "様式１－３" in text and "（" in text and "youshiki13_header_idx" not in markers:
            markers["youshiki13_header_idx"] = i
        elif "様式２－１" in text and "（" in text and "youshiki21_header_idx" not in markers:
            markers["youshiki21_header_idx"] = i

    for key, label in [
        ("youshiki12_header_idx", "（様式１－２）"),
        ("youshiki13_header_idx", "（様式１－３）"),
        ("youshiki21_header_idx", "（様式２－１）"),
    ]:
        if key not in markers:
            raise ValueError(f"セクションマーカーが見つかりません: {label}")

    # 様式1-2 placeholder start: first paragraph starting with "１．"
    for i in range(markers["youshiki12_header_idx"] + 1, markers["youshiki13_header_idx"]):
        if get_element_text(children[i]).strip().startswith("１．"):
            markers["youshiki12_delete_start"] = i
            break
    else:
        raise ValueError("様式1-2 のプレースホルダ開始（１．）が見つかりません")

    markers["youshiki12_delete_end"] = markers["youshiki13_header_idx"] - 1

    # 様式1-3 placeholder start: first paragraph starting with "（１）"
    for i in range(markers["youshiki13_header_idx"] + 1, markers["youshiki21_header_idx"]):
        if get_element_text(children[i]).strip().startswith("（１）"):
            markers["youshiki13_delete_start"] = i
            break
    else:
        raise ValueError("様式1-3 のプレースホルダ開始（（１））が見つかりません")

    markers["youshiki13_delete_end"] = markers["youshiki21_header_idx"] - 1

    return markers


# ============================================================================
# Narrative body extraction
# ============================================================================

def extract_narrative_body(src_parts):
    """Extract body child elements from a narrative docx, excluding final sectPr."""
    root = ET.fromstring(src_parts["word/document.xml"])
    body = root.find(f"{W}body")
    if body is None:
        return []

    children = list(body)

    # Exclude trailing w:sectPr (Pandoc always generates one)
    if children and children[-1].tag == f"{W}sectPr":
        children = children[:-1]

    # Detach from parent so they can be inserted elsewhere
    for child in children:
        body.remove(child)

    return children


# ============================================================================
# Relationship (rId) merge
# ============================================================================

def _get_max_rid(rels_root):
    """Get the maximum rId number from a Relationships root."""
    max_rid = 0
    for rel in rels_root:
        rid = rel.get("Id", "")
        if rid.startswith("rId"):
            try:
                max_rid = max(max_rid, int(rid[3:]))
            except ValueError:
                pass
    return max_rid


_COPY_REL_TYPES = {
    "http://schemas.openxmlformats.org/officeDocument/2006/relationships/image",
    "http://schemas.openxmlformats.org/officeDocument/2006/relationships/hyperlink",
}


def merge_rels(target_parts, src_parts, body_elements):
    """Merge image/hyperlink relationships from source into target.

    Updates rId references in body_elements in-place.
    Returns: (rid_map {old->new}, list of copied rel Elements)
    """
    RELS_PATH = "word/_rels/document.xml.rels"
    if RELS_PATH not in src_parts:
        return {}, []

    ET.register_namespace("", RELS_NS)

    tgt_rels_root = ET.fromstring(target_parts[RELS_PATH])
    src_rels_root = ET.fromstring(src_parts[RELS_PATH])

    # Collect source rels that need copying
    copy_rels = [r for r in src_rels_root if r.get("Type", "") in _COPY_REL_TYPES]
    if not copy_rels:
        return {}, []

    max_rid = _get_max_rid(tgt_rels_root)
    rid_map = {}

    for rel in copy_rels:
        old_rid = rel.get("Id")
        max_rid += 1
        new_rid = f"rId{max_rid}"
        rid_map[old_rid] = new_rid

        new_rel = ET.SubElement(tgt_rels_root, "Relationship")
        new_rel.set("Id", new_rid)
        new_rel.set("Type", rel.get("Type", ""))
        new_rel.set("Target", rel.get("Target", ""))
        if rel.get("TargetMode"):
            new_rel.set("TargetMode", rel.get("TargetMode"))

    # Renumber rId references in body elements
    r_attrs = [f"{R}id", f"{R}embed", f"{R}link"]
    for elem in body_elements:
        for node in elem.iter():
            for attr in r_attrs:
                val = node.get(attr)
                if val and val in rid_map:
                    node.set(attr, rid_map[val])

    # Serialize updated rels
    rels_buf = BytesIO()
    ET.ElementTree(tgt_rels_root).write(rels_buf, xml_declaration=True, encoding="UTF-8")
    target_parts[RELS_PATH] = rels_buf.getvalue()

    return rid_map, copy_rels


# ============================================================================
# Media file copy
# ============================================================================

def copy_media(target_parts, src_parts, copied_rels):
    """Copy word/media/ files referenced by copied relationships.

    When a filename conflict occurs, the file is renamed and the
    corresponding relationship Target in target_parts is updated.
    """
    RELS_PATH = "word/_rels/document.xml.rels"
    target_media = {k for k in target_parts if k.startswith("word/media/")}
    rename_map = {}  # old_target -> new_target (only for renamed files)

    for rel in copied_rels:
        target_path = rel.get("Target", "")
        if not target_path.startswith("media/"):
            continue
        full_path = f"word/{target_path}"
        if full_path in src_parts:
            if full_path in target_media:
                # Filename conflict — rename with _n suffix
                base, ext = os.path.splitext(target_path)
                counter = 1
                while True:
                    new_path = f"word/{base}_n{counter}{ext}"
                    if new_path not in target_parts:
                        break
                    counter += 1
                target_parts[new_path] = src_parts[full_path]
                rename_map[target_path] = f"{base}_n{counter}{ext}"
            else:
                target_parts[full_path] = src_parts[full_path]
                target_media.add(full_path)

    # Update relationship Targets for renamed media files
    if rename_map and RELS_PATH in target_parts:
        ET.register_namespace("", RELS_NS)
        rels_root = ET.fromstring(target_parts[RELS_PATH])
        for rel_elem in rels_root:
            old_target = rel_elem.get("Target", "")
            if old_target in rename_map:
                rel_elem.set("Target", rename_map[old_target])
        rels_buf = BytesIO()
        ET.ElementTree(rels_root).write(
            rels_buf, xml_declaration=True, encoding="UTF-8")
        target_parts[RELS_PATH] = rels_buf.getvalue()


# ============================================================================
# Numbering merge
# ============================================================================

def merge_numbering(target_parts, src_parts, body_elements):
    """Merge w:abstractNum / w:num definitions from source into target.

    Renumbers IDs to avoid collision, updates numPr references in body_elements.
    """
    if "word/numbering.xml" not in src_parts:
        return

    src_root = ET.fromstring(src_parts["word/numbering.xml"])
    src_abstracts = list(src_root.findall(f"{W}abstractNum"))
    src_nums = list(src_root.findall(f"{W}num"))

    if not src_abstracts and not src_nums:
        return

    # Parse or create target numbering.xml
    if "word/numbering.xml" in target_parts:
        tgt_xml = target_parts["word/numbering.xml"]
        tgt_root_tag = extract_root_tag(tgt_xml, "numbering")
        tgt_root = ET.fromstring(tgt_xml)
    else:
        tgt_root = ET.Element(f"{W}numbering")
        tgt_root_tag = None

    # Find max IDs in target
    max_abstract = 0
    for e in tgt_root.findall(f"{W}abstractNum"):
        aid = e.get(f"{W}abstractNumId")
        if aid:
            try:
                max_abstract = max(max_abstract, int(aid))
            except ValueError:
                pass

    max_num = 0
    for e in tgt_root.findall(f"{W}num"):
        nid = e.get(f"{W}numId")
        if nid:
            try:
                max_num = max(max_num, int(nid))
            except ValueError:
                pass

    # Renumber source abstractNums
    abstract_id_map = {}
    for elem in src_abstracts:
        old_id = elem.get(f"{W}abstractNumId")
        if old_id:
            max_abstract += 1
            abstract_id_map[old_id] = str(max_abstract)
            elem.set(f"{W}abstractNumId", str(max_abstract))

    # Renumber source nums and update their abstractNumId references
    num_id_map = {}
    for elem in src_nums:
        old_id = elem.get(f"{W}numId")
        if old_id:
            max_num += 1
            num_id_map[old_id] = str(max_num)
            elem.set(f"{W}numId", str(max_num))
        for ref in elem.findall(f"{W}abstractNumId"):
            old_ref = ref.get(f"{W}val")
            if old_ref and old_ref in abstract_id_map:
                ref.set(f"{W}val", abstract_id_map[old_ref])

    # Append to target in correct schema order:
    # abstractNum elements before num elements
    # Find insertion point: before the first w:num in target
    tgt_children = list(tgt_root)
    first_num_idx = None
    for i, child in enumerate(tgt_children):
        if child.tag == f"{W}num":
            first_num_idx = i
            break

    for j, elem in enumerate(src_abstracts):
        if first_num_idx is not None:
            tgt_root.insert(first_num_idx + j, elem)
        else:
            tgt_root.append(elem)

    # Append nums at the end (but before w:numIdMacAtCleanup if present)
    cleanup = tgt_root.find(f"{W}numIdMacAtCleanup")
    if cleanup is not None:
        cleanup_idx = list(tgt_root).index(cleanup)
        for j, elem in enumerate(src_nums):
            tgt_root.insert(cleanup_idx + j, elem)
    else:
        for elem in src_nums:
            tgt_root.append(elem)

    # Update numPr → numId references in body elements
    for body_elem in body_elements:
        for num_id_el in body_elem.iter(f"{W}numId"):
            old_val = num_id_el.get(f"{W}val")
            if old_val and old_val in num_id_map:
                num_id_el.set(f"{W}val", num_id_map[old_val])

    # Serialize
    new_xml = serialize_xml(tgt_root)
    new_xml = restore_root_tag(new_xml, tgt_root_tag, "numbering")
    target_parts["word/numbering.xml"] = new_xml


# ============================================================================
# Styles merge
# ============================================================================

# Pandoc style definitions matching template fonts/sizes
# (same values as fix_reference_styles.py)
_PANDOC_STYLES = {
    "Heading1": ("Heading 1", "paragraph", "Normal",
                 "MS Gothic", "\uff2d\uff33 \u30b4\u30b7\u30c3\u30af", 12, True),
    "Heading2": ("Heading 2", "paragraph", "Normal",
                 "MS Gothic", "\uff2d\uff33 \u30b4\u30b7\u30c3\u30af", 10.5, True),
    "Heading3": ("Heading 3", "paragraph", "Normal",
                 "MS Gothic", "\uff2d\uff33 \u30b4\u30b7\u30c3\u30af", 10.5, False),
    "BodyText": ("Body Text", "paragraph", "Normal",
                 "MS Mincho", "\uff2d\uff33 \u660e\u671d", 10.5, False),
    "FirstParagraph": ("First Paragraph", "paragraph", "BodyText",
                       "MS Mincho", "\uff2d\uff33 \u660e\u671d", 10.5, False),
    "Compact": ("Compact", "paragraph", "BodyText",
                "MS Mincho", "\uff2d\uff33 \u660e\u671d", 10.5, False),
    "SourceCode": ("Source Code", "paragraph", "Normal",
                   "Courier New", "\uff2d\uff33 \u30b4\u30b7\u30c3\u30af", 9, False),
}


def _build_style_element(style_id, name, stype, based_on,
                         font_ascii, font_ea, size_pt, bold):
    """Build a <w:style> element."""
    style = ET.Element(f"{W}style")
    style.set(f"{W}type", stype)
    style.set(f"{W}styleId", style_id)

    n = ET.SubElement(style, f"{W}name")
    n.set(f"{W}val", name)

    b = ET.SubElement(style, f"{W}basedOn")
    b.set(f"{W}val", based_on)

    rpr = ET.SubElement(style, f"{W}rPr")
    rf = ET.SubElement(rpr, f"{W}rFonts")
    rf.set(f"{W}ascii", font_ascii)
    rf.set(f"{W}hAnsi", font_ascii)
    rf.set(f"{W}eastAsia", font_ea)

    if bold:
        ET.SubElement(rpr, f"{W}b")
        ET.SubElement(rpr, f"{W}bCs")

    half_pt = str(int(size_pt * 2))
    sz = ET.SubElement(rpr, f"{W}sz")
    sz.set(f"{W}val", half_pt)
    szc = ET.SubElement(rpr, f"{W}szCs")
    szc.set(f"{W}val", half_pt)

    return style


def merge_styles(target_parts, src_parts):
    """Add Pandoc style definitions to target styles.xml.

    Also copies any character styles (e.g. syntax highlighting) from source
    that are missing in target.
    """
    if "word/styles.xml" not in target_parts:
        return

    tgt_xml = target_parts["word/styles.xml"]
    tgt_root_tag = extract_root_tag(tgt_xml, "styles")
    tgt_root = ET.fromstring(tgt_xml)

    existing_ids = {
        s.get(f"{W}styleId")
        for s in tgt_root.findall(f"{W}style")
        if s.get(f"{W}styleId")
    }

    # Add hardcoded Pandoc styles (with correct font/size matching template)
    for sid, params in _PANDOC_STYLES.items():
        if sid not in existing_ids:
            tgt_root.append(_build_style_element(sid, *params))
            existing_ids.add(sid)
            print(f"    style: +{sid} ({params[0]})")

    # Merge additional styles from source (character styles for syntax, etc.)
    if "word/styles.xml" in src_parts:
        src_root = ET.fromstring(src_parts["word/styles.xml"])
        for style_elem in src_root.findall(f"{W}style"):
            sid = style_elem.get(f"{W}styleId")
            if sid and sid not in existing_ids:
                tgt_root.append(style_elem)
                existing_ids.add(sid)

    new_xml = serialize_xml(tgt_root)
    new_xml = restore_root_tag(new_xml, tgt_root_tag, "styles")
    target_parts["word/styles.xml"] = new_xml


# ============================================================================
# Content Types merge
# ============================================================================

# C13-01: 既知の画像拡張子 → Content-Type の対応表。narrative 側が Override で
# jpg/png を登録しているケース（Pandoc 流儀）でも、target 側で拡張子ベースの
# Default に昇格させることで「Content-Type 未登録の media Part」を防ぐ。
_MEDIA_CONTENT_TYPES = {
    "jpg":  "image/jpeg",
    "jpeg": "image/jpeg",
    "png":  "image/png",
    "gif":  "image/gif",
    "svg":  "image/svg+xml",
    "webp": "image/webp",
    "bmp":  "image/bmp",
    "tif":  "image/tiff",
    "tiff": "image/tiff",
}


def merge_content_types(target_parts, src_parts):
    """Merge Content-Type registrations from source into target.

    C13-01: narrative docx は Pandoc 流儀で `<Override PartName="/word/media/rId23.jpg"
    ContentType="image/jpeg"/>` のように **Override** で jpg/png を登録する。一方
    template の `<Default Extension="jpeg"/>` は `.jpg` にマッチしないため、単純に
    Default のみコピーすると `/word/media/*.jpg` と `/word/media/*.png` の
    Content-Type が **完全に失われる**（Word は修復ダイアログを出す）。

    対策:
    1. source の Default をコピー（従来通り）
    2. source の Override もコピー（narrative 側の jpg/png Override を保全）
    3. target_parts 内の `word/media/*` を走査し、拡張子が未カバーなら
       `_MEDIA_CONTENT_TYPES` から Default を自動補完
    """
    ET.register_namespace("", CT_NS)
    tgt_root = ET.fromstring(target_parts["[Content_Types].xml"])

    existing_exts = {
        d.get("Extension", "").lower()
        for d in tgt_root.findall(f"{{{CT_NS}}}Default")
    }
    existing_overrides = {
        o.get("PartName", "")
        for o in tgt_root.findall(f"{{{CT_NS}}}Override")
    }

    # 1. Default merge（従来）
    src_root = ET.fromstring(src_parts["[Content_Types].xml"])
    for d in src_root.findall(f"{{{CT_NS}}}Default"):
        ext = d.get("Extension", "")
        if ext.lower() not in existing_exts:
            new_d = ET.SubElement(tgt_root, f"{{{CT_NS}}}Default")
            new_d.set("Extension", ext)
            new_d.set("ContentType", d.get("ContentType", ""))
            existing_exts.add(ext.lower())

    # 2. Override merge — narrative 側の /word/media/*.jpg 等を保全
    for o in src_root.findall(f"{{{CT_NS}}}Override"):
        part_name = o.get("PartName", "")
        if not part_name.startswith("/word/media/"):
            continue  # 本文・スタイル等は target 側で既に定義済み
        if part_name in existing_overrides:
            continue
        new_o = ET.SubElement(tgt_root, f"{{{CT_NS}}}Override")
        new_o.set("PartName", part_name)
        new_o.set("ContentType", o.get("ContentType", ""))
        existing_overrides.add(part_name)

    # 3. 拡張子ベース Default 自動補完
    #    copy_media が rename を行った場合や、source が Override でカバーしていない
    #    media に対する防御線。実際に target_parts に存在する media の拡張子のみを
    #    対象とすることで、不要な Default 追加を避ける。
    media_exts = set()
    for fn in target_parts:
        if not fn.startswith("word/media/"):
            continue
        _, ext = os.path.splitext(fn)
        if ext.startswith("."):
            media_exts.add(ext[1:].lower())

    for ext in sorted(media_exts):
        if ext in existing_exts:
            continue
        ct = _MEDIA_CONTENT_TYPES.get(ext)
        if ct is None:
            # 未知拡張子は Override がある前提で skip（なければ後続で verify）
            continue
        new_d = ET.SubElement(tgt_root, f"{{{CT_NS}}}Default")
        new_d.set("Extension", ext)
        new_d.set("ContentType", ct)
        existing_exts.add(ext)

    target_parts["[Content_Types].xml"] = serialize_xml(tgt_root)


def verify_media_content_types(target_parts):
    """Fail loudly if any /word/media/* has no Content-Type (Default or Override).

    C13-01 の fix が実質機能していることを inject 最終段で検証する。ECMA-376 OPC
    §8 違反（Content-Type 未登録 Part）を silent に通過させない。
    """
    ct_root = ET.fromstring(target_parts["[Content_Types].xml"])
    exts_covered = {
        d.get("Extension", "").lower()
        for d in ct_root.findall(f"{{{CT_NS}}}Default")
    }
    overrides_covered = {
        o.get("PartName", "")
        for o in ct_root.findall(f"{{{CT_NS}}}Override")
    }

    missing = []
    for fn in target_parts:
        if not fn.startswith("word/media/"):
            continue
        _, ext = os.path.splitext(fn)
        ext = ext[1:].lower() if ext.startswith(".") else ""
        part_name = "/" + fn
        if ext in exts_covered:
            continue
        if part_name in overrides_covered:
            continue
        missing.append(fn)

    if missing:
        print(
            f"ERROR: [Content_Types].xml に Content-Type 登録の無い media Part があります:\n"
            + "\n".join(f"  - {m}" for m in missing)
            + "\n  merge_content_types の拡張子対応表を更新してください。",
            file=sys.stderr,
        )
        sys.exit(1)


# ============================================================================
# Footnotes merge
# ============================================================================

def _merge_notes(target_parts, src_parts, body_elements, note_type):
    """Merge real footnotes or endnotes (id > 0) from source into target.

    note_type: "footnote" or "endnote"
    Skip if source has no real notes (only separator/continuationSeparator).

    M13-04: `word/_rels/{note_type}s.xml.rels` も同時に merge する。脚注内に
    ハイパーリンクや画像が含まれる場合、rels が orphan になると Word で
    リンク切れ / 画像欠落が発生するため、document.xml と同様に rId 再採番を行う。
    """
    xml_path = f"word/{note_type}s.xml"
    rels_path = f"word/_rels/{note_type}s.xml.rels"
    tag_local = f"{note_type}s"
    note_tag = f"{W}{note_type}"
    ref_tag = f"{W}{note_type}Reference"

    if xml_path not in src_parts:
        return
    if xml_path not in target_parts:
        return

    src_root = ET.fromstring(src_parts[xml_path])
    real_notes = [
        n for n in src_root.findall(note_tag)
        if n.get(f"{W}type", "") not in ("separator", "continuationSeparator")
        and n.get(f"{W}id") and int(n.get(f"{W}id", "0")) > 0
    ]
    if not real_notes:
        return

    tgt_xml = target_parts[xml_path]
    tgt_root_tag = extract_root_tag(tgt_xml, tag_local)
    tgt_root = ET.fromstring(tgt_xml)

    max_id = max(
        (int(n.get(f"{W}id", "0")) for n in tgt_root.findall(note_tag)),
        default=0,
    )

    id_map = {}
    for n in real_notes:
        old_id = n.get(f"{W}id")
        max_id += 1
        id_map[old_id] = str(max_id)
        n.set(f"{W}id", str(max_id))
        tgt_root.append(n)

    for elem in body_elements:
        for ref in elem.iter(ref_tag):
            old_id = ref.get(f"{W}id")
            if old_id and old_id in id_map:
                ref.set(f"{W}id", id_map[old_id])

    # M13-04: note rels（hyperlink / image）を target に merge して rId 再採番
    if rels_path in src_parts:
        ET.register_namespace("", RELS_NS)
        src_rels_root = ET.fromstring(src_parts[rels_path])
        copy_rels = [r for r in src_rels_root
                     if r.get("Type", "") in _COPY_REL_TYPES]
        if copy_rels:
            if rels_path in target_parts:
                tgt_rels_root = ET.fromstring(target_parts[rels_path])
            else:
                tgt_rels_root = ET.Element(f"{{{RELS_NS}}}Relationships")
            max_rid = _get_max_rid(tgt_rels_root)
            note_rid_map = {}
            for rel in copy_rels:
                old_rid = rel.get("Id")
                max_rid += 1
                new_rid = f"rId{max_rid}"
                note_rid_map[old_rid] = new_rid
                new_rel = ET.SubElement(tgt_rels_root, "Relationship")
                new_rel.set("Id", new_rid)
                new_rel.set("Type", rel.get("Type", ""))
                new_rel.set("Target", rel.get("Target", ""))
                if rel.get("TargetMode"):
                    new_rel.set("TargetMode", rel.get("TargetMode"))
            # note 本体の rId も書き換え
            r_attrs = [f"{R}id", f"{R}embed", f"{R}link"]
            for n in real_notes:
                for node in n.iter():
                    for attr in r_attrs:
                        val = node.get(attr)
                        if val and val in note_rid_map:
                            node.set(attr, note_rid_map[val])
            rels_buf = BytesIO()
            ET.ElementTree(tgt_rels_root).write(
                rels_buf, xml_declaration=True, encoding="UTF-8")
            target_parts[rels_path] = rels_buf.getvalue()

    new_xml = serialize_xml(tgt_root)
    new_xml = restore_root_tag(new_xml, tgt_root_tag, tag_local)
    target_parts[xml_path] = new_xml


def merge_footnotes(target_parts, src_parts, body_elements):
    """Merge real footnotes (id > 0) from source into target."""
    _merge_notes(target_parts, src_parts, body_elements, "footnote")


def merge_endnotes(target_parts, src_parts, body_elements):
    """Merge real endnotes (id > 0) from source into target."""
    _merge_notes(target_parts, src_parts, body_elements, "endnote")


# ============================================================================
# Section injection
# ============================================================================

def inject_section(body, delete_start, delete_end, narrative_elements, label):
    """Delete placeholder elements and insert narrative body at that position.

    Processes body children by index. delete_start..delete_end (inclusive) are
    removed, then narrative_elements are inserted at delete_start.
    """
    children = list(body)
    n_delete = delete_end - delete_start + 1

    # Remove in reverse to preserve indices
    for i in range(delete_end, delete_start - 1, -1):
        body.remove(children[i])
    print(f"  {label}: deleted {n_delete} placeholder elements")

    if not narrative_elements:
        print(f"  {label}: empty narrative — no elements to insert")
        return

    # Insert at the position where deleted range started
    for j, elem in enumerate(narrative_elements):
        body.insert(delete_start + j, elem)
    print(f"  {label}: inserted {len(narrative_elements)} elements")


# ============================================================================
# Main processing
# ============================================================================

def process(template_path, youshiki12_path, youshiki13_path, output_path):
    """Main injection pipeline."""

    # --- Validate inputs ---
    for path, name in [
        (template_path, "--template"),
        (youshiki12_path, "--youshiki12"),
        (youshiki13_path, "--youshiki13"),
    ]:
        if not os.path.isfile(path):
            print(f"ERROR: {name} ファイルが見つかりません: {path}", file=sys.stderr)
            sys.exit(1)

    print(f"Template:  {template_path}")
    print(f"様式1-2:   {youshiki12_path}")
    print(f"様式1-3:   {youshiki13_path}")
    print(f"Output:    {output_path}")
    print()

    # --- Read all docx files as ZIP parts ---
    tgt_parts = read_docx(template_path)
    src12_parts = read_docx(youshiki12_path)
    src13_parts = read_docx(youshiki13_path)

    # --- Parse template document.xml ---
    doc_xml = tgt_parts["word/document.xml"]
    original_root_tag = extract_root_tag(doc_xml, "document")
    root = ET.fromstring(doc_xml)
    body = root.find(f"{W}body")
    if body is None:
        print("ERROR: document.xml に body 要素がありません", file=sys.stderr)
        sys.exit(1)

    # --- Detect section boundaries ---
    print("Detecting section boundaries...")
    bounds = find_section_boundaries(body)
    print(f"  様式1-2: header[{bounds['youshiki12_header_idx']}]  "
          f"delete[{bounds['youshiki12_delete_start']}..{bounds['youshiki12_delete_end']}]")
    print(f"  様式1-3: header[{bounds['youshiki13_header_idx']}]  "
          f"delete[{bounds['youshiki13_delete_start']}..{bounds['youshiki13_delete_end']}]")
    print()

    # --- Extract narrative body elements ---
    print("Extracting narrative bodies...")
    narr12 = extract_narrative_body(src12_parts)
    narr13 = extract_narrative_body(src13_parts)
    print(f"  様式1-2: {len(narr12)} elements")
    print(f"  様式1-3: {len(narr13)} elements")
    print()

    # --- Merge relationships (images, hyperlinks) ---
    print("Merging relationships...")
    _, rels12 = merge_rels(tgt_parts, src12_parts, narr12)
    _, rels13 = merge_rels(tgt_parts, src13_parts, narr13)
    n_rels = len(rels12) + len(rels13)
    print(f"  {n_rels} relationship(s) added" if n_rels else "  (none)")

    # --- Copy media files ---
    if rels12:
        copy_media(tgt_parts, src12_parts, rels12)
    if rels13:
        copy_media(tgt_parts, src13_parts, rels13)

    # --- Merge numbering ---
    print("Merging numbering...")
    merge_numbering(tgt_parts, src12_parts, narr12)
    merge_numbering(tgt_parts, src13_parts, narr13)
    print("  done")

    # --- Merge styles ---
    print("Merging styles...")
    merge_styles(tgt_parts, src12_parts)
    merge_styles(tgt_parts, src13_parts)
    print("  done")

    # --- Merge footnotes / endnotes ---
    merge_footnotes(tgt_parts, src12_parts, narr12)
    merge_footnotes(tgt_parts, src13_parts, narr13)
    merge_endnotes(tgt_parts, src12_parts, narr12)
    merge_endnotes(tgt_parts, src13_parts, narr13)

    # --- Merge content types ---
    merge_content_types(tgt_parts, src12_parts)
    merge_content_types(tgt_parts, src13_parts)

    # C13-01: media Part の Content-Type カバレッジを最終検証。
    verify_media_content_types(tgt_parts)

    # --- Inject narratives into body ---
    # Process 1-3 FIRST (higher indices) to preserve lower indices for 1-2
    print("Injecting narratives...")
    inject_section(
        body,
        bounds["youshiki13_delete_start"],
        bounds["youshiki13_delete_end"],
        narr13,
        "様式1-3",
    )
    inject_section(
        body,
        bounds["youshiki12_delete_start"],
        bounds["youshiki12_delete_end"],
        narr12,
        "様式1-2",
    )

    # --- Verify wp:docPr/@id uniqueness across the merged package ---
    # M11-08: wrap_textbox.py assigns docPr/@id via narrative-scoped
    # bases (1-2=3000, 1-3=4000) under the assumption that the template
    # has no existing wp:docPr elements. Validate that assumption here
    # so a future template change cannot silently introduce id
    # collisions that Word rejects or renumbers at open time.
    # M12-05: body (document.xml) だけでなく header*/footer*.xml も走査対象に含め、
    #         テンプレート更新時の潜在衝突を見逃さない。document.xml 本体はまだ
    #         tgt_parts に書き戻されていないため、serialize 済みの root を優先使用する。
    docpr_ids = [p.get("id") for p in root.iter(f"{WP}docPr")]
    for fn, data in tgt_parts.items():
        if not (fn.startswith("word/") and fn.endswith(".xml")):
            continue
        if fn == "word/document.xml":
            continue  # 本体は上の root から収集済み
        if not (fn.startswith("word/header") or fn.startswith("word/footer")):
            continue
        try:
            r = ET.fromstring(data)
        except ET.ParseError:
            continue
        docpr_ids.extend(p.get("id") for p in r.iter(f"{WP}docPr"))

    seen = set()
    dupes = set()
    for did in docpr_ids:
        if did in seen:
            dupes.add(did)
        seen.add(did)
    if dupes:
        print(
            f"ERROR: wp:docPr/@id collision detected in merged package "
            f"(document/header/footer): {sorted(dupes)}. Re-run "
            f"wrap_textbox.py with distinct --docpr-id-base per narrative.",
            file=sys.stderr,
        )
        sys.exit(1)
    if docpr_ids:
        print(f"  docPr uniqueness OK ({len(docpr_ids)} ids, incl. header/footer)")

    # --- Serialize document.xml with root tag restoration ---
    # M13-01: narrative 由来の wps:wsp / asvg 要素が body に含まれる場合は
    #         mc:Ignorable に該当 prefix を補完する。
    print("\nSerializing...")
    extra_ignorable = _detect_required_ignorable(root)
    if extra_ignorable:
        print(f"  mc:Ignorable に追加: {' '.join(extra_ignorable)}")
    new_xml = serialize_xml(root)
    new_xml = restore_root_tag(new_xml, original_root_tag, "document",
                               extra_ignorable=extra_ignorable)
    tgt_parts["word/document.xml"] = new_xml

    # --- Atomic write: temp file → rename ---
    out_dir = os.path.dirname(os.path.abspath(output_path))
    os.makedirs(out_dir, exist_ok=True)
    fd, tmp_path = tempfile.mkstemp(suffix=".docx", dir=out_dir)
    os.close(fd)

    try:
        write_docx(tmp_path, tgt_parts)

        # Basic validation: ensure the ZIP can be re-read
        try:
            read_docx(tmp_path)
        except Exception as e:
            print(f"WARNING: 出力ファイル検証エラー: {e}", file=sys.stderr)

        shutil.move(tmp_path, output_path)
        print(f"\nDone: {output_path}")
    except Exception:
        if os.path.exists(tmp_path):
            os.unlink(tmp_path)
        raise


# ============================================================================
# CLI
# ============================================================================

def main():
    parser = argparse.ArgumentParser(
        description="Pandoc生成の様式1-2/1-3本文をテンプレートdocxに挿入する",
    )
    parser.add_argument("--template", required=True,
                        help="youshiki1_5_filled.docx のパス")
    parser.add_argument("--youshiki12", required=True,
                        help="youshiki1_2_narrative.docx のパス")
    parser.add_argument("--youshiki13", required=True,
                        help="youshiki1_3_narrative.docx のパス")
    parser.add_argument("--output",
                        help="出力パス（デフォルト: --template を上書き）")
    args = parser.parse_args()

    process(args.template, args.youshiki12, args.youshiki13,
            args.output or args.template)


if __name__ == "__main__":
    main()
