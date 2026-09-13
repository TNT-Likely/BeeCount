import 'dart:async';

import 'package:beecount/cloud/sync/change_tracker.dart';
import 'package:beecount/cloud/sync/sync_engine.dart';
import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '_fakes/fake_beecount_cloud_provider.dart';

class GatedProvider extends FakeBeeCountCloudProvider {
  final started = Completer<void>();
  final release = Completer<void>();
  int calls = 0;

  @override
  Future<List<BeeCountCloudReadLedger>> readLedgers() async {
    calls++;
    started.complete();
    await release.future;
    return super.readLedgers();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('replacement engine waits but fetches its own server result', () async {
    SharedPreferences.setMockInitialValues({});
    final db = BeeDatabase.forTesting(NativeDatabase.memory());
    final first = GatedProvider();
    final second = GatedProvider();
    SyncEngine makeEngine(GatedProvider provider) => SyncEngine(
          db: db,
          provider: provider,
          changeTracker: ChangeTracker(db),
          repo: LocalRepository(db),
        );
    final oldEngine = makeEngine(first);
    final newEngine = makeEngine(second);
    addTearDown(() async {
      oldEngine.dispose();
      newEngine.dispose();
      await db.close();
    });
    final oldWork = oldEngine.syncLedgersFromServer();
    await first.started.future;
    oldEngine.dispose();
    final newWork = newEngine.syncLedgersFromServer();
    await Future<void>.delayed(Duration.zero);
    expect(second.calls, 0);
    first.release.complete();
    await oldWork;
    await second.started.future;
    expect(second.calls, 1);
    second.release.complete();
    await newWork;
  });
}
