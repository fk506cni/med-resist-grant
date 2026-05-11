#!/usr/bin/env python3
"""fig1_overview の 2 バリアント SVG を生成する。

いらすとや PNG を base64 で埋め込み、Mermaid 風のフローチャート構造を
持つ自立 SVG を `figs/` 直下に書き出す。

Variant 1 (`fig1_overview_v1.svg`):
    A=電子カルテ B=データ分析 C=たらい回し救急車 D=ハッカー E=報告書
Variant 2 (`fig1_overview_v2.svg`):
    A=電子カルテ B=データ分析 C=病院+救急車+地図(合成) D=ランサムウェア E=報告書
"""

from __future__ import annotations

import base64
from dataclasses import dataclass
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
CACHE_DIR = SCRIPT_DIR / "irasutoya_cache"

CANVAS_W = 1200
CANVAS_H = 520
NODE_BOX = 150  # 画像スロットの一辺
LABEL_FONT = 22
ARROW_COLOR = "#333333"
LABEL_COLOR = "#222222"
NODE_STROKE = "#888888"
NODE_FILL = "#ffffff"
BG_COLOR = "#ffffff"

# ノードの中心座標（画像中心）
NODE_POS = {
    "A": (150, 170),
    "B": (415, 170),
    "C": (680, 170),
    "E": (1050, 170),
    "D": (680, 400),
}


@dataclass
class NodeSpec:
    key: str
    label: str
    image: str | list[str]  # 単体 or 合成用複数枚


def b64_png(name: str) -> str:
    path = CACHE_DIR / name
    data = path.read_bytes()
    return "data:image/png;base64," + base64.b64encode(data).decode()


def img_tag(href: str, cx: float, cy: float, w: float, h: float) -> str:
    x = cx - w / 2
    y = cy - h / 2
    return (
        f'<image x="{x:.1f}" y="{y:.1f}" width="{w:.1f}" height="{h:.1f}" '
        f'preserveAspectRatio="xMidYMid meet" href="{href}"/>'
    )


def node_frame(cx: float, cy: float, label: str) -> str:
    """ノード画像を囲む矩形 + 下部ラベル"""
    w = NODE_BOX + 30
    h = NODE_BOX + 60
    x = cx - w / 2
    y = cy - NODE_BOX / 2 - 10
    label_y = cy + NODE_BOX / 2 + 30
    return (
        f'<rect x="{x:.1f}" y="{y:.1f}" width="{w:.1f}" height="{h:.1f}" '
        f'rx="12" ry="12" fill="{NODE_FILL}" stroke="{NODE_STROKE}" stroke-width="1.5"/>\n'
        f'<text x="{cx:.1f}" y="{label_y:.1f}" text-anchor="middle" '
        f'font-family="Noto Sans CJK JP, sans-serif" font-size="{LABEL_FONT}" '
        f'font-weight="bold" fill="{LABEL_COLOR}">{label}</text>'
    )


def single_image_node(cx: float, cy: float, label: str, image_name: str) -> str:
    href = b64_png(image_name)
    return (
        node_frame(cx, cy, label) + "\n" + img_tag(href, cx, cy, NODE_BOX, NODE_BOX)
    )


def composite_region_node(cx: float, cy: float, label: str) -> str:
    """C ノード合成版: 病院+救急車+地図 を 1 枠内に配置"""
    parts: list[str] = [node_frame(cx, cy, label)]
    # 地図を下半分に大きく配置（ランドスケープ）
    parts.append(
        img_tag(
            b64_png("map_open.png"),
            cx=cx,
            cy=cy + 25,
            w=NODE_BOX - 10,
            h=(NODE_BOX - 10) * 0.6,
        )
    )
    # 病院を左上
    parts.append(
        img_tag(
            b64_png("tatemono_byouin2.png"),
            cx=cx - 40,
            cy=cy - 30,
            w=70,
            h=70,
        )
    )
    # 救急車を右上
    parts.append(
        img_tag(
            b64_png("norimono_kyukyusya.png"),
            cx=cx + 40,
            cy=cy - 25,
            w=75,
            h=55,
        )
    )
    return "\n".join(parts)


