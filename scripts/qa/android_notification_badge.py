#!/usr/bin/env python3
"""App-only Android badge acceptance on a new private AVD; never uses Cloud."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import socket
import subprocess
import tempfile
import time

import isolated_app_cloud as qa

APP_ID = 'com.tntlikely.beecount.qa.dev.debug'
TEST_ID = APP_ID + '.test'
SDK = Path.home() / 'Library/Android/sdk'
ADB = SDK / 'platform-tools/adb'
EMULATOR = SDK / 'emulator/emulator'
JAVA = Path('/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home')


def load(path):
    root = Path(path)
    if root.is_symlink():
        raise ValueError('Refusing linked QA root')
    root = root.resolve()
    m = json.loads((root / 'manifest.json').read_text())
    if m['root'] != str(root) or (root / '.qa-owner').read_text() != m['run_id'] or m['android_app_id'] != APP_ID:
        raise ValueError('Android QA ownership or application identity mismatch')
    for name in ('app-source', 'device.avd', 'avd-registry', 'evidence', 'raw-logs', 'private-backups', 'android-user'):
        qa.inside(root, root / name)
    return root, m


def device(m):
    if m['serial'] in m['protected_serials'] or not re.fullmatch(r'emulator-\d+', m['serial']):
        raise ValueError('Refusing an existing or physical device')
    name = qa.command([ADB, '-s', m['serial'], 'emu', 'avd', 'name']).splitlines()[0]
    if name != m['avd_name']:
        raise ValueError('Android AVD identity no longer matches')


def adb(m, *args, **kwargs):
    device(m)
    kwargs.setdefault('check', True)
    return subprocess.run([str(ADB), '-s', m['serial'], *args], **kwargs)


def environment(root):
    return dict(os.environ, JAVA_HOME=str(JAVA), ANDROID_SDK_ROOT=str(SDK),
                ANDROID_USER_HOME=str(root / 'android-user'),
                ANDROID_EMULATOR_HOME=str(root / 'android-user'),
                ANDROID_AVD_HOME=str(root / 'avd-registry'))


def prepare(args):
    root = Path(tempfile.mkdtemp(prefix='beecount-android-qa-')).resolve()
    root.chmod(0o700)
    for name in ('evidence', 'raw-logs', 'private-backups', 'android-user', 'avd-registry'):
        (root / name).mkdir(mode=0o700)
    (root / '.qa-owner').write_text(root.name)
    _, identity = qa.read_skill_identity(argparse.Namespace(skill_dir=None, skill_repo=None))
    m = dict(root=str(root), run_id=root.name, mode='app-only', app_id=qa.APP_ID,
             android_app_id=APP_ID, avd_name='BeeCount-QA-' + root.name,
             protected_serials=[line.split()[0] for line in qa.command([ADB, 'devices']).splitlines()[1:] if line.strip()],
             protected_avds=qa.command([EMULATOR, '-list-avds']).splitlines(),
             cloud='not-applicable', pull_requests=['https://github.com/TNT-Likely/BeeCount/pull/569'], **identity)
    for port in range(5554, 5586, 2):
        try:
            with socket.socket() as a, socket.socket() as b:
                a.bind(('127.0.0.1', port)); b.bind(('127.0.0.1', port + 1))
            if f'emulator-{port}' not in m['protected_serials']:
                break
        except OSError:
            continue
    else:
        raise ValueError('No free owned emulator port')
    m.update(serial=f'emulator-{port}', port=port)
    qa.write_json(root / 'manifest.json', m)
    source = qa.snapshot(root, m)
    build = source / 'android/app/build.gradle'
    build.write_text(build.read_text().replace('applicationId = "com.tntlikely.beecount"',
        'applicationId = "com.tntlikely.beecount.qa"').replace('"@string/app_name_test"', '"BeeCount QA"'))
    env = environment(root)
    avd_env = dict(env, JAVA_HOME='/Applications/Android Studio.app/Contents/jbr/Contents/Home')
    with (root / 'raw-logs/avd-create.log').open('w') as log:
        subprocess.run([str(SDK / 'cmdline-tools/22.0/bin/avdmanager'), 'create', 'avd',
                        '-n', m['avd_name'], '-p', str(root / 'device.avd'), '-d', 'pixel_10',
                        '-k', 'system-images;android-37.2;google_apis_playstore_ps16k;arm64-v8a'],
                       input='no\n', text=True, env=avd_env, stdout=log, stderr=log, check=True)
    with (root / 'raw-logs/emulator.log').open('w') as log:
        proc = subprocess.Popen([str(EMULATOR), '-avd', m['avd_name'], '-port', str(port),
                                 '-no-snapshot', '-no-boot-anim', '-no-audio'], env=env,
                                stdout=log, stderr=log, start_new_session=True)
    m.update(emulator_pid=proc.pid, emulator_process_start=qa.command(['ps', '-p', str(proc.pid), '-o', 'lstart=']))
    qa.write_json(root / 'manifest.json', m)
    print(root, flush=True)
    print(f'New owned Android device: {m["serial"]}; Cloud: not applicable', flush=True)


def build(root, m, flutter):
    source = root / 'app-source'
    env = environment(root)
    for name, command, cwd in [
        ('pub', [flutter, 'pub', 'get'], source),
        ('apk', [flutter, 'build', 'apk', '--debug', '--flavor', 'dev', '--target-platform', 'android-arm64'], source),
        ('native-tests', ['./gradlew', ':app:assembleDevDebugAndroidTest'], source / 'android')]:
        print('Android QA build: ' + name, flush=True)
        with (root / f'raw-logs/{name}.log').open('w') as log:
            subprocess.run(command, cwd=cwd, env=env, stdout=log, stderr=log, check=True)
    verify(root, m)


def verify(root, m):
    apk = root / 'app-source/build/app/outputs/flutter-apk/app-dev-debug.apk'
    test = root / 'app-source/build/app/outputs/apk/androidTest/dev/debug/app-dev-debug-androidTest.apk'
    certificates = []
    for artifact, expected in ((apk, APP_ID), (test, TEST_ID)):
        data = qa.command([SDK / 'build-tools/36.0.0/aapt', 'dump', 'badging', artifact])
        if not re.search(r"package: name='" + re.escape(expected) + "'", data):
            raise ValueError('Unsafe Android artifact application ID')
        tree = qa.command([SDK / 'build-tools/36.0.0/aapt', 'dump', 'xmltree', artifact, 'AndroidManifest.xml'])
        if 'android:sharedUserId' in tree:
            raise ValueError('QA APK must not share a production user ID')
        if artifact == test:
            if not re.search(r'android:targetPackage[^\n]*"' + re.escape(APP_ID) + '"', tree):
                raise ValueError('Unsafe instrumentation target package')
        elif not re.search(r'android:authorities[^\n]*"' + re.escape(APP_ID + '.fileprovider') + '"', tree):
            raise ValueError('QA FileProvider authority must use its independent application ID')
        signature = qa.command([SDK / 'build-tools/36.0.0/apksigner', 'verify', '--print-certs', artifact], env=environment(root))
        certificates.append(re.search(r'certificate SHA-256 digest: (\w+)', signature).group(1))
        m['test_apk_sha256' if artifact == test else 'apk_sha256'] = hashlib.sha256(artifact.read_bytes()).hexdigest()
    if len(set(certificates)) != 1:
        raise ValueError('QA App and instrumentation APK signatures must match before installation')
    m['signer_sha256'] = certificates[0]
    qa.write_json(root / 'manifest.json', m)
    return apk, test


def backup(root, m):
    device(m)
    packages = qa.command([ADB, '-s', m['serial'], 'shell', 'pm', 'list', 'packages', APP_ID])
    present = ('package:' + APP_ID) in packages.splitlines()
    if present:
        adb(m, 'shell', 'am', 'force-stop', APP_ID)
        with (root / 'private-backups' / f'app-{time.time_ns()}.tar').open('wb') as file:
            adb(m, 'exec-out', 'run-as', APP_ID, 'tar', '-cf', '-', '.', stdout=file)
    m['previous_app_backed_up' if present else 'first_install_absence_confirmed'] = True
    qa.write_json(root / 'manifest.json', m)


def run(root, m):
    if m.get('review_pending'):
        raise ValueError('Human review data must not be overwritten by rerunning fixtures')
    device(m)
    attempt = str(time.time_ns())
    apk, test = verify(root, m)
    adb(m, 'shell', 'settings', 'put', 'global', 'device_provisioned', '1')
    adb(m, 'shell', 'settings', 'put', 'secure', 'user_setup_complete', '1')
    backup(root, m)
    adb(m, 'install', '-r', str(apk), capture_output=True)
    adb(m, 'install', '-r', str(test), capture_output=True)
    adb(m, 'shell', 'pm', 'grant', APP_ID, 'android.permission.POST_NOTIFICATIONS')
    adb(m, 'shell', 'appops', 'set', APP_ID, 'SCHEDULE_EXACT_ALARM', 'allow')
    adb(m, 'shell', 'run-as', APP_ID, 'rm', '-rf', 'files/badge-qa')
    with (root / f'raw-logs/instrumentation-{attempt}.log').open('w') as log:
        result = adb(m, 'shell', 'am', 'instrument', '-w', '-r', '-e', 'class',
            'com.tntlikely.beecount.NotificationBadgeTest', TEST_ID + '/androidx.test.runner.AndroidJUnitRunner', stdout=log, stderr=log, check=False)
    output = (root / f'raw-logs/instrumentation-{attempt}.log').read_text()
    passed = result.returncode == 0 and 'OK (1 test)' in output and 'FAILURES' not in output
    qa.write_json(root / 'evidence/execution.json', dict(status='PASS' if passed else 'FAIL',
                  instrumentation_exit_code=result.returncode, assertions_passed=passed, cloud='not-applicable'))
    m['instrumentation_passed'] = passed
    m.setdefault('native_runs', []).append(dict(attempt=attempt, status='PASS' if passed else 'FAIL', exit_code=result.returncode))
    qa.write_json(root / 'manifest.json', m)
    device(m)
    exported = adb(m, 'exec-out', 'run-as', APP_ID, 'tar', '-cf', '-', 'files/badge-qa', capture_output=True, check=False)
    import io, tarfile
    attempt_dir = root / 'evidence' / ('attempt-' + attempt)
    attempt_dir.mkdir()
    if exported.returncode == 0:
        with tarfile.open(fileobj=io.BytesIO(exported.stdout)) as archive:
            for entry in archive.getmembers():
                if entry.isfile():
                    data = archive.extractfile(entry).read()
                    (attempt_dir / Path(entry.name).name).write_bytes(data)
                    (root / 'evidence' / Path(entry.name).name).write_bytes(data)
    with (attempt_dir / 'last-screen.png').open('wb') as file:
        adb(m, 'exec-out', 'screencap', '-p', stdout=file)
    if not passed:
        raise RuntimeError('Android badge assertions failed; private evidence retained')
    review(root, m)
    print('Android App-only badge acceptance passed', flush=True)


def review(root, m):
    device(m)
    apk, _ = verify(root, m)
    installed = qa.command([ADB, '-s', m['serial'], 'shell', 'pm', 'path', APP_ID]).split(':', 1)[1].strip()
    with (root / 'installed.apk').open('wb') as file:
        adb(m, 'exec-out', 'cat', installed, stdout=file)
    if hashlib.sha256((root / 'installed.apk').read_bytes()).hexdigest() != m['apk_sha256']:
        raise ValueError('Installed App is not the verified normal-entry binary')
    adb(m, 'shell', 'am', 'start', '-W', '-n', APP_ID + '/com.tntlikely.beecount.MainActivity', capture_output=True)
    time.sleep(3)
    with (root / 'evidence/android-normal-entry.png').open('wb') as file:
        adb(m, 'exec-out', 'screencap', '-p', stdout=file)
    m['normal_entry_running'] = bool(qa.command([ADB, '-s', m['serial'], 'shell', 'pidof', APP_ID]))
    m['review_pending'] = True
    qa.write_json(root / 'manifest.json', m)
    print(f'Normal Android QA App remains available on {m["serial"]}', flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=('prepare', 'build', 'run', 'review'))
    parser.add_argument('--run')
    parser.add_argument('--flutter', default=shutil.which('flutter'))
    args = parser.parse_args()
    if args.action == 'prepare':
        prepare(args)
    else:
        if not args.run: parser.error('--run is required')
        root, manifest = load(args.run)
        if args.action == 'build': build(root, manifest, args.flutter)
        elif args.action == 'run': run(root, manifest)
        else: review(root, manifest)
