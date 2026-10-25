import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai/privacy/ai_privacy_consent.dart';
import '../../l10n/app_localizations.dart';
import '../../pages/settings/privacy_policy_page.dart';
import '../../providers/ai_privacy_consent_providers.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart';

/// 确保已取得"AI 第三方数据共享"的同意。
///
/// 已同意 → 直接返回 true;未同意 → 弹出不可绕过的同意页,
/// 用户点「同意并开启」返回 true 并落库,点「取消」返回 false。
Future<bool> ensureAiPrivacyConsent(BuildContext context, WidgetRef ref) async {
  if (await AiPrivacyConsentStore.isConsented()) return true;
  if (!context.mounted) return false;
  final agreed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const AiPrivacyConsentDialog(),
      ) ??
      false;
  if (agreed) {
    await ref.read(aiPrivacyConsentProvider.notifier).accept();
  }
  return agreed;
}

class AiPrivacyConsentDialog extends ConsumerWidget {
  const AiPrivacyConsentDialog({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    return BeeDialog(
        showClose: false,
        title: Text(l.aiConsentTitle),
        content: BeeAIConsentContent(
            description: l.aiConsentBody,
            policyLabel: l.aboutPrivacyPolicy,
            onPolicy: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                    builder: (_) => const PrivacyPolicyPage()))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l.commonCancel)),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l.aiConsentAgree)),
        ]);
  }
}
