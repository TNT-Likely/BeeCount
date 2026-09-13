import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:beecount/providers/sync_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('BeeCount Cloud UI auth and SyncEngine share one auth instance',
      () async {
    const config = CloudServiceConfig(
      type: CloudBackendType.beecountCloud,
      name: 'BeeCount Cloud',
      beecountCloudBaseUrl: 'https://cloud.example.com',
      beecountCloudApiPrefix: '/api/v1',
    );
    final container = ProviderContainer(
      overrides: [
        activeCloudConfigProvider.overrideWith((ref) async => config),
      ],
    );
    addTearDown(container.dispose);

    // 真机上 Mine/云服务页会先 watch UI auth，同步引擎随后
    // eager-load provider。主线在这个顺序下会各自创建一套 auth。
    final authFuture = container.read(authServiceProvider.future);
    final providerFuture = container.read(beecountCloudProviderInstance.future);

    final auth = await authFuture;
    final provider = await providerFuture;

    expect(provider, isNotNull);
    expect(
      identical(auth, provider!.auth),
      isTrue,
      reason: 'UI 与同步引擎不应持有两套独立 session',
    );
  });
}
