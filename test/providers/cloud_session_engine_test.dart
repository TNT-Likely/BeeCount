import 'package:drift/native.dart';
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:beecount/cloud/cloud_session_manager.dart';
import 'package:beecount/cloud/sync/sync_providers.dart';
import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/providers/database_providers.dart';
import 'package:beecount/providers/sync_providers.dart';
import '../cloud/sync/_fakes/fake_beecount_cloud_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('configuration switch closes the cached engine and rejects its old key',
      () async {
    SharedPreferences.setMockInitialValues({});
    final db = BeeDatabase.forTesting(NativeDatabase.memory());
    var config = const CloudServiceConfig(
        type: CloudBackendType.beecountCloud,
        name: 'A',
        beecountCloudBaseUrl: 'https://a.example');
    final manager = CloudSessionManager(factory: (_) async {
      final p = FakeBeeCountCloudProvider();
      return (provider: p, auth: p.auth);
    });
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      repositoryProvider.overrideWithValue(LocalRepository(db)),
      cloudSessionManagerProvider.overrideWithValue(manager),
      activeCloudConfigProvider.overrideWith((ref) async => config),
    ]);
    addTearDown(() async {
      container.dispose();
      await manager.dispose();
      await db.close();
    });
    final oldProvider =
        (await container.read(beecountCloudProviderInstance.future))!;
    final oldEngine = container.read(syncEngineProvider(oldProvider));
    container.invalidate(activeCloudConfigProvider);
    expect(await container.read(beecountCloudProviderInstance.future),
        same(oldProvider));
    expect(container.read(syncEngineProvider(oldProvider)), same(oldEngine));
    config = const CloudServiceConfig(
        type: CloudBackendType.beecountCloud,
        name: 'B',
        beecountCloudBaseUrl: 'https://b.example');
    container.invalidate(activeCloudConfigProvider);
    final newProvider =
        (await container.read(beecountCloudProviderInstance.future))!;
    expect(newProvider, isNot(same(oldProvider)));
    expect((await oldEngine.sync(ledgerId: '1')).hasError, isTrue);
    expect(() => container.read(syncEngineProvider(oldProvider)),
        throwsStateError);
    expect(container.read(syncEngineProvider(newProvider)),
        isNot(same(oldEngine)));
  });
}
