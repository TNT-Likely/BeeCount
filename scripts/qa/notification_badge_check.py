#!/usr/bin/env python3
"""Exercise iOS badge behavior on an existing, verified normal-entry QA App."""
import argparse
import hashlib
from http.server import BaseHTTPRequestHandler, HTTPServer
import json
from pathlib import Path
import secrets
import subprocess
import threading
import time

import isolated_app_cloud as qa


def check(root, manifest):
    qa.device(manifest)
    qa.cloud_identity(manifest)
    installed = Path(qa.command(['xcrun', 'simctl', 'get_app_container', manifest['udid'], qa.APP_ID, 'app']))
    if hashlib.sha256((installed / 'Runner').read_bytes()).hexdigest() != manifest.get('normal_artifact_hash'):
        raise ValueError('Badge checks require the verified normal-entry QA artifact')
    attempt = str(time.time_ns())
    native = qa.inside(root, root / ('native-notification-badge-' + attempt))
    native.mkdir()  # Never overwrite prior evidence or repeat fixtures silently.
    cases = []
    token = '/' + secrets.token_urlsafe(24)
    pushes = {'warm': 7, 'cold': 9, 'foreground': 5, 'tap': 3}
    expected = ('warm-resume', 'cold-launch', 'foreground-banner-no-badge', 'notification-tap', 'repeated-activation')

    class Control(BaseHTTPRequestHandler):
        def log_message(self, *_):
            pass

        def do_GET(self):
            if not self.path.startswith(token + '/'):
                self.send_error(403)
                return
            try:
                qa.device(manifest)  # Recheck protection before every device command.
                action, name = self.path[len(token) + 1:].split('/')
                if action == 'push' and name in pushes:
                    payload = {'aps': {'alert': {'title': f'QA badge {name}', 'body': f'Synthetic notification for issue 557: {attempt}'},
                                       'badge': pushes[name], 'sound': 'default'}}
                    subprocess.run(['xcrun', 'simctl', 'push', manifest['udid'], qa.APP_ID, '-'],
                                   input=json.dumps(payload).encode(), capture_output=True, check=True)
                elif action == 'capture' and name.startswith('badge-') and name.replace('-', '').isalnum():
                    subprocess.run(['xcrun', 'simctl', 'io', manifest['udid'], 'screenshot',
                                    str(root / 'evidence' / (name + '.png'))], capture_output=True, check=True)
                elif action == 'pass' and name in expected and name not in [c['id'] for c in cases]:
                    cases.append(dict(id=name, status='PASS'))
                    qa.write_json(root / 'evidence/notification-badge.json', dict(cases=cases, status='RUNNING'))
                else:
                    raise ValueError('Unsupported QA control request')
            except Exception:
                self.send_error(500, 'QA control failed; inspect private test results')
                return
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b'{}')

    server = HTTPServer(('127.0.0.1', 0), Control)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    try:
        source = Path(__file__).with_name('notification_badge_smoke.swift').read_text()
        source = source.replace('__QA_CONTROL_ORIGIN__', f'http://127.0.0.1:{server.server_port}{token}')
        (native / 'QASmoke.swift').write_text(source)
        subprocess.run(['ruby', str(Path(__file__).with_name('create_smoke_project.rb')), str(native)], check=True)
        args = ['xcodebuild', '-project', str(native / 'QASmoke.xcodeproj'), '-scheme', 'QASmoke',
                '-configuration', 'Debug', '-sdk', 'iphonesimulator', '-destination', f'id={manifest["udid"]}',
                '-derivedDataPath', str(native / 'build'), '-parallel-testing-enabled', 'NO', 'CODE_SIGNING_ALLOWED=NO']
        with (root / f'raw-logs/badge-build-{attempt}.log').open('w') as log:
            subprocess.run([args[0], 'build-for-testing', *args[1:]], stdout=log, stderr=log, check=True)
        qa.verify_smoke_bundles(native)
        qa.device(manifest)
        with (root / f'raw-logs/badge-test-{attempt}.log').open('w') as log:
            result = subprocess.run([args[0], 'test-without-building', *args[1:],
                                     '-resultBundlePath', str(native / 'result.xcresult')], stdout=log, stderr=log)
        passed = result.returncode == 0 and [c['id'] for c in cases] == list(expected)
        report = dict(
            status='PASS' if passed else 'FAIL', exit_code=result.returncode, cases=cases,
            injection='simctl synthetic APNs; actual SpringBoard badge, banner and normal App lifecycle',
            normal_artifact_hash=manifest['normal_artifact_hash'],
            harness_source_hash=hashlib.sha256(Path(__file__).read_bytes() +
                Path(__file__).with_name('notification_badge_smoke.swift').read_bytes()).hexdigest())
        qa.write_json(root / f'evidence/notification-badge-{attempt}.json', report)
        qa.write_json(root / 'evidence/notification-badge.json', report)
        manifest['notification_badge_exit_code'] = result.returncode
        qa.write_json(root / 'manifest.json', manifest)
        if not passed:
            raise RuntimeError('Notification badge acceptance failed; private evidence is preserved')
        print('Notification badge acceptance passed: cold launch, resume, foreground banner, tap and repeated activation')
    finally:
        server.shutdown()
        server.server_close()
        thread.join(timeout=5)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--run', required=True)
    args = parser.parse_args()
    check(*qa.load_run(args.run))
