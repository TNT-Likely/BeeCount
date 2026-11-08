// Host-side evidence writer. Output is private and must never be committed.
// QA_EVIDENCE_DIR must name an existing directory beneath beecount-qa-... .
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  final path = Platform.environment['QA_EVIDENCE_DIR'];
  if (path == null || path.isEmpty) {
    throw StateError(
        'Set QA_EVIDENCE_DIR to a private, empty evidence directory');
  }
  final directory = Directory(path).absolute;
  if (!directory.existsSync() ||
      !directory
          .resolveSymbolicLinksSync()
          .split(Platform.pathSeparator)
          .any((part) => part.startsWith('beecount-qa-'))) {
    throw StateError(
        'Evidence must be inside an existing beecount-qa-... directory');
  }
  final manifest = File('${directory.path}/manifest.json');
  final mediaManifest = File('${directory.path}/media-manifest.json');
  // The media run may reuse a directory containing the screenshot matrix,
  // but neither kind is allowed to overwrite its own earlier evidence.
  final screenshotOutputExists = manifest.existsSync() ||
      directory.listSync().any((entry) => entry.path.endsWith('.png'));
  final mediaOutputExists = mediaManifest.existsSync();
  final files = <String, Map<String, Object?>>{};
  final namePattern = RegExp(r'^(zh|en)_(light|dark)_(\d{2}-[a-z]+)$');
  const core = [
    '01-home',
    '02-analytics',
    '03-accounts',
    '04-ledgers',
    '05-transaction',
    '06-budgets'
  ];

  Future<void> write(Map<String, Object?> data) async {
    await manifest.writeAsString(
        const JsonEncoder.withIndent('  ').convert(data),
        flush: true);
  }

  await integrationDriver(
    onScreenshot: (name, bytes, [args]) async {
      final match = namePattern.firstMatch(name);
      if (screenshotOutputExists || match == null || files.containsKey(name)) {
        return false;
      }
      if (bytes.length < 24 ||
          !List.generate(8, (i) => bytes[i]).asMap().entries.every((entry) =>
              entry.value ==
              const [137, 80, 78, 71, 13, 10, 26, 10][entry.key])) {
        throw StateError('$name is not a PNG screenshot');
      }
      final header = ByteData.sublistView(Uint8List.fromList(bytes), 16, 24);
      final width = header.getUint32(0), height = header.getUint32(4);
      if (width < 320 || height < 640) {
        throw StateError('Unexpected PNG dimensions for $name');
      }
      await File('${directory.path}/$name.png')
          .writeAsBytes(bytes, flush: true);
      files[name] = {
        'file': '$name.png',
        'locale': match.group(1),
        'theme': match.group(2),
        'scene': match.group(3),
        'pixel_width': width,
        'pixel_height': height,
        'bytes': bytes.length
      };
      // Native screenshots reach this callback at the end of the run. Keep a
      // partial manifest even if a later image/production-page assertion fails.
      await write({
        'schema_version': 1,
        'complete': false,
        'files': files.values.toList()
      });
      return true;
    },
    writeResponseOnFailure: true,
    responseDataCallback: (data) async {
      if (data == null ||
          !RegExp(r'^beecount-qa-[a-zA-Z0-9_-]+$')
              .hasMatch('${data['run_id']}')) {
        throw StateError('The App did not return a valid QA run identity');
      }
      final expectedRun = Platform.environment['QA_RUN_ID'];
      if (expectedRun != null && data['run_id'] != expectedRun) {
        throw StateError('Host and App QA_RUN_ID do not match');
      }
      if (data['kind'] == 'production_app_media') {
        if (mediaOutputExists) {
          throw StateError(
              'Use a new media evidence directory; refusing to overwrite media-manifest.json');
        }
        final clips = (data['media_clips'] as List? ?? const []).cast<Map>();
        const scenes = [
          '01-add-transaction',
          '02-ai-chat',
          '03-ai-photo-recognition',
          '04-data-analysis',
          '05-copy-transaction',
          '06-import-ledger'
        ];
        final expected = {
          for (final locale in ['zh', 'en'])
            for (final theme in ['light', 'dark'])
              for (final scene in scenes) '${locale}_${theme}_$scene'
        };
        final expectedMediaCount = (data['expected_media_clips'] as int? ?? 24);
        if (expectedMediaCount == 20) {
          expected.removeWhere((name) => name.contains('-ai-photo-'));
        }
        final errors = <String>[];
        final names = <String>{};
        var previousEnd = 0;
        for (final clip in clips) {
          final name = '${clip['name']}';
          if (!names.add(name) || !expected.contains(name)) {
            errors.add('Unexpected or repeated clip: $name');
          }
          if (clip['status'] != 'PASS' ||
              (clip['assertions'] as List? ?? const []).isEmpty) {
            errors.add('Missing real assertions or PASS: $name');
          }
          final start = clip['started_at_ms'], end = clip['ended_at_ms'];
          if (start is! int ||
              end is! int ||
              start < 1600000000000 ||
              start <= previousEnd ||
              end - start < 5000 ||
              end - start >= (name.contains('-ai-') ? 60000 : 45000)) {
            errors.add('Invalid wall-clock interval: $name');
          } else {
            previousEnd = end;
          }
          if (name.endsWith('01-add-transaction')) {
            final transaction = clip['transaction'];
            if (transaction is! Map ||
                transaction['amount'] != 37.5 ||
                transaction['id'] is! int ||
                clip['production_page'] != 'HomePage') {
              errors.add('Missing saved add-transaction proof: $name');
            }
          } else if (name.endsWith('04-data-analysis')) {
            if (clip['annual_income'] is! num ||
                clip['monthly_expense'] is! num ||
                (clip['annual_income'] as num) <= 0 ||
                (clip['monthly_expense'] as num) <= 0 ||
                clip['production_page'] != 'AnalyticsPage') {
              errors.add('Missing rendered analytics proof: $name');
            }
          } else if (name.endsWith('05-copy-transaction')) {
            final source = clip['source_before'],
                after = clip['source_after'],
                copy = clip['copy'];
            if (source is! Map ||
                after is! Map ||
                copy is! Map ||
                jsonEncode(source) != jsonEncode(after) ||
                source['id'] == copy['id'] ||
                source['syncId'] == copy['syncId'] ||
                copy['amount'] != 42.8 ||
                clip['production_page'] != 'HomePage') {
              errors.add(
                  'Missing independent copy/unchanged source proof: $name');
            }
          }
        }
        if (files.isNotEmpty ||
            (data['captures'] as List? ?? const []).isNotEmpty) {
          errors.add('Media mode must not capture or require PNG screenshots');
        }
        final missing = expected.difference(names).toList()..sort();
        if (clips.length != expectedMediaCount || missing.isNotEmpty) {
          errors.add('Expected exactly $expectedMediaCount native media clips');
        }
        final result = Map<String, Object?>.from(data)..remove('screenshots');
        result['files'] = <Object?>[];
        result['missing'] = missing;
        result['validation_errors'] = errors;
        result['complete'] = data['complete'] == true && errors.isEmpty;
        await mediaManifest.writeAsString(
            const JsonEncoder.withIndent('  ').convert(result),
            flush: true);
        if (data['complete'] == true && errors.isNotEmpty) {
          throw StateError(
              'Invalid native media evidence; inspect ${mediaManifest.path}');
        }
        return;
      }
      if (screenshotOutputExists) {
        throw StateError(
            'Use a new screenshot evidence directory; never overwrite an earlier run');
      }
      if (data['native_host_capture'] == true) {
        for (final entry in directory.listSync().whereType<File>()) {
          final fileName = entry.uri.pathSegments.last;
          if (!fileName.endsWith('.png')) continue;
          final name = fileName.substring(0, fileName.length - 4);
          final match = namePattern.firstMatch(name);
          if (match == null || entry.resolveSymbolicLinksSync() != entry.path) {
            throw StateError('Unexpected native screenshot file: $fileName');
          }
          final bytes = await entry.readAsBytes();
          if (bytes.length < 24 ||
              !List.generate(8, (i) => bytes[i]).asMap().entries.every((e) =>
                  e.value == const [137, 80, 78, 71, 13, 10, 26, 10][e.key])) {
            throw StateError('Invalid native PNG: $fileName');
          }
          final header = ByteData.sublistView(bytes, 16, 24);
          files[name] = {
            'file': fileName,
            'locale': match.group(1),
            'theme': match.group(2),
            'scene': match.group(3),
            'pixel_width': header.getUint32(0),
            'pixel_height': header.getUint32(4),
            'bytes': bytes.length,
          };
        }
      }
      final captures = (data['captures'] as List? ?? const []).cast<Map>();
      final complete = data['complete'] == true;
      final expectedCount = (data['screens_per_group'] as int? ?? 6) * 4;
      final expectedScenes = <String>{...core};
      if (expectedCount == 48) {
        expectedScenes.addAll([
          '07-mine',
          '08-tags',
          '09-cloud',
          '10-categories',
          '11-personalization',
          '12-search'
        ]);
      }
      final expectedNames = {
        for (final locale in ['zh', 'en'])
          for (final theme in ['light', 'dark'])
            for (final scene in expectedScenes) '${locale}_${theme}_$scene'
      };
      final capturedNames = captures.map((capture) => capture['name']).toSet();
      final missing = expectedNames.difference(files.keys.toSet()).toList()
        ..sort();
      final invalid = captures
          .where((capture) =>
              capture['status'] != 'PASS' ||
              capture['production_page'] == null ||
              (capture['viewport_assertions'] as List? ?? const []).isEmpty)
          .isNotEmpty;
      final result = Map<String, Object?>.from(data)..remove('screenshots');
      result['files'] = [
        for (final entry in files.entries)
          {
            ...entry.value,
            'assertions': captures
                .where((capture) => capture['name'] == entry.key)
                .firstOrNull
          }
      ];
      result['missing'] = missing;
      result['complete'] = complete &&
          missing.isEmpty &&
          !invalid &&
          files.length == expectedCount &&
          capturedNames.length == expectedCount;
      await write(result);
      if (complete && result['complete'] != true) {
        throw StateError(
            'Incomplete production screenshot matrix; inspect ${manifest.path}');
      }
    },
  );
}
