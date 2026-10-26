import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../ai/providers/ai_provider_config.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/ai_chat_providers.dart';
import '../../../services/system/logger_service.dart';
import '../../../utils/website_urls.dart';
import '../../../widgets/ui/toast.dart';
import 'ai_provider_editor_controller.dart';

final aiProviderConnectionTesterProvider = Provider<AIProviderConnectionTester>(
    (ref) => const ProductionAIProviderConnectionTester());

class AIProviderEditor extends ConsumerStatefulWidget {
  const AIProviderEditor({super.key, this.provider});
  final AIServiceProviderConfig? provider;
  @override
  ConsumerState<AIProviderEditor> createState() => _AIProviderEditorState();
}

class _AIProviderEditorState extends ConsumerState<AIProviderEditor> {
  AIProviderEditorController? controller;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    controller ??= AIProviderEditorController(
        l: AppLocalizations.of(context),
        original: widget.provider,
        tester: ref.read(aiProviderConnectionTesterProvider),
        onCapabilities: (cfg, cap) =>
            ref.read(agentModelCapabilityServiceProvider).cache(cfg, cap));
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = controller!, l = AppLocalizations.of(context);
    return AnimatedBuilder(
        animation: c,
        builder: (context, _) => BeeDialog(
                title: Text(widget.provider == null
                    ? l.aiProviderAddTitle
                    : l.aiProviderEditTitle),
                content: _fields(c, l),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(l.commonCancel)),
                  FilledButton(
                      onPressed: c.saving || c.busy
                          ? null
                          : () async {
                              final result = await c.save();
                              if (!context.mounted) return;
                              if (result.$1) {
                                showToast(context, l.commonSaved);
                                Navigator.pop(context, true);
                              } else if (result.$2 != null) {
                                showToast(context, result.$2!);
                              }
                            },
                      child: c.saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(l.commonSave)),
                ]));
  }

  Widget _fields(AIProviderEditorController c, AppLocalizations l) {
    Widget testField(ProviderTestCapability capability, String title,
        TextEditingController input,
        {bool secret = false}) {
      final status = c.statuses[capability]!,
          busy = status == TestStatus.testing;
      return BeeAIModelTestField(
          title: title,
          testLabel: switch (status) {
            TestStatus.idle => l.aiCloudApiTestKey,
            TestStatus.testing => l.aiProviderTestRunning,
            TestStatus.success => l.aiProviderTestSuccess,
            TestStatus.failed => l.aiProviderTestFailed
          },
          busy: busy,
          tone: status == TestStatus.success
              ? BeeTone.success
              : status == TestStatus.failed
                  ? BeeTone.error
                  : BeeTone.neutral,
          detail: secret && status != TestStatus.failed
              ? null
              : c.details[capability],
          onTest: (secret ? c.key.text.isNotEmpty : c.canTest(capability))
              ? () async {
                  final message = await c.test(capability);
                  if (mounted && message != null) showToast(context, message);
                }
              : null,
          field: BeeField(
              label: title,
              showLabel: false,
              controller: input,
              obscure: secret && c.obscure,
              hint:
                  secret ? l.aiCloudApiKeyHintCustom : c.modelHint(capability),
              helper:
                  !secret && input.text.isEmpty ? l.aiModelInputHelper : null,
              suffixIcon: !secret
                  ? null
                  : BeeIconButton(
                      label:
                          c.obscure ? l.aiProviderShowKey : l.aiProviderHideKey,
                      icon: BeeLineIcon(c.obscure ? 'EyeOff' : 'Eye', size: 18),
                      onPressed: c.toggleObscure)));
    }

    final allSuccess = c.statuses.values.every((s) => s == TestStatus.success),
        anyFailed = c.statuses.values.contains(TestStatus.failed);
    return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.aiProviderBasicInfo,
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 14),
          BeeField(
              label: l.aiProviderName,
              controller: c.name,
              hint: l.aiProviderNameHint,
              enabled: !c.builtIn),
          const SizedBox(height: 14),
          BeeField(
              label: 'Base URL',
              controller: c.url,
              hint: 'https://api.example.com/v1',
              helper: c.builtIn ? null : l.aiCustomBaseUrlHelper,
              enabled: !c.builtIn),
          const SizedBox(height: 10),
          testField(ProviderTestCapability.text, 'API Key', c.key,
              secret: true),
          if (c.builtIn) ...[
            const SizedBox(height: 8),
            Text(l.aiCloudApiKeyHelper,
                style: TextStyle(
                    fontSize: 11, color: Theme.of(context).hintColor)),
            Wrap(alignment: WrapAlignment.spaceBetween, children: [
              TextButton(
                  onPressed: () => _openKey(), child: Text(l.aiCloudApiGetKey)),
              TextButton(
                  onPressed: () => _openTutorial(),
                  child: Text(l.aiCloudApiTutorial))
            ])
          ],
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 14),
          Text(l.aiProviderModels,
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(l.aiProviderModelsHint,
              style:
                  TextStyle(fontSize: 11, color: Theme.of(context).hintColor)),
          const SizedBox(height: 6),
          testField(ProviderTestCapability.text, l.aiTextModelTitle, c.text),
          const SizedBox(height: 8),
          testField(
              ProviderTestCapability.vision, l.aiVisionModelTitle, c.vision),
          const SizedBox(height: 8),
          testField(
              ProviderTestCapability.speech, l.aiAudioModelTitle, c.speech),
          const SizedBox(height: 14),
          BeeButton(
              label: c.busy
                  ? l.aiProviderTestRunning
                  : allSuccess
                      ? l.aiProviderTestSuccess
                      : anyFailed
                          ? l.aiProviderTestAllRetry
                          : l.aiProviderTestAll,
              kind: BeeButtonKind.secondary,
              onPressed: c.busy || c.key.text.isEmpty ? null : c.testAll,
              icon: const BeeLineIcon('RefreshCw', size: 18)),
        ]);
  }

  Future<void> _openKey() async {
    final uri = Uri.parse(WebsiteUrls.glmInvite);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        logger.warning('AIProviderEditPage', '无法打开邀请链接: $uri');
      }
    } catch (e) {
      logger.error('AIProviderEditPage', '打开邀请链接失败: $uri', e);
    }
  }

  Future<void> _openTutorial() async {
    final uri = Uri.parse(
        WebsiteUrls.docsAi('overview', Localizations.localeOf(context)));
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
