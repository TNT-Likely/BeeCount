import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:beecount/cloud/sync/sync_engine.dart';
import 'package:beecount/data/db.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'relations_fixture.dart';

const parentKey = 'relations-food', childKey = 'relations-breakfast';
const trip = 'relations-trip', refund = 'relations-refund';
// Each index is an original image. Each book has its own 12 references.
// Multi-image transactions deliberately use non-numeric image order.
const groups = [
  [0],
  [5, 1, 4, 3, 2],
  [8, 6, 11, 9, 7, 10]
];
String txKey(int book, int group) => 'relations-tx-$book-$group';
List<String> expectedTags(int group, bool changed, int book) {
  if (changed && book == 0 && group == 0) return [trip];
  if (changed && book == 0 && group == 1) return [];
  return group == 2 ? [] : [refund, trip];
}

List<int> expectedPhotos(int book, int group, bool changed) =>
    changed && book == 0 && group == 0 ? [] : groups[group];
int cents(int book, int group) => 2850 + 100 * book + group;

Future<List<Map<String, dynamic>>> checkCloud(RelationsWeb web,
    List<String> ledgerKeys, List<String> hashes, String parentName,
    {required bool changed}) async {
  final refs = <Map<String, dynamic>>[];
  for (var book = 0; book < ledgerKeys.length; book++) {
    final snapshot = await web.snapshot(ledgerKeys[book]);
    final categories =
        (snapshot['categories'] as List).cast<Map<String, dynamic>>();
    final child = categories.singleWhere((r) => r['syncId'] == childKey);
    expect(child['parentSyncId'], parentKey, reason: 'Cloud child parent ID');
    expect(categories.singleWhere((r) => r['syncId'] == parentKey)['name'],
        parentName);
    expect(child['parentName'], parentName, reason: 'Cloud child parent name');
    final txs = (snapshot['items'] as List).cast<Map<String, dynamic>>();
    expect(txs.length, groups.length);
    for (var group = 0; group < groups.length; group++) {
      final key = txKey(book, group);
      final tx = txs.singleWhere((r) => r['syncId'] == key);
      expect(tx['categoryId'], childKey, reason: 'Cloud $key category');
      expect((tx['amount'] as num) * 100, closeTo(cents(book, group), 1e-7),
          reason: 'Cloud $key amount');
      final actualTags = List<String>.from(tx['tagIds'] as List? ?? [])..sort();
      expect(actualTags, expectedTags(group, changed, book),
          reason: 'Cloud $key tag IDs');
      final media =
          (tx['attachments'] as List? ?? []).cast<Map<String, dynamic>>();
      final expected = expectedPhotos(book, group, changed);
      expect(media.length, expected.length,
          reason: 'Cloud $key attachment count');
      for (var i = 0; i < expected.length; i++) {
        final att = media[i];
        expect(att['cloudSha256'], hashes[expected[i]],
            reason: 'Cloud $key photo $i digest');
        expect(att['sortOrder'], i, reason: 'Cloud $key photo $i order');
        expect(att['originalName'], 'receipt.png');
        expect(att['cloudFileId'],
            isA<String>().having((v) => v.isNotEmpty, 'populated', true));
        refs.add({
          'book': book,
          'tx': key,
          'index': i,
          'sha256': att['cloudSha256'],
          'fileId': att['cloudFileId']
        });
      }
    }
  }
  return refs;
}

