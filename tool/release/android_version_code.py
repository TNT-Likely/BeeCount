#!/usr/bin/env python3
"""Allocate Android codes from the highest code actually delivered.

4.0.0 betas use floor+1 in 226..299. Stable 4.0.0 and later versions use
max(300, floor+1). Version names and globally increasing codes are independent.
No network, signing, builds, tags, repository or device operations are performed.
"""
from __future__ import annotations

import argparse
from dataclasses import dataclass, replace
import json
import re
import sys

MAX_VERSION_CODE = 2_100_000_000
LEGACY_VERSION_NAME = "3.9.0"
LEGACY_VERSION_CODE = 225
FIRST_STABLE_CODE = 300
_VERSION = re.compile(
    r"v?(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)"
    r"(?:-beta\.([1-9][0-9]*))?\Z"
)


@dataclass(frozen=True)
class AndroidVersion:
    major: int
    minor: int
    patch: int
    beta: int | None = None
    # A parsed name does not imply an installation code. Allocation needs the
    # externally verified floor and the local append-only delivery registry.
    code: int | None = None

    @property
    def name(self) -> str:
        suffix = "" if self.beta is None else f"-beta.{self.beta}"
        return f"{self.major}.{self.minor}.{self.patch}{suffix}"

    @property
    def order(self) -> tuple[int, int, int, int, int]:
        return self.major, self.minor, self.patch, int(self.beta is None), self.beta or 0

    @property
    def initial_beta(self) -> bool:
        return (self.major, self.minor, self.patch) == (4, 0, 0) and self.beta is not None


def parse_version(value: str) -> AndroidVersion:
    if not isinstance(value, str):
        raise ValueError("版本名必须为字符串")
    match = _VERSION.fullmatch(value)
    if match is None:
        raise ValueError("版本必须为 X.Y.Z 或 X.Y.Z-beta.N，可带一个 v 前缀")
    return AndroidVersion(*(int(match[i]) for i in (1, 2, 3)),
                          beta=None if match[4] is None else int(match[4]))


def validate_recorded_version(value: str, code: int) -> AndroidVersion:
    """Validate a stored name/code pair without deriving the code from its name."""
    version = parse_version(value)
    if type(code) is not int or not 1 <= code <= MAX_VERSION_CODE:
        raise ValueError(f"versionCode 必须为 1..{MAX_VERSION_CODE} 的整数")
    if version.order < parse_version("4.0.0-beta.1").order:
        raise ValueError("候选版本名不得早于 4.0.0-beta.1")
    if version.initial_beta:
        if not LEGACY_VERSION_CODE < code < FIRST_STABLE_CODE:
            raise ValueError("4.0.0 Beta 的 versionCode 只允许 226..299；用尽后必须调整版本计划")
    elif code < FIRST_STABLE_CODE:
        raise ValueError("4.0.0 正式版及后续版本的 versionCode 至少为 300")
    return replace(version, code=code)


def validate_candidate(value: str, *, minimum_code: int,
                       minimum_version: str | None = None) -> AndroidVersion:
    version = parse_version(value)
    if type(minimum_code) is not int:
        raise ValueError("已发最高 versionCode 必须为整数")
    if not LEGACY_VERSION_CODE <= minimum_code <= MAX_VERSION_CODE:
        raise ValueError(f"已发最高 code 必须在已核线上 {LEGACY_VERSION_NAME}+{LEGACY_VERSION_CODE} 与 {MAX_VERSION_CODE} 之间")
    if minimum_version is not None and version.order < parse_version(minimum_version).order:
        raise ValueError("候选版本名不得早于本地最近已交付版本")
    code = minimum_code + 1 if version.initial_beta else max(FIRST_STABLE_CODE, minimum_code + 1)
    return validate_recorded_version(value, code)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("version", help="例如 4.0.0-beta.1 或 4.0.0")
    parser.add_argument("--minimum-code", required=True, type=int,
                        help="所有已交付正式版与 Beta 的最高实际 versionCode")
    parser.add_argument("--json", action="store_true", help="输出非敏感校验元数据")
    args = parser.parse_args(argv)
    try:
        version = validate_candidate(args.version, minimum_code=args.minimum_code)
    except ValueError as error:
        print(f"Android 版本门禁失败：{error}", file=sys.stderr)
        return 2
    if args.json:
        print(json.dumps({"versionName": version.name, "versionCode": version.code,
                          "channel": "stable" if version.beta is None else "beta",
                          "minimumCode": args.minimum_code,
                          "legacyBaseline": f"{LEGACY_VERSION_NAME}+{LEGACY_VERSION_CODE}"}, ensure_ascii=False))
    else:
        print(version.code)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
