"""Reclaim only local resources registered and proved to belong to a QA round."""
import json
import os
from pathlib import Path
import plistlib
import shutil
import signal
import subprocess
import time
from zipfile import BadZipFile

from pr_lifecycle import checked_id, check_zip, digest, edit_round, find, PR_URL, run_lock, write_json

QA_APP_IDS = {
    'com.tntlikely.beecount.qa',
    'com.tntlikely.beecount.officialqa',
    'com.tntlikely.beecount.officialreleaseqa',
    'com.tntlikely.beecount.skinpreview',
}
ADB = Path.home() / 'Library/Android/sdk/platform-tools/adb'


def command(*args):
    return subprocess.check_output(args, text=True, timeout=30).strip()


def confirm_merges(record):
    if record.get('pending_pr_repos') or not record['pr_urls']:
        raise ValueError('Waiting for PR association')
    merge_commits = {}
    for url in record['pr_urls']:
        result = json.loads(command('gh', 'pr', 'view', url, '--json', 'state,mergeCommit'))
        if result['state'] != 'MERGED' or not result.get('mergeCommit', {}).get('oid'):
            raise ValueError(f'Waiting for merge: {url}')
        merge_commits[url] = result['mergeCommit']['oid']
    return merge_commits


def verify_reports(record):
    reports = record.get('reports') or ([record['report']] if record.get('report') else [])
    for report in reports:
        html = Path(report['html']).resolve()
        archive = Path(report['zip']).resolve()
        for item in record.get('runs', []):
            run = Path(item['root']).resolve()
            if html.is_relative_to(run) or archive.is_relative_to(run):
                raise ValueError('Report is inside an owned run')
        if not html.is_file() or digest(archive) != report['zip_sha256']:
            raise ValueError('The independent report or its recorded ZIP has changed')
        check_zip(archive)


def load_identity(item):
    root = Path(item['root'])
    manifest = root / 'manifest.json'
    marker = root / '.qa-owner'
    if (root.resolve() != root or not root.is_dir() or root.stat().st_uid != os.getuid() or
            root.stat().st_mode & 0o077 or manifest.is_symlink() or marker.is_symlink() or
            str(manifest) != item['manifest']):
        raise ValueError('Run ownership or canonical paths differ')
    identity = json.loads(manifest.read_text())
    run_id = item.get('id', item.get('run_id'))
    if (marker.read_text().strip() != run_id or identity['run_id'] != run_id or
            identity['root'] != str(root) or identity['app_id'] not in QA_APP_IDS):
        raise ValueError('Run ownership marker or QA app identity differs')
    return root, identity


def wait_until(predicate, label):
    for _ in range(40):
        if predicate():
            return
        time.sleep(0.25)
    raise RuntimeError(f'{label} is still present')


def process_start(pid):
    probe = subprocess.run(['ps', '-p', str(pid), '-o', 'lstart='],
                           text=True, capture_output=True, timeout=10)
    return probe.stdout.strip() if probe.returncode == 0 else None


def process_paths(pid, *, cwd_only=False):
    args = ['lsof', '-nP', '-a', '-p', str(pid), '-Fn']
    if cwd_only:
        args += ['-d', 'cwd']
    probe = subprocess.run(args, text=True, capture_output=True, timeout=10)
    return {line[1:] for line in probe.stdout.splitlines() if line.startswith('n/')}


def stop_cloud(root, identity, apply):
    pid = identity.get('cloud_pid')
    start = process_start(pid) if pid else None
    if not start:
        return
    if (start != identity.get('cloud_process_start') or
            'uvicorn qa_server:app' not in command('ps', '-p', str(pid), '-o', 'args=') or
            str(root / 'cloud-runtime') not in process_paths(pid, cwd_only=True)):
        raise ValueError('Cloud PID, command or working directory differs')
    if apply:
        os.kill(pid, signal.SIGTERM)
        wait_until(lambda: process_start(pid) != start, 'Owned Cloud service')


def ios_devices():
    groups = json.loads(command('xcrun', 'simctl', 'list', 'devices', '-j'))['devices']
    return [(runtime, device) for runtime, group in groups.items() for device in group]


def cleanup_ios(identity, apply):
    udid = identity.get('udid')
    if not udid:
        if identity.get('device_name') and any(
                device['name'] == identity['device_name'] and runtime == identity.get('runtime')
                for runtime, device in ios_devices()):
            raise ValueError('Device allocation needs an exact UDID before cleanup')
        return
    if udid in identity['protected_udids'] or identity.get('reused_existing_qa_device'):
        raise ValueError('The simulator is protected or belongs to another run')
    devices = [(runtime, device) for runtime, device in ios_devices() if device['udid'] == udid]
    if not devices:
        if (Path.home() / 'Library/Developer/CoreSimulator/Devices' / udid).exists():
            raise ValueError('Simulator data still exists outside the device inventory')
        return
    runtime, device = devices[0]
    if (len(devices) != 1 or runtime != identity['runtime'] or
            device['name'] != identity['device_name']):
        raise ValueError('Simulator name or runtime changed')
    storage = Path(device['dataPath']).parent if device.get('dataPath') else (
        Path.home() / 'Library/Developer/CoreSimulator/Devices' / udid)
    for info in (storage / 'data/Containers/Bundle/Application').glob('*/*.app/Info.plist'):
        app_id = plistlib.loads(info.read_bytes()).get('CFBundleIdentifier', '')
        if not any(app_id == allowed or app_id.startswith(allowed + '.') for allowed in QA_APP_IDS):
            raise ValueError('Simulator contains an application outside the verified BeeCount QA IDs')
    if apply:
        if device['state'] != 'Shutdown':
            command('xcrun', 'simctl', 'shutdown', udid)
        command('xcrun', 'simctl', 'delete', udid)
        wait_until(lambda: not storage.exists() and
                   all(current['udid'] != udid for _, current in ios_devices()),
                   'Owned simulator')


