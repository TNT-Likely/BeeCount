import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai/privacy/ai_privacy_consent.dart';
import '../../l10n/app_localizations.dart';
import '../../pages/settings/privacy_policy_page.dart';
import '../../providers/ai_privacy_consent_providers.dart';
import '../../providers/theme_providers.dart';

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
    final l10n = AppLocalizations.of(context);
    final primary = ref.watch(primaryColorProvider);
    return AlertDialog(
      title: Text(l10n.aiConsentTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.aiConsentBody, style: const TextStyle(height: 1.5)),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const PrivacyPolicyPage()),
                ),
                child: Text(l10n.aboutPrivacyPolicy,
                    style: TextStyle(color: primary)),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: primary),
          onPressed: () => Navigator.pop(context, true),
          child: Text(l10n.aiConsentAgree),
        ),
      ],
    );
  }
}