def arrow(x1: float, y1: float, x2: float, y2: float) -> str:
    return (
        f'<line x1="{x1:.1f}" y1="{y1:.1f}" x2="{x2:.1f}" y2="{y2:.1f}" '
        f'stroke="{ARROW_COLOR}" stroke-width="3" marker-end="url(#arrow)"/>'
    )


def svg_header() -> str:
    return f'''<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink"
     viewBox="0 0 {CANVAS_W} {CANVAS_H}" width="{CANVAS_W}" height="{CANVAS_H}">
  <defs>
    <marker id="arrow" viewBox="0 0 12 12" refX="11" refY="6"
            markerWidth="9" markerHeight="9" orient="auto-start-reverse">
      <path d="M 0 0 L 12 6 L 0 12 z" fill="{ARROW_COLOR}"/>
    </marker>
  </defs>
  <rect width="100%" height="100%" fill="{BG_COLOR}"/>
'''


def svg_footer() -> str:
    return "</svg>\n"


def build_variant(
    c_image: str | None,
    c_label: str,
    d_image: str,
    d_label: str,
    c_composite: bool = False,
) -> str:
    out = [svg_header()]

    # --- ノード ---
    out.append(
        single_image_node(*NODE_POS["A"], label="DPC／NDB／レセプト", image_name="iryou_karute_carte_denshi.png")
    )
    out.append(
        single_image_node(*NODE_POS["B"], label="需給推定器", image_name="document_data_bunseki.png")
    )
    if c_composite:
        out.append(composite_region_node(*NODE_POS["C"], label=c_label))
    else:
        assert c_image is not None
        out.append(single_image_node(*NODE_POS["C"], label=c_label, image_name=c_image))
    out.append(
        single_image_node(*NODE_POS["E"], label="インパクト評価レポート", image_name="document_houkokusyo.png")
    )
    out.append(single_image_node(*NODE_POS["D"], label=d_label, image_name=d_image))

    # --- 矢印 ---
    half = NODE_BOX / 2 + 18  # 枠の端からの水平オフセット
    # A -> B
    out.append(arrow(NODE_POS["A"][0] + half, NODE_POS["A"][1],
                     NODE_POS["B"][0] - half, NODE_POS["B"][1]))
    # B -> C
    out.append(arrow(NODE_POS["B"][0] + half, NODE_POS["B"][1],
                     NODE_POS["C"][0] - half, NODE_POS["C"][1]))
    # C -> E
    out.append(arrow(NODE_POS["C"][0] + half, NODE_POS["C"][1],
                     NODE_POS["E"][0] - half, NODE_POS["E"][1]))
    # D -> C (下から上へ)
    vhalf = NODE_BOX / 2 + 48  # 枠+ラベル分を見込んだ垂直オフセット
    out.append(arrow(NODE_POS["D"][0], NODE_POS["D"][1] - NODE_BOX / 2 - 18,
                     NODE_POS["C"][0], NODE_POS["C"][1] + vhalf))

    out.append(svg_footer())
    return "\n".join(out)


def main() -> None:
    v1 = build_variant(
        c_image="medical_kyukyu_taraimawashi.png",
        c_label="地域医療シミュレータ",
        d_image="computer_hacker_black1.png",
        d_label="サイバー攻撃シナリオ",
    )
    (SCRIPT_DIR / "fig1_overview_v1.svg").write_text(v1, encoding="utf-8")
    print("wrote fig1_overview_v1.svg")

    v2 = build_variant(
        c_image=None,
        c_label="地域医療シミュレータ",
        d_image="virus_ransomware_pc.png",
        d_label="サイバー攻撃シナリオ",
        c_composite=True,
    )
    (SCRIPT_DIR / "fig1_overview_v2.svg").write_text(v2, encoding="utf-8")
    print("wrote fig1_overview_v2.svg")


if __name__ == "__main__":
    main()
