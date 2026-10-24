import 'package:beecount/providers/font_scale_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ProviderContainer container;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    container = ProviderContainer();
    await container.read(fontScaleInitProvider.future);
  });
  tearDown(() => container.dispose());
  test('冷启动裁剪旧偏好，已存自定义仍优先于档位', () async {
    container.dispose();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('fontScaleLevel', 99);
    await prefs.setDouble('customFontScale', 9);
    container = ProviderContainer();
    await container.read(fontScaleInitProvider.future);
    expect(container.read(fontScaleLevelProvider), 4);
    expect(container.read(customFontScaleProvider), 1.5);
    expect(container.read(effectiveFontScaleProvider), 1.5);
  });
  test('先选快捷档再自定义倍率，保留新倍率并归零档位', () async {
    container.read(fontScaleLevelProvider.notifier).state = 2;
    await pumpEventQueue();
    expect(container.read(effectiveFontScaleProvider), 1.16);
    container.read(customFontScaleProvider.notifier).state = 1.23;
    await pumpEventQueue();
    expect(container.read(fontScaleLevelProvider), 0);
    expect(container.read(customFontScaleProvider), 1.23);
    expect(container.read(effectiveFontScaleProvider), 1.23);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('fontScaleLevel'), 0);
    expect(prefs.getDouble('customFontScale'), 1.23);
  });
  test('快速连续调整后只保留最后一次倍率，快捷档可清除自定义', () async {
    container.read(fontScaleLevelProvider.notifier).state = 4;
    for (final value in [1.11, 1.17, 1.23, 1.48]) {
      container.read(customFontScaleProvider.notifier).state = value;
    }
    await pumpEventQueue(times: 100);
    expect(container.read(effectiveFontScaleProvider), 1.48);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getDouble('customFontScale'), 1.48);
    container.read(fontScaleLevelProvider.notifier).state = -3;
    await pumpEventQueue();
    expect(container.read(customFontScaleProvider), 1);
    expect(container.read(effectiveFontScaleProvider), .8);
    expect(prefs.getInt('fontScaleLevel'), -3);
    expect(prefs.getDouble('customFontScale'), 1);
  });
}
