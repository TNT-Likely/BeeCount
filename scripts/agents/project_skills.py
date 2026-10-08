#!/usr/bin/env python3
"""安装 BeeCount 项目 skill；只建立项目引用，显式迁移时备份旧全局安装。"""
from __future__ import annotations

import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess

SKILLS = ('beecount-release', 'isolated-app-cloud-qa')
CLIENT_ROOTS = ('.agents/skills', '.claude/skills')
SOURCE_REPO = Path(__file__).resolve().parents[2]


def git(project: Path, *args: str) -> str:
    return subprocess.check_output(['git', '-C', str(project), *args], text=True).strip()


def project_root(value: Path) -> Path:
    root = value.expanduser().resolve()
    if Path(git(root, 'rev-parse', '--show-toplevel')).resolve() != root:
        raise ValueError('--project must be the repository root')
    remote = git(root, 'remote', 'get-url', 'origin')
    if not re.search(r'[:/]TNT-Likely/BeeCount(?:-Cloud|-Website)?(?:\.git)?/?$', remote, re.I):
        raise ValueError('Project skills are limited to the BeeCount, Cloud and Website repositories')
    return root


def source_skills(source: Path) -> dict[str, Path]:
    source = project_root(source)
    result = {}
    for name in SKILLS:
        directory = source / '.agents/skills' / name
        body = (directory / 'SKILL.md').read_text()
        if f'name: {name}\n' not in body:
            raise ValueError(f'Skill source name does not match: {name}')
        result[name] = directory.resolve()
    return result


def state_file(project: Path) -> Path:
    return Path(git(project, 'rev-parse', '--path-format=absolute', '--git-path',
                    'beecount-project-skills.json'))


def load_state(project: Path) -> dict:
    path = state_file(project)
    return json.loads(path.read_text()) if path.exists() else {'schema_version': 1, 'links': {}}


def save_state(project: Path, value: dict) -> None:
    path = state_file(project)
    temporary = path.with_suffix('.tmp')
    temporary.write_text(json.dumps(value, ensure_ascii=False, indent=2))
    temporary.replace(path)


def bundle_hash(directory: Path) -> str:
    digest = hashlib.sha256()
    for path in sorted(directory.rglob('*')):
        if path.is_file():
            digest.update(str(path.relative_to(directory)).encode() + b'\0' + path.read_bytes())
    return digest.hexdigest()


def plan_links(project: Path, skills: dict[str, Path]) -> list[tuple[Path, str]]:
    state = load_state(project)
    result = []
    for client in CLIENT_ROOTS:
        for name, source in skills.items():
            destination = project / client / name
            if not destination.parent.resolve().is_relative_to(project):
                raise ValueError(f'Client directory escapes this project: {client}')
            if destination.exists() and destination.resolve() == source:
                continue  # 原生源码或已存在的正确链接，不改写。
            previous = state['links'].get(str(destination.relative_to(project)))
            if destination.is_symlink():
                if previous != os.readlink(destination):
                    raise ValueError(f'Existing symlink is not owned by this installer: {destination}')
            elif destination.exists():
                raise ValueError(f'Refusing to replace an existing skill directory: {destination}')
            result.append((destination, os.path.relpath(source, destination.parent)))
    return result


def install(project: Path, source: Path, dry_run: bool) -> None:
    skills = source_skills(source)
    plan = plan_links(project, skills)  # 所有冲突先核对，再修改任何路径。
    state = load_state(project)
    for destination, target in plan:
        print(f'{destination.relative_to(project)} -> {target}')
    if dry_run:
        return
    for destination, target in plan:
        destination.parent.mkdir(parents=True, exist_ok=True)
        if destination.is_symlink():
            destination.unlink()
        destination.symlink_to(target, target_is_directory=True)
        state['links'][str(destination.relative_to(project))] = target
        save_state(project, state)
    state['source_repo'] = str(source.resolve())
    save_state(project, state)
    # 仅排除本机跨仓安装的链接。已有源码/跟踪文件不会被 Git 忽略规则隐藏。
    if state['links']:
        exclude = Path(git(project, 'rev-parse', '--path-format=absolute', '--git-path', 'info/exclude'))
        exclude.parent.mkdir(parents=True, exist_ok=True)
        text = exclude.read_text() if exclude.exists() else ''
        entries = [f'/{relative}' for relative in state['links']]
        missing = [entry for entry in entries if entry not in text.splitlines()]
        if missing:
            exclude.write_text(text.rstrip() + '\n\n# Local BeeCount project skill links\n' +
                               '\n'.join(missing) + '\n')
    status(project, source)


