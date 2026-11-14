"""Immutable public build receipts stored inside the Release body, not assets.

Older published Betas retain their original JSON attachments. New Betas expose
only the installable APK/IPA; gates and deduplicated notification still read the
same independently validated records. No credentials belong in these records.
"""
from __future__ import annotations

import base64
import json
import re

import local_apk as gate

PREFIX = '<!-- beecount-beta-metadata:'
PATTERN = re.compile(r'<!-- beecount-beta-metadata:v1:([A-Za-z0-9_-]+={0,2}) -->')
MAX_BYTES = 128 * 1024


def _unique(pairs):
    result = {}
    for key, value in pairs:
        gate.require(key not in result, 'Beta元数据包含重复字段')
        result[key] = value
    return result


def records(release):
    body = release.get('body') or ''
    gate.require(isinstance(body, str), 'Release正文格式无效')
    matches = list(PATTERN.finditer(body))
    gate.require(body.count(PREFIX) == len(matches) <= 1, 'Beta元数据缺失、损坏或重复')
    if not matches:
        return {}
    payload = matches[0].group(1)
    gate.require(len(payload) <= MAX_BYTES * 2, 'Beta元数据超过上限')
    try:
        raw = base64.b64decode(payload, altchars=b'-_', validate=True)
        gate.require(len(raw) <= MAX_BYTES, 'Beta元数据超过上限')
        data = json.loads(raw, object_pairs_hook=_unique)
    except (ValueError, UnicodeError) as error:
        raise gate.GateError('Beta元数据无法解码') from error
    gate.require(isinstance(data, dict) and type(data.get('schemaVersion')) is int
                 and data['schemaVersion'] == 1 and isinstance(data.get('records'), dict),
                 'Beta元数据版本或记录格式无效')
    for name, record in data['records'].items():
        gate.require(isinstance(name, str) and re.fullmatch(r'[a-z][a-z0-9._-]{0,99}\.json', name)
                     and isinstance(record, dict), 'Beta元数据记录名称或类型无效')
    return data['records']


def names(release):
    embedded = records(release)
    legacy = [a['name'] for a in release.get('assets', []) if a.get('name', '').endswith('.json')]
    gate.require(len(legacy) == len(set(legacy)) and not set(legacy).intersection(embedded),
                 'Beta回执存在重复来源')
    return set(legacy) | embedded.keys()


def has(release, name):
    return name in names(release)


def read(client, release, name):
    gate.require(name in names(release), '缺少可核验的Beta回执：' + name)
    embedded = records(release)
    if name in embedded:
        return embedded[name]
    asset = next(a for a in release['assets'] if a.get('name') == name)
    return client.receipt(asset)


def with_records(body, additions):
    existing = records({'body': body})
    merged = dict(existing)
    for name, record in additions.items():
        gate.require(name not in merged or merged[name] == record, '禁止覆盖已有Beta回执')
        merged[name] = record
    payload = json.dumps(dict(schemaVersion=1, records=merged), ensure_ascii=False,
                         sort_keys=True, separators=(',', ':')).encode()
    gate.require(len(payload) <= MAX_BYTES, 'Beta元数据超过上限')
    encoded = base64.urlsafe_b64encode(payload).decode()
    result = PATTERN.sub('', body or '').rstrip() + '\n\n' + PREFIX + 'v1:' + encoded + ' -->\n'
    records({'body': result})  # Reject bad names/types before any remote mutation.
    return result


def save(client, release, name, record):
    """Read the latest notes, preserve all records, then persist an immutable one.

    The workflow's shared concurrency lock serializes release/notification jobs.
    A fresh read also preserves human edits to the user-visible notes.
    """
    ident = release['id']
    # Preserve legacy immutable assets; never migrate an already published Beta.
    if has(release, name):
        gate.require(read(client, release, name) == record, '禁止替换已有Beta回执')
        return
    fresh = client.request('GET', f'/repos/{client_repository()}/releases/{int(ident)}')
    gate.require(isinstance(fresh, dict) and fresh.get('id') == ident, '无法核对最新Release身份')
    for key, value in records(release).items():
        gate.require(records(fresh).get(key) == value, '已有Beta回执在通知前改变')
    if has(fresh, name):
        gate.require(read(client, fresh, name) == record, '禁止替换已有Beta回执')
        release.update(fresh)
        return
    body = with_records(fresh.get('body', ''), {name: record})
    saved = client.request('PATCH', f'/repos/{client_repository()}/releases/{int(ident)}', {'body': body})
    gate.require(isinstance(saved, dict) and saved.get('id') == ident
                 and records(saved).get(name) == record, 'Beta回执写入未获确认')
    release.update(saved)


def client_repository():
    # Avoid an import cycle with beta_release, which reads legacy receipts too.
    return 'TNT-Likely/BeeCount'
