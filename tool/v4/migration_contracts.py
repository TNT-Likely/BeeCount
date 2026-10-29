"""Shared read-only support for the local historical migration audits.

Original read-only backups remain the first reference. Some audited files have
subsequent reviewed V4 fixes (sync hydration, import throughput, shared dialogs).
Those deltas must be reported, and the current source must still match the
published pre-directory-move revision. Imports and the approved toast API rename
are the only normalization performed here.
"""
import hashlib
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[2]
REVIEWED_SOURCE = '0bbc79c86e278ccb6a07c8baa2e4fc2f842956a3'
AUDIT = []


def reviewed_source(path):
    return subprocess.check_output(['git', 'show', f'{REVIEWED_SOURCE}:{path}'],
                                   cwd=ROOT, text=True)


def source_tokens(source):
    source = re.sub(r'(?m)^\s*(?:import|export|part(?:\s+of)?)\s+[^;]+;', '', source)
    pattern = r'''("""[\s\S]*?"""|\x27\x27\x27[\s\S]*?\x27\x27\x27|"(?:\\.|[^"\\])*"|\x27(?:\\.|[^\x27\\])*\x27|//[^\n]*|/\*[\s\S]*?\*/|\w+|[^\s])'''
    tokens = re.findall(pattern, source)
    renamed = {'showToast': 'showBeeToast', 'showToastOnOverlay': 'showBeeToastOnOverlay'}
    return [renamed.get(t, t) for t in tokens if not t.startswith(('//', '/*'))]


def audit_dependency(path, original):
    current = (ROOT / path).read_text()
    if source_tokens(current) == source_tokens(original):
        relation = 'original-semantics'
    else:
        assert source_tokens(current) == source_tokens(reviewed_source(path)), (
            'Dependency changed after the published pre-move V4 reference', path)
        relation = 'preexisting-v4-change'
    AUDIT.append({'path': path, 'relation': relation,
                  'current_sha256': hashlib.sha256(current.encode()).hexdigest()})
    return hashlib.sha256(current.encode()).hexdigest()


def audit_block(original, current, reviewed, label, canonical=source_tokens):
    if canonical(original) == canonical(current):
        return
    assert canonical(reviewed) == canonical(current), (
        'Contract changed after the published pre-move V4 reference', label)
    AUDIT.append({'contract': label, 'relation': 'preexisting-v4-change'})


def page_bindings(prefix):
    return '\n'.join(p.read_text() for p in sorted((ROOT / 'lib/pages').rglob(prefix + '*.dart')))