Future<void> checkDevice(
    RelationsDevice device, List<String> ledgerKeys, List<String> hashes,
    {required bool changed, required String parentName}) async {
  final db = device.db;
  final categories = await db.select(db.categories).get();
  final parent = categories.singleWhere((r) => r.syncId == parentKey);
  final child = categories.singleWhere((r) => r.syncId == childKey);
  expect(parent.name, parentName, reason: 'App parent name');
  expect(child.parentId, parent.id,
      reason: 'App child references correct local parent ID');
  for (var book = 0; book < ledgerKeys.length; book++) {
    final ledger = await (db.select(db.ledgers)
          ..where((r) => r.syncId.equals(ledgerKeys[book])))
        .getSingle();
    final txs = await (db.select(db.transactions)
          ..where((r) => r.ledgerId.equals(ledger.id)))
        .get();
    expect(txs.length, groups.length);
    for (var group = 0; group < groups.length; group++) {
      final key = txKey(book, group);
      final tx = txs.singleWhere((r) => r.syncId == key);
      expect(tx.categoryId, child.id, reason: 'App $key linked to child ID');
      expect((tx.amount * 100).round(), cents(book, group),
          reason: 'App $key amount');
      final tags = await device.repo.getTagsForTransaction(tx.id);
      expect(tags.map((t) => t.syncId!).toList()..sort(),
          expectedTags(group, changed, book),
          reason: 'App $key tag IDs');
      final photos = await device.repo.getAttachmentsByTransaction(tx.id);
      final expected = expectedPhotos(book, group, changed);
      expect(photos.length, expected.length,
          reason: 'App $key attachment count');
      for (var i = 0; i < expected.length; i++) {
        final row = photos[i];
        final digest = hashes[expected[i]];
        expect(row.sortOrder, i, reason: 'App $key order');
        expect(row.originalName, 'receipt.png');
        expect(row.cloudSha256, digest, reason: 'App $key cloud digest');
        final path = await device.attachments.getAttachmentPath(row.fileName);
        expect(await File(path).exists(), true,
            reason: 'App $key photo $i missing locally');
        expect(
            sha256.convert(await File(path).readAsBytes()).toString(), digest,
            reason: 'App $key file bytes $i');
      }
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
      'parent rename, offline tags and shared receipt survive a lost ack and a fresh device',
      () async {
    HttpOverrides.global = null;
    final env = Platform.environment;
    final origin = Uri.parse(env['CLOUD_SYNC_QA_URL'] ??
        const String.fromEnvironment('CLOUD_SYNC_QA_URL'));
    expect(origin.scheme, 'http');
    expect(origin.host, '127.0.0.1');
    final output = env['CLOUD_SYNC_QA_OUTPUT'] ??
        const String.fromEnvironment('CLOUD_SYNC_QA_OUTPUT');
    expect(output, isNotEmpty);
    final file =
        File(output.endsWith('.json') ? output : '$output/relations.json');
    await file.parent.create(recursive: true);
    final seed = int.parse(env['CLOUD_SYNC_QA_SEED'] ??
        const String.fromEnvironment('CLOUD_SYNC_QA_SEED',
            defaultValue: '20261126'));
    final web = RelationsWeb(origin);
    final identity = await web.api('GET', '/__qa__/identity');
    expect(identity['database_is_isolated'], true);
    expect(identity['cloud_sha'], matches(RegExp(r'^[a-f0-9]{40}$')));
    final requiredSha = env['CLOUD_SYNC_QA_CLOUD_SHA'] ?? '';
    if (requiredSha.isNotEmpty) expect(identity['cloud_sha'], requiredSha);
    final evidence = <String, dynamic>{
      'scenario': 'relations',
      'seed': seed,
      'cloud_sha': identity['cloud_sha'],
      'status': 'RUNNING',
      'representativeTransactions': 6,
      'images': 12,
      'initialReferences': 24,
      'stages': <String>[]
    };
    String stage = 'init';
    Future<void> mark(String name) async {
      (evidence['stages'] as List<String>).add(name);
      await file
          .writeAsString(const JsonEncoder.withIndent('  ').convert(evidence));
    }

    final savedPaths = RelationsPaths.current;
    final scratch =
        await Directory.systemTemp.createTemp('beecount-relations-');
    final devices = <RelationsDevice>[];
    final links = <RelationsRelay>[];
    addTearDown(() async {
      for (final device in devices.reversed) {
        await device.close();
      }
      for (final link in links.reversed) {
        await link.close();
      }
      RelationsPaths.restore(savedPaths);
      await scratch.delete(recursive: true);
    });
    Future<(RelationsDevice, RelationsRelay)> device(String name) async {
      // ignore: invalid_use_of_visible_for_testing_member
      SharedPreferences.setMockInitialValues({});
      final local =
          RelationsDevice(await Directory('${scratch.path}/$name').create());
      local.selectFiles();
      devices.add(local);
      final relay = await RelationsRelay.open(origin);
      links.add(relay);
      await local.cloud.initialize({'baseUrl': relay.localOrigin});
      return (local, relay);
    }

    try {
      final (a, linkA) = await device('a');
      final rng = Random.secure();
      final email =
          'relations-${DateTime.now().microsecondsSinceEpoch}-${rng.nextInt(1 << 30)}@qa.example.com';
      final secret =
          base64UrlEncode(List.generate(25, (_) => rng.nextInt(256)));
      await a.cloud.auth.signUpWithEmail(email: email, password: secret);
      final webSession = await web.api('POST', '/api/v1/auth/login', {
        'email': email,
        'password': secret,
        'client_type': 'web',
        'device_name': 'QA relations writer'
      });
      web.token = webSession['access_token'] as String;
      final ledgers = [
        await a.repo.createLedger(name: 'Relations main'),
        await a.repo.createLedger(name: 'Relations travel')
      ];
      for (final id in ledgers) {
        await a.sync(id);
      }
      final keys = <String>[
        for (final id in ledgers) (await a.repo.getLedgerById(id))!.syncId!
      ];
      final parent = await a.repo
          .createCategory(name: '餐饮', kind: 'expense', syncId: parentKey);
      final breakfast = await a.repo.createSubCategory(
          parentId: parent, name: '早餐', kind: 'expense', syncId: childKey);
      final travel = await a.repo.createTag(name: '出差', syncId: trip);
      final reimbursable = await a.repo.createTag(name: '可报销', syncId: refund);
      final inputs = [
        for (var i = 0; i < 12; i++) await relationImage(scratch, seed, i)
      ];
      final hashes = inputs.map((it) => it.digest).toList();
      expect(hashes.toSet().length, 12);
      final rows = <String, int>{};
      stage = 'seed references';
      for (var book = 0; book < 2; book++) {
        for (var group = 0; group < groups.length; group++) {
          final key = txKey(book, group);
          final amount = cents(book, group) / 100;
          final row = await a.repo.addTransaction(
              ledgerId: ledgers[book],
              type: 'expense',
              amount: amount,
              nativeAmount: amount,
              currencyCode: 'CNY',
              syncId: key,
              categoryId: breakfast,
              happenedAt: DateTime.utc(2026, 11, 20, 8, book, group),
              note: key);
          rows[key] = row;
          if (group < 2) {
            await a.repo.updateTransactionTags(
                transactionId: row, tagIds: [travel, reimbursable]);
          }
          for (var k = 0; k < groups[group].length; k++) {
            final image = inputs[groups[group][k]];
            final saved = await a.attachments.saveAttachment(
                transactionId: row,
                sourceFile: image.source,
                index: k,
                urgent: true);
            expect(saved, isNotNull, reason: 'App save $key photo $k');
            final original =
                File(await a.attachments.getAttachmentPath(saved!.fileName));
            expect(sha256.convert(await original.readAsBytes()).toString(),
                image.digest);
          }
        }
      }
      stage = 'baseline round trip';
      for (final ledger in ledgers) {
        await a.sync(ledger);
      }
      final baseline =
          await checkCloud(web, keys, hashes, '餐饮', changed: false);
      expect(baseline.length, 24);
      await checkDevice(a, keys, hashes, changed: false, parentName: '餐饮');
      expect(await a.tracker.getUnpushedCount(), 0);
      evidence['originalSha256'] = hashes;
      evidence['initialCloudFileIds'] =
          baseline.map((r) => r['fileId']).toSet().length;
      await mark(stage);

      stage = 'offline changes and online parent rename';
      final target = rows[txKey(0, 0)]!, clear = rows[txKey(0, 1)]!;
      final beforeCursor = (await web.events(0))['server_cursor'] as int;
      linkA.offline = true;
      await a.repo
          .updateTransactionTags(transactionId: target, tagIds: [travel]);
      await a.repo.updateTransactionTags(transactionId: clear, tagIds: []);
      final shared = (await a.repo.getAttachmentsByTransaction(target)).single;
      await a.attachments.deleteAttachment(shared.id);
      final sharedPath = await a.attachments.getAttachmentPath(shared.fileName);
      expect(await a.repo.countAttachmentsByFileName(shared.fileName), 1);
      expect(sha256.convert(await File(sharedPath).readAsBytes()).toString(),
          hashes.first);
      final offline = await a.engine.sync(ledgerId: ledgers.first.toString());
      expect(offline.hasError, true);
      expect(linkA.blocked, greaterThan(0));
      expect(await a.tracker.getUnpushedCount(), greaterThan(0));
      await web.api(
          'PATCH',
          '/api/v1/write/ledgers/${keys.first}/categories/$parentKey',
          {'base_change_id': 0, 'name': '餐饮与差旅'});
      await checkCloud(web, keys, hashes, '餐饮与差旅', changed: false);
      await mark(stage);

      stage = 'response loss after commit';
      linkA.offline = false;
      linkA.loseNextPush = true;
      final noAck = await a.engine.sync(ledgerId: ledgers.first.toString());
      expect(linkA.lost, 1,
          reason:
              'the upstream accepted the request before the relay dropped its response');
      expect(noAck.hasError, true);
      expect(await a.tracker.getUnpushedCount(), greaterThan(0));
      await checkCloud(web, keys, hashes, '餐饮与差旅', changed: true);
      final beforeRetry = await web.events(beforeCursor);
      final changedTx = (beforeRetry['changes'] as List)
          .where((c) => c['entity_type'] == 'transaction')
          .map((c) => c['entity_sync_id'])
          .toList();
      expect(changedTx.toSet(), {txKey(0, 0), txKey(0, 1)},
          reason: 'changes received after editing target rows');
      // The target had two independent user actions (tags, then attachment).
      // The other row had one. An implementation may coalesce the first pair.
      expect(changedTx.where((id) => id == txKey(0, 0)).length,
          inInclusiveRange(1, 2));
      expect(changedTx.where((id) => id == txKey(0, 1)).length, 1);
      await mark(stage);

      stage = 'reconnect and repeat';
      final committed = beforeRetry['server_cursor'] as int;
      await a.sync(ledgers.first);
      await a.sync(ledgers.last);
      expect(await a.tracker.getUnpushedCount(), 0);
      await checkDevice(a, keys, hashes, changed: true, parentName: '餐饮与差旅');
      await a.sync(ledgers.first);
      expect((await web.events(committed))['changes'], isEmpty,
          reason: 'retry and second sync must be idempotent');
      evidence['retry'] = {
        'offlineRequestsBlocked': linkA.blocked,
        'responsesLostAfterCommit': linkA.lost,
        'updatedTransactions': changedTx,
        'pendingAfterRetry': await a.tracker.getUnpushedCount(),
        'eventsAfterRetry': 0
      };
      await mark(stage);

      stage = 'cold restore';
      final (b, linkB) = await device('b');
      await b.cloud.auth.signInWithEmail(email: email, password: secret);
      expect(await b.db.select(b.db.transactions).get(), isEmpty);
      expect(await b.engine.appCursor.read(), 0);
      await b.engine.syncLedgersFromServer();
      final shells = await b.db.select(b.db.ledgers).get();
      final selected = <Ledger>[
        for (final key in keys) shells.singleWhere((row) => row.syncId == key)
      ];
      for (final ledger in selected) {
        await b.engine.downloadAndRestoreToCurrentLedger(ledgerId: ledger.id);
      }
      await checkDevice(b, keys, hashes, changed: true, parentName: '餐饮与差旅');
      final finalRefs =
          await checkCloud(web, keys, hashes, '餐饮与差旅', changed: true);
      expect(finalRefs.length, 23);
      expect(await b.tracker.getUnpushedCount(), 0);
      await mark(stage);

      stage = 'evict, redownload and open offline';
      final cache = await b.attachments.getAttachmentDirectory();
      final cached = await cache.list().where((it) => it is File).toList();
      expect(cached.length, 12,
          reason: '12 unique originals shared across 23 final references');
      for (final it in cached) {
        await it.delete();
      }
      final priorDownloads = linkB.downloads;
      for (final ledger in selected) {
        await b.engine.downloadAttachments(ledgerId: ledger.id);
      }
      expect(linkB.downloads - priorDownloads, 12,
          reason: 'new cache filled by real successful HTTP downloads');
      linkB.offline = true;
      await checkDevice(b, keys, hashes, changed: true, parentName: '餐饮与差旅');
      expect(linkB.blocked, 0,
          reason: 'all 23 references can read from disk offline');
      evidence['coldRestore'] = {
        'transactions': 6,
        'references': finalRefs.length,
        'uniqueFileHashes': hashes.toSet().length,
        'freshHttpDownloadsAfterEviction': linkB.downloads - priorDownloads,
        'otherBookReceiptSha256': hashes.first,
        'targetRemainingTagIds': [trip],
        'clearedTagIds': <String>[]
      };
      await mark(stage);
      stage = 'attachment checksum assertion canary';
      final canaryKey = txKey(1, 0);
      final canaryTx = await (b.db.select(b.db.transactions)
            ..where((row) => row.syncId.equals(canaryKey)))
          .getSingle();
      final photo =
          (await b.repo.getAttachmentsByTransaction(canaryTx.id)).single;
      final privateFile =
          File(await b.attachments.getAttachmentPath(photo.fileName));
      final originalBytes = await privateFile.readAsBytes();
      final changedBytes = [...originalBytes];
      changedBytes[changedBytes.length - 1] ^= 1;
      final damagedHash = sha256.convert(changedBytes).toString();
      try {
        await privateFile.writeAsBytes(changedBytes);
        await expectLater(
            checkDevice(b, keys, hashes, changed: true, parentName: '餐饮与差旅'),
            throwsA(predicate((e) =>
                e is TestFailure &&
                e.toString().contains('App $canaryKey file bytes 0') &&
                e.toString().contains(damagedHash) &&
                e.toString().contains(hashes.first))));
      } finally {
        await privateFile.writeAsBytes(originalBytes);
      }
      await checkDevice(b, keys, hashes, changed: true, parentName: '餐饮与差旅');
      evidence['assertionCanary'] = {
        'kind': 'deliberately altered local byte',
        'transaction': canaryKey,
        'attachmentOrder': 0,
        'expectedSha256': hashes.first,
        'injectedSha256': damagedHash,
        'specificMismatchDetected': true,
        'originalRestored': true
      };
      evidence['status'] = 'PASS';
      await mark(stage);
    } catch (error) {
      evidence['status'] = 'FAIL';
      evidence['firstFailedStage'] = stage;
      evidence['error'] = error.toString();
      await file
          .writeAsString(const JsonEncoder.withIndent('  ').convert(evidence));
      rethrow;
    }
  }, timeout: const Timeout(Duration(minutes: 5)));
}
