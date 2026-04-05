#!/usr/bin/env python3
"""validate_yaml.py — main/00_setup/*.yaml の整合性チェック

チェック項目:
  1. 4ファイルがYAMLとして正しくパースできるか
  2. 必須フィールドの存在チェック
  3. budget.by_institution の機関別合計と budget.details の institution 別合算が一致するか
  4. researchers.yaml の全研究者が security.yaml の researchers キーに存在するか
  5. effort_percent の合算が100%を超えていないか（other_funding.yaml との突合）
"""

import argparse
import sys
from pathlib import Path

import yaml


def _parse_args():
    parser = argparse.ArgumentParser(description="Validate YAML setup files")
    parser.add_argument(
        "--setup-dir",
        default=str(Path(__file__).resolve().parent.parent / "main" / "00_setup"),
        help="Directory containing YAML setup files",
    )
    return parser.parse_args()


SETUP_DIR = Path(__file__).resolve().parent.parent / "main" / "00_setup"

YAML_FILES = ["config.yaml", "researchers.yaml", "other_funding.yaml", "security.yaml"]

# 必須フィールド（ドット区切りパス）
REQUIRED_FIELDS = {
    "config.yaml": [
        "project.title_ja",
        "project.title_en",
        "project.type",
        "project.period_years",
        "lead_institution.name",
        "budget.yearly",
        "budget.by_institution",
        "budget.details",
    ],
    "researchers.yaml": [
        "pi.name_ja",
        "pi.affiliation",
        "pi.effort_percent",
    ],
    "other_funding.yaml": [
        "pi_funding.entries",
    ],
    "security.yaml": [
        "researchers",
    ],
}


def load_yamls():
    """全YAMLを読み込んで返す。パースエラーがあればメッセージをリストに追加。"""
    data = {}
    errors = []
    for name in YAML_FILES:
        path = SETUP_DIR / name
        if not path.exists():
            errors.append(f"{name}: ファイルが見つかりません")
            continue
        try:
            with open(path, encoding="utf-8") as f:
                data[name] = yaml.safe_load(f)
        except yaml.YAMLError as e:
            errors.append(f"{name}: YAMLパースエラー — {e}")
    return data, errors


def get_nested(d, dotpath):
    """ドット区切りパスで辞書から値を取得。見つからなければ None。"""
    keys = dotpath.split(".")
    cur = d
    for k in keys:
        if not isinstance(cur, dict) or k not in cur:
            return None
        cur = cur[k]
    return cur


def check_required_fields(data):
    errors = []
    for filename, fields in REQUIRED_FIELDS.items():
        if filename not in data:
            continue
        d = data[filename]
        for field in fields:
            if get_nested(d, field) is None:
                errors.append(f"{filename}: 必須フィールド '{field}' がありません")
    return errors


def check_budget_consistency(config):
    """by_institution の年度別合計と yearly の直接経費合計が一致するか。"""
    errors = []
    budget = config.get("budget", {})
    yearly = budget.get("yearly", [])
    by_inst = budget.get("by_institution", [])

    if not yearly or not by_inst:
        return errors

    # yearly の年度別直接経費
    yearly_direct = {}
    for y in yearly:
        year = y.get("year")
        direct = sum(
            y.get(k, 0)
            for k in ["equipment", "consumables", "travel", "personnel", "other"]
        )
        yearly_direct[year] = direct

    # by_institution の年度別合計
    inst_totals = {}
    for inst in by_inst:
        for y in inst.get("yearly", []):
            year = y.get("year")
            inst_totals[year] = inst_totals.get(year, 0) + y.get("amount", 0)

    for year in sorted(set(yearly_direct) | set(inst_totals)):
        yd = yearly_direct.get(year, 0)
        it = inst_totals.get(year, 0)
        if yd != it:
            errors.append(
                f"config.yaml: {year}年目の直接経費合計 ({yd}千円) と "
                f"by_institution 合計 ({it}千円) が不一致"
            )

    # details の institution 別合算と by_institution の比較
    details = budget.get("details", [])
    if details:
        # details: year -> institution -> sum(amount)
        detail_inst = {}  # {year: {institution: total}}
        for yd in details:
            year = yd.get("year")
            if year not in detail_inst:
                detail_inst[year] = {}
            for item in yd.get("line_items", []):
                inst = item.get("institution", "")
                amt = item.get("amount", 0)
                detail_inst[year][inst] = detail_inst[year].get(inst, 0) + amt

        for bi in by_inst:
            inst_name = bi.get("institution", "")
            for y in bi.get("yearly", []):
                year = y.get("year")
                expected = y.get("amount", 0)
                actual = detail_inst.get(year, {}).get(inst_name, 0)
                if expected != actual:
                    errors.append(
                        f"config.yaml: {year}年目 {inst_name} — "
                        f"by_institution ({expected}千円) と "
                        f"details 合算 ({actual}千円) が不一致"
                    )

    return errors


