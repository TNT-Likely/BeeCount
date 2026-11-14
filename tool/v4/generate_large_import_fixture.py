#!/usr/bin/env python3
"""Create deterministic synthetic CSV/oracle files, never touch App or Cloud.

The files are deliberately not tracked. Import through the production file picker
and confirmation flow; generating this fixture is not an import performance test.
"""

import argparse
import collections
import csv
import datetime as dt
from decimal import Decimal
import hashlib
import io
import json
import math
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
PREFIX = "QA15K-20261026"
HEADERS = ["日期", "收支", "金额", "币种", "分类", "二级分类", "账户", "转出账户", "转入账户", "备注", "标签", "附件"]
CURRENCIES = ["CNY", "USD", "EUR", "JPY", "KWD", "HKD", "CHF", "GBP"]
TYPE_NAMES = {"expense": "支出", "income": "收入", "transfer": "转账"}
ANCHOR = dt.datetime(2026, 10, 26, 7)
LEGACY_TAG_NAMES = [f"{PREFIX}-{name}" for name in [
    "工作日", "旅行", "报销", "家庭", "网购", "阅读", "礼物", "通勤", "医疗", "订阅", "现金", "银行卡",
    "长标签用于验证单行省略和更多数量仍然可读", "Unicode-🧋", "café-日本語", "待确认",
]]


# Display names are separate from the long ownership prefix carried by notes and
# the manifest. Category save uses Dart String.length (UTF-16), not Python len.
RESOURCE_PREFIX = "Q15"
PROFILES = ("normal", "import-robustness")
TAG_NAMES = [f"{RESOURCE_PREFIX}-{name}" for name in [
    "工作日", "旅行", "报销", "家庭", "网购", "阅读", "礼物", "通勤", "医疗", "订阅", "现金", "银行卡",
    "二十字符标签边界与多标签排版验证", "茶🧋", "café-日本語", "待确认",
]]
DAILY_ACCOUNT_TYPES = ["cash", "bank_card", "credit_card", "alipay", "wechat", "other"]
ACCOUNT_LABELS = {"cash": "现金", "bank_card": "用于验证省略的很长银行卡账户名称",
                  "credit_card": "信用卡", "alipay": "支付宝", "wechat": "微信", "other": "其他"}
TAG_COLORS = ["#FF5722", "#E91E63", "#9C27B0", "#673AB7", "#3F51B5", "#2196F3", "#009688", "#4CAF50"]
CATEGORY_ICONS = ["restaurant", "local_cafe", "directions_subway", "shopping_basket", "home", "movie", "book", "favorite"]


def utf16_units(text):
    return len(text.encode("utf-16-le")) // 2


def category_names(index, kind, profile="normal"):
    if kind == "transfer" or (profile == "import-robustness" and index % 17 == 0):
        return "", ""
    if profile == "import-robustness":
        return (f"{PREFIX}-{'收入' if kind == 'income' else '消费'}{index % 8}",
                f"{PREFIX}-子类{index % 24}" if index % 3 else "")
    kind_label = "收入" if kind == "income" else "支出"
    parent = (f"{RESOURCE_PREFIX}边界{kind_label}分类7" if index % 8 == 7
              else f"{RESOURCE_PREFIX}{kind_label}{index % 8}")
    child = (f"{RESOURCE_PREFIX}边界子分类{index % 24:02d}" if index % 24 in (1, 2)
             else f"{RESOURCE_PREFIX}子类{index % 24:02d}") if index % 3 else ""
    return parent, child


def account_name(index, code, profile="normal"):
    if profile == "import-robustness":
        return f"{PREFIX}-{code}-{'现金' if index % 2 else '用于验证省略的很长银行卡账户名称'}"
    kind = DAILY_ACCOUNT_TYPES[CURRENCIES.index(code) % len(DAILY_ACCOUNT_TYPES)]
    return f"{PREFIX}-{code}-{ACCOUNT_LABELS[kind]}"


def manual_input_boundaries(item):
    """Only established UI restrictions; no invented account/ledger/note cap.

    Tag checks deliberately use the stricter UTF-16 budget, so these generated
    Unicode samples also fit Flutter's grapheme-based maxLength 20.
    """
    reasons = []
    if item["type"] != "transfer" and not item["category"]:
        reasons.append("category:missing-for-new-entry")
    for field in ("category", "subCategory"):
        if item[field] is not None and utf16_units(item[field].strip()) > 10:
            reasons.append(field + ":over-10-utf16")
    if any(utf16_units(name.strip()) > 20 for name in item["tagNames"]):
        reasons.append("tagName:over-20-safe-units")
    amount = Decimal(item["amount"])
    if not amount.is_finite() or not math.isfinite(float(amount)):
        reasons.append("amount:non-finite")
    elif amount <= 0:
        reasons.append("amount:not-positive")
    if amount.is_finite() and max(0, -amount.normalize().as_tuple().exponent) > 2:
        reasons.append("amount:over-two-decimals")
    return reasons


