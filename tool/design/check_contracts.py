#!/usr/bin/env python3
"""Validate App-owned contracts offline, or explicitly compare a pinned design checkout."""
import argparse
import hashlib
import json
import re
import subprocess
from pathlib import Path

APP = Path(__file__).resolve().parents[2]


def digest(file):
    return hashlib.sha256(file.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--design-root', type=Path, help='BeeCount-Design repository root')
    args = parser.parse_args()
    lock = json.loads((APP / 'tool/design/design.lock.json').read_text())
    assert re.fullmatch(r'[0-9a-f]{40}', lock['commit']), 'Design commit must be a fixed 40-character SHA'
    for relative, expected in lock['appContractHashes'].items():
        file = APP / relative
        assert file.is_file(), f'Missing App contract: {relative}'
        assert digest(file) == expected, f'App contract changed without lock update: {relative}'
    checked = {'status': 'PASS', 'appContractFiles': len(lock['appContractHashes']), 'crossRepository': False}
    if args.design_root:
        root = args.design_root.resolve()
        assert (root / 'card-refresh').is_dir(), 'Expected BeeCount-Design repository root'
        commit = subprocess.check_output(['git', '-C', str(root), 'rev-parse', 'HEAD'], text=True).strip()
        assert commit == lock['commit'], f'Design revision differs from lock: {commit}'
        assert not subprocess.check_output(['git', '-C', str(root), 'status', '--porcelain'], text=True).strip(), 'Design checkout has uncommitted changes'
        for local, source in lock['designSources'].items():
            assert digest(APP / local) == digest(root / source), f'Design source differs: {source}'
        geometry = json.loads((APP / 'tool/design/contracts/ai-conversation-geometry.json').read_text())
        css = (root / 'card-refresh/prototype/src/ai-conversation.css').read_text()
        entry, messages, answer = (geometry[key] for key in ['input', 'messages', 'answer'])
        assert f"margin:{entry['marginTop']}px {entry['marginHorizontal']}px 0;padding:{entry['padding']}px;border-radius:{entry['radius']}px" in css, 'Conversation input geometry differs'
        assert f"min-height:{entry['fieldMinHeight']}px" in css, 'Conversation field height differs'
        assert f".a85-messages .bc-chat-answer{{font-size:{answer['fontSize']}px;line-height:{answer['lineHeight']}}}" in css, 'Conversation answer typography differs'
        assert f"padding:{messages['paddingVertical']}px {messages['paddingHorizontal']}px" in css, 'Conversation message padding differs'
        assert f".a85-messages>.bc-surface{{margin:{answer['marginTop']}px 0 {answer['marginBottom']}px;padding:{answer['padding']}px}}" in css, 'Conversation answer surface differs'
        checked['crossRepository'] = True
        checked['designCommit'] = commit
    print(json.dumps(checked))


if __name__ == '__main__':
    main()
