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
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
PREFIX = "QA15K-20261026"
HEADERS = ["日期", "收支", "金额", "币种", "分类", "二级分类", "账户", "转出账户", "转入账户", "备注", "标签", "附件"]
CURRENCIES = ["CNY", "USD", "EUR", "JPY", "KWD", "HKD", "CHF", "GBP"]
TYPE_NAMES = {"expense": "支出", "income": "收入", "transfer": "转账"}
ANCHOR = dt.datetime(2026, 10, 26, 7)
TAG_NAMES = [f"{PREFIX}-{name}" for name in [
    "工作日", "旅行", "报销", "家庭", "网购", "阅读", "礼物", "通勤", "医疗", "订阅", "现金", "银行卡",
    "长标签用于验证单行省略和更多数量仍然可读", "Unicode-🧋", "café-日本語", "待确认",
]]


def records(count, attachment_names=(), long_note_percent=2):
    """Single-line CSV notes: production CsvParser does not support RFC multiline."""
    for index in range(count):
        code = CURRENCIES[index % len(CURRENCIES)]
        kind = "transfer" if index % 10 == 9 else "income" if index % 5 == 3 else "expense"
        precision = 0 if code == "JPY" else 3 if code == "KWD" else 2
        quantum = Decimal(1).scaleb(-precision)
        amount = (Decimal((index * 7919) % 1900000) / 100).quantize(quantum)
        edge = index % 101
        if edge == 0:
            amount = Decimal(0)
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
        parent = "" if kind == "transfer" or index % 17 == 0 else f"{PREFIX}-{'收入' if kind == 'income' else '消费'}{index % 8}"
        child = f"{PREFIX}-子类{index % 24}" if parent and index % 3 else ""
        account = f"{PREFIX}-{code}-{'现金' if index % 2 else '用于验证省略的很长银行卡账户名称'}"
        if kind != "transfer" and index % 23 == 0:
            account = ""
        elif kind != "transfer" and index % 29 == 0:
            account = f"{PREFIX}-多币种旅行钱包"
        from_account = f"{PREFIX}-{code}-转出现金" if kind == "transfer" else ""
        to_account = f"{PREFIX}-{code}-转入银行卡" if kind == "transfer" else ""
        if kind == "transfer":
            account = ""
        tag_count = [0, 1, 2, 6, 12][index % 10 // 2]
        if index < 12:
            tag_count = [2, 6, 12][index % 3]
        tags = [TAG_NAMES[(index + j) % len(TAG_NAMES)] for j in range(tag_count)]
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
        yield row, oracle


def make_fixture(directory, count=15000, attachment_names=(), long_note_percent=2):
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
    if any(p.exists() for p in (csv_path, oracle_path, manifest_path)):
        raise FileExistsError("Refuse to overwrite an existing fixture")
    output = io.StringIO(newline="")
    writer = csv.writer(output, lineterminator="\n")
    writer.writerow(HEADERS)
    counts = collections.Counter()
    totals = collections.defaultdict(Decimal)
    oracle_lines = []
    all_rows = []
    for row, item in records(count, attachment_names, long_note_percent):
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
        totals[item["type"] + ":" + item["currencyCode"]] += Decimal(item["amount"])
    raw = b"\xef\xbb\xbf" + output.getvalue().encode("utf-8")
    assert list(csv.reader(io.StringIO(raw.decode("utf-8-sig"))))[1:] == all_rows
    oracle_bytes = ("\n".join(oracle_lines) + "\n").encode("utf-8")
    manifest = {
        "version": 1, "synthetic": True, "datasetPrefix": PREFIX,
        "ledgerName": "QA · 15000笔混合压力账本", "baseCurrency": "CNY", "records": count,
        "header": HEADERS, "anchorLocal": ANCHOR.isoformat(), "longNotePercent": long_note_percent,
        "counts": dict(sorted(counts.items())),
        "originalAmountTotals": {k: str(v) for k, v in sorted(totals.items())},
        "csv": {"file": csv_path.name, "bytes": len(raw), "sha256": hashlib.sha256(raw).hexdigest()},
        "oracle": {"file": oracle_path.name, "bytes": len(oracle_bytes), "sha256": hashlib.sha256(oracle_bytes).hexdigest()},
        "limitations": [
            "Fixture generation is not a device import or performance result",
            "CSV cannot restore historical native-amount snapshots; actual effective import rates are separate",
            "CSV does not import exclusion flags, tag colors or custom category images",
            "CSV attachment names are metadata only; optional basenames must already exist as owned QA files",
            "Production CSV parser does not support quoted multiline fields; notes are single-line",
            "Import does not content-deduplicate repeated files; do not import this fixture a second time",
        ],
    }
    for path, contents in [(csv_path, raw), (oracle_path, oracle_bytes),
                           (manifest_path, (json.dumps(manifest, ensure_ascii=False, indent=2) + "\n").encode())]:
        with path.open("xb") as stream:
            stream.write(contents)
        path.chmod(0o600)
    return manifest


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", type=Path, default=ROOT / ".docs/v4-ui-migration/large-import-15000-20261026/fixture-main")
    parser.add_argument("--count", type=int, default=15000)
    parser.add_argument("--long-note-percent", type=int, default=2)
    parser.add_argument("--attachment-names-json", type=Path)
    args = parser.parse_args()
    attachments = json.loads(args.attachment_names_json.read_text()) if args.attachment_names_json else []
    if not isinstance(attachments, list) or not all(isinstance(x, str) for x in attachments):
        raise ValueError("Attachment list must contain only names, never binary data")
    result = make_fixture(args.output_dir, args.count, attachments, args.long_note_percent)
    print(json.dumps({"output": str(args.output_dir), "records": result["records"],
                      "csv": result["csv"], "syntheticOnly": True}, ensure_ascii=False))


if __name__ == "__main__":
    main()
