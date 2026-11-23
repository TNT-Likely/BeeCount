#!/usr/bin/env python3
"""Local handoff for BeeCount design, QA, PR delivery and cleanup."""
import argparse
from contextlib import contextmanager
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
from zipfile import BadZipFile, ZipFile

PROJECT = Path(__file__).resolve().parents[2]
RECORD_ID = re.compile(r'[A-Za-z0-9][A-Za-z0-9_.-]{0,95}')
REPO = re.compile(r'[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+')
PR_URL = re.compile(r'https://github\.com/([A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+)/pull/([1-9][0-9]*)')


def registry(repo):
    common_dir = subprocess.check_output(
        ['git', '-C', str(repo), 'rev-parse', '--path-format=absolute', '--git-common-dir'],
        text=True,
    ).strip()
    return Path(common_dir) / 'beecount-qa' / 'pr-runs'


def checked_id(value):
    if not isinstance(value, str) or not RECORD_ID.fullmatch(value):
        raise ValueError('Expected a stable QA round or run ID')
    return value


def pr_key(url):
    if not isinstance(url, str) or not PR_URL.fullmatch(url):
        raise ValueError('Expected a canonical GitHub pull request URL')
    return url.lower()


def read_record(path):
    record = json.loads(path.read_text(encoding='utf-8'))
    if not isinstance(record, dict):
        raise ValueError('Expected a QA handoff record object')
    checked_id(record.get('id'))
    urls = record.get('pr_urls')
    if not isinstance(urls, list):
        raise ValueError('Expected pr_urls to be a list')
    return record, {pr_key(url) for url in urls}


def write_json(destination, data):
    staged_path = None
    try:
        with tempfile.NamedTemporaryFile(
            mode='w', encoding='utf-8', dir=destination.parent, delete=False,
        ) as staged:
            staged_path = Path(staged.name)
            json.dump(data, staged, ensure_ascii=False, indent=2)
            staged.write('\n')
            staged.flush()
            os.fsync(staged.fileno())
        staged_path.replace(destination)
    finally:
        if staged_path is not None:
            staged_path.unlink(missing_ok=True)


@contextmanager
def file_lock(path, *, wait=True):
    fd = os.open(path, os.O_CREAT | os.O_NOFOLLOW | os.O_RDWR, 0o600)
    try:
        fcntl.flock(fd, fcntl.LOCK_EX | (0 if wait else fcntl.LOCK_NB))
        yield
    finally:
        os.close(fd)


def run_lock(root):
    return file_lock(Path(root) / '.qa-lock', wait=False)


@contextmanager
def edit_round(directory, round_id, *, create=False, persist=True):
    round_id = checked_id(round_id)
    directory.mkdir(mode=0o700, parents=True, exist_ok=True)
    destination = directory / (round_id + '.json')
    with file_lock(directory / (round_id + '.lock')):
        if destination.exists():
            record, _ = read_record(destination)
            if record['id'] != round_id:
                raise ValueError('Round ID differs from its registry file')
        elif create:
            record = {'schema_version': 2, 'id': round_id, 'pr_urls': [], 'runs': []}
        else:
            raise ValueError(f'QA round does not exist: {round_id}')
        yield record
        if persist:
            write_json(destination, record)


def save(directory, source):
    incoming, _ = read_record(source)
    with edit_round(directory, incoming['id'], create=True) as record:
        # Legacy imports can fill absent fields; use scoped commands for updates.
        for key, value in incoming.items():
            current = record.get(key)
            if current is not None and current != value and current not in ({}, []):
                raise ValueError(f'Existing round field differs: {key}')
            record[key] = value
    return directory / (incoming['id'] + '.json')


def find(directory, url):
    target = pr_key(url)
    matches = []
    for path in sorted(directory.glob('*.json')):
        _, urls = read_record(path)
        if target in urls:
            matches.append(str(path))
    return matches


