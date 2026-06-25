import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ai/privacy/ai_privacy_consent.dart';

/// 已同意的文案版本(响应式)。0 = 从未同意。
class AiPrivacyConsentNotifier extends StateNotifier<int> {
  AiPrivacyConsentNotifier() : super(0) {
    _load();
  }

  Future<void> _load() async {
    final v = await AiPrivacyConsentStore.readVersion();
    if (mounted) state = v;
  }

  Future<void> accept() async {
    await AiPrivacyConsentStore.accept();
    if (mounted) state = kAiPrivacyConsentVersion;
  }
}

final aiPrivacyConsentProvider =
    StateNotifierProvider<AiPrivacyConsentNotifier, int>(
        (ref) => AiPrivacyConsentNotifier());

/// 是否已对当前文案版本同意(供响应式 UI watch)。
final aiPrivacyConsentedProvider = Provider<bool>((ref) {
  return ref.watch(aiPrivacyConsentProvider) >= kAiPrivacyConsentVersion;
});
