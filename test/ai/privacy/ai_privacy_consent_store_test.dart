import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:beecount/ai/privacy/ai_privacy_consent.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('从未同意:readVersion=0,isConsented=false', () async {
    SharedPreferences.setMockInitialValues({});
    expect(await AiPrivacyConsentStore.readVersion(), 0);
    expect(await AiPrivacyConsentStore.isConsented(), isFalse);
  });

  test('accept 后:版本落为当前版本,isConsented=true', () async {
    SharedPreferences.setMockInitialValues({});
    await AiPrivacyConsentStore.accept();
    expect(await AiPrivacyConsentStore.readVersion(), kAiPrivacyConsentVersion);
    expect(await AiPrivacyConsentStore.isConsented(), isTrue);
  });

  test('旧版本同意(版本号更低)视为未同意,需重新征得', () async {
    SharedPreferences.setMockInitialValues({
      'ai_privacy_consent_version': kAiPrivacyConsentVersion - 1,
    });
    expect(await AiPrivacyConsentStore.isConsented(), isFalse);
  });
}