def register_run(directory, round_id, root):
    root = Path(root).absolute()
    if root.is_symlink() or root.resolve() != root or root.stat().st_mode & 0o077:
        raise ValueError('Expected a canonical private run directory')
    manifest_path = root / 'manifest.json'
    marker = root / '.qa-owner'
    if manifest_path.is_symlink() or marker.is_symlink():
        raise ValueError('Expected regular QA identity files')
    manifest = json.loads(manifest_path.read_text())
    run_id = checked_id(manifest['run_id'])
    if manifest['root'] != str(root) or marker.read_text().strip() != run_id:
        raise ValueError('QA owner does not match the registered run')
    item = {'id': run_id, 'root': str(root), 'manifest': str(manifest_path)}
    directory.mkdir(mode=0o700, parents=True, exist_ok=True)
    with file_lock(directory / '.registration.lock'):
        for path in directory.glob('*.json'):
            if path.stem == round_id:
                continue
            other, _ = read_record(path)
            if any(run.get('root') == str(root) for run in other.get('runs', [])):
                raise ValueError('This run is already owned by another round')
        with edit_round(directory, round_id, create=True) as record:
            runs = record.setdefault('runs', [])
            for previous in runs:
                if previous.get('id', previous.get('run_id')) == run_id:
                    if previous.get('root') != item['root']:
                        raise ValueError('Existing run ID belongs to another directory')
                    return
            if record.get('cleanup_receipt'):
                raise ValueError('Start a new QA round after cleanup')
            runs.append(item)


def register_prepared_run(args, root):
    directory = registry(Path(args.registry_repo) if args.registry_repo else PROJECT)
    round_id = args.round or root.name
    register_run(directory, round_id, root)
    print(f'QA round: {round_id}; run: {root}', flush=True)


def add_round_arguments(parser):
    parser.add_argument('--round', help='Reuse this lifecycle round for each QA attempt')
    parser.add_argument('--registry-repo', help='BeeCount checkout holding the shared local registry')


def bind(record, url):
    target = pr_key(url)
    if target not in {pr_key(x) for x in record['pr_urls']}:
        record['pr_urls'].append(url)
    owner_repo = PR_URL.fullmatch(target)[1]
    record['pending_pr_repos'] = [
        repo for repo in record.get('pending_pr_repos', []) if repo.lower() != owner_repo
    ]


def digest(path):
    with Path(path).open('rb') as file:
        return hashlib.file_digest(file, 'sha256').hexdigest()


def check_zip(path):
    with ZipFile(path) as archive:
        if archive.testzip() is not None:
            raise ValueError('Report ZIP integrity check failed')


def record_report(record, html, archive, shas):
    html, archive = html.resolve(), archive.resolve()
    if not html.is_file() or not archive.is_file():
        raise ValueError('Expected the standalone HTML report and ZIP')
    for run in record.get('runs', []):
        root = Path(run['root']).resolve()
        if html.is_relative_to(root) or archive.is_relative_to(root):
            raise ValueError('Keep evidence outside every run directory')
    shas = dict(item.split('=', 1) for item in shas)
    if not shas or any(not REPO.fullmatch(repo) or not re.fullmatch('[0-9a-f]{40}', sha)
                       for repo, sha in shas.items()):
        raise ValueError('Provide at least one tested OWNER/REPO=SHA')
    check_zip(archive)
    report = {'html': str(html), 'zip': str(archive), 'zip_sha256': digest(archive),
              'source_shas': shas}
    history = record.setdefault('reports', [])
    if record.get('report') and record['report'] not in history:
        history.append(record['report'])
    if report not in history:
        history.append(report)
    record['report'] = report


