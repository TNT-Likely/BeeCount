import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'pull_delta.dart';
import 'pull_full.dart';
import 'pull_same_device.dart';
import 'pull_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;
  final env = PullEnvironment();
  final deltaResults = <Json>[];

  Future<Json> exercise(
      String scenario, Future<Json> Function(PullServer) action) async {
    final report = <String, dynamic>{
      'scenario': scenario,
      'seed': env.seed,
      'configuredTransactions': env.transactionCount,
      'status': 'FAIL'
    };
    final watch = Stopwatch()..start();
    PullServer? server;
    try {
      server = await PullServer.start(env);
      report['cloudSha'] = server.identity['cloud_sha'];
      report['database'] = server.identity['database'];
      report['sessionTimeZone'] = server.identity['session_timezone'];
      final revision = await Process.run('git', ['rev-parse', 'HEAD']);
      if (revision.exitCode != 0) throw StateError('Run from the App checkout');
      report['appSha'] = (revision.stdout as String).trim();
      report['result'] = await action(server);
      report['status'] = 'PASS';
      return report;
    } catch (error) {
      // No credentials, HTTP bodies or stack traces in shareable evidence.
      final message = error.toString();
      report['failure'] =
          message.length > 1000 ? message.substring(0, 1000) : message;
      rethrow;
    } finally {
      server?.close();
      report['elapsedMs'] = watch.elapsedMilliseconds;
      await env.save(scenario, report);
      if (scenario.startsWith('delta-pull-')) deltaResults.add(report);
    }
  }

  test('full pull restores rich personal ledgers', () async {
    configurePullHostChannels(true);
    try {
      await exercise('full-pull', checkFullPull);
    } finally {
      configurePullHostChannels(false);
    }
  }, timeout: const Timeout(Duration(minutes: 20)));

  for (final count in [499, 500, 501, 1001]) {
    test('delta pull verifies exact event pages ($count events)', () async {
      await exercise(
          'delta-pull-$count', (server) => checkDeltaPull(server, count));
    }, timeout: const Timeout(Duration(minutes: 8)));
  }

  test('same device restores its history across a reopened local database',
      () async {
    await exercise('same-device-restore', checkSameDeviceRestore);
  }, timeout: const Timeout(Duration(minutes: 8)));

  tearDownAll(() async {
    if (deltaResults.isNotEmpty) {
      await env.save('delta-pull', {
        'scenario': 'delta-pull',
        'seed': env.seed,
        'appSha': deltaResults.first['appSha'],
        'cloudSha': deltaResults.first['cloudSha'],
        'status':
            deltaResults.every((r) => r['status'] == 'PASS') ? 'PASS' : 'FAIL',
        'cases': deltaResults
      });
    }
  });
}
