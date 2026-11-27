import 'dart:convert';

import 'package:beecount/cloud/cloud_version_policy.dart';
import 'package:beecount/cloud/sync/change_tracker.dart';
import 'package:beecount/cloud/sync/sync_engine.dart';
import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'sync/_fakes/fake_beecount_cloud_provider.dart';

class _UpgradeRequiredProvider extends FakeBeeCountCloudProvider {
  @override
  Future<BeeCountCloudPullResult> pullChanges({
    int? since,
    int limit = 500,
    bool persistCursor = true,
    String? restoreDeviceId,
  }) async {
    throw BeeCountCloudUpgradeRequiredException(
      'BeeCount App 4.1.0 or newer is required',
      serverVersion: '1.12.0',
      minAppVersion: '4.1.0',
      recommendedAppVersion: '4.2.0',
      clientAppVersion: '4.0.1',
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('CloudSemVer', () {
    test('parses standard, v-prefixed, build-numbered, and prerelease forms', () {
      expect(CloudSemVer.tryParse('4.1.0'), const CloudSemVer(4, 1, 0));
      expect(CloudSemVer.tryParse('v4.1.0+42'), const CloudSemVer(4, 1, 0));
      expect(CloudSemVer.tryParse('4.1.0 42'), const CloudSemVer(4, 1, 0));
      expect(CloudSemVer.tryParse('4.1.0 (42)'), const CloudSemVer(4, 1, 0));
      expect(CloudSemVer.tryParse('4.1.0-beta.2'), const CloudSemVer(4, 1, 0));
      expect(CloudSemVer.tryParse('web-1.11.0'), isNull);
      expect(CloudSemVer.tryParse(''), isNull);
      expect(CloudSemVer.tryParse(null), isNull);
    });
  });

  group('evaluateCloudVersionCompatibility', () {
    test('returns unknown for null, invalid, or dev fallback 1.0.0 server', () {
      expect(
        evaluateCloudVersionCompatibility(appVersion: '4.1.0', server: null)
            .status,
        CloudVersionMatchStatus.unknown,
      );
      expect(
        evaluateCloudVersionCompatibility(
          appVersion: '4.1.0',
          server: const BeeCountCloudServerVersion(
            name: 'BeeCount Cloud',
            version: '1.0.0',
          ),
        ).status,
        CloudVersionMatchStatus.unknown,
      );
      expect(
        evaluateCloudVersionCompatibility(
          appVersion: '4.1.0',
          server: const BeeCountCloudServerVersion(
            name: 'BeeCount Cloud',
            version: '1.11.0-dev',
          ),
        ).status,
        CloudVersionMatchStatus.unknown,
      );
    });

    test('evaluates matched versions cleanly', () {
      final result = evaluateCloudVersionCompatibility(
        appVersion: '4.1.0+12',
        server: const BeeCountCloudServerVersion(
          name: 'BeeCount Cloud',
          version: '1.11.0',
          minAppVersion: '4.0.0',
          recommendedAppVersion: '4.1.0',
        ),
      );
      expect(result.status, CloudVersionMatchStatus.matched);
      expect(result.isMatched, isTrue);
      expect(result.needsNotice, isFalse);
      expect(result.isBlocking, isFalse);
    });

    test('distinguishes recommended vs required Cloud upgrades', () {
      final recommended = evaluateCloudVersionCompatibility(
        appVersion: '4.1.0',
        server: const BeeCountCloudServerVersion(
          name: 'BeeCount Cloud',
          version: '1.10.1',
        ),
      );
      expect(
        recommended.status,
        CloudVersionMatchStatus.upgradeCloudRecommended,
      );
      expect(recommended.isBlocking, isFalse);
      expect(recommended.upgradeTargetIsCloud, isTrue);
      expect(recommended.targetVersion, '1.11.0');

      final required = evaluateCloudVersionCompatibility(
        appVersion: '4.1.0',
        server: const BeeCountCloudServerVersion(
          name: 'BeeCount Cloud',
          version: '1.9.0',
        ),
      );
      expect(required.status, CloudVersionMatchStatus.upgradeCloudRequired);
      expect(required.isBlocking, isTrue);
      expect(required.upgradeTargetIsCloud, isTrue);
      expect(required.targetVersion, '1.10.0');
    });

    test('distinguishes recommended vs required App updates', () {
      final recommended = evaluateCloudVersionCompatibility(
        appVersion: '4.1.0',
        server: const BeeCountCloudServerVersion(
          name: 'BeeCount Cloud',
          version: '1.12.0',
          minAppVersion: '4.1.0',
          recommendedAppVersion: '4.2.0',
        ),
      );
      expect(recommended.status, CloudVersionMatchStatus.upgradeAppRecommended);
      expect(recommended.isBlocking, isFalse);
      expect(recommended.upgradeTargetIsApp, isTrue);
      expect(recommended.targetVersion, '4.2.0');

      final required = evaluateCloudVersionCompatibility(
        appVersion: '4.0.1',
        server: const BeeCountCloudServerVersion(
          name: 'BeeCount Cloud',
          version: '1.12.0',
          minAppVersion: '4.1.0',
          recommendedAppVersion: '4.2.0',
        ),
      );
      expect(required.status, CloudVersionMatchStatus.upgradeAppRequired);
      expect(required.isBlocking, isTrue);
      expect(required.upgradeTargetIsApp, isTrue);
      expect(required.targetVersion, '4.1.0');
    });

    test('parses HTTP 426 response into blocking App upgrade compatibility', () {
      final response = http.Response(
        jsonEncode({
          'error': {
            'code': 'APP_UPGRADE_REQUIRED',
            'message': 'BeeCount App 4.1.0 or newer is required',
          },
          'server_version': '1.12.0',
          'min_app_version': '4.1.0',
          'recommended_app_version': '4.2.0',
          'client_app_version': '4.0.1',
        }),
        426,
        headers: {'content-type': 'application/json'},
      );
      final exc = BeeCountCloudUpgradeRequiredException.fromResponse(response);
      final compat = CloudVersionCompatibility.fromUpgradeRequired(exc);
      expect(compat.status, CloudVersionMatchStatus.upgradeAppRequired);
      expect(compat.isBlocking, isTrue);
      expect(compat.serverVersion, '1.12.0');
      expect(compat.appVersion, '4.0.1');
      expect(compat.targetVersion, '4.1.0');
    });
  });

  group('SyncEngine version guard', () {
    test('pauses cloud sync when versionGuard blocks while local DB stays usable',
        () async {
      final db = BeeDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final tracker = ChangeTracker(db);
      final repo = LocalRepository(db, changeTracker: tracker);
      final provider = FakeBeeCountCloudProvider();
      final engine = SyncEngine(
        db: db,
        provider: provider,
        changeTracker: tracker,
        repo: repo,
      );
      engine.versionGuard = () async => const CloudVersionCompatibility(
            status: CloudVersionMatchStatus.upgradeCloudRequired,
            appVersion: '4.1.0',
            serverVersion: '1.9.0',
            targetVersion: '1.10.0',
          );

      // Local write succeeds normally even when cloud sync is paused.
      final ledgerId = await repo.createLedger(name: '离线账本', currency: 'CNY');
      await repo.addTransaction(
        ledgerId: ledgerId,
        type: 'expense',
        amount: 18.5,
        happenedAt: DateTime.utc(2026, 11, 27, 12),
        note: '午餐',
      );

      final result = await engine.sync(ledgerId: '$ledgerId');
      expect(result.error, 'sync_paused_version_mismatch');
      expect(result.pushed, 0);
      expect(provider.pushedBatches, isEmpty);
      expect(await engine.pull('$ledgerId'), 0);

      // Local transaction remains persisted.
      final txs = await (db.select(db.transactions)
            ..where((t) => t.ledgerId.equals(ledgerId)))
          .get();
      expect(txs.length, 1);
      expect(txs.single.amount, 18.5);
    });

    test('triggers onUpgradeRequired when pull receives HTTP 426', () async {
      final db = BeeDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final tracker = ChangeTracker(db);
      final repo = LocalRepository(db, changeTracker: tracker);
      final provider = _UpgradeRequiredProvider();
      final engine = SyncEngine(
        db: db,
        provider: provider,
        changeTracker: tracker,
        repo: repo,
      );
      CloudVersionCompatibility? captured;
      engine.onUpgradeRequired = (c) => captured = c;

      final pulled = await engine.pull('1');
      expect(pulled, 0);
      expect(captured, isNotNull);
      expect(captured!.status, CloudVersionMatchStatus.upgradeAppRequired);
      expect(captured!.serverVersion, '1.12.0');
      expect(captured!.targetVersion, '4.1.0');
    });
  });
}
