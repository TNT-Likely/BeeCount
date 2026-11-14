#!/usr/bin/env python3
"""Build the isolated local-only original 3.9.0 skin renderer; never the App."""
from __future__ import annotations
from design_paths import design_root
import argparse, hashlib, json, os, pathlib, shutil, subprocess

ROOT = pathlib.Path(__file__).resolve().parents[2]
PIN = '3fddb41747d5e6d89df82a2ff493f2f56a5ac37b'
PARTS = {
    'skin_common.dart': '9bf14bce7b857a53ac84952ce149402499b9e109de616f30ae15b8471734773c',
    'anniversary_skin.dart': 'ed19fed0335529ee3b5f98363171ebf784d0deb1d27142ee706ba0414f7a66e3',
    'anniv_cake_skin.dart': 'b9953ee141b3f1d387ff82325ba5305c457b0d12156bdfdc7a2bc5aa0336f059',
}
TEMPLATE = ROOT / 'tool/v4/original_skin_renderer'
PROJECT = TEMPLATE / 'build/source_project'
OUTPUT = design_root(ROOT) / 'renderers/build/original-skins-390'


def git_source(path: str) -> bytes:
    return subprocess.check_output(['git', 'show', f'{PIN}:{path}'], cwd=ROOT)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--flutter', default=os.environ.get('FLUTTER_BIN', str(pathlib.Path.home() / 'fvm/default/bin/flutter')))
    parser.add_argument('--check-only', action='store_true')
    args = parser.parse_args()
    tag = subprocess.check_output(['git', 'rev-parse', '3.9.0^{}'], cwd=ROOT, text=True).strip()
    if tag != PIN:
        raise SystemExit('Official 3.9.0 tag no longer matches the pinned source commit')
    manifest = {'sourceRef': '3.9.0', 'sourceCommit': PIN, 'parts': {}}
    data = {}
    for name, expected in PARTS.items():
        path = f'lib/styles/header_skins/{name}'
        value = git_source(path)
        digest = hashlib.sha256(value).hexdigest()
        if digest != expected:
            raise SystemExit(f'Original part hash mismatch: {path}')
        data[name] = value
        manifest['parts'][path] = digest
    if args.check_only:
        print(json.dumps(manifest, ensure_ascii=False, indent=2))
        return
    flutter = pathlib.Path(args.flutter).expanduser().resolve()
    if not flutter.is_file():
        raise SystemExit('Flutter executable not found; pass --flutter or FLUTTER_BIN')
    PROJECT.mkdir(parents=True, exist_ok=True)
    target_parts = PROJECT / 'lib/header_skins'
    target_parts.mkdir(parents=True, exist_ok=True)
    for name, value in data.items():
        (target_parts / name).write_bytes(value)  # Do not format/change original source.
    registry_bytes = git_source('lib/styles/header_skins.dart')
    manifest['registrySha256'] = hashlib.sha256(registry_bytes).hexdigest()
    registry = registry_bytes.decode()
    helpers = registry[registry.index('Color _lighten('):registry.index('/// 已注册皮肤')]
    library = (TEMPLATE / 'lib/header_skins.dart.in').read_text().replace('@@ORIGINAL_HSL_HELPERS@@', helpers)
    (PROJECT / 'lib/header_skins.dart').write_text(library)
    shutil.copyfile(TEMPLATE / 'lib/main.dart.in', PROJECT / 'lib/main.dart')
    shutil.copytree(TEMPLATE / 'web', PROJECT / 'web', dirs_exist_ok=True)
    fonts = PROJECT / 'assets/fonts'
    fonts.mkdir(parents=True, exist_ok=True)
    # Local SDK font only: no Google/CDN fallback request at runtime.
    roboto = flutter.parents[1] / 'bin/cache/artifacts/material_fonts/Roboto-Regular.ttf'
    shutil.copyfile(roboto, fonts / 'Roboto-Regular.ttf')
    (PROJECT / 'pubspec.yaml').write_text('''name: beecount_original_skin_renderer
publish_to: none
version: 1.0.0
environment:
  sdk: '>=3.6.0 <4.0.0'
dependencies:
  flutter:
    sdk: flutter
flutter:
  fonts:
    - family: Roboto
      fonts:
        - asset: assets/fonts/Roboto-Regular.ttf
''')
    subprocess.run([str(flutter), 'pub', 'get', '--offline'], cwd=PROJECT, check=True)
    subprocess.run([str(flutter), 'build', 'web', '--release', '--no-web-resources-cdn', '--pwa-strategy=none', '--base-href=/renderers/build/original-skins-390/', '--output', str(OUTPUT)], cwd=PROJECT, check=True)
    # This is the engine's local default-font fallback path, not a public URL.
    fallback = OUTPUT / 'fonts/roboto/v20'
    fallback.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(roboto, fallback / 'KFOmCnqEu92Fr1Me5WZLCzYlKw.ttf')
    manifest['flutterVersion'] = json.loads(subprocess.check_output([str(flutter), '--version', '--machine'], text=True))
    manifest['runtimeResources'] = 'local CanvasKit + local SDK Roboto; no service worker/CDN'
    (OUTPUT / 'source-manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n')
    print(f'Original renderer built: {OUTPUT}')


if __name__ == '__main__':
    main()
