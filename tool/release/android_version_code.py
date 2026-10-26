#!/usr/bin/env python3
"""One Android version-code scheme for local APKs and production workflows.

Code = major*1_000_000 + minor*10_000 + patch*100 + channel.
Beta channels are 1..98; stable is 99. Minor and patch are limited to 0..99.
The CLI requires the highest code already distributed across every channel.
It performs no network, signing, build, tag, repository or device operations.
"""

from __future__ import annotations

import argparse
from dataclasses import dataclass
import json
import re
import sys

# Conservative project ceiling, compatible with Google Play's versionCode cap.
MAX_VERSION_CODE = 2_100_000_000
LEGACY_VERSION_NAME = "3.9.0"
# Verified from the public 3.9.0 arm64 APK, not inferred from its filename.
LEGACY_VERSION_CODE = 225
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

    @property
    def name(self) -> str:
        suffix = "" if self.beta is None else f"-beta.{self.beta}"
        return f"{self.major}.{self.minor}.{self.patch}{suffix}"

    @property
    def channel(self) -> int:
        return 99 if self.beta is None else self.beta

    @property
    def order(self) -> tuple[int, int, int, int]:
        return self.major, self.minor, self.patch, self.channel

    @property
    def code(self) -> int:
        return (
            self.major * 1_000_000
            + self.minor * 10_000
            + self.patch * 100
            + self.channel
        )


def parse_version(value: str) -> AndroidVersion:
    match = _VERSION.fullmatch(value)
    if match is None:
        raise ValueError("版本必须为 X.Y.Z 或 X.Y.Z-beta.N，可带一个 v 前缀")
    major, minor, patch = (int(match[i]) for i in (1, 2, 3))
    beta = None if match[4] is None else int(match[4])
    if not 0 <= minor <= 99 or not 0 <= patch <= 99:
        raise ValueError("minor 与 patch 必须在 0..99，避免版本槽位冲突")
    if beta is not None and not 1 <= beta <= 98:
        raise ValueError("beta 序号只允许 1..98；99 保留给正式版，不自动进位")
    version = AndroidVersion(major, minor, patch, beta)
    if not 1 <= version.code <= MAX_VERSION_CODE:
        raise ValueError(f"versionCode 超出项目分发上限 {MAX_VERSION_CODE}")
    return version


def validate_candidate(value: str, *, minimum_code: int) -> AndroidVersion:
    version = parse_version(value)
    if isinstance(minimum_code, bool) or not isinstance(minimum_code, int):
        raise ValueError("已发最高 versionCode 必须为整数")
    if not LEGACY_VERSION_CODE <= minimum_code <= MAX_VERSION_CODE:
        raise ValueError(
            f"已发最高 code 不得低于已核线上 {LEGACY_VERSION_NAME}+"
            f"{LEGACY_VERSION_CODE}，也不得超过 {MAX_VERSION_CODE}"
        )
    # The old run-number scheme was small. A new encoded 3.8.0 would otherwise
    # have a larger integer while still being an older product version.
    if version.order <= parse_version(LEGACY_VERSION_NAME).order:
        raise ValueError(f"候选版本名必须高于已核线上 {LEGACY_VERSION_NAME}")
    if version.code <= minimum_code:
        raise ValueError(
            f"候选 {version.name} 的 code {version.code} 必须严格大于"
            f"全部已发正式版/Beta 的最高 code {minimum_code}；拒绝退码或复用"
        )
    return version


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("version", help="例如 4.0.0-beta.1 或 4.0.0")
    parser.add_argument(
        "--minimum-code",
        required=True,
        type=int,
        help="所有已交付正式版与 Beta 的最高实际 versionCode，不能填猜测值",
    )
    parser.add_argument("--json", action="store_true", help="输出非敏感校验元数据")
    args = parser.parse_args(argv)
    try:
        version = validate_candidate(args.version, minimum_code=args.minimum_code)
    except ValueError as error:
        print(f"Android 版本门禁失败：{error}", file=sys.stderr)
        return 2
    if args.json:
        print(
            json.dumps(
                {
                    "versionName": version.name,
                    "versionCode": version.code,
                    "channel": "stable" if version.beta is None else "beta",
                    "minimumCode": args.minimum_code,
                    "legacyBaseline": f"{LEGACY_VERSION_NAME}+{LEGACY_VERSION_CODE}",
                },
                ensure_ascii=False,
            )
        )
    else:
        print(version.code)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
