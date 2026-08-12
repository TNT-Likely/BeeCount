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

    final provider = await container.read(beecountCloudProviderInstance.future);
    final auth = await container.read(authServiceProvider.future);

    expect(provider, isNotNull);
    expect(identical(auth, provider!.auth), isTrue);
  });
}