def status(project: Path, source: Path) -> list[dict]:
    skills = source_skills(source)
    entries = []
    for client in CLIENT_ROOTS:
        for name, origin in skills.items():
            path = project / client / name / 'SKILL.md'
            matches = path.is_file() and bundle_hash(path.parent) == bundle_hash(origin)
            entry = {'client_root': client, 'skill': name, 'available': matches,
                     'source': str(origin), 'bundle_sha256': bundle_hash(origin),
                     'kind': 'linked' if path.parent.is_symlink() else 'native'}
            entries.append(entry)
    print(json.dumps(entries, ensure_ascii=False, indent=2))
    if not all(entry['available'] for entry in entries):
        raise ValueError('Project skill entry missing or not matching the selected source')
    return entries


def uninstall(project: Path, dry_run: bool) -> None:
    state = load_state(project)
    for relative, target in state['links'].items():
        path = project / relative
        if not path.parent.resolve().is_relative_to(project):
            raise ValueError('Owned link parent escapes the project')
        if path.is_symlink() and os.readlink(path) == target:
            print(f'Remove owned link: {relative}')
        elif path.exists() or path.is_symlink():
            raise ValueError(f'Owned link has changed; leave it untouched: {relative}')
    if dry_run:
        return
    for relative, target in state['links'].items():
        path = project / relative
        if path.is_symlink() and os.readlink(path) == target:
            path.unlink()
    state['links'] = {}
    save_state(project, state)
    print('Native source and tracked project bridges are preserved.')


def migrate_global(project: Path, source: Path, backup_dir: Path | None, dry_run: bool) -> None:
    status(project, source)  # 项目级入口可读后，才迁走旧全局安装。
    home = Path.home()
    names = (*SKILLS, 'release')
    roots = (home / '.codex/skills', home / '.agents/skills', home / '.claude/skills')
    candidates = []
    for root in roots:
        for name in names:
            path = root / name
            entry = path / 'SKILL.md'
            if not entry.is_file():
                continue
            body = entry.read_text()
            if 'BeeCount' not in body and not (path / 'references/beecount.md').is_file():
                continue  # 不碰其他项目同名 release/qa。
            candidates.append(path)
    stamp = datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
    backup = (backup_dir.expanduser().resolve() if backup_dir else
              home / '.local/share/beecount/project-skill-backups' / stamp)
    if any(backup.is_relative_to(root) for root in roots):
        raise ValueError('Backup must be outside all global skill discovery roots')
    moves = [(path, backup / path.parent.parent.name / path.name) for path in candidates]
    if any(destination.exists() for _, destination in moves):
        raise ValueError('Backup destination already exists')
    for path, destination in moves:
        print(f'Archive global skill: {path} -> {destination}')
    if dry_run or not moves:
        return
    backup.mkdir(parents=True, mode=0o700, exist_ok=True)
    records = []
    for path, destination in moves:
        destination.parent.mkdir(mode=0o700, exist_ok=True)
        digest = hashlib.sha256((path / 'SKILL.md').read_bytes()).hexdigest()
        shutil.move(str(path), destination)
        records.append({'old_path': str(path), 'backup_path': str(destination), 'entry_sha256': digest})
    (backup / 'migration.json').write_text(json.dumps(records, ensure_ascii=False, indent=2))
    print(f'Global skills archived; restore from {backup} if needed. Restart clients to refresh discovery.')


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=('install', 'status', 'uninstall', 'migrate-global'))
    parser.add_argument('--project', type=Path, default=Path.cwd())
    parser.add_argument('--source-repo', type=Path, default=SOURCE_REPO)
    parser.add_argument('--backup-dir', type=Path)
    parser.add_argument('--dry-run', action='store_true')
    args = parser.parse_args()
    try:
        project = project_root(args.project)
        if args.action == 'install':
            install(project, args.source_repo, args.dry_run)
        elif args.action == 'status':
            status(project, args.source_repo)
        elif args.action == 'uninstall':
            uninstall(project, args.dry_run)
        else:
            migrate_global(project, args.source_repo, args.backup_dir, args.dry_run)
    except (ValueError, OSError, subprocess.CalledProcessError) as exc:
        parser.exit(1, f'Project skill operation stopped: {exc}\n')


if __name__ == '__main__':
    main()
