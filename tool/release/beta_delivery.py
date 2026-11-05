"""Join independently verified platform receipts into one curated announcement."""
import argparse
import os
import re

import beta_release as android
import ios_beta_release as ios
import local_apk as gate


def platform_lines(ios_context, result, public_url=''):
    gate.require(result in ('', 'success', 'failure', 'cancelled', 'skipped'), 'iOS作业结果无效')
    if ios_context is None:
        gate.require(result != 'success', 'iOS作业成功但缺少签名产物回执')
        return ['Android：ARM64 APK 已发布。', 'iOS：尚未完成签名构建/上传，请查看本次 Actions。']
    processed = ios_context['status'] == 'testflight-processed'
    lines = [f'Android：ARM64 APK 已发布；iOS：4.0.0 / build {ios_context["buildNumber"]} IPA 已归档。',
             'TestFlight：Apple已处理，测试组/外部审核以 App Store Connect 为准。' if processed
             else 'TestFlight：尚未完成上传/处理；App Store 签名 IPA 不能直接侧载。']
    if processed and public_url:
        gate.require(re.fullmatch(r'https://testflight\.apple\.com/join/[A-Za-z0-9]+', public_url), 'TestFlight邀请链接无效')
        lines.append('TestFlight邀请：' + public_url)
    return lines


def notification_plan():
    android.notification_plan()
    context = android.read_context()
    client = android.GitHub()
    release, record = ios.get_release(client, context['versionName'])
    _, number = ios.ios_version(context['versionName'], record['versionCode'],
                               os.environ.get('IOS_BUILD_NUMBER', ''), '225')
    names = ios.public_names(context['versionName'], number)
    assets = {a['name'] for a in release.get('assets', [])}
    ready = all(n in assets for n in names)
    # A partial published identity is an error, not a successful fallback.
    gate.require(ready or not any(n in assets for n in names), 'iOS公开资产不完整，拒绝公告')
    ios_context = None
    if ready:
        ios.notification_plan()
        ios_context = ios.context_read()
    context['platformLines'] = platform_lines(ios_context,
        os.environ.get('IOS_DELIVERY_RESULT', ''), os.environ.get('TESTFLIGHT_PUBLIC_URL', ''))
    android.telegram_text(context)
    android.save_context(context)
    print('已核对双端公开身份，生成单条短摘要；尚未发送通知')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('action', choices=['notification_plan'])
    parser.parse_args()
    try:
        notification_plan()
    except gate.GateError as error:
        raise SystemExit(str(error)) from None
