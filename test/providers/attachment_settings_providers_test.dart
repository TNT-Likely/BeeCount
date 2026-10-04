import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:beecount/providers/attachment_settings_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('original attachment mode defaults to off', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(
        await container.read(attachmentKeepOriginalProvider.future), isFalse);
  });

  test('the preference is restored in a new container and can be disabled',
      () async {
    SharedPreferences.setMockInitialValues({});
    final first = ProviderContainer();
    await first.read(attachmentKeepOriginalProvider.future);
    await first.read(attachmentKeepOriginalProvider.notifier).setEnabled(true);
    first.dispose();

    final restored = ProviderContainer();
    addTearDown(restored.dispose);
    expect(await restored.read(attachmentKeepOriginalProvider.future), isTrue);
    await restored
        .read(attachmentKeepOriginalProvider.notifier)
        .setEnabled(false);
    expect(restored.read(attachmentKeepOriginalProvider).value, isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(
        prefs.getBool(AttachmentKeepOriginalNotifier.preferenceKey), isFalse);
  });
}
