import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:beecount/ai/providers/ai_provider_factory.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('未同意隐私时 chat 立即抛错(提示去同意)', () async {
    SharedPreferences.setMockInitialValues({}); // 无同意记录
    await expectLater(
      () => AIProviderFactory.chat('你好'),
      throwsA(predicate((e) => e.toString().contains('同意'))),
    );
  });
}