def records(count, attachment_names=(), long_note_percent=2, profile="normal"):
    """Single-line CSV notes: production CsvParser does not support RFC multiline."""
    if profile not in PROFILES:
        raise ValueError("Unknown fixture profile")
    for index in range(count):
        code = CURRENCIES[index % len(CURRENCIES)]
        kind = "transfer" if index % 10 == 9 else "income" if index % 5 == 3 else "expense"
        precision = 0 if code == "JPY" else 3 if code == "KWD" and profile == "import-robustness" else 2
        quantum = Decimal(1).scaleb(-precision)
        amount = (Decimal((index * 7919) % 1900000) / 100).quantize(quantum)
        edge = index % 101
        if edge == 0:
            amount = Decimal(0) if profile == "import-robustness" else quantum * 2
        elif edge == 1:
            amount = quantum
        elif edge == 2:
            amount = Decimal("999999999.99").quantize(quantum)
        amount_text = f"{amount:.{precision}f}"
        if index % 97 == 3:
            amount_text = f"{amount:,.{precision}f}"
        if index % 113 == 7:
            amount_text = "-" + amount_text  # production imports magnitude by abs()
        if code == "CNY" and index % 149 == 4:
            amount_text = "¥" + amount_text
        when = ANCHOR - (dt.timedelta(seconds=index) if index < 48 else
                         dt.timedelta(days=1 + (index * 37) % 2860,
                                      seconds=(index * 313) % 86400))
        if index == 14999:
            when = dt.datetime(2024, 2, 29, 0, 0, 7)
        date_text = when.strftime("%Y-%m-%d %H:%M:%S")
        if index % 11 == 1:
            date_text = when.strftime("%Y年%m月%d日 %H:%M:%S")
        elif index % 11 == 2:
            date_text = when.strftime("%Y/%m/%d %H:%M:%S")
        parent, child = category_names(index, kind, profile)
        account = account_name(index, code, profile)
        if kind != "transfer" and index % 23 == 0:
            account = ""
        elif kind != "transfer" and index % 29 == 0:
            account = (f"{PREFIX}-多币种旅行钱包" if profile == "import-robustness"
                       else f"{PREFIX}-{code}-旅行钱包")
        from_account = f"{PREFIX}-{code}-转出现金" if kind == "transfer" else ""
        to_account = f"{PREFIX}-{code}-转入银行卡" if kind == "transfer" else ""
        if kind == "transfer":
            account = ""
        tag_count = [0, 1, 2, 6, 12][index % 10 // 2]
        if index < 12:
            tag_count = [2, 6, 12][index % 3]
        tag_names = LEGACY_TAG_NAMES if profile == "import-robustness" else TAG_NAMES
        tags = [tag_names[(index + j) % len(tag_names)] for j in range(tag_count)]
        csv_tags = tags + ([tags[0]] if tags and index % 19 == 0 else [])
        note = f"{PREFIX}#{index + 1:05d} " + [
            "午餐", '包含逗号,与"双引号"的合法单行备注', "Unicode 🧋 café 日本語 한글", "同日同金额用于验证独立交易",
            "非常长的备注用于验证省略、首次绘制高度和完整详情保留。" * (48 if index % 100 < long_note_percent * 5 else 2),
        ][index % 5]
        attached = list(attachment_names[:1 + index % min(3, len(attachment_names))]) if attachment_names and index < 16 else []
        row = [date_text, TYPE_NAMES[kind], amount_text, code, parent, child, account,
               from_account, to_account, note, ",".join(csv_tags), ",".join(attached)]
        oracle = {"sequence": index + 1, "type": kind, "amount": str(amount),
                  "currencyCode": code, "happenedAtLocal": when.isoformat(),
                  "category": parent or None, "subCategory": child or None,
                  "accountName": account or None, "fromAccountName": from_account or None,
                  "toAccountName": to_account or None, "note": note,
                  "tagNames": list(dict.fromkeys(tags)), "attachmentNames": attached}
        oracle["manualInputBoundaryReasons"] = manual_input_boundaries(oracle)
        if profile == "normal" and oracle["manualInputBoundaryReasons"]:
            raise ValueError("Normal fixture violates UI constraints: " + str(oracle["manualInputBoundaryReasons"]))
        yield row, oracle



def resource_plan(count, profile="normal"):
    """Owned pre-seed/UI plan; CSV cannot carry these richer definitions."""
    categories, accounts = {}, {}
    for _, item in records(count, profile=profile):
        code, kind = item["currencyCode"], item["type"]
        if item["category"]:
            key = (kind, item["category"])
            categories[key] = {"name": key[1], "kind": kind, "level": 1,
                               "parentName": None, "iconType": "material",
                               "icon": CATEGORY_ICONS[int(hashlib.sha256((kind + key[1]).encode()).hexdigest()[:8], 16) % len(CATEGORY_ICONS)]}
        if item["subCategory"]:
            key = (kind, item["subCategory"])
            categories[key] = {"name": key[1], "kind": kind, "level": 2,
                               "parentName": item["category"], "iconType": "material",
                               "icon": CATEGORY_ICONS[int(hashlib.sha256((kind + key[1]).encode()).hexdigest()[:8], 16) % len(CATEGORY_ICONS)]}
        for role in ("accountName", "fromAccountName", "toAccountName"):
            name = item[role]
            if not name:
                continue
            target = name if profile == "normal" else (name, code)
            account_type = ("cash" if role == "fromAccountName" else "bank_card" if role == "toAccountName"
                            else "other" if "旅行钱包" in name
                            else DAILY_ACCOUNT_TYPES[CURRENCIES.index(code) % len(DAILY_ACCOUNT_TYPES)])
            accounts[target] = {"name": name, "currency": code, "type": account_type,
                                "uiInitialBalance": "0.00", "storedInitialBalance": "0.00",
                                "transactionEligible": True}
            if account_type in ("bank_card", "credit_card"):
                accounts[target]["cardLastFour"] = "0028"
            if account_type == "credit_card":
                accounts[target].update(creditLimit="10000.00", billingDay=1,
                                        paymentDueDay=28, creditBalanceKind="owed")
    for kind, label, balance in [("real_estate", "房产", "1800000.00"),
                                 ("vehicle", "车辆", "120000.00"),
                                 ("investment", "投资", "35000.25"),
                                 ("insurance", "保险", "12000.00"),
                                 ("social_fund", "公积金", "65000.50"),
                                 ("loan", "贷款", "450000.00")]:
        name = f"{RESOURCE_PREFIX}-{label}"
        accounts[name] = {"name": name, "currency": "CNY", "type": kind,
                          "uiInitialBalance": balance,
                          "storedInitialBalance": "-" + balance if kind == "loan" else balance,
                          "transactionEligible": False}
    names = LEGACY_TAG_NAMES if profile == "import-robustness" else TAG_NAMES
    cats = sorted(categories.values(), key=lambda x: (x["kind"], x["level"], x["name"]))
    if cats:
        # The image already belongs to this public App fixture. Prepare via the
        # real category image picker; a CSV cannot restore its definition.
        cats[0].update(iconType="custom", icon=None,
                       customIconFixture="category-coffee.png")
    return {"schema": "beecount-qa-resource-preparation-v1", "notAnImportableBackup": True,
            "datasetPrefix": PREFIX, "profile": profile,
            "ledger": {"name": "QA · 15000笔混合压力账本", "currency": "CNY", "monthStartDay": 1},
            "requiresOwnedIsolatedEnvironment": True,
            "application": "Prepare through QA UI or an explicitly owned fixture setup; generating this plan applies nothing",
            "normalPreparationRequired": ["daily account types before CSV import", "valuation assets without transaction links", "tag colors", "custom category image via picker"],
            "csvOnlyAccountType": "cash", "csvOnlyTagColorAndCustomIcon": "not restored",
            "accounts": sorted(accounts.values(), key=lambda x: (x["type"], x["currency"], x["name"])),
            "categories": cats,
            "tags": [{"name": name, "color": TAG_COLORS[i % len(TAG_COLORS)]} for i, name in enumerate(names)]}


def legacy_rename_plan(count):
    categories = {}
    for index in range(count):
        code = CURRENCIES[index % len(CURRENCIES)]
        kind = "transfer" if index % 10 == 9 else "income" if index % 5 == 3 else "expense"
        old_parent, old_child = category_names(index, kind, "import-robustness")
        new_parent, new_child = category_names(index, kind)
        for old_name, new_name, level in [(old_parent, new_parent, 1), (old_child, new_child, 2)]:
            if old_name:
                categories[(kind, old_name)] = {"oldName": old_name, "newName": new_name,
                                                "kind": kind, "level": level,
                                                "expectedOldParentName": old_parent if level == 2 else None,
                                                "expectedNewParentName": new_parent if level == 2 else None}
    return {"schema": "beecount-qa-rename-suggestion-v1", "datasetPrefix": PREFIX,
            "readOnlySuggestion": True, "neverApplyByNameAlone": True,
            "requiredGuards": ["private current backup of database/preferences/attachments",
                               "exact owned environment package and application identity",
                               "concrete category/tag IDs and sync IDs captured from that fixture's manifest",
                               "all references and linked transactions checked against datasetPrefix notes",
                               "shared/user-created resource or a conflicting destination name => skip and record",
                               "rename identities in place; never delete/recreate or truncate every category"],
            "categories": sorted(categories.values(), key=lambda x: (x["kind"], x["level"], x["oldName"])),
            "tags": [{"oldName": old, "newName": new} for old, new in zip(LEGACY_TAG_NAMES, TAG_NAMES) if utf16_units(old) > 20],
            "accounts": [], "accountNote": "No existing account-name length cap was found; do not bulk truncate account names",
            "amounts": "Existing zero/three-decimal imports are historical import-boundary data; never rewrite financial values to make a fixture look normal"}


def make_fixture(directory, count=15000, attachment_names=(), long_note_percent=2,
                 profile="normal"):
    if profile not in PROFILES:
        raise ValueError("Unknown fixture profile")
    directory = Path(directory).resolve()
    try:
        inside = directory.relative_to(ROOT)
    except ValueError:
        inside = None
    if inside is not None and not inside.is_relative_to(".docs/v4-ui-migration"):
        raise ValueError("Generated data must stay in the private ignored directory")
    if not 0 <= long_note_percent <= 20:
        raise ValueError("Long-note percentage must be 0..20")
    if count < 1 or count > 50000:
        raise ValueError("Count must be 1..50000")
    for name in attachment_names:
        if Path(name).name != name or not name or any(c in name for c in ",\r\n"):
            raise ValueError("Attachment names must be existing owned basenames")
    directory.mkdir(parents=True, exist_ok=True, mode=0o700)
    csv_path = directory / "beecount-15000-mixed.csv"
    oracle_path = directory / "expected-records.jsonl"
    manifest_path = directory / "fixture-manifest.json"
    resources_path = directory / "fixture-resources.json"
    renames_path = directory / "legacy-resource-rename-plan.json"
    if any(p.exists() for p in (csv_path, oracle_path, manifest_path, resources_path, renames_path, directory / "category-coffee.png")):
        raise FileExistsError("Refuse to overwrite an existing fixture")
    output = io.StringIO(newline="")
    writer = csv.writer(output, lineterminator="\n")
    writer.writerow(HEADERS)
    counts = collections.Counter()
    totals = collections.defaultdict(Decimal)
    oracle_lines = []
    all_rows = []
    for row, item in records(count, attachment_names, long_note_percent, profile):
        writer.writerow(row)
        all_rows.append(row)
        oracle_lines.append(json.dumps(item, ensure_ascii=False, separators=(",", ":")))
        counts["type:" + item["type"]] += 1
        counts["currency:" + item["currencyCode"]] += 1
        counts["tagCount:" + str(len(item["tagNames"]))] += 1
        counts["subCategory"] += int(item["subCategory"] is not None)
        counts["noAccount"] += int(item["type"] != "transfer" and item["accountName"] is None)
        counts["zeroAmount"] += int(Decimal(item["amount"]) == 0)
        counts["quotedCommaNote"] += int("," in item["note"] and '"' in item["note"])
        counts["longNote"] += int(len(item["note"]) > 1000)
        counts["attachmentMetadata"] += len(item["attachmentNames"])
        for boundary in item["manualInputBoundaryReasons"]:
            counts["manualBoundary:" + boundary] += 1
        totals[item["type"] + ":" + item["currencyCode"]] += Decimal(item["amount"])
    raw = b"\xef\xbb\xbf" + output.getvalue().encode("utf-8")
    assert list(csv.reader(io.StringIO(raw.decode("utf-8-sig"))))[1:] == all_rows
    oracle_bytes = ("\n".join(oracle_lines) + "\n").encode("utf-8")
    manifest = {
        "version": 2, "synthetic": True, "datasetPrefix": PREFIX,
        "profile": profile, "routineUiSamples": profile == "normal",
        "nameOwnership": "Short visible names alone never prove fixture ownership",
        "constraintValidation": {
            "status": "PASS" if profile == "normal" else "EXPLICIT_IMPORT_BOUNDARIES",
            "categoryUtf16Max": 10, "tagSafeUtf16Max": 20,
            "amountMustBeFinitePositive": True, "manualFractionDigitsMax": 2,
            "integerDigitsMax": None, "accountNameMax": None, "ledgerNameMax": None, "noteMax": None,
            "rowsWithManualInputBoundary": sum(bool(json.loads(line)["manualInputBoundaryReasons"]) for line in oracle_lines),
        },
        "ledgerName": "QA · 15000笔混合压力账本", "baseCurrency": "CNY", "records": count,
        "header": HEADERS, "anchorLocal": ANCHOR.isoformat(), "longNotePercent": long_note_percent,
        "counts": dict(sorted(counts.items())),
        "originalAmountTotals": {k: str(v) for k, v in sorted(totals.items())},
        "csv": {"file": csv_path.name, "bytes": len(raw), "sha256": hashlib.sha256(raw).hexdigest()},
        "oracle": {"file": oracle_path.name, "bytes": len(oracle_bytes), "sha256": hashlib.sha256(oracle_bytes).hexdigest()},
        "limitations": [
            "Fixture generation is not a device import or performance result",
            "CSV cannot restore historical native-amount snapshots; actual effective import rates are separate",
            "CSV does not import exclusion flags, tag colors, custom category images or account types",
            "fixture-resources.json is a preparation plan, not an importable backup or proof those resources were applied",
            "Without preparing the owned resources through QA UI/setup, CSV imports unknown accounts as cash",
            "import-robustness intentionally contains records unavailable through normal UI; never use it as routine UI acceptance data",
            "CSV attachment names are metadata only; optional basenames must already exist as owned QA files",
            "Production CSV parser does not support quoted multiline fields; notes are single-line",
            "Import does not content-deduplicate repeated files; do not import this fixture a second time",
        ],
    }
    resources = resource_plan(count, profile)
    rename_plan = legacy_rename_plan(count)
    image_source = ROOT / "test/fixtures/design/category-coffee.png"
    image_bytes = image_source.read_bytes()
    resources["customIconImage"] = {"file": "category-coffee.png", "sha256": hashlib.sha256(image_bytes).hexdigest(),
                                   "source": "test/fixtures/design/category-coffee.png"}
    resources_bytes = (json.dumps(resources, ensure_ascii=False, indent=2) + "\n").encode()
    renames_bytes = (json.dumps(rename_plan, ensure_ascii=False, indent=2) + "\n").encode()
    manifest["resources"] = {"file": resources_path.name, "sha256": hashlib.sha256(resources_bytes).hexdigest()}
    manifest["legacyRenamePlan"] = {"file": renames_path.name, "sha256": hashlib.sha256(renames_bytes).hexdigest()}
    for path, contents in [(csv_path, raw), (oracle_path, oracle_bytes),
                           (directory / "category-coffee.png", image_bytes),
                           (resources_path, resources_bytes), (renames_path, renames_bytes),
                           (manifest_path, (json.dumps(manifest, ensure_ascii=False, indent=2) + "\n").encode())]:
        with path.open("xb") as stream:
            stream.write(contents)
        path.chmod(0o600)
    return manifest


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", type=Path)
    parser.add_argument("--count", type=int, default=15000)
    parser.add_argument("--profile", choices=PROFILES, default="normal")
    parser.add_argument("--long-note-percent", type=int, default=2)
    parser.add_argument("--attachment-names-json", type=Path)
    args = parser.parse_args()
    args.output_dir = args.output_dir or ROOT / ".docs/v4-ui-migration/large-import-15000-v2" / args.profile
    attachments = json.loads(args.attachment_names_json.read_text()) if args.attachment_names_json else []
    if not isinstance(attachments, list) or not all(isinstance(x, str) for x in attachments):
        raise ValueError("Attachment list must contain only names, never binary data")
    result = make_fixture(args.output_dir, args.count, attachments, args.long_note_percent, args.profile)
    print(json.dumps({"output": str(args.output_dir), "records": result["records"],
                      "csv": result["csv"], "profile": result["profile"], "syntheticOnly": True}, ensure_ascii=False))


if __name__ == "__main__":
    main()
