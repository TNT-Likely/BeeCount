import 'package:flutter/material.dart';
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/cloud/cloud_session_manager.dart';
import 'package:beecount/pages/cloud/cloud_service_page.dart';
import 'package:beecount/providers/sync_providers.dart';

import '../../cloud/sync/_fakes/fake_beecount_cloud_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({'multi_device_sync': false});
  });

  testWidgets('BeeCount Cloud 测试连接复用主 provider', (tester) async {
    const config = CloudServiceConfig(
      type: CloudBackendType.beecountCloud,
      name: 'BeeCount Cloud',
      beecountCloudBaseUrl: 'https://cloud.example.com',
      beecountCloudApiPrefix: '/api/v1',
    );
    final fakeProvider = FakeBeeCountCloudProvider();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeCloudConfigProvider.overrideWith((ref) async => config),
          beecountCloudConfigProvider.overrideWith((ref) async => config),
          webdavConfigProvider.overrideWith((ref) async => null),
          s3ConfigProvider.overrideWith((ref) async => null),
          activeCloudServicesProvider.overrideWith((ref) async => CloudSession(
              config, (provider: fakeProvider, auth: fakeProvider.auth))),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: const CloudServicePage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.wifi_find));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(fakeProvider.storageListCallCount, 1);

    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
  });

  testWidgets('S3 connection test retries failed initialization once',
      (tester) async {
    const config = CloudServiceConfig(
      type: CloudBackendType.s3,
      name: 'S3',
      s3Endpoint: 's3.example.com',
      s3AccessKey: 'test',
      s3SecretKey: 'test',
      s3Bucket: 'test',
    );
    final fake = FakeBeeCountCloudProvider();
    var attempts = 0;
    final manager = CloudSessionManager(factory: (_) async {
      if (++attempts == 1) throw StateError('offline');
      return (provider: fake, auth: fake.auth);
    });
    final container = ProviderContainer(overrides: [
      cloudSessionManagerProvider.overrideWithValue(manager),
      activeCloudConfigProvider.overrideWith((ref) async => config),
      s3ConfigProvider.overrideWith((ref) async => config),
      beecountCloudConfigProvider.overrideWith((ref) async => null),
      webdavConfigProvider.overrideWith((ref) async => null),
    ]);
    await expectLater(container.read(activeCloudServicesProvider.future),
        throwsStateError);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: const CloudServicePage(),
      ),
    ));
    await tester.pumpAndSettle();
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.byIcon(Icons.wifi_find));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(attempts, 2);
      expect(fake.storageListCallCount, i + 1);
      await tester.tap(find.text('确定'));
      await tester.pumpAndSettle();
    }
    await tester.pumpWidget(const SizedBox());
    // Flush the logger's delayed write timer before fake-async teardown.
    await tester.pump(const Duration(seconds: 3));
    container.dispose();
    final closing = manager.dispose();
    await tester.pumpAndSettle();
    await closing;
  });
}
