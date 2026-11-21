#!/usr/bin/env python3
"""Store PR-to-QA handoff records across BeeCount worktrees on this machine."""
import argparse
import json
from pathlib import Path
import re
import subprocess
import tempfile

PROJECT = Path(__file__).resolve().parents[2]
RECORD_ID = re.compile(r'[A-Za-z0-9][A-Za-z0-9_-]{0,95}')
PR_URL = re.compile(r'https://github\.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+/pull/[1-9][0-9]*')


def registry(repo):
    common_dir = subprocess.check_output(
        ['git', '-C', str(repo), 'rev-parse', '--path-format=absolute', '--git-common-dir'],
        text=True,
    ).strip()
    return Path(common_dir) / 'beecount-qa' / 'pr-runs'


def pr_key(url):
    if not isinstance(url, str) or not PR_URL.fullmatch(url):
        raise ValueError('Expected a canonical GitHub pull request URL')
    return url.lower()


def read_record(path):
    record = json.loads(path.read_text(encoding='utf-8'))
    if not isinstance(record, dict):
        raise ValueError('Expected a QA handoff record object')
    record_id = record.get('id')
    if not isinstance(record_id, str) or not RECORD_ID.fullmatch(record_id):
        raise ValueError('Expected a stable QA handoff record ID')
    urls = record.get('pr_urls')
    if not isinstance(urls, list):
        raise ValueError('Expected pr_urls to be a list')
    return record, {pr_key(url) for url in urls}


def save(directory, source):
    record, _ = read_record(source)
    directory.mkdir(mode=0o700, parents=True, exist_ok=True)
    destination = directory / (record['id'] + '.json')
    staged_path = None
    try:
        with tempfile.NamedTemporaryFile(
            mode='w', encoding='utf-8', dir=directory, delete=False,
        ) as staged:
            staged_path = Path(staged.name)
            json.dump(record, staged, ensure_ascii=False, indent=2)
            staged.write('\n')
        staged_path.replace(destination)
    finally:
        if staged_path is not None:
            staged_path.unlink(missing_ok=True)
    return destination


def find(directory, url):
    target = pr_key(url)
    matches = []
    for path in sorted(directory.glob('*.json')):
        _, urls = read_record(path)
        if target in urls:
            matches.append(str(path))
    return matches


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--repo', type=Path, default=PROJECT, help='BeeCount skill source checkout')
    commands = parser.add_subparsers(dest='command', required=True)
    commands.add_parser('save').add_argument('record', type=Path)
    commands.add_parser('find').add_argument('pr_url')
    args = parser.parse_args()
    try:
        directory = registry(args.repo)
        if args.command == 'save':
            print(save(directory, args.record))
        else:
            print(json.dumps(find(directory, args.pr_url), ensure_ascii=False))
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        parser.error(str(error))


if __name__ == '__main__':
    main()
