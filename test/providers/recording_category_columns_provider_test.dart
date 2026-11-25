import 'package:beecount/providers/recording_category_columns_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const key = RecordingCategoryColumns.preferenceKey;

  for (final saved in <Object?>[null, 4, 5, 6, 5.0, '5']) {
    test(
        'loads the supported layout for a stored value of ${saved.runtimeType}: $saved',
        () async {
      SharedPreferences.setMockInitialValues({if (saved != null) key: saved});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        await container.read(recordingCategoryColumnsProvider.future),
        saved is int && saved == 5 ? 5 : 4,
      );
    });
  }

  test('persists changes and restores the last selection', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final setting = container.read(recordingCategoryColumnsProvider.notifier);
    final preferences = await SharedPreferences.getInstance();

    await setting.setColumns(5);
    expect(container.read(recordingCategoryColumnsProvider).requireValue, 5);
    expect(preferences.getInt(key), 5);

    await Future.wait([setting.setColumns(4), setting.setColumns(5)]);
    final reopened = ProviderContainer();
    addTearDown(reopened.dispose);
    expect(await reopened.read(recordingCategoryColumnsProvider.future), 5);
    expect(preferences.getInt(key), 5);
    expect(() => setting.setColumns(3), throwsArgumentError);
  });
}
