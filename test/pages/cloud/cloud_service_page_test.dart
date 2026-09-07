import 'package:flutter/material.dart';
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:beecount/l10n/app_localizations.dart';
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
          beecountCloudProviderInstance
              .overrideWith((ref) async => fakeProvider),
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
}