def check_researcher_security(researchers_data, security_data):
    """researchers.yaml の全研究者が security.yaml の researchers キーに存在するか。"""
    errors = []
    sec_researchers = security_data.get("researchers", {}) or {}

    # PI
    pi_name = researchers_data.get("pi", {}).get("name_ja", "")
    if pi_name and pi_name not in sec_researchers:
        errors.append(
            f"security.yaml: 研究代表者 '{pi_name}' が researchers に存在しません"
        )

    # Co-investigators
    for ci in researchers_data.get("co_investigators", []) or []:
        ci_name = ci.get("name_ja", "")
        if ci_name and ci_name not in sec_researchers:
            errors.append(
                f"security.yaml: 研究分担者 '{ci_name}' が researchers に存在しません"
            )

    return errors


def check_effort(researchers_data, other_funding_data):
    """effort_percent の合算が100%を超えていないか。"""
    errors = []

    # PI
    pi = researchers_data.get("pi", {})
    pi_name = pi.get("name_ja", "未設定")
    pi_effort = pi.get("effort_percent", 0) or 0

    pi_other_effort = 0
    for entry in (other_funding_data.get("pi_funding", {}).get("entries", []) or []):
        pi_other_effort += entry.get("effort_percent", 0) or 0

    total_pi = pi_effort + pi_other_effort
    if total_pi > 100:
        errors.append(
            f"エフォート超過: {pi_name} — 本課題 {pi_effort}% + 他制度 {pi_other_effort}% = {total_pi}%"
        )

    # Co-investigators
    ci_funding_map = {}
    for cf in (other_funding_data.get("co_investigator_funding", []) or []):
        name = cf.get("researcher_name", "")
        total = sum(
            (e.get("effort_percent", 0) or 0) for e in (cf.get("entries", []) or [])
        )
        ci_funding_map[name] = total

    for ci in (researchers_data.get("co_investigators", []) or []):
        ci_name = ci.get("name_ja", "未設定")
        ci_effort = ci.get("effort_percent", 0) or 0
        ci_other = ci_funding_map.get(ci_name, 0)
        total_ci = ci_effort + ci_other
        if total_ci > 100:
            errors.append(
                f"エフォート超過: {ci_name} — 本課題 {ci_effort}% + 他制度 {ci_other}% = {total_ci}%"
            )

    return errors


def main():
    global SETUP_DIR
    args = _parse_args()
    SETUP_DIR = Path(args.setup_dir)

    print("=== YAMLバリデーション ===")
    print()

    data, errors = load_yamls()

    if not errors:
        errors.extend(check_required_fields(data))

    if "config.yaml" in data:
        errors.extend(check_budget_consistency(data["config.yaml"]))

    if "researchers.yaml" in data and "security.yaml" in data:
        errors.extend(
            check_researcher_security(data["researchers.yaml"], data["security.yaml"])
        )

    if "researchers.yaml" in data and "other_funding.yaml" in data:
        errors.extend(check_effort(data["researchers.yaml"], data["other_funding.yaml"]))

    if errors:
        print("エラー:")
        for e in errors:
            print(f"  ✗ {e}")
        print()
        print(f"バリデーション失敗: {len(errors)} 件のエラー")
        sys.exit(1)
    else:
        print("  全チェック OK")
        print()


if __name__ == "__main__":
    main()
