"""Allocate and deliver the signed official Android App Bundle to Google Play."""

import argparse
import json
import os
import sys

from google.oauth2.service_account import Credentials
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError
from googleapiclient.http import MediaFileUpload


PACKAGE = 'com.tntlikely.beecount'
TRACK = 'production'


def highest_code(service, edit):
    numbers = set()
    for track in service.edits().tracks().list(packageName=PACKAGE, editId=edit).execute().get('tracks', []):
        for release in track.get('releases', []):
            numbers.update(int(code) for code in release.get('versionCodes', []))
    for bundle in service.edits().bundles().list(packageName=PACKAGE, editId=edit).execute().get('bundles', []):
        numbers.add(int(bundle['versionCode']))
    return max(numbers, default=0)


def release_notes(raw):
    if not raw:
        return []
    values = json.loads(raw)
    if not isinstance(values, dict) or any(
        locale not in {'en-US', 'zh-CN', 'zh-HK'} or not isinstance(note, str)
        or not note.strip() or len(note) > 500 for locale, note in values.items()
    ):
        raise ValueError('Google Play 文案需要受支持的语言标签和每项 1–500 字符')
    return [{'language': locale, 'text': note} for locale, note in values.items()]


def application():
    key = json.loads(os.environ['GOOGLE_PLAY_SERVICE_ACCOUNT_JSON'])
    credentials = Credentials.from_service_account_info(
        key, scopes=['https://www.googleapis.com/auth/androidpublisher']
    )
    return build('androidpublisher', 'v3', credentials=credentials, cache_discovery=False)


def process(service, args):
    edits = service.edits()
    edit = edits.insert(body={}, packageName=PACKAGE).execute()['id']
    committed = False
    try:
        current = highest_code(service, edit)
        if args.action == 'floor':
            print(current)
            return
        if args.code <= current:
            raise ValueError(f'Android 候选 {args.code} 未超过 Google Play 当前最高 {current}')
        localized = release_notes(os.environ.get('PLAY_RELEASE_NOTES', ''))
        uploaded = edits.bundles().upload(
            packageName=PACKAGE, editId=edit,
            media_body=MediaFileUpload(args.bundle, mimetype='application/octet-stream', resumable=True)
        ).execute()
        if int(uploaded['versionCode']) != args.code:
            raise ValueError('Google Play 收到的 AAB versionCode 不符')
        release = {'name': args.version, 'versionCodes': [str(args.code)], 'status': 'completed'}
        if localized:
            release['releaseNotes'] = localized
        track = edits.tracks().update(
            packageName=PACKAGE, editId=edit, track=TRACK, body={'releases': [release]}
        ).execute()
        if track['track'] != TRACK or not any(
            str(args.code) in [str(value) for value in row['versionCodes']]
            for row in track.get('releases', [])
        ):
            raise ValueError('Google Play production 编辑回读与候选不符')
        edits.commit(packageName=PACKAGE, editId=edit).execute()
        committed = True
        print(f'Google Play production 已提交 {args.version} (versionCode {args.code})')
    finally:
        if not committed:
            try:
                edits.delete(packageName=PACKAGE, editId=edit).execute()
            except HttpError:
                print('Google Play 临时编辑将自行过期', file=sys.stderr)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    action = parser.add_subparsers(dest='action', required=True)
    action.add_parser('floor')
    publish = action.add_parser('publish')
    publish.add_argument('bundle')
    publish.add_argument('version')
    publish.add_argument('code', type=int)
    args = parser.parse_args()
    try:
        process(application(), args)
    except HttpError as error:
        print(f'Google Play API HTTP {error.status_code}: {error.reason}', file=sys.stderr)
        return 1
    except (OSError, KeyError, ValueError) as error:
        print(f'Google Play 发布检查失败: {error}', file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
