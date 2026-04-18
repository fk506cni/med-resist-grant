#!/usr/bin/env python3
"""merge_pdfs.py — Concatenate per-form PDFs into a single submission PDF.

Driven by ``main/00_setup/package.yaml``. Source PDFs must already exist in
``data/products/`` (produced by Windows Word COM via ``roundtrip.sh``).

Usage:
    python merge_pdfs.py \\
        --mode submission \\
        --package main/00_setup/package.yaml \\
        --config main/00_setup/config.yaml \\
        --researchers main/00_setup/researchers.yaml \\
        --products-dir data/products \\
        --output-dir data/products
"""

import argparse
import sys
from pathlib import Path

import yaml
from pypdf import PdfReader, PdfWriter


# ============================================================================
# YAML helpers
# ============================================================================

def _load_yaml(path: Path) -> dict:
    with open(path, encoding="utf-8") as f:
        return yaml.safe_load(f) or {}


def _resolve_dotpath(data: dict, dotpath: str) -> str:
    """Return data[a][b][c] for dotpath 'a.b.c', or '' if missing."""
    cur = data
    for key in dotpath.split("."):
        if not isinstance(cur, dict) or key not in cur:
            return ""
        cur = cur[key]
    return str(cur) if cur is not None else ""


# ============================================================================
# Source resolution
# ============================================================================

def _resolve_sources(sources: list, products_dir: Path) -> list:
    """Resolve package.yaml source list to concrete ordered file paths."""
    out = []
    for src in sources:
        if isinstance(src, str):
            p = products_dir / src
            if not p.is_file():
                raise FileNotFoundError(f"PDF not found: {p}")
            out.append(p)
        elif isinstance(src, dict) and "pattern" in src:
            matches = sorted(products_dir.glob(src["pattern"]))
            if not matches:
                print(
                    f"  ⚠ pattern '{src['pattern']}' matched no files in "
                    f"{products_dir}",
                    file=sys.stderr,
                )
            out.extend(matches)
        else:
            raise ValueError(f"Invalid source spec: {src!r}")
    return out


# ============================================================================
# Metadata
# ============================================================================

def _build_metadata(mode_cfg: dict, cfg: dict, res: dict) -> dict:
    """Build a pypdf-compatible metadata dict (/Title, /Author, /Subject …)."""
    md = mode_cfg.get("metadata", {}) or {}
    out = {}
    if "title_from" in md:
        v = (
            _resolve_dotpath(cfg, md["title_from"])
            or _resolve_dotpath(res, md["title_from"])
        )
        if v:
            out["/Title"] = v
    if "author_from" in md:
        v = (
            _resolve_dotpath(res, md["author_from"])
            or _resolve_dotpath(cfg, md["author_from"])
        )
        if v:
            out["/Author"] = v
    if "subject" in md:
        out["/Subject"] = str(md["subject"])
    out["/Creator"] = "med-resist-grant/merge_pdfs.py (pypdf)"
    return out


# ============================================================================
# Merge
# ============================================================================

def _merge(sources: list, output: Path, metadata: dict) -> int:
    """Concatenate *sources* into *output*, return total page count."""
    writer = PdfWriter()
    readers = []  # keep PdfReader objects alive until writer.write() completes
    total = 0
    for src in sources:
        reader = PdfReader(str(src))
        readers.append(reader)
        for page in reader.pages:
            writer.add_page(page)
            total += 1
    if metadata:
        writer.add_metadata(metadata)
    with open(output, "wb") as f:
        writer.write(f)
    return total


# ============================================================================
# Main
# ============================================================================

def main() -> None:
    ap = argparse.ArgumentParser(
        description="Merge per-form PDFs into a single submission PDF"
    )
    ap.add_argument("--package", default="main/00_setup/package.yaml")
    ap.add_argument("--config", default="main/00_setup/config.yaml")
    ap.add_argument("--researchers", default="main/00_setup/researchers.yaml")
    ap.add_argument("--products-dir", default="data/products")
    ap.add_argument("--output-dir", default="data/products")
    ap.add_argument(
        "--mode",
        choices=["submission", "interview"],
        default="submission",
        help="package.yaml の mode キー",
    )
    args = ap.parse_args()

    pkg = _load_yaml(Path(args.package))
    cfg = _load_yaml(Path(args.config))
    res = _load_yaml(Path(args.researchers))

    if args.mode not in pkg:
        print(
            f"ERROR: mode '{args.mode}' が {args.package} に定義されていません",
            file=sys.stderr,
        )
        sys.exit(1)

    mode_cfg = pkg[args.mode]
    products_dir = Path(args.products_dir)
    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)
    out_path = output_dir / mode_cfg["output"]

    print(f"=== merge_pdfs ({args.mode}) ===")
    print(f"  products-dir: {products_dir}")
    print(f"  output:       {out_path}")

    try:
        sources = _resolve_sources(
            mode_cfg.get("sources", []) or [], products_dir
        )
    except (FileNotFoundError, ValueError) as e:
        print(f"ERROR: {e}", file=sys.stderr)
        sys.exit(1)

    if not sources:
        print(
            f"ERROR: mode '{args.mode}' の sources が 0 件です",
            file=sys.stderr,
        )
        sys.exit(1)

    print(f"  sources ({len(sources)}):")
    for s in sources:
        reader = PdfReader(str(s))
        print(f"    + {s.name}  ({len(reader.pages)}p)")

    metadata = _build_metadata(mode_cfg, cfg, res)
    total = _merge(sources, out_path, metadata)

    verify = PdfReader(str(out_path))
    if len(verify.pages) != total:
        print(
            f"ERROR: ページ数不一致 expected={total} got={len(verify.pages)}",
            file=sys.stderr,
        )
        sys.exit(1)

    size_kb = out_path.stat().st_size / 1024
    print(f"  → {out_path.name}  ({total}p, {size_kb:.1f} KB)")
    if metadata:
        kv = ", ".join(f"{k}={v!r}" for k, v in metadata.items())
        print(f"  metadata: {kv}")


if __name__ == "__main__":
    main()