def current_android_serials():
    return {line.split()[0] for line in command(ADB, 'devices').splitlines()[1:] if line.strip()}


def cleanup_android(root, identity, apply):
    if 'serial' not in identity and not (root / 'device.avd').exists():
        return
    serial, avd = identity['serial'], identity['avd_name']
    if (not serial.startswith('emulator-') or serial in identity['protected_serials'] or
            avd in identity['protected_avds'] or
            identity['android_app_id'] != 'com.tntlikely.beecount.qa.dev.debug'):
        raise ValueError('Expected a disposable Android QA AVD')
    pid = identity.get('emulator_pid')
    start = process_start(pid) if pid else None
    actual = None
    if serial in current_android_serials():
        actual = command(ADB, '-s', serial, 'emu', 'avd', 'name').splitlines()[0]
    if actual == avd or start:
        own_avd = str(root / 'device.avd') + '/'
        if (actual != avd or not start or start != identity.get('emulator_process_start') or
                not any(path.startswith(own_avd) for path in process_paths(pid))):
            raise ValueError('Android emulator identity or AVD location differs')
        if apply:
            command(ADB, '-s', serial, 'emu', 'kill')
            wait_until(lambda: process_start(pid) != start, 'Owned Android emulator')


def process_run(item, apply):
    root, identity = load_identity(item)
    with run_lock(root):
        root, identity = load_identity(item)
        # Check identities before stopping any resource.
        stop_cloud(root, identity, False)
        device = cleanup_android if identity.get('android_app_id') else None
        if device:
            device(root, identity, False)
        else:
            cleanup_ios(identity, False)
        if apply:
            stop_cloud(root, identity, True)
            if device:
                device(root, identity, True)
            else:
                cleanup_ios(identity, True)
            shutil.rmtree(root)
            if root.exists():
                raise RuntimeError('Run directory is still present')
    return {'run_id': identity['run_id'], 'root': str(root),
            'udid': identity.get('udid'), 'serial': identity.get('serial'),
            'cloud_pid': identity.get('cloud_pid'),
            'emulator_pid': identity.get('emulator_pid'),
            'state': 'removed' if apply else 'ready'}



def verify_disappeared(intent):
    udid = intent.get('udid')
    if udid and (any(device['udid'] == udid for _, device in ios_devices()) or
                 (Path.home() / 'Library/Developer/CoreSimulator/Devices' / udid).exists()):
        raise ValueError('Simulator is still present after interrupted cleanup')
    for pid in (intent.get('cloud_pid'), intent.get('emulator_pid')):
        if pid and process_start(pid):
            raise ValueError('A recorded process still needs ownership verification')
    return dict(intent, state='removed')

def cleanup_round(directory, round_id, apply, end_review):
    with edit_round(directory, round_id, persist=apply) as record:
        if record.get('cleanup_receipt'):
            return {'round': round_id, 'state': 'already cleaned'}
        if record.get('keep_after_merge') and not end_review:
            return {'round': round_id, 'state': 'retained by request'}
        merges = {} if end_review else confirm_merges(record)
        verify_reports(record)
        outcomes = []
        completed = record.setdefault('removed_runs', {})
        intents = record.setdefault('cleanup_intent', {})
        registry_file = directory / (round_id + '.json')
        for item in record.get('runs', []):
            path = item['root']
            try:
                if path in completed and not Path(path).exists():
                    outcomes.append(completed[path])
                    continue
                if path in intents and not Path(path).exists():
                    result = verify_disappeared(intents[path])
                else:
                    result = process_run(item, False)
                    if apply:
                        intents[path] = result
                        write_json(registry_file, record)
                        result = process_run(item, True)
                if apply:
                    completed[path] = result
                    write_json(registry_file, record)
                outcomes.append(result)
            except (BadZipFile, OSError, KeyError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
                outcomes.append({'root': path, 'state': 'pending', 'reason': str(error)})
        pending = any(result['state'] == 'pending' for result in outcomes)
        state = 'pending' if pending else 'removed' if apply else 'ready'
        receipt = {'round': round_id, 'state': state, 'merge_commits': merges,
                   'ended_review': end_review, 'runs': outcomes}
        if apply:
            # Keep receipts alongside the durable registry, outside every run.
            record['removed_runs'] = completed
            record['last_cleanup'] = receipt
            if not pending:
                record['cleanup_receipt'] = receipt
        return receipt


def cleanup(directory, target, *, apply=False, end_review=False):
    ids = [Path(path).stem for path in find(directory, target)] if PR_URL.fullmatch(target) else [
        checked_id(target)]
    if not ids:
        print('No local QA round is associated with this PR.')
        return True
    success = True
    for round_id in ids:
        try:
            result = cleanup_round(directory, round_id, apply, end_review)
        except (BadZipFile, OSError, KeyError, ValueError, subprocess.SubprocessError) as error:
            result = {'round': round_id, 'state': 'pending', 'reason': str(error)}
        print(json.dumps(result, ensure_ascii=False))
        success = success and result['state'] != 'pending'
    return success
