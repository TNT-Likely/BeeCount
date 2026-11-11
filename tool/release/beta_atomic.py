#!/usr/bin/env python3
"""Publish only after private Android+iOS verification, then announce once.

No candidate binaries are uploaded as Actions artifacts. A failed build never
creates a tag/Release. A failed asset upload leaves a private draft. Published
assets and tags remain immutable; notification intent/ack prevents rerun spam.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import time

import beta_release as android
import beta_metadata as metadata
import beta_delivery as delivery
import ios_beta_release as ios
import local_apk as gate

INTENT = 'beta-notification-intent.json'
ACK = 'beta-notification.json'


def ios_assets(android_context, context):
    """Recheck all local iOS bytes before the publisher may create any Release."""
    gate.require(android_context.get('status') == 'verified', 'Android尚未通过验包')
    mode = context.get('mode')
    gate.require(mode in ('ipa', 'testflight') and context.get('atomic') is True,
                 'iOS不是本轮私有双端构建上下文')
    expected_status = 'testflight-processed' if mode == 'testflight' else 'verified'
    gate.require(context.get('status') == expected_status, 'iOS构建/Apple处理未完整成功，拒绝创建Release')
    for key in ('sourceSha', 'versionName'):
        gate.require(context.get(key) == android_context.get(key), '双端冻结源码或版本不同')
    gate.require(context.get('androidVersionCode') == android_context.get('versionCode'), '双端Android基准码不同')
    version, number = ios.ios_version(context['versionName'], context['androidVersionCode'],
                                     str(context['buildNumber']), '225')
    gate.require(version == context.get('appVersion'), 'iOS数字版本无效')
    run = Path(context['run']).resolve()
    dist = Path(context['dist'])
    gate.require(run.parent == Path(os.environ['RUNNER_TEMP']).resolve()
                 and run.name.startswith('beecount-ios-beta-run-')
                 and not dist.is_symlink() and dist.resolve() == run/'dist', 'iOS暂存路径不属于本轮')
    names = ios.public_names(context['versionName'], number)
    for name in names:
        gate.require((dist/name).is_file() and not (dist/name).is_symlink(), '缺少签名IPA/校验/回执')
    artifact = context['artifact']
    record = json.loads((dist/names[2]).read_text())
    gate.require(record == context.get('receipt') and record.get('schemaVersion') == 1
                 and record.get('kind') == 'beecount-ios-beta-release'
                 and record.get('sourceSha') == context['sourceSha']
                 and record.get('versionName') == context['versionName']
                 and record.get('androidVersionCode') == context['androidVersionCode']
                 and record.get('appVersion') == version and record.get('buildNumber') == number
                 and record.get('bundleId') == ios.BUNDLE and record.get('widgetBundleId') == ios.WIDGET
                 and record.get('architecture') == 'arm64' and record.get('distribution') == 'app-store'
                 and record.get('dependencyLockUnchanged') is True
                 and re.fullmatch(r'[0-9a-f]{64}', record.get('certificateSha256', '')),
                 'iOS暂存回执不属于已验证的生产双端候选')
    actual = gate.sha256(dist/names[0])
    gate.require(actual == artifact.get('ipaSha256') == record.get('ipaSha256')
                 and (dist/names[0]).stat().st_size == record.get('bytes') == artifact.get('bytes')
                 and 0 < record['bytes'] <= ios.MAX_ASSET, 'IPA字节与签名验包回执不同')
    gate.require((dist/names[1]).read_text() == actual+'  '+names[0]+'\n', 'IPA校验文件改变')
    all_names = list(names)
    if mode == 'testflight':
        tf_name = f'ios-testflight-{number}.json'
        path = dist/tf_name
        gate.require(path.is_file() and not path.is_symlink(), '缺少Apple处理完成回执')
        tf = json.loads(path.read_text())
        gate.require(tf == context.get('testflight') and tf.get('kind') == 'beecount-ios-testflight-upload'
                     and tf.get('sourceSha') == context['sourceSha'] and tf.get('versionName') == context['versionName']
                     and tf.get('ipaSha256') == actual and tf.get('appVersion') == version
                     and tf.get('buildNumber') == number and tf.get('uploadAccepted') is True
                     and tf.get('processingState') == 'VALID' and tf.get('testNotesUpdated') is True,
                     'TestFlight尚未通过真实Apple处理与内测说明更新')
        all_names.append(tf_name)
    return [dict(name=name, path=str(dist/name), sha256=gate.sha256(dist/name),
                 contentType=('application/octet-stream' if name.endswith('.ipa') else
                              'text/plain' if name.endswith('.sha256') else 'application/json'))
            for name in all_names]


def publish():
    gate.require(os.environ.get('BETA_ATOMIC') == '1', '只允许统一双端原子发布入口')
    a, i = android.read_context(), ios.context_read()
    assets = ios_assets(a, i)  # Must happen before publish creates a tag/draft.
    android.publish(additional_assets=assets)
    published = android.read_context()
    gate.require(published.get('status') == 'published', '双端Release尚未公开')
    i.update(releaseId=published['releaseId'], releaseUrl=published['releaseUrl'])
    if i['mode'] == 'ipa':
        i['status'] = 'published'
    ios.context_write(i)
    print('Android与iOS全部成功，双端资产已在同一Release一次公开；尚未通知')


def notification_identity(context, ios_context):
    return dict(versionName=context['versionName'], sourceSha=context['sourceSha'],
                androidVersionCode=context['versionCode'], iosBuildNumber=ios_context['buildNumber'])


def same_notification(record, identity, kind):
    gate.require(isinstance(record, dict) and record.get('schemaVersion') == 1
                 and record.get('kind') == kind
                 and all(record.get(k) == v for k, v in identity.items()), '通知回执身份不匹配，拒绝忽略')


def announce():
    # Fresh notification contexts, without any signing material or builds.
    # The route marker also retires the legacy always()/partial-success sender.
    os.environ['BETA_ATOMIC_NOTIFY'] = '1'
    delivery.notification_plan()
    context = android.read_context()
    gate.require(context.get('status') == 'published', '两端未完整发布，不发送安装通知')
    i = ios.context_read()
    if os.environ.get('BETA_EXPECT_TESTFLIGHT') == '1':
        gate.require(i.get('status') == 'testflight-processed', '选择TestFlight但缺少Apple处理完成回执，拒绝公告')
    identity = notification_identity(context, i)
    client = android.GitHub()
    release, _ = ios.get_release(client, context['versionName'])
    if metadata.has(release, ACK):
        same_notification(metadata.read(client, release, ACK), identity, 'beecount-beta-notification-ack')
        print('此双端Beta通知已确认送达，跳过重复发送')
        return
    if metadata.has(release, INTENT):
        same_notification(metadata.read(client, release, INTENT), identity, 'beecount-beta-notification-intent')
        gate.require(os.environ.get('BETA_NOTIFICATION_MANUAL_RETRY') == '1',
                     '已有未确认通知意图，不自动重发；核对群消息后仅手动notify-only可重试')
    else:
        intent = dict(schemaVersion=1, kind='beecount-beta-notification-intent', **identity,
                      workflowRun=os.environ.get('GITHUB_RUN_ID'), createdAtUnix=int(time.time()))
        # Persist intent before sending; failure cannot trigger Telegram.
        metadata.save(client, release, INTENT, intent)
    message_id = android.notify()
    gate.require(type(message_id) is int and message_id > 0, 'Telegram未返回可核验message_id，保留意图且不自动重发')
    ack = dict(schemaVersion=1, kind='beecount-beta-notification-ack', **identity,
               workflowRun=os.environ.get('GITHUB_RUN_ID'), messageId=message_id,
               acknowledgedAtUnix=int(time.time()))
    metadata.save(client, release, ACK, ack)
    print('双端Beta唯一通知已确认送达并保存幂等回执')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('action', choices=['publish', 'announce'])
    args = parser.parse_args()
    try:
        globals()[args.action]()
    except gate.GateError as error:
        raise SystemExit(str(error)) from None