def record_delivery(record, url, phase, name, value):
    target = pr_key(url)
    bound = {pr_key(pr_url) for pr_url in record['pr_urls']}
    if target not in bound or not record.get('report'):
        raise ValueError('Bind the PR and register the checked report first')
    key = record['report']['zip_sha256']
    receipts = record.setdefault('delivery', {})
    delivery = receipts.setdefault(target, {}).setdefault(key, {})
    if phase == 'upload':
        if not name or not value or not value.startswith('https://'):
            raise ValueError('Provide the filename and actual HTTPS attachment URL')
        delivery.setdefault('attachments', {})[name] = value
    elif phase == 'published':
        if not delivery.get('attachments'):
            raise ValueError('Record the uploaded attachment links first')
        delivery['published'] = True
    elif phase == 'verified':
        if not delivery.get('published') or not value or digest(value) != key:
            raise ValueError('Pass the downloaded ZIP after verifying the published PR body')
        check_zip(value)
        delivery['verified'] = True
        delivery.pop('reference_pr', None)
    elif phase == 'reference':
        source = pr_key(value)
        primary = receipts.get(source, {}).get(key, {})
        if (
            source == target or source not in bound
            or not primary.get('verified') or primary.get('reference_pr')
        ):
            raise ValueError('Reference another PR with a verified copy of this report')
        if any(
            entry.get(key, {}).get('reference_pr', '').lower() == target
            for entry in receipts.values()
        ):
            raise ValueError('This report PR is already referenced by another PR')
        delivery['reference_pr'] = value


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--repo', type=Path, default=PROJECT)
    actions = parser.add_subparsers(dest='action', required=True)
    actions.add_parser('save').add_argument('record', type=Path)
    actions.add_parser('find').add_argument('pr_url')
    actions.add_parser('status').add_argument('round')
    start = actions.add_parser('start')
    start.add_argument('round')
    start.add_argument('--expect-pr', action='append', default=[])
    run = actions.add_parser('register-run')
    run.add_argument('round')
    run.add_argument('root', type=Path)
    design = actions.add_parser('design')
    design.add_argument('round')
    design.add_argument('html', type=Path)
    design.add_argument('--baseline', required=True)
    link = actions.add_parser('bind')
    link.add_argument('round')
    link.add_argument('pr_url')
    report = actions.add_parser('report')
    report.add_argument('round')
    report.add_argument('--html', required=True, type=Path)
    report.add_argument('--zip', required=True, type=Path)
    report.add_argument('--tested', required=True, action='append')
    attach = actions.add_parser('delivery')
    attach.add_argument('round')
    attach.add_argument('pr_url')
    attach.add_argument('phase', choices=('upload', 'published', 'verified', 'reference'))
    attach.add_argument('--name')
    attach.add_argument('--value')
    keep = actions.add_parser('keep')
    keep.add_argument('round')
    keep.add_argument('state', choices=('on', 'off'))
    clean = actions.add_parser('cleanup')
    clean.add_argument('target', help='QA round ID or canonical PR URL')
    clean.add_argument('--apply', action='store_true')
    clean.add_argument('--end-review', action='store_true', help='Use only after explicit authorization')
    reconcile = actions.add_parser('reconcile')
    reconcile.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    try:
        directory = registry(args.repo)
        if args.action == 'save':
            print(save(directory, args.record))
        elif args.action == 'find':
            print(json.dumps(find(directory, args.pr_url)))
        elif args.action == 'status':
            record, _ = read_record(directory / (checked_id(args.round) + '.json'))
            print(json.dumps(record, ensure_ascii=False, indent=2))
        elif args.action == 'register-run':
            register_run(directory, args.round, args.root)
        elif args.action in ('cleanup', 'reconcile'):
            from qa_cleanup import cleanup
            if args.action == 'cleanup':
                if not cleanup(directory, args.target, apply=args.apply, end_review=args.end_review):
                    parser.exit(1)
            else:
                for path in sorted(directory.glob('*.json')):
                    record, _ = read_record(path)
                    if record.get('runs') and record['pr_urls'] and not record.get('cleanup_receipt'):
                        cleanup(directory, record['id'], apply=args.apply)
        else:
            with edit_round(directory, args.round, create=args.action == 'start') as record:
                if args.action == 'start':
                    if any(not REPO.fullmatch(repo) for repo in args.expect_pr):
                        raise ValueError('Expected OWNER/REPO')
                    bound = {PR_URL.fullmatch(pr_key(url))[1] for url in record['pr_urls']}
                    pending = set(record.get('pending_pr_repos', []))
                    pending.update(repo.lower() for repo in args.expect_pr if repo.lower() not in bound)
                    record['pending_pr_repos'] = sorted(pending)
                elif args.action == 'design':
                    html = args.html.resolve()
                    if not html.is_file() or not re.fullmatch('[0-9a-f]{40}', args.baseline):
                        raise ValueError('Expected the HTML file and a full base commit SHA')
                    record['design'] = {'html': str(html), 'sha256': digest(html), 'base_sha': args.baseline}
                elif args.action == 'bind':
                    bind(record, args.pr_url)
                elif args.action == 'report':
                    record_report(record, args.html, args.zip, args.tested)
                elif args.action == 'delivery':
                    record_delivery(record, args.pr_url, args.phase, args.name, args.value)
                elif args.action == 'keep':
                    record['keep_after_merge'] = args.state == 'on'
    except (BadZipFile, OSError, KeyError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
        parser.exit(1, f'QA lifecycle: {error}\n')


if __name__ == '__main__':
    main()
